#!/usr/bin/env python3
"""教材原本（Google Spreadsheet）を Supabase へ片方向で同期する。

使い方は docs/operations/sync-sheet-to-supabase.md にある。

- シートの数字をそのまま DB の整数IDにし、IDごとに上書きする。何度流しても同じ結果になる。
- 生成するSQLは1トランザクションで、ASCIIだけで書く（docs/decisions/usl-286-ascii-only-sql.md）。
- 画像と音声の状態は、Storage にファイルがあるかを DB の中で調べて決める。
  ファイルを置いたあとにもう一度流せば present になる。
- シートから消えた行は DB から消さない。デッキのカードだけ is_active = false にする。
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import re
import subprocess
import sys
import tempfile
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

DEFAULT_SHEET_ID = "1BNTVknQmhmQdZFwOztsKtBSuk6TaPiVeVBij8cMpPso"
PRODUCTION_PROJECT_REF = "udvmzaodsrgwecfybkry"
REPO_ROOT = Path(__file__).resolve().parents[1]
MAX_ID = 999_999
CEFR_LEVELS = {"A1", "A2", "B1", "B2", "C1", "C2"}

SHEET_COLUMNS: dict[str, tuple[str, ...]] = {
    "01_core_words": ("word_id", "word_text"),
    "01_core_senses": (
        "sense_id", "word_id", "priority", "part_of_speech_jp", "part_of_speech_en",
        "definition_jp", "cefr_level", "pronunciation_ipa", "pronunciation_kana", "etymology",
        "synonyms", "antonyms", "inflections", "derivatives", "collocations", "related",
    ),
    "02_content_concepts": ("concept_id", "concept_code", "concept_name", "description", "is_active"),
    "02_content_examples": (
        "example_id", "sense_id", "concept_id", "sentence_en", "sentence_jp", "image_asset_path",
    ),
    "03_audio_pronunciations": ("pronunciation_id", "word_id", "audio_asset_path", "voice_label"),
    "03_audio_example_audio": ("example_audio_id", "example_id", "audio_asset_path", "voice_label"),
    "04_decks": ("deck_id", "deck_name", "concept_id"),
    "04_deck_words": ("deck_id", "sense_id"),
}


class SyncError(Exception):
    def __init__(self, errors: list[str]) -> None:
        super().__init__(f"{len(errors)} problem(s) in the sheet")
        self.errors = errors


# ---------------------------------------------------------------- reading

def http_get(url: str) -> str:
    with urllib.request.urlopen(url, timeout=60) as response:  # noqa: S310 - fixed Google host
        return response.read().decode("utf-8")


def fetch_csvs(sheet_id: str) -> dict[str, str]:
    """公開シートの8枚を CSV で読む。タブの gid はシートの名前から探す。"""
    base = f"https://docs.google.com/spreadsheets/d/{sheet_id}"
    html = http_get(f"{base}/htmlview")
    gids = dict(re.findall(r'\{name: "([^"]+)", pageUrl: "[^"]*", gid: "(\d+)"', html))
    missing = [name for name in SHEET_COLUMNS if name not in gids]
    if missing:
        raise SyncError([f"sheet tabs not found: {', '.join(missing)}"])
    return {name: http_get(f"{base}/export?format=csv&gid={gids[name]}") for name in SHEET_COLUMNS}


def read_csv_dir(directory: Path) -> dict[str, str]:
    return {
        name: (directory / f"{name}.csv").read_text(encoding="utf-8")
        for name in SHEET_COLUMNS
        if (directory / f"{name}.csv").exists()
    }


def read_rows(name: str, text: str | None, errors: list[str]) -> list[tuple[int, dict[str, str]]]:
    if text is None:
        errors.append(f"{name}: sheet is missing")
        return []
    reader = csv.DictReader(io.StringIO(text))
    header = reader.fieldnames or []
    missing = [column for column in SHEET_COLUMNS[name] if column not in header]
    if missing:
        errors.append(f"{name}: missing columns {', '.join(missing)}")
        return []
    rows = []
    for line, row in enumerate(reader, start=2):
        values = {column: (row.get(column) or "").strip() for column in SHEET_COLUMNS[name]}
        if any(values.values()):
            rows.append((line, values))
    return rows


# ---------------------------------------------------------------- checking

def parse_id(value: str, label: str, errors: list[str]) -> int | None:
    if not re.fullmatch(r"\d+", value) or not 0 < int(value) <= MAX_ID:
        errors.append(f"{label}: {value!r} is not an ID from 1 to {MAX_ID}")
        return None
    return int(value)


def require(value: str, label: str, errors: list[str]) -> str:
    if not value:
        errors.append(f"{label}: must not be empty")
    return value


def text_list(value: str, label: str, errors: list[str]) -> list[str] | None:
    if not value:
        return None
    items = [item.strip() for item in value.split("/&/")]
    if not all(items):
        errors.append(f"{label}: has an empty item between /&/ separators")
    return [item for item in items if item]


def shelf(record_id: int) -> str:
    return f"{record_id // 1000:03d}"


def image_path(concept_code: str, example_id: int) -> str:
    return f"content-images/{concept_code}/{shelf(example_id)}/example-{example_id:06d}.webp"


def example_audio_path(concept_code: str, example_id: int) -> str:
    return f"content-audio/example/{concept_code}/{shelf(example_id)}/example-{example_id:06d}.mp3"


def word_audio_path(pronunciation_id: int) -> str:
    return f"content-audio/word/{shelf(pronunciation_id)}/pron-{pronunciation_id:06d}.mp3"


def check_path(sheet_value: str, expected: str, label: str, errors: list[str]) -> None:
    if sheet_value and sheet_value != expected:
        errors.append(f"{label}: path {sheet_value!r} must be {expected!r}")


def check_unique(ids: list[int | None], label: str, errors: list[str]) -> None:
    duplicates = sorted(key for key, count in Counter(i for i in ids if i is not None).items() if count > 1)
    if duplicates:
        errors.append(f"{label}: duplicate IDs {duplicates[:10]}")


def build_document(csvs: dict[str, str]) -> dict[str, list[dict[str, Any]]]:
    """シートを DB へ入れる形に直す。問題があれば全部集めて SyncError にする。"""
    errors: list[str] = []
    sheets = {name: read_rows(name, csvs.get(name), errors) for name in SHEET_COLUMNS}
    if errors:
        raise SyncError(errors)

    def at(name: str, line: int, column: str) -> str:
        return f"{name} line {line} {column}"

    concepts = []
    for line, row in sheets["02_content_concepts"]:
        active = row["is_active"].upper()
        if active not in {"TRUE", "FALSE"}:
            errors.append(f"{at('02_content_concepts', line, 'is_active')}: must be TRUE or FALSE")
        code = require(row["concept_code"], at("02_content_concepts", line, "concept_code"), errors)
        if code and not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", code):
            errors.append(f"{at('02_content_concepts', line, 'concept_code')}: {code!r} must be lowercase letters, digits and hyphens")
        concepts.append({
            "id": parse_id(row["concept_id"], at("02_content_concepts", line, "concept_id"), errors),
            "concept_code": code,
            "concept_name": require(row["concept_name"], at("02_content_concepts", line, "concept_name"), errors),
            "description": row["description"] or None,
            "is_active": active == "TRUE",
        })
    concept_codes = {c["id"]: c["concept_code"] for c in concepts}

    words = [
        {
            "id": parse_id(row["word_id"], at("01_core_words", line, "word_id"), errors),
            "word_text": require(row["word_text"], at("01_core_words", line, "word_text"), errors),
        }
        for line, row in sheets["01_core_words"]
    ]
    word_ids = {w["id"] for w in words}

    senses = []
    for line, row in sheets["01_core_senses"]:
        label = lambda column: at("01_core_senses", line, column)  # noqa: E731
        word_id = parse_id(row["word_id"], label("word_id"), errors)
        if word_id is not None and word_id not in word_ids:
            errors.append(f"{label('word_id')}: word {word_id} is not in 01_core_words")
        priority = parse_id(row["priority"], label("priority"), errors)
        cefr = row["cefr_level"].upper() or None
        if cefr and cefr not in CEFR_LEVELS:
            errors.append(f"{label('cefr_level')}: {row['cefr_level']!r} must be A1 to C2 or empty")
        inflections = None
        if row["inflections"]:
            try:
                inflections = json.loads(row["inflections"])
            except json.JSONDecodeError as error:
                errors.append(f"{label('inflections')}: not JSON ({error.msg})")
            else:
                if not isinstance(inflections, dict):
                    errors.append(f"{label('inflections')}: must be a JSON object")
        senses.append({
            "id": parse_id(row["sense_id"], label("sense_id"), errors),
            "word_id": word_id,
            "priority": priority,
            "part_of_speech_jp": row["part_of_speech_jp"] or None,
            "part_of_speech_en": require(row["part_of_speech_en"], label("part_of_speech_en"), errors),
            "definition_jp": require(row["definition_jp"], label("definition_jp"), errors),
            "cefr_level": cefr,
            "pronunciation_ipa": row["pronunciation_ipa"] or None,
            "pronunciation_kana": row["pronunciation_kana"] or None,
            "etymology": row["etymology"] or None,
            "synonyms": text_list(row["synonyms"], label("synonyms"), errors),
            "antonyms": text_list(row["antonyms"], label("antonyms"), errors),
            "inflections": inflections,
            "derivatives": text_list(row["derivatives"], label("derivatives"), errors),
            "collocations": text_list(row["collocations"], label("collocations"), errors),
            "related": text_list(row["related"], label("related"), errors),
        })
    sense_words = {s["id"]: s["word_id"] for s in senses}

    examples = []
    order_in_group: Counter[tuple[Any, Any]] = Counter()
    for line, row in sheets["02_content_examples"]:
        label = lambda column: at("02_content_examples", line, column)  # noqa: E731
        example_id = parse_id(row["example_id"], label("example_id"), errors)
        sense_id = parse_id(row["sense_id"], label("sense_id"), errors)
        concept_id = parse_id(row["concept_id"], label("concept_id"), errors)
        if sense_id is not None and sense_id not in sense_words:
            errors.append(f"{label('sense_id')}: sense {sense_id} is not in 01_core_senses")
        if concept_id is not None and concept_id not in concept_codes:
            errors.append(f"{label('concept_id')}: concept {concept_id} is not in 02_content_concepts")
        code = concept_codes.get(concept_id)
        path = None
        if example_id is not None and code:
            path = image_path(code, example_id)
            check_path(row["image_asset_path"], path, label("image_asset_path"), errors)
        order_in_group[(sense_id, concept_id)] += 1
        examples.append({
            "id": example_id,
            "meaning_id": sense_id,
            "concept_id": concept_id,
            "theme": code,
            "sentence_en": require(row["sentence_en"], label("sentence_en"), errors),
            "sentence_jp": require(row["sentence_jp"], label("sentence_jp"), errors),
            "image_path": path,
            "display_order": order_in_group[(sense_id, concept_id)],
        })
    example_concepts = {e["id"]: concept_codes.get(e["concept_id"]) for e in examples}

    def audio_rows(name: str, id_column: str, parent_column: str, parents: set[Any], path_of) -> tuple[list[dict[str, Any]], int]:
        rows, skipped = [], 0
        order: Counter[Any] = Counter()
        for line, row in sheets[name]:
            label = lambda column: at(name, line, column)  # noqa: E731
            record_id = parse_id(row[id_column], label(id_column), errors)
            parent_id = parse_id(row[parent_column], label(parent_column), errors)
            if parent_id is not None and parent_id not in parents:
                errors.append(f"{label(parent_column)}: {parent_id} does not exist")
            path = path_of(record_id, parent_id) if record_id is not None and parent_id is not None else None
            if path:
                check_path(row["audio_asset_path"], path, label("audio_asset_path"), errors)
            if not row["voice_label"]:
                # 音声をまだ用意していない行（docs/decisions/audio-path-built-by-import-20260915.md）
                skipped += 1
                continue
            order[parent_id] += 1
            rows.append({
                "id": record_id,
                "parent_id": parent_id,
                "path": path,
                "voice_label": row["voice_label"],
                "is_primary": order[parent_id] == 1,
                "display_order": order[parent_id],
            })
        return rows, skipped

    pronunciations, skipped_pronunciations = audio_rows(
        "03_audio_pronunciations", "pronunciation_id", "word_id", word_ids,
        lambda record_id, _parent: word_audio_path(record_id),
    )
    example_audio, skipped_example_audio = audio_rows(
        "03_audio_example_audio", "example_audio_id", "example_id", set(example_concepts),
        lambda _record_id, parent: example_audio_path(example_concepts[parent], parent)
        if example_concepts.get(parent) else None,
    )

    decks = []
    for line, row in sheets["04_decks"]:
        concept_id = parse_id(row["concept_id"], at("04_decks", line, "concept_id"), errors)
        if concept_id is not None and concept_id not in concept_codes:
            errors.append(f"{at('04_decks', line, 'concept_id')}: concept {concept_id} is not in 02_content_concepts")
        decks.append({
            "id": parse_id(row["deck_id"], at("04_decks", line, "deck_id"), errors),
            "deck_name": require(row["deck_name"], at("04_decks", line, "deck_name"), errors),
            "concept_id": concept_id,
        })
    deck_ids = {d["id"] for d in decks}

    deck_words = []
    positions: Counter[Any] = Counter()
    seen_words: dict[Any, set[Any]] = defaultdict(set)
    for line, row in sheets["04_deck_words"]:
        deck_id = parse_id(row["deck_id"], at("04_deck_words", line, "deck_id"), errors)
        sense_id = parse_id(row["sense_id"], at("04_deck_words", line, "sense_id"), errors)
        if deck_id is not None and deck_id not in deck_ids:
            errors.append(f"{at('04_deck_words', line, 'deck_id')}: deck {deck_id} is not in 04_decks")
        word_id = sense_words.get(sense_id)
        if sense_id is not None and word_id is None:
            errors.append(f"{at('04_deck_words', line, 'sense_id')}: sense {sense_id} is not in 01_core_senses")
        if word_id is not None and word_id in seen_words[deck_id]:
            errors.append(f"{at('04_deck_words', line, 'sense_id')}: deck {deck_id} already has word {word_id}")
        seen_words[deck_id].add(word_id)
        deck_words.append({
            "deck_id": deck_id,
            "word_id": word_id,
            "meaning_id": sense_id,
            "sort_order": positions[deck_id],
        })
        positions[deck_id] += 1

    check_unique([c["id"] for c in concepts], "02_content_concepts concept_id", errors)
    check_unique([w["id"] for w in words], "01_core_words word_id", errors)
    check_unique([s["id"] for s in senses], "01_core_senses sense_id", errors)
    check_unique([e["id"] for e in examples], "02_content_examples example_id", errors)
    check_unique([p["id"] for p in pronunciations], "03_audio_pronunciations pronunciation_id", errors)
    check_unique([a["id"] for a in example_audio], "03_audio_example_audio example_audio_id", errors)
    check_unique([d["id"] for d in decks], "04_decks deck_id", errors)

    if errors:
        raise SyncError(errors)
    return {
        "concepts": concepts,
        "words": words,
        "senses": senses,
        "examples": examples,
        "pronunciations": pronunciations,
        "example_audio": example_audio,
        "decks": decks,
        "deck_words": deck_words,
        "skipped": [
            {"sheet": "03_audio_pronunciations", "rows": skipped_pronunciations},
            {"sheet": "03_audio_example_audio", "rows": skipped_example_audio},
        ],
    }


# ---------------------------------------------------------------- SQL

def sql_text(value: Any) -> str:
    """文字列リテラルを ASCII だけで書く。非ASCIIは U&'\\XXXX' にする。"""
    if value is None:
        return "null"
    text = str(value)
    if text.isascii():
        return "'" + text.replace("'", "''") + "'"
    parts: list[str] = []
    for character in text:
        code_point = ord(character)
        if character == "'":
            parts.append("''")
        elif character == "\\":
            parts.append("\\\\")
        elif code_point < 128:
            parts.append(character)
        elif code_point <= 0xFFFF:
            parts.append(f"\\{code_point:04X}")
        else:
            parts.append(f"\\+{code_point:06X}")
    return "U&'" + "".join(parts) + "'"


def sql_value(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, list):
        return "array[" + ", ".join(sql_text(item) for item in value) + "]::text[]"
    return sql_text(value)


def sql_json(value: Any) -> str:
    if value is None:
        return "null"
    return sql_text(json.dumps(value, ensure_ascii=True, separators=(",", ":"))) + "::jsonb"


def insert_values(table: str, columns: tuple[str, ...], rows: list[tuple[str, ...]], chunk: int = 300) -> str:
    statements = []
    for start in range(0, len(rows), chunk):
        values = ",\n".join("  (" + ", ".join(row) + ")" for row in rows[start:start + chunk])
        statements.append(f"insert into {table} ({', '.join(columns)}) values\n{values};")
    return "\n".join(statements)


STAGING = """
create temp table sync_concepts (id integer primary key, concept_code text, concept_name text, description text, is_active boolean);
create temp table sync_words (id integer primary key, word_text text);
create temp table sync_senses (id integer primary key, word_id integer, priority integer, part_of_speech_jp text,
  part_of_speech_en text, definition_jp text, cefr_level text, pronunciation_ipa text, pronunciation_kana text,
  etymology text, synonyms text[], antonyms text[], inflections jsonb, derivatives jsonb, collocations jsonb, related text[]);
create temp table sync_examples (id integer primary key, meaning_id integer, concept_id integer, theme text,
  sentence_en text, sentence_jp text, image_path text, display_order integer);
create temp table sync_pronunciations (id integer primary key, word_id integer, path text, voice_label text,
  is_primary boolean, display_order integer);
create temp table sync_example_audio (id integer primary key, example_id integer, path text, voice_label text,
  is_primary boolean, display_order integer);
create temp table sync_decks (id integer primary key, deck_name text, concept_id integer);
create temp table sync_deck_words (deck_id integer, word_id integer, meaning_id integer, sort_order integer,
  primary key (deck_id, word_id));
"""

# Storage にファイルがあるか。path は "<bucket>/<object name>"。
def object_exists(path_sql: str) -> str:
    return (
        "exists (select 1 from storage.objects o where o.bucket_id = split_part("
        f"{path_sql}, '/', 1) and o.name = substr({path_sql}, strpos({path_sql}, '/') + 1))"
    )


APPLY = f"""
do $$
begin
  if exists (select 1 from public.decks d join sync_decks s on s.id = d.id where d.owner_id is not null) then
    raise exception 'sheet sync stopped: a deck_id in 04_decks belongs to a personal deck';
  end if;
end $$;

insert into public.content_concepts (id, concept_code, concept_name, description, is_active)
select id, concept_code, concept_name, description, is_active from sync_concepts
on conflict (id) do update set concept_code = excluded.concept_code, concept_name = excluded.concept_name,
  description = excluded.description, is_active = excluded.is_active;

insert into public.words (id, word_text)
select id, word_text from sync_words
on conflict (id) do update set word_text = excluded.word_text;

insert into public.word_meanings (id, word_id, priority, part_of_speech_jp, part_of_speech_en, definition_jp,
  cefr_level, pronunciation_ipa, pronunciation_kana, etymology, synonyms, antonyms, inflections, derivatives,
  collocations, related)
select id, word_id, priority, part_of_speech_jp, part_of_speech_en, definition_jp, cefr_level, pronunciation_ipa,
  pronunciation_kana, etymology, synonyms, antonyms, inflections, derivatives, collocations, related
from sync_senses
on conflict (id) do update set word_id = excluded.word_id, priority = excluded.priority,
  part_of_speech_jp = excluded.part_of_speech_jp, part_of_speech_en = excluded.part_of_speech_en,
  definition_jp = excluded.definition_jp, cefr_level = excluded.cefr_level,
  pronunciation_ipa = excluded.pronunciation_ipa, pronunciation_kana = excluded.pronunciation_kana,
  etymology = excluded.etymology, synonyms = excluded.synonyms, antonyms = excluded.antonyms,
  inflections = excluded.inflections, derivatives = excluded.derivatives,
  collocations = excluded.collocations, related = excluded.related;

insert into public.example_contents (id, meaning_id, concept_id, theme, sentence_en, sentence_jp,
  image_asset_path, image_state, audio_asset_path, display_order)
select s.id, s.meaning_id, s.concept_id, s.theme, s.sentence_en, s.sentence_jp,
  case when {object_exists('s.image_path')} then s.image_path end,
  case when {object_exists('s.image_path')} then 'present' else 'blank' end,
  (select a.path from sync_example_audio a where a.example_id = s.id and a.is_primary and {object_exists('a.path')}),
  s.display_order
from sync_examples s
on conflict (id) do update set meaning_id = excluded.meaning_id, concept_id = excluded.concept_id,
  theme = excluded.theme, sentence_en = excluded.sentence_en, sentence_jp = excluded.sentence_jp,
  image_asset_path = excluded.image_asset_path, image_state = excluded.image_state,
  audio_asset_path = excluded.audio_asset_path, display_order = excluded.display_order;

-- At most one primary voice per word/example. Clear it first so a swap does not hit the unique index.
update public.word_pronunciations set is_primary = false
where is_primary and word_id in (select word_id from sync_pronunciations);

insert into public.word_pronunciations (id, word_id, accent, ipa, ipa_state, audio_asset_path, audio_state,
  voice_label, is_primary, display_order)
select id, word_id, 'US', null, 'blank',
  case when {object_exists('path')} then path end,
  case when {object_exists('path')} then 'present' else 'blank' end,
  voice_label, is_primary, display_order
from sync_pronunciations
on conflict (id) do update set word_id = excluded.word_id, accent = excluded.accent, ipa = excluded.ipa,
  ipa_state = excluded.ipa_state, audio_asset_path = excluded.audio_asset_path,
  audio_state = excluded.audio_state, voice_label = excluded.voice_label,
  is_primary = excluded.is_primary, display_order = excluded.display_order;

update public.example_audio set is_primary = false
where is_primary and example_id in (select example_id from sync_example_audio);

insert into public.example_audio (id, example_id, audio_asset_path, audio_state, voice_label, is_primary,
  display_order)
select id, example_id,
  case when {object_exists('path')} then path end,
  case when {object_exists('path')} then 'present' else 'blank' end,
  voice_label, is_primary, display_order
from sync_example_audio
on conflict (id) do update set example_id = excluded.example_id, audio_asset_path = excluded.audio_asset_path,
  audio_state = excluded.audio_state, voice_label = excluded.voice_label,
  is_primary = excluded.is_primary, display_order = excluded.display_order;

insert into public.decks (id, deck_name, concept_id)
select id, deck_name, concept_id from sync_decks
on conflict (id) do update set deck_name = excluded.deck_name, concept_id = excluded.concept_id;

insert into public.cards (word_id, card_template_id, deck_id, sort_order, primary_meaning_id, is_active)
select d.word_id, t.id, d.deck_id, d.sort_order, d.meaning_id, true
from sync_deck_words d
cross join public.card_templates t
where t.is_active
on conflict (word_id, card_template_id, deck_id) do update set sort_order = excluded.sort_order,
  primary_meaning_id = excluded.primary_meaning_id, is_active = true;

-- Hide, never delete, cards whose word left the sheet deck: study records still point at them.
update public.cards c set is_active = false
where c.is_active
  and c.deck_id in (select id from sync_decks)
  and not exists (select 1 from sync_deck_words d where d.deck_id = c.deck_id and d.word_id = c.word_id);

select setval(pg_get_serial_sequence('public.' || t, 'id'), greatest(m, 1))
from (values
  ('content_concepts', (select max(id) from public.content_concepts)),
  ('words', (select max(id) from public.words)),
  ('word_meanings', (select max(id) from public.word_meanings)),
  ('example_contents', (select max(id) from public.example_contents)),
  ('word_pronunciations', (select max(id) from public.word_pronunciations)),
  ('example_audio', (select max(id) from public.example_audio)),
  ('decks', (select max(id) from public.decks))
) as seq(t, m)
where pg_get_serial_sequence('public.' || t, 'id') is not null;
"""

SUMMARY = """
select
  (select count(*) from sync_words) as words,
  (select count(*) from sync_senses) as meanings,
  (select count(*) from sync_examples) as examples,
  (select count(*) from public.example_contents e join sync_examples s using (id) where e.image_state = 'present') as images_present,
  (select count(*) from public.example_audio a join sync_example_audio s using (id) where a.audio_state = 'present') as example_audio_present,
  (select count(*) from public.word_pronunciations p join sync_pronunciations s using (id) where p.audio_state = 'present') as word_audio_present,
  (select count(*) from public.cards c where c.deck_id in (select id from sync_decks) and c.is_active) as active_cards,
  (select count(*) from public.cards c where c.deck_id in (select id from sync_decks) and not c.is_active) as hidden_cards,
  (select count(*) from public.word_meanings m where m.word_id in (select id from sync_words)
     and m.id not in (select id from sync_senses)) as meanings_not_in_sheet,
  (select count(*) from public.decks d where d.owner_id is null and d.id not in (select id from sync_decks)) as official_decks_not_in_sheet
"""


def render_sql(document: dict[str, list[dict[str, Any]]], *, dry_run: bool) -> str:
    parts = [
        "-- Generated by scripts/sync-sheet-to-supabase.py. Do not edit; do not commit (contains lesson text).",
        "begin;",
        STAGING,
        insert_values("sync_concepts", ("id", "concept_code", "concept_name", "description", "is_active"), [
            (sql_value(c["id"]), sql_text(c["concept_code"]), sql_text(c["concept_name"]),
             sql_text(c["description"]), sql_value(c["is_active"]))
            for c in document["concepts"]
        ]),
        insert_values("sync_words", ("id", "word_text"), [
            (sql_value(w["id"]), sql_text(w["word_text"])) for w in document["words"]
        ]),
        insert_values("sync_senses", (
            "id", "word_id", "priority", "part_of_speech_jp", "part_of_speech_en", "definition_jp",
            "cefr_level", "pronunciation_ipa", "pronunciation_kana", "etymology", "synonyms", "antonyms",
            "inflections", "derivatives", "collocations", "related",
        ), [
            (sql_value(s["id"]), sql_value(s["word_id"]), sql_value(s["priority"]),
             sql_text(s["part_of_speech_jp"]), sql_text(s["part_of_speech_en"]), sql_text(s["definition_jp"]),
             sql_text(s["cefr_level"]), sql_text(s["pronunciation_ipa"]), sql_text(s["pronunciation_kana"]),
             sql_text(s["etymology"]), sql_value(s["synonyms"]), sql_value(s["antonyms"]),
             sql_json(s["inflections"]), sql_json(s["derivatives"]), sql_json(s["collocations"]),
             sql_value(s["related"]))
            for s in document["senses"]
        ]),
        insert_values("sync_examples", (
            "id", "meaning_id", "concept_id", "theme", "sentence_en", "sentence_jp", "image_path", "display_order",
        ), [
            (sql_value(e["id"]), sql_value(e["meaning_id"]), sql_value(e["concept_id"]), sql_text(e["theme"]),
             sql_text(e["sentence_en"]), sql_text(e["sentence_jp"]), sql_text(e["image_path"]),
             sql_value(e["display_order"]))
            for e in document["examples"]
        ]),
        insert_values("sync_pronunciations", ("id", "word_id", "path", "voice_label", "is_primary", "display_order"), [
            (sql_value(p["id"]), sql_value(p["parent_id"]), sql_text(p["path"]), sql_text(p["voice_label"]),
             sql_value(p["is_primary"]), sql_value(p["display_order"]))
            for p in document["pronunciations"]
        ]),
        insert_values("sync_example_audio", ("id", "example_id", "path", "voice_label", "is_primary", "display_order"), [
            (sql_value(a["id"]), sql_value(a["parent_id"]), sql_text(a["path"]), sql_text(a["voice_label"]),
             sql_value(a["is_primary"]), sql_value(a["display_order"]))
            for a in document["example_audio"]
        ]),
        insert_values("sync_decks", ("id", "deck_name", "concept_id"), [
            (sql_value(d["id"]), sql_text(d["deck_name"]), sql_value(d["concept_id"])) for d in document["decks"]
        ]),
        insert_values("sync_deck_words", ("deck_id", "word_id", "meaning_id", "sort_order"), [
            (sql_value(d["deck_id"]), sql_value(d["word_id"]), sql_value(d["meaning_id"]), sql_value(d["sort_order"]))
            for d in document["deck_words"]
        ]),
        APPLY,
    ]
    if dry_run:
        parts.append(
            "do $$ declare summary jsonb; begin\n"
            f"  select to_jsonb(s) into summary from ({SUMMARY}) s;\n"
            "  raise exception 'SHEET_SYNC_DRY_RUN rolled back: %', summary;\nend $$;"
        )
    else:
        parts.append("commit;")
        parts.append(SUMMARY + ";")
    sql = "\n\n".join(part for part in parts if part)
    offenders = sorted({character for character in sql if not character.isascii()})
    if offenders:
        raise SyncError([f"generated SQL contains non-ASCII characters: {offenders[:5]}"])
    return sql


# ---------------------------------------------------------------- commands

def load_document(args: argparse.Namespace) -> dict[str, list[dict[str, Any]]]:
    csvs = read_csv_dir(Path(args.from_dir)) if args.from_dir else fetch_csvs(args.sheet_id)
    document = build_document(csvs)
    counts = ", ".join(f"{key} {len(value)}" for key, value in document.items() if key != "skipped")
    print(f"sheet ok: {counts}", file=sys.stderr)
    for skipped in document["skipped"]:
        if skipped["rows"]:
            print(f"  skipped {skipped['rows']} rows without voice_label in {skipped['sheet']}", file=sys.stderr)
    return document


def command_fetch(args: argparse.Namespace) -> int:
    output = Path(args.output_dir)
    output.mkdir(parents=True, exist_ok=True)
    for name, text in fetch_csvs(args.sheet_id).items():
        (output / f"{name}.csv").write_text(text, encoding="utf-8")
    print(f"saved {len(SHEET_COLUMNS)} sheets to {output}")
    return 0


def command_check(args: argparse.Namespace) -> int:
    load_document(args)
    return 0


def command_render(args: argparse.Namespace) -> int:
    sql = render_sql(load_document(args), dry_run=args.dry_run)
    Path(args.output).write_text(sql, encoding="utf-8")
    print(f"wrote {args.output} ({len(sql):,} bytes)")
    return 0


def local_db_container() -> str:
    config = (REPO_ROOT / "supabase" / "config.toml").read_text(encoding="utf-8")
    match = re.search(r'^project_id\s*=\s*"([^"]+)"', config, re.MULTILINE)
    return f"supabase_db_{match.group(1) if match else REPO_ROOT.name}"


def command_sync(args: argparse.Namespace) -> int:
    if args.target == "production" and not args.dry_run and args.confirm_production != PRODUCTION_PROJECT_REF:
        print(
            f"refused: writing to production needs --confirm-production {PRODUCTION_PROJECT_REF} "
            "(get approval first; try --dry-run)",
            file=sys.stderr,
        )
        return 2
    sql = render_sql(load_document(args), dry_run=args.dry_run)
    if args.target == "local":
        # `supabase db query --local` accepts one statement only, so use psql inside the local DB container.
        result = subprocess.run(
            ["docker", "exec", "-i", local_db_container(), "psql", "-U", "postgres", "-d", "postgres",
             "-v", "ON_ERROR_STOP=1", "-q", "-f", "-"],
            input=sql, capture_output=True, text=True,
        )
    else:
        with tempfile.TemporaryDirectory(prefix="usalingo-sheet-sync-") as directory:
            path = Path(directory) / "sync.sql"
            path.write_text(sql, encoding="utf-8")
            result = subprocess.run(
                ["supabase", "db", "query", "--file", str(path), "--linked",
                 "--project-ref", PRODUCTION_PROJECT_REF, "--workdir", str(REPO_ROOT)],
                capture_output=True, text=True,
            )
    output = (result.stdout + result.stderr).strip()
    if args.dry_run and "SHEET_SYNC_DRY_RUN" in output:
        # psql prints the summary as plain JSON; the Management API returns it inside an escaped JSON string.
        summary = re.search(r"SHEET_SYNC_DRY_RUN rolled back: (\{.*?\})", re.sub(r'\\+"', '"', output))
        print("dry run ok (nothing was written):")
        try:
            print(json.dumps(json.loads(summary.group(1)), indent=2))
        except (AttributeError, json.JSONDecodeError):
            print(output)
        return 0
    print(output)
    return result.returncode


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = root.add_subparsers(dest="command", required=True)

    def source_options(command: argparse.ArgumentParser) -> None:
        command.add_argument("--sheet-id", default=DEFAULT_SHEET_ID)
        command.add_argument("--from-dir", help="read <sheet name>.csv files from this directory instead of Google")

    fetch = commands.add_parser("fetch", help="save the 8 sheets as CSV")
    fetch.add_argument("--sheet-id", default=DEFAULT_SHEET_ID)
    fetch.add_argument("--output-dir", required=True)
    fetch.set_defaults(handler=command_fetch)

    check = commands.add_parser("check", help="read and check the sheet without touching a database")
    source_options(check)
    check.set_defaults(handler=command_check)

    render = commands.add_parser("render", help="write the sync SQL to a file")
    source_options(render)
    render.add_argument("--output", required=True)
    render.add_argument("--dry-run", action="store_true", help="end with a rollback that reports the result")
    render.set_defaults(handler=command_render)

    sync = commands.add_parser("sync", help="check the sheet and write it to a database")
    source_options(sync)
    sync.add_argument("--target", choices=("local", "production"), required=True)
    sync.add_argument("--dry-run", action="store_true", help="run everything, report, then roll back")
    sync.add_argument("--confirm-production", help=f"must be {PRODUCTION_PROJECT_REF} to write to production")
    sync.set_defaults(handler=command_sync)
    return root


def main() -> int:
    args = parser().parse_args()
    try:
        return args.handler(args)
    except SyncError as error:
        print(f"stopped: {error}", file=sys.stderr)
        for message in error.errors[:50]:
            print(f"  - {message}", file=sys.stderr)
        if len(error.errors) > 50:
            print(f"  ... and {len(error.errors) - 50} more", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

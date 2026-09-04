#!/usr/bin/env python3
"""Build validated, idempotent SQL for the first TARGET-1900 content batch.

The source Anki database and generated JSON/SQL are operator-local artifacts.
This script never connects to Supabase and never writes to the Anki collection.
"""

from __future__ import annotations

import argparse
import hashlib
import html
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import sqlite3
import sys
from typing import Any, Iterable


DECK_ID = 1_748_673_634_399
NOTETYPE_ID = 1_751_695_639_914
DECK_CODE = "target-1900-image"
DECK_NAME = "TARGET-1900 Images 0001-0050"
FIELD_NAMES = [
    "Anki｜Field｜W&V&I｜00｜Index",
    "Anki｜Field｜W&V&I｜00｜Number",
    "Anki｜Field｜W&V&I｜01｜Stage",
    "Anki｜Field｜W&V&I｜02｜English word",
    "Anki｜Field｜W&V&I｜02-voice｜English word",
    "Anki｜Field｜W&V&I｜03｜Part of speech",
    "Anki｜Field｜W&V&I｜04｜Example sentence",
    "Anki｜Field｜W&V&I｜04-voice｜Example sentence",
    "Anki｜Field｜W&V&I｜05｜Example sentence image",
    "Anki｜Field｜W&V&I｜06｜Japanese word",
    "Anki｜Field｜W&V&I｜07｜Translation of example sentece",
    "Anki｜Field｜W&V&I｜08｜Etymology",
    "Anki｜Field｜W&V&I｜09｜Synonym",
    "Anki｜Field｜W&V&I｜99｜Temp-Memo",
]
POS_MAP = {
    "名詞": "noun",
    "動詞": "verb",
    "形容詞": "adjective",
    "副詞": "adverb",
    "前置詞": "preposition",
    "接続詞": "conjunction",
}
WORD_BASE = 1_000
MEANING_BASE = 2_000
EXAMPLE_BASE = 3_000
PRONUNCIATION_BASE = 4_000
EXAMPLE_AUDIO_BASE = 5_000
DECK_DB_ID = 286
# デッキの説明とライセンスは配信先の利用者に見える値なので、検証用の文言を残さない。
# 権利の確認結果は docs/decisions/usl-284-material-rights.md にある。
DECK_DESCRIPTION = "TARGET-1900 source positions 1-50. Words, meanings, examples, images and audio created by the rights holder using generative AI."
DECK_LICENSE = "proprietary-rights-holder"


class TextExtractor(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag.lower() in {"br", "p", "div", "li"}:
            self.parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() in {"p", "div", "li"}:
            self.parts.append("\n")

    def handle_data(self, data: str) -> None:
        self.parts.append(data)


class ImageExtractor(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.sources: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag.lower() != "img":
            return
        for key, value in attrs:
            if key.lower() == "src" and value:
                self.sources.append(html.unescape(value))


def plain_text(value: str) -> str:
    parser = TextExtractor()
    parser.feed(value)
    lines = [" ".join(line.split()) for line in "".join(parser.parts).splitlines()]
    return "\n".join(line for line in lines if line).strip()


def sound_filename(value: str) -> str:
    matches = re.findall(r"\[sound:([^\]]+)\]", value)
    return matches[0].strip() if len(matches) == 1 else ""


def image_filename(value: str) -> str:
    parser = ImageExtractor()
    parser.feed(value)
    return parser.sources[0].strip() if len(parser.sources) == 1 else ""


def asset_range(value: int) -> str:
    start = (value // 500) * 500
    return f"{start:04d}-{start + 499:04d}"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def media_record(media_dir: Path, filename: str, planned_path: str) -> dict[str, Any]:
    source = media_dir / filename
    try:
        safe_source = source.resolve(strict=True)
        safe_source.relative_to(media_dir.resolve(strict=True))
    except (FileNotFoundError, ValueError):
        return {"source_file": filename, "planned_asset_path": planned_path, "exists": False}
    if not filename or Path(filename).name != filename or not safe_source.is_file():
        return {"source_file": filename, "planned_asset_path": planned_path, "exists": False}
    return {
        "source_file": filename,
        "planned_asset_path": planned_path,
        "exists": True,
        "size_bytes": safe_source.stat().st_size,
        "sha256": sha256_file(safe_source),
    }


def sqlite_connection(path: Path) -> sqlite3.Connection:
    uri = f"file:{path.resolve()}?mode=ro&immutable=1"
    return sqlite3.connect(uri, uri=True)


def extract_anki(collection: Path, media_dir: Path) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    with sqlite_connection(collection) as database:
        fields = [
            row[0]
            for row in database.execute(
                "select name from fields where ntid = ? order by ord", (NOTETYPE_ID,)
            )
        ]
        if fields != FIELD_NAMES:
            errors.append("notetype fields do not match the 14-field USL-280 contract")

        deck = database.execute("select name from decks where id = ?", (DECK_ID,)).fetchone()
        note_type = database.execute(
            "select name from notetypes where id = ?", (NOTETYPE_ID,)
        ).fetchone()
        if not deck:
            errors.append(f"Anki deck id {DECK_ID} was not found")
        if not note_type:
            errors.append(f"Anki notetype id {NOTETYPE_ID} was not found")

        rows = database.execute(
            """
            select distinct n.guid, n.flds
            from notes as n
            join cards as c on c.nid = n.id
            where n.mid = ? and c.did = ?
            """,
            (NOTETYPE_ID, DECK_ID),
        ).fetchall()

    entries: list[dict[str, Any]] = []
    for guid, packed_fields in rows:
        values = packed_fields.split("\x1f")
        if len(values) != len(FIELD_NAMES):
            errors.append(f"note {guid}: expected 14 fields, found {len(values)}")
            continue
        number_text = plain_text(values[1]).lstrip("0") or "0"
        if not number_text.isdigit():
            errors.append(f"note {guid}: Number is not numeric")
            continue
        position = int(number_text)
        if not 1 <= position <= 50:
            continue

        word = plain_text(values[3])
        parts_jp = [plain_text(item) for item in values[5].split("／")]
        definitions = [plain_text(item) for item in values[9].split("／")]
        if len(parts_jp) != len(definitions):
            errors.append(f"position {position}: part-of-speech and definition counts differ")
            continue
        if len(parts_jp) > 1:
            warnings.append(
                f"position {position}: example is assigned to priority 1; review before production"
            )

        senses: list[dict[str, Any]] = []
        for priority, (part_jp, definition) in enumerate(zip(parts_jp, definitions), start=1):
            part_en = POS_MAP.get(part_jp)
            if not part_en:
                errors.append(f"position {position}: unsupported part of speech {part_jp!r}")
                part_en = ""
            senses.append(
                {
                    "id": MEANING_BASE + position * 10 + priority,
                    "priority": priority,
                    "part_of_speech_en": part_en,
                    "part_of_speech_jp": part_jp,
                    "definition_jp": definition,
                    "etymology": plain_text(values[11]) or None,
                }
            )

        example_id = EXAMPLE_BASE + position
        pronunciation_id = PRONUNCIATION_BASE + position
        word_audio = sound_filename(values[4])
        example_audio = sound_filename(values[7])
        image = image_filename(values[8])
        image_path = f"content-images/simple/{asset_range(example_id)}/{example_id}.webp"
        word_audio_path = (
            f"content-audio/word/{asset_range(pronunciation_id)}/{pronunciation_id}.mp3"
        )
        example_audio_path = (
            f"content-audio/example/simple/{asset_range(example_id)}/{example_id}.mp3"
        )
        entries.append(
            {
                "source": {
                    "note_guid": guid,
                    "deck_code": DECK_CODE,
                    "position": position,
                    "index": plain_text(values[0]),
                    "stage": plain_text(values[2]),
                    "synonym_raw": plain_text(values[12]) or None,
                },
                "word": {"id": WORD_BASE + position, "word_text": word},
                "senses": senses,
                "example": {
                    "id": example_id,
                    "meaning_id": senses[0]["id"] if senses else None,
                    "concept_code": "simple",
                    "sentence_en": plain_text(values[6]),
                    "sentence_jp": plain_text(values[10]),
                    "display_order": 1,
                    "image": media_record(media_dir, image, image_path),
                    "audio": media_record(media_dir, example_audio, example_audio_path),
                },
                "pronunciation": {
                    "id": pronunciation_id,
                    "accent": "unspecified",
                    "ipa": None,
                    "ipa_state": "blank",
                    "voice_label": "default",
                    "is_primary": True,
                    "display_order": 1,
                    "audio": media_record(media_dir, word_audio, word_audio_path),
                },
                "forms": {},
                "relations": {},
            }
        )

    entries.sort(key=lambda item: item["source"]["position"])
    document = {
        "schema_version": 1,
        "source": {
            "kind": "anki",
            "deck_id": DECK_ID,
            "deck_name": deck[0] if deck else None,
            "notetype_id": NOTETYPE_ID,
            "notetype_name": note_type[0] if note_type else None,
            "collection_sha256": sha256_file(collection),
        },
        "batch": {"deck_code": DECK_CODE, "positions": [1, 50], "expected_words": 50},
        "entries": entries,
        "validation": {"errors": errors, "warnings": warnings},
    }
    document["validation"]["errors"].extend(validate_document(document))
    document["validation"]["errors"] = sorted(set(document["validation"]["errors"]))
    return document


def required_text(value: Any, label: str, errors: list[str]) -> None:
    if not isinstance(value, str) or not value.strip():
        errors.append(f"{label} is required")


def validate_document(document: dict[str, Any]) -> list[str]:
    recorded_errors = document.get("validation", {}).get("errors", [])
    errors: list[str] = [str(error) for error in recorded_errors]
    if document.get("schema_version") != 1:
        errors.append("schema_version must be 1")
    entries = document.get("entries")
    if not isinstance(entries, list):
        return ["entries must be an array"]
    if len(entries) != 50:
        errors.append(f"expected 50 entries, found {len(entries)}")

    positions: list[int] = []
    words: list[str] = []
    guids: list[str] = []
    for entry in entries:
        source = entry.get("source", {})
        word = entry.get("word", {})
        position = source.get("position")
        if not isinstance(position, int):
            errors.append(f"source position {position!r} must be an integer")
            continue
        positions.append(position)
        guids.append(source.get("note_guid"))
        words.append(str(word.get("word_text", "")).casefold())
        if source.get("deck_code") != DECK_CODE:
            errors.append(f"position {position}: deck_code must be {DECK_CODE}")
        if word.get("id") != WORD_BASE + position:
            errors.append(f"position {position}: word id does not match the reserved range")
        required_text(source.get("note_guid"), f"position {position} note_guid", errors)
        required_text(word.get("word_text"), f"position {position} word_text", errors)
        senses = entry.get("senses", [])
        if not senses:
            errors.append(f"position {position}: at least one sense is required")
        for sense in senses:
            priority = sense.get("priority")
            if not isinstance(priority, int) or priority < 1:
                errors.append(f"position {position}: sense priority must be a positive integer")
            elif sense.get("id") != MEANING_BASE + position * 10 + priority:
                errors.append(f"position {position}: meaning id does not match the reserved range")
            required_text(
                sense.get("part_of_speech_en"), f"position {position} part_of_speech_en", errors
            )
            required_text(sense.get("definition_jp"), f"position {position} definition_jp", errors)
        example = entry.get("example", {})
        if example.get("id") != EXAMPLE_BASE + position:
            errors.append(f"position {position}: example id does not match the reserved range")
        if senses and example.get("meaning_id") != senses[0].get("id"):
            errors.append(f"position {position}: example must reference the priority-1 meaning")
        required_text(example.get("sentence_en"), f"position {position} sentence_en", errors)
        required_text(example.get("sentence_jp"), f"position {position} sentence_jp", errors)
        pronunciation = entry.get("pronunciation", {})
        if pronunciation.get("id") != PRONUNCIATION_BASE + position:
            errors.append(f"position {position}: pronunciation id does not match the reserved range")
        for label, media in (
            ("image", example.get("image", {})),
            ("example audio", example.get("audio", {})),
            ("word audio", entry.get("pronunciation", {}).get("audio", {})),
        ):
            required_text(media.get("source_file"), f"position {position} {label} source_file", errors)
            if not media.get("exists"):
                errors.append(f"position {position}: {label} source file is missing")
            required_text(
                media.get("planned_asset_path"), f"position {position} {label} asset path", errors
            )
        expected_paths = {
            "image": f"content-images/simple/{asset_range(EXAMPLE_BASE + position)}/"
            f"{EXAMPLE_BASE + position}.webp",
            "example audio": f"content-audio/example/simple/"
            f"{asset_range(EXAMPLE_BASE + position)}/{EXAMPLE_BASE + position}.mp3",
            "word audio": f"content-audio/word/{asset_range(PRONUNCIATION_BASE + position)}/"
            f"{PRONUNCIATION_BASE + position}.mp3",
        }
        actual_paths = {
            "image": example.get("image", {}).get("planned_asset_path"),
            "example audio": example.get("audio", {}).get("planned_asset_path"),
            "word audio": pronunciation.get("audio", {}).get("planned_asset_path"),
        }
        for label, expected in expected_paths.items():
            if actual_paths[label] != expected:
                errors.append(f"position {position}: {label} asset path does not match its fixed id")
        if not isinstance(entry.get("forms"), dict):
            errors.append(f"position {position}: forms must be an object")
        if not isinstance(entry.get("relations"), dict):
            errors.append(f"position {position}: relations must be an object")

    if sorted(positions) != list(range(1, 51)):
        errors.append("source positions must be exactly 1 through 50")
    if len(set(positions)) != len(positions):
        errors.append("source positions contain duplicates")
    if len(set(words)) != len(words):
        errors.append("word_text contains case-insensitive duplicates")
    if len(set(guids)) != len(guids):
        errors.append("source note GUIDs contain duplicates")
    return sorted(set(errors))


def sql_text(value: Any) -> str:
    """SQLの文字列リテラルを、必ずASCIIだけで書き出す。

    2026-09-04に本番で事故を起こした。日本語をそのまま書いたSQLを
    クリップボード経由でSupabaseのSQL Editorへ貼ったところ、UTF-8のバイト列が
    Mac Romanとして読まれ、`挑戦` が `Êåëʈ¶` として保存された。
    生成物をASCIIだけにしておけば、どの経路を通っても文字が化けない。

    非ASCIIを含む場合は PostgreSQL の Unicode エスケープ `U&'\\6311\\6226'` を使う。
    """
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


def sql_bool(value: bool) -> str:
    return "true" if value else "false"


def values_sql(rows: Iterable[Iterable[Any]]) -> str:
    return ",\n".join("  (" + ", ".join(sql_text(value) for value in row) + ")" for row in rows)


def render_sql(document: dict[str, Any]) -> str:
    errors = validate_document(document)
    if errors:
        raise ValueError("cannot render invalid content:\n- " + "\n- ".join(errors))
    entries = document["entries"]
    words = [
        (
            entry["word"]["id"],
            entry["word"]["word_text"],
            entry["source"]["note_guid"],
            entry["source"]["deck_code"],
            entry["source"]["position"],
        )
        for entry in entries
    ]
    meanings = [
        (
            sense["id"],
            entry["word"]["id"],
            sense["priority"],
            sense["part_of_speech_en"],
            sense["part_of_speech_jp"],
            sense["definition_jp"],
            sense.get("etymology"),
        )
        for entry in entries
        for sense in entry["senses"]
    ]
    examples = [
        (
            entry["example"]["id"],
            entry["example"]["meaning_id"],
            entry["example"]["sentence_en"],
            entry["example"]["sentence_jp"],
            entry["example"]["image"]["planned_asset_path"],
            entry["example"]["audio"]["planned_asset_path"],
            entry["example"]["display_order"],
        )
        for entry in entries
    ]
    pronunciations = [
        (
            entry["pronunciation"]["id"],
            entry["word"]["id"],
            entry["pronunciation"]["accent"],
            entry["pronunciation"]["ipa"],
            entry["pronunciation"]["ipa_state"],
            entry["pronunciation"]["audio"]["planned_asset_path"],
            "unverified",
            entry["pronunciation"]["voice_label"],
            entry["pronunciation"]["is_primary"],
            entry["pronunciation"]["display_order"],
        )
        for entry in entries
    ]
    example_audio = [
        (
            EXAMPLE_AUDIO_BASE + entry["source"]["position"],
            entry["example"]["id"],
            entry["example"]["audio"]["planned_asset_path"],
            "unverified",
            "default",
            True,
            1,
        )
        for entry in entries
    ]
    extras = [
        (
            entry["word"]["id"],
            json.dumps(entry["forms"], ensure_ascii=False, separators=(",", ":")),
            json.dumps(entry["relations"], ensure_ascii=False, separators=(",", ":")),
        )
        for entry in entries
    ]

    return f"""-- Generated by scripts/prepare-official-content.py. LOCAL ONLY.
-- Media paths are planned paths with state=unverified; no Storage objects are uploaded here.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create temporary table import_words (
  id integer primary key, word_text text not null, source_note_guid text not null,
  source_deck_code text not null, source_position integer not null
) on commit drop;
insert into import_words values
{values_sql(words)};

do $$
begin
  if (select count(*) from import_words) <> 50
     or (select count(distinct source_position) from import_words) <> 50 then
    raise exception 'USL-286 import stopped: the batch is not exactly 50 unique positions.';
  end if;
  if exists (
    select 1 from public.words existing join import_words incoming on existing.id = incoming.id
    where existing.source_note_guid is distinct from incoming.source_note_guid
       or existing.source_deck_code is distinct from incoming.source_deck_code
       or existing.source_position is distinct from incoming.source_position
  ) or exists (
    select 1 from public.words existing join import_words incoming
      on existing.word_text = incoming.word_text
      or existing.source_note_guid = incoming.source_note_guid
      or (existing.source_deck_code = incoming.source_deck_code
          and existing.source_position = incoming.source_position)
    where existing.id <> incoming.id
  ) then
    raise exception 'USL-286 import stopped: an existing word owns a reserved id or source key.';
  end if;
end
$$;

insert into public.words (id, word_text, source_note_guid, source_deck_code, source_position)
select * from import_words
on conflict (id) do update set
  word_text = excluded.word_text,
  source_note_guid = excluded.source_note_guid,
  source_deck_code = excluded.source_deck_code,
  source_position = excluded.source_position,
  updated_at = now();

create temporary table import_meanings (
  id integer primary key, word_id integer not null, priority integer not null,
  part_of_speech_en text not null, part_of_speech_jp text,
  definition_jp text not null, etymology text
) on commit drop;
insert into import_meanings values
{values_sql(meanings)};

do $$
begin
  if exists (
    select 1 from public.word_meanings existing join import_meanings incoming using (id)
    where existing.word_id <> incoming.word_id or existing.priority <> incoming.priority
  ) then
    raise exception 'USL-286 import stopped: a meaning reserved id belongs to another row.';
  end if;
end
$$;

insert into public.word_meanings (
  id, word_id, priority, part_of_speech_en, part_of_speech_jp, definition_jp, etymology
)
select * from import_meanings
on conflict (id) do update set
  word_id = excluded.word_id, priority = excluded.priority,
  part_of_speech_en = excluded.part_of_speech_en,
  part_of_speech_jp = excluded.part_of_speech_jp,
  definition_jp = excluded.definition_jp, etymology = excluded.etymology,
  updated_at = now();

create temporary table import_examples (
  id integer primary key, meaning_id integer not null, sentence_en text not null,
  sentence_jp text not null, image_asset_path text not null,
  audio_asset_path text not null, display_order integer not null
) on commit drop;
insert into import_examples values
{values_sql(examples)};

do $$
begin
  if exists (
    select 1 from public.example_contents existing join import_examples incoming using (id)
    where existing.meaning_id <> incoming.meaning_id
  ) then
    raise exception 'USL-286 import stopped: an example reserved id belongs to another row.';
  end if;
end
$$;

insert into public.example_contents (
  id, meaning_id, theme, sentence_en, sentence_jp, image_asset_path,
  audio_asset_path, concept_id, image_state, display_order
)
select examples.id, examples.meaning_id, 'simple', examples.sentence_en,
  examples.sentence_jp, examples.image_asset_path, examples.audio_asset_path,
  concept.id, 'unverified', examples.display_order
from import_examples examples
join public.content_concepts concept on concept.concept_code = 'simple'
on conflict (id) do update set
  meaning_id = excluded.meaning_id, theme = excluded.theme,
  sentence_en = excluded.sentence_en, sentence_jp = excluded.sentence_jp,
  image_asset_path = excluded.image_asset_path,
  audio_asset_path = excluded.audio_asset_path,
  concept_id = excluded.concept_id, image_state = excluded.image_state,
  display_order = excluded.display_order, updated_at = now();

-- The V5 compatibility trigger maps every inserted non-null path to present.
-- These paths are only planned until USL-288 uploads and reads back the media.
update public.example_contents
set image_state = 'unverified'
where id in (select id from import_examples);

create temporary table import_pronunciations (
  id integer primary key, word_id integer not null, accent text not null, ipa text,
  ipa_state text not null, audio_asset_path text not null, audio_state text not null,
  voice_label text not null, is_primary boolean not null, display_order integer not null
) on commit drop;
insert into import_pronunciations values
{values_sql((row[:-2] + (sql_bool(row[-2]), row[-1]) for row in pronunciations))};

do $$
begin
  if exists (
    select 1 from public.word_pronunciations existing
    join import_pronunciations incoming using (id)
    where existing.word_id <> incoming.word_id
  ) or exists (
    select 1 from public.word_pronunciations existing
    join import_pronunciations incoming on incoming.word_id = existing.word_id
    where existing.is_primary and existing.id <> incoming.id
  ) then
    raise exception 'USL-286 import stopped: a pronunciation key belongs to another row.';
  end if;
end
$$;

insert into public.word_pronunciations (
  id, word_id, accent, ipa, ipa_state, audio_asset_path, audio_state,
  voice_label, is_primary, display_order
)
select id, word_id, accent, ipa, ipa_state, audio_asset_path, audio_state,
  voice_label, is_primary::boolean, display_order
from import_pronunciations
on conflict (id) do update set
  word_id = excluded.word_id, accent = excluded.accent, ipa = excluded.ipa,
  ipa_state = excluded.ipa_state, audio_asset_path = excluded.audio_asset_path,
  audio_state = excluded.audio_state, voice_label = excluded.voice_label,
  is_primary = excluded.is_primary, display_order = excluded.display_order,
  updated_at = now();

create temporary table import_example_audio (
  id integer primary key, example_id integer not null, audio_asset_path text not null,
  audio_state text not null, voice_label text not null,
  is_primary boolean not null, display_order integer not null
) on commit drop;
insert into import_example_audio values
{values_sql((row[:-2] + (sql_bool(row[-2]), row[-1]) for row in example_audio))};

do $$
begin
  if exists (
    select 1 from public.example_audio existing join import_example_audio incoming using (id)
    where existing.example_id <> incoming.example_id
  ) or exists (
    select 1 from public.example_audio existing
    join import_example_audio incoming on incoming.example_id = existing.example_id
    where existing.is_primary and existing.id <> incoming.id
  ) then
    raise exception 'USL-286 import stopped: an example-audio key belongs to another row.';
  end if;
end
$$;

insert into public.example_audio (
  id, example_id, audio_asset_path, audio_state, voice_label, is_primary, display_order
)
select id, example_id, audio_asset_path, audio_state, voice_label,
  is_primary::boolean, display_order
from import_example_audio
on conflict (id) do update set
  example_id = excluded.example_id, audio_asset_path = excluded.audio_asset_path,
  audio_state = excluded.audio_state, voice_label = excluded.voice_label,
  is_primary = excluded.is_primary, display_order = excluded.display_order,
  updated_at = now();

create temporary table import_extras (
  word_id integer primary key, forms_json jsonb not null, relations_json jsonb not null
) on commit drop;
insert into import_extras values
{values_sql(extras)};
insert into public.word_forms (word_id, forms_json)
select word_id, forms_json from import_extras
on conflict (word_id) do update set forms_json = excluded.forms_json, updated_at = now();
insert into public.word_relations (word_id, relations_json)
select word_id, relations_json from import_extras
on conflict (word_id) do update set relations_json = excluded.relations_json, updated_at = now();

do $$
begin
  if exists (
    select 1 from public.decks
    where (id = {DECK_DB_ID} and deck_name <> {sql_text(DECK_NAME)})
       or (deck_name = {sql_text(DECK_NAME)} and id <> {DECK_DB_ID})
  ) then
    raise exception 'USL-286 import stopped: the deck id or name belongs to another row.';
  end if;
end
$$;

insert into public.decks (id, deck_name, description, source_list_name, license)
values ({DECK_DB_ID}, {sql_text(DECK_NAME)},
  {sql_text(DECK_DESCRIPTION)},
  {sql_text(DECK_CODE)}, {sql_text(DECK_LICENSE)})
on conflict (id) do update set
  deck_name = excluded.deck_name, description = excluded.description,
  source_list_name = excluded.source_list_name, license = excluded.license,
  updated_at = now();

insert into public.deck_words (deck_id, word_id)
select {DECK_DB_ID}, id from import_words
on conflict (deck_id, word_id) do nothing;

insert into public.cards (word_id, card_template_id, deck_id, sort_order, is_active)
select words.id, templates.id, {DECK_DB_ID}, words.source_position - 1, true
from import_words words
join public.card_templates templates on templates.template_code = 'basic_en_to_ja'
on conflict (word_id, card_template_id, deck_id) do update set
  sort_order = excluded.sort_order, is_active = excluded.is_active, updated_at = now();

do $$
begin
  if (select count(*) from public.words where source_deck_code = {sql_text(DECK_CODE)}
      and source_position between 1 and 50) <> 50 then
    raise exception 'USL-286 verification failed: words count is not 50.';
  end if;
  if (select count(*) from public.deck_words where deck_id = {DECK_DB_ID}) <> 50 then
    raise exception 'USL-286 verification failed: deck_words count is not 50.';
  end if;
  if (select count(*) from public.cards where deck_id = {DECK_DB_ID} and is_active) <> 50 then
    raise exception 'USL-286 verification failed: active cards count is not 50.';
  end if;
  if exists (
    select 1 from import_words words
    where not exists (
      select 1 from public.word_meanings meanings where meanings.word_id = words.id
    ) or not exists (
      select 1 from public.word_meanings meanings
      join public.example_contents examples on examples.meaning_id = meanings.id
      where meanings.word_id = words.id
    ) or not exists (
      select 1 from public.word_pronunciations pronunciations
      where pronunciations.word_id = words.id
    )
  ) then
    raise exception 'USL-286 verification failed: a required content relation is missing.';
  end if;
end
$$;

commit;
"""


def render_merge_sql(document: dict[str, Any]) -> str:
    """本番に手作業で入れた既存50語を、正本JSONの内容へ差し替えるSQLを作る。

    render_sql が「空のDBへ 1001-1050 で入れる」のに対し、こちらは
    「すでにある 1-50 を更新する」。本番の既存行は source_position が
    英単語の並び順と一致していたため、position をそのまま既存idとして使う。

    priority 1 の意味は既存行（id = position）を更新し、2つ目以降だけ
    予約ID帯 2000 + position*10 + priority へ新規追加する。
    """
    errors = validate_document(document)
    if errors:
        raise ValueError("cannot render invalid content:\n- " + "\n- ".join(errors))
    entries = document["entries"]

    words = [
        (
            entry["source"]["position"],
            entry["word"]["word_text"],
            entry["source"]["note_guid"],
            entry["source"]["deck_code"],
        )
        for entry in entries
    ]
    meanings = [
        (
            position if sense["priority"] == 1 else MEANING_BASE + position * 10 + sense["priority"],
            position,
            sense["priority"],
            sense["part_of_speech_en"],
            sense["part_of_speech_jp"],
            sense["definition_jp"],
            sense.get("etymology"),
        )
        for entry in entries
        for position in [entry["source"]["position"]]
        for sense in entry["senses"]
    ]
    examples = [
        (
            entry["source"]["position"],
            entry["example"]["sentence_en"],
            entry["example"]["sentence_jp"],
            entry["example"]["image"]["planned_asset_path"],
            entry["example"]["audio"]["planned_asset_path"],
            entry["pronunciation"]["audio"]["planned_asset_path"],
        )
        for entry in entries
    ]
    extras = [
        (
            entry["source"]["position"],
            json.dumps(entry["forms"], ensure_ascii=False, separators=(",", ":")),
            json.dumps(entry["relations"], ensure_ascii=False, separators=(",", ":")),
        )
        for entry in entries
    ]

    return f"""-- Generated by scripts/prepare-official-content.py (render-merge-sql).
-- Replace the 50 hand-entered production words (words.id 1-50) with the canonical JSON.
-- Read docs/operations/import-official-content-production.md before running this.
-- Every literal below is ASCII only; Japanese uses PostgreSQL Unicode escapes.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

create temporary table merge_words (
  position integer primary key, word_text text not null,
  source_note_guid text not null, source_deck_code text not null
) on commit drop;
insert into merge_words values
{values_sql(words)};

create temporary table merge_meanings (
  meaning_id integer primary key, position integer not null, priority integer not null,
  part_of_speech_en text, part_of_speech_jp text, definition_jp text not null, etymology text
) on commit drop;
insert into merge_meanings values
{values_sql(meanings)};

create temporary table merge_examples (
  position integer primary key, sentence_en text not null, sentence_jp text not null,
  image_path text not null, example_audio_path text not null, word_audio_path text not null
) on commit drop;
insert into merge_examples values
{values_sql(examples)};

create temporary table merge_extras (
  position integer primary key, forms_json text not null, relations_json text not null
) on commit drop;
insert into merge_extras values
{values_sql(extras)};

do $$
declare
  missing bigint;
begin
  if (select count(*) from merge_words) <> 50 then
    raise exception 'USL-286 merge stopped: the batch is not exactly 50 positions.';
  end if;

  -- Every target must be an existing row with the same id and the same word_text.
  select count(*) into missing
  from merge_words m
  left join public.words w on w.id = m.position and w.word_text = m.word_text
  where w.id is null;
  if missing > 0 then
    raise exception
      'USL-286 merge stopped: % positions have no existing word with the same id and word_text.', missing;
  end if;

  -- No other row may own one of these word_text values (words.word_text is UNIQUE).
  if exists (
    select 1 from public.words w join merge_words m on w.word_text = m.word_text
    where w.id <> m.position
  ) then
    raise exception 'USL-286 merge stopped: another word row owns one of these word_text values.';
  end if;

  -- The child rows we update must already exist.
  select count(*) into missing from merge_words m
  where not exists (select 1 from public.word_meanings x where x.id = m.position and x.word_id = m.position)
     or not exists (select 1 from public.example_contents x where x.id = m.position and x.meaning_id = m.position)
     or not exists (select 1 from public.word_pronunciations x where x.id = m.position and x.word_id = m.position)
     or not exists (select 1 from public.example_audio x where x.example_id = m.position);
  if missing > 0 then
    raise exception 'USL-286 merge stopped: % positions are missing an existing meaning, example, pronunciation or example audio row.', missing;
  end if;

  -- The reserved ids for extra senses must not belong to a different word.
  if exists (
    select 1 from public.word_meanings x join merge_meanings m on x.id = m.meaning_id
    where x.word_id <> m.position
  ) then
    raise exception 'USL-286 merge stopped: a reserved meaning id belongs to another word.';
  end if;

  -- No other word may own one of these Anki note GUIDs.
  if exists (
    select 1 from public.words w join merge_words m on w.source_note_guid = m.source_note_guid
    where w.id <> m.position
  ) then
    raise exception 'USL-286 merge stopped: another word row owns one of these Anki note GUIDs.';
  end if;
end
$$;

-- Capture the pre-merge values inside the same transaction. Nobody copies values by
-- hand, so a transcription slip cannot make the change unrecoverable.
-- A re-run keeps the first snapshot; overwriting it would lose the original values.
create table if not exists public.usl286_pre_merge_snapshot (
  word_id integer primary key,
  source_note_guid text, source_deck_code text, source_position integer,
  meaning_priority integer, meaning_part_of_speech_en text, meaning_part_of_speech_jp text,
  meaning_definition_jp text, meaning_etymology text,
  sentence_en text, sentence_jp text,
  word_audio_asset_path text, word_audio_state text,
  taken_at timestamptz not null default now()
);

insert into public.usl286_pre_merge_snapshot (
  word_id, source_note_guid, source_deck_code, source_position,
  meaning_priority, meaning_part_of_speech_en, meaning_part_of_speech_jp,
  meaning_definition_jp, meaning_etymology, sentence_en, sentence_jp,
  word_audio_asset_path, word_audio_state
)
select w.id, w.source_note_guid, w.source_deck_code, w.source_position,
       mn.priority, mn.part_of_speech_en, mn.part_of_speech_jp,
       mn.definition_jp, mn.etymology, e.sentence_en, e.sentence_jp,
       p.audio_asset_path, p.audio_state
from merge_words m
join public.words w on w.id = m.position
join public.word_meanings mn on mn.id = m.position
join public.example_contents e on e.id = m.position
join public.word_pronunciations p on p.id = m.position
on conflict (word_id) do nothing;

do $$
begin
  if (select count(*) from public.usl286_pre_merge_snapshot) <> 50 then
    raise exception 'USL-286 merge stopped: the pre-merge snapshot does not hold exactly 50 rows.';
  end if;
end
$$;

update public.words w set
  source_note_guid = m.source_note_guid,
  source_deck_code = m.source_deck_code,
  source_position = m.position,
  updated_at = now()
from merge_words m where w.id = m.position;

update public.word_meanings x set
  priority = m.priority,
  part_of_speech_en = m.part_of_speech_en,
  part_of_speech_jp = m.part_of_speech_jp,
  definition_jp = m.definition_jp,
  etymology = m.etymology,
  updated_at = now()
from merge_meanings m where x.id = m.meaning_id and m.priority = 1;

insert into public.word_meanings (
  id, word_id, priority, part_of_speech_en, part_of_speech_jp, definition_jp, etymology
)
select meaning_id, position, priority, part_of_speech_en, part_of_speech_jp, definition_jp, etymology
from merge_meanings where priority > 1
on conflict (id) do update set
  word_id = excluded.word_id, priority = excluded.priority,
  part_of_speech_en = excluded.part_of_speech_en,
  part_of_speech_jp = excluded.part_of_speech_jp,
  definition_jp = excluded.definition_jp,
  etymology = excluded.etymology, updated_at = now();

-- Only the sentence text is aligned. Image and example-audio paths stay untouched:
-- example_contents *_asset_path_contract derives the path tail from the row id
-- (id=1 must be .../0000-0499/1.webp), so the 3000-3499 / 4000-4499 objects that
-- USL-288 uploaded can never be referenced from rows 1-50. Keeping the existing
-- paths avoids breaking delivery that already works.
update public.example_contents x set
  sentence_en = m.sentence_en,
  sentence_jp = m.sentence_jp,
  updated_at = now()
from merge_examples m where x.id = m.position;

-- word_pronunciations has no path-shape contract, so it can point at the objects
-- USL-288 already uploaded. Production currently has audio_state='blank' on all
-- 1000 rows, so word pronunciation is not delivered at all today.
update public.word_pronunciations x set
  audio_asset_path = m.word_audio_path,
  audio_state = 'present',
  updated_at = now()
from merge_examples m where x.id = m.position;

insert into public.word_forms (word_id, forms_json)
select position, forms_json::jsonb from merge_extras
on conflict (word_id) do update set forms_json = excluded.forms_json, updated_at = now();

insert into public.word_relations (word_id, relations_json)
select position, relations_json::jsonb from merge_extras
on conflict (word_id) do update set relations_json = excluded.relations_json, updated_at = now();

do $$
begin
  if (select count(*) from public.words where source_deck_code = {sql_text(DECK_CODE)}) <> 50 then
    raise exception 'USL-286 merge check failed: source_deck_code was not set on exactly 50 words.';
  end if;
  if (select count(*) from public.word_meanings where word_id between 1 and 50) <> {len(meanings)} then
    raise exception 'USL-286 merge check failed: meanings for positions 1-50 are not {len(meanings)}.';
  end if;
  if (select count(*) from public.word_pronunciations where id between 1 and 50 and audio_state <> 'present') <> 0 then
    raise exception 'USL-286 merge check failed: word audio is not present on all 50 rows.';
  end if;
  if (select count(*) from public.word_forms where word_id between 1 and 50) <> 50
     or (select count(*) from public.word_relations where word_id between 1 and 50) <> 50 then
    raise exception 'USL-286 merge check failed: forms or relations are not 50 rows.';
  end if;
end
$$;

commit;
"""


def load_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError("top-level JSON value must be an object")
    return value


def command_extract(args: argparse.Namespace) -> int:
    document = extract_anki(args.collection, args.media_dir)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    errors = document["validation"]["errors"]
    warnings = document["validation"]["warnings"]
    print(f"entries={len(document['entries'])} errors={len(errors)} warnings={len(warnings)}")
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    for warning in warnings:
        print(f"WARNING: {warning}", file=sys.stderr)
    return 1 if errors else 0


def command_validate(args: argparse.Namespace) -> int:
    errors = validate_document(load_json(args.input))
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("valid: 50 entries, positions 1-50, required fields and media references present")
    return 0


def assert_ascii_only(sql: str, label: str) -> None:
    """生成SQLに非ASCIIが1文字でもあれば止める。

    2026-09-04、日本語を含むSQLをクリップボード経由でSupabaseのSQL Editorへ貼った
    ところ、UTF-8がMac Romanとして読まれて本番の50語が文字化けした。
    生成物をASCIIに限れば、貼り付け経路の文字コードに関係なく同じ結果になる。
    """
    offenders = sorted({character for character in sql if not character.isascii()})
    if offenders:
        sample = ", ".join(f"{character!r} (U+{ord(character):04X})" for character in offenders[:5])
        raise ValueError(
            f"{label} contains {len(offenders)} non-ASCII characters and would break "
            f"when pasted through a non-UTF-8 path: {sample}"
        )


def command_render_merge_sql(args: argparse.Namespace) -> int:
    sql = render_merge_sql(load_json(args.input))
    assert_ascii_only(sql, "render-merge-sql output")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(sql, encoding="utf-8")
    print(f"wrote {args.output} (ASCII only)")
    return 0


def command_render_sql(args: argparse.Namespace) -> int:
    sql = render_sql(load_json(args.input))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(sql, encoding="utf-8")
    print(f"wrote {args.output}")
    return 0


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)
    extract = commands.add_parser("extract-anki", help="read Anki and write validated JSON")
    extract.add_argument("--collection", required=True, type=Path)
    extract.add_argument("--media-dir", required=True, type=Path)
    extract.add_argument("--output", required=True, type=Path)
    extract.set_defaults(function=command_extract)
    validate = commands.add_parser("validate", help="validate an intermediate JSON file")
    validate.add_argument("--input", required=True, type=Path)
    validate.set_defaults(function=command_validate)
    render = commands.add_parser("render-sql", help="write idempotent local import SQL")
    render.add_argument("--input", required=True, type=Path)
    render.add_argument("--output", required=True, type=Path)
    render.set_defaults(function=command_render_sql)
    merge = commands.add_parser(
        "render-merge-sql", help="write SQL that replaces existing words 1-50 with the canonical JSON"
    )
    merge.add_argument("--input", required=True, type=Path)
    merge.add_argument("--output", required=True, type=Path)
    merge.set_defaults(function=command_render_merge_sql)
    return root


def main() -> int:
    args = parser().parse_args()
    return args.function(args)


if __name__ == "__main__":
    raise SystemExit(main())

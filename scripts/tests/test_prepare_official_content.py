from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "prepare-official-content.py"
SPEC = importlib.util.spec_from_file_location("prepare_official_content", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def valid_document() -> dict:
    entries = []
    for position in range(1, 51):
        example_id = MODULE.EXAMPLE_BASE + position
        pronunciation_id = MODULE.PRONUNCIATION_BASE + position
        entries.append(
            {
                "source": {
                    "note_guid": f"guid-{position}",
                    "deck_code": MODULE.DECK_CODE,
                    "position": position,
                },
                "word": {"id": MODULE.WORD_BASE + position, "word_text": f"word-{position}"},
                "senses": [
                    {
                        "id": MODULE.MEANING_BASE + position * 10 + 1,
                        "priority": 1,
                        "part_of_speech_en": "noun",
                        "part_of_speech_jp": "名詞",
                        "definition_jp": f"意味-{position}",
                        "etymology": None,
                    }
                ],
                "example": {
                    "id": example_id,
                    "meaning_id": MODULE.MEANING_BASE + position * 10 + 1,
                    "sentence_en": f"Example {position}.",
                    "sentence_jp": f"例文{position}。",
                    "display_order": 1,
                    "image": {
                        "source_file": f"image-{position}.jpg",
                        "planned_asset_path": f"content-images/simple/"
                        f"{MODULE.asset_range(example_id)}/{example_id}.webp",
                        "exists": True,
                    },
                    "audio": {
                        "source_file": f"example-{position}.mp3",
                        "planned_asset_path": f"content-audio/example/simple/"
                        f"{MODULE.asset_range(example_id)}/{example_id}.mp3",
                        "exists": True,
                    },
                },
                "pronunciation": {
                    "id": pronunciation_id,
                    "accent": "unspecified",
                    "ipa": None,
                    "ipa_state": "blank",
                    "voice_label": "default",
                    "is_primary": True,
                    "display_order": 1,
                    "audio": {
                        "source_file": f"word-{position}.mp3",
                        "planned_asset_path": f"content-audio/word/"
                        f"{MODULE.asset_range(pronunciation_id)}/{pronunciation_id}.mp3",
                        "exists": True,
                    },
                },
                "forms": {},
                "relations": {},
            }
        )
    return {"schema_version": 1, "entries": entries, "validation": {"errors": []}}


class PrepareOfficialContentTests(unittest.TestCase):
    def test_plain_text_and_media_parsers(self) -> None:
        self.assertEqual(MODULE.plain_text("<div>Hello<br>world &amp; all</div>"), "Hello\nworld & all")
        self.assertEqual(MODULE.sound_filename("[sound:voice.mp3]"), "voice.mp3")
        self.assertEqual(MODULE.image_filename('<img src="picture.jpg">'), "picture.jpg")

    def test_validation_accepts_exact_batch(self) -> None:
        self.assertEqual(MODULE.validate_document(valid_document()), [])

    def test_validation_lists_missing_values_before_sql(self) -> None:
        document = valid_document()
        document["entries"][4]["word"]["word_text"] = ""
        document["entries"][8]["example"]["image"]["exists"] = False
        errors = MODULE.validate_document(document)
        self.assertIn("position 5 word_text is required", errors)
        self.assertIn("position 9: image source file is missing", errors)
        with self.assertRaises(ValueError):
            MODULE.render_sql(document)

    def test_recorded_extraction_error_blocks_render(self) -> None:
        document = valid_document()
        document["validation"]["errors"] = ["source contract mismatch"]
        self.assertIn("source contract mismatch", MODULE.validate_document(document))

    def test_validation_rejects_changed_reserved_ids(self) -> None:
        document = valid_document()
        document["entries"][0]["word"]["id"] = 9999
        document["entries"][1]["source"]["position"] = None
        errors = MODULE.validate_document(document)
        self.assertIn("position 1: word id does not match the reserved range", errors)
        self.assertIn("source position None must be an integer", errors)

    def test_sql_is_deterministic_and_uses_conflict_updates(self) -> None:
        document = valid_document()
        first = MODULE.render_sql(document)
        second = MODULE.render_sql(json.loads(json.dumps(document)))
        self.assertEqual(first, second)
        self.assertIn("on conflict (id) do update", first)
        self.assertIn("on conflict (word_id, card_template_id, deck_id) do update", first)
        self.assertIn("USL-286 verification failed: words count is not 50", first)
        self.assertNotIn("service_role", first)


if __name__ == "__main__":
    unittest.main()

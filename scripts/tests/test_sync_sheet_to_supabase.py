from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "sync-sheet-to-supabase.py"
SPEC = importlib.util.spec_from_file_location("sync_sheet_to_supabase", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def csvs(**overrides: str) -> dict[str, str]:
    sheets = {
        "01_core_words": "word_id,word_text\n0001,create\n0002,increase\n",
        "01_core_senses": (
            "sense_id,word_id,priority,part_of_speech_jp,part_of_speech_en,definition_jp,cefr_level,"
            "pronunciation_ipa,pronunciation_kana,etymology,synonyms,antonyms,inflections,derivatives,"
            "collocations,related\n"
            '0001,0001,1,動詞,verb,作り出す,A1,kriˈeɪt,クリエイト,,make :: 作る /&/ produce :: 生産する,,'
            '"{""past"":""created""}",creation :: 創造 :: 名詞,,invent :: 発明する\n'
            "0002,0002,1,動詞,verb,増加する,b1,,,,,,,,,\n"
            "1001,0002,2,名詞,noun,増加,B1,,,,,,,,,\n"
        ),
        "02_content_concepts": "concept_id,concept_code,concept_name,description,is_active\n1,simple,シンプル,,TRUE\n",
        "02_content_examples": (
            "example_id,sense_id,concept_id,sentence_en,sentence_jp,image_asset_path\n"
            "0001,0001,1,He creates.,彼は作る。,content-images/simple/000/example-000001.webp\n"
            "0002,0002,1,It increases.,増える。,\n"
        ),
        "03_audio_pronunciations": (
            "pronunciation_id,word_id,audio_asset_path,voice_label\n"
            "0001,0001,content-audio/word/000/pron-000001.mp3,default\n"
            "0002,0002,,\n"
        ),
        "03_audio_example_audio": (
            "example_audio_id,example_id,audio_asset_path,voice_label\n"
            "0001,0001,content-audio/example/simple/000/example-000001.mp3,default\n"
        ),
        "04_decks": "deck_id,deck_name,concept_id\n0001,大学受験頻出1000語,0001\n",
        "04_deck_words": "deck_id,sense_id\n0001,0002\n0001,0001\n",
    }
    sheets.update(overrides)
    return sheets


class BuildDocumentTest(unittest.TestCase):
    def test_converts_sheet_rows_to_database_rows(self) -> None:
        document = MODULE.build_document(csvs())

        self.assertEqual([w["id"] for w in document["words"]], [1, 2])
        create = document["senses"][0]
        self.assertEqual(create["synonyms"], ["make :: 作る", "produce :: 生産する"])
        self.assertEqual(create["inflections"], {"past": "created"})
        self.assertEqual(create["derivatives"], ["creation :: 創造 :: 名詞"])
        self.assertEqual(create["related"], ["invent :: 発明する"])
        self.assertIsNone(create["antonyms"])
        self.assertEqual(document["senses"][1]["cefr_level"], "B1")

    def test_builds_media_paths_from_ids(self) -> None:
        document = MODULE.build_document(csvs())

        self.assertEqual(document["examples"][1]["image_path"], "content-images/simple/000/example-000002.webp")
        self.assertEqual(document["example_audio"][0]["path"], "content-audio/example/simple/000/example-000001.mp3")
        self.assertEqual(MODULE.word_audio_path(1000), "content-audio/word/001/pron-001000.mp3")

    def test_skips_audio_rows_without_voice_label(self) -> None:
        document = MODULE.build_document(csvs())

        self.assertEqual([p["id"] for p in document["pronunciations"]], [1])
        self.assertTrue(document["pronunciations"][0]["is_primary"])
        self.assertEqual(document["skipped"][0]["rows"], 1)

    def test_keeps_deck_order_and_primary_sense(self) -> None:
        document = MODULE.build_document(csvs())

        self.assertEqual(
            document["deck_words"],
            [
                {"deck_id": 1, "word_id": 2, "meaning_id": 2, "sort_order": 0},
                {"deck_id": 1, "word_id": 1, "meaning_id": 1, "sort_order": 1},
            ],
        )

    def assert_stops(self, message: str, **overrides: str) -> None:
        with self.assertRaises(MODULE.SyncError) as raised:
            MODULE.build_document(csvs(**overrides))
        self.assertTrue(any(message in error for error in raised.exception.errors), raised.exception.errors)

    def test_stops_on_image_path_without_kind(self) -> None:
        self.assert_stops(
            "must be 'content-images/simple/000/example-000001.webp'",
            **{"02_content_examples": (
                "example_id,sense_id,concept_id,sentence_en,sentence_jp,image_asset_path\n"
                "0001,0001,1,He creates.,彼は作る。,content-images/simple/000/000001.webp\n"
            )},
        )

    def test_stops_on_same_word_twice_in_a_deck(self) -> None:
        self.assert_stops("already has word 2", **{"04_deck_words": "deck_id,sense_id\n1,2\n1,1001\n"})

    def test_stops_on_inflections_that_are_not_an_object(self) -> None:
        senses = csvs()["01_core_senses"].replace('"{""past"":""created""}"', '"[1]"')
        self.assert_stops("must be a JSON object", **{"01_core_senses": senses})

    def test_stops_on_missing_reference(self) -> None:
        self.assert_stops("sense 9 is not in 01_core_senses", **{"04_deck_words": "deck_id,sense_id\n1,9\n"})

    def test_stops_on_duplicate_ids(self) -> None:
        self.assert_stops("duplicate IDs [1]", **{"01_core_words": "word_id,word_text\n1,create\n0001,creates\n2,increase\n"})


class RenderSqlTest(unittest.TestCase):
    def test_sql_is_ascii_and_transactional(self) -> None:
        sql = MODULE.render_sql(MODULE.build_document(csvs()), dry_run=False)

        self.assertTrue(sql.isascii())
        self.assertIn("begin;", sql)
        self.assertIn("commit;", sql)
        self.assertIn("U&'\\4F5C\\308A\\51FA\\3059'", sql)  # 作り出す
        self.assertIn("'{\"past\":\"created\"}'::jsonb", sql)

    def test_dry_run_rolls_back_with_an_exception(self) -> None:
        sql = MODULE.render_sql(MODULE.build_document(csvs()), dry_run=True)

        self.assertNotIn("commit;", sql)
        self.assertIn("SHEET_SYNC_DRY_RUN", sql)


if __name__ == "__main__":
    unittest.main()

from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "prepare-official-media.py"
SPEC = importlib.util.spec_from_file_location("prepare_official_media", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def content_document() -> dict:
    entries = []
    for position in range(1, 51):
        example_id = 3000 + position
        pronunciation_id = 4000 + position
        entries.append(
            {
                "source": {"position": position},
                "example": {
                    "image": {
                        "source_file": f"image-{position}.png",
                        "planned_asset_path": f"content-images/simple/3000-3499/{example_id}.webp",
                    },
                    "audio": {
                        "source_file": f"example-{position}.wav",
                        "planned_asset_path": f"content-audio/example/simple/3000-3499/{example_id}.mp3",
                    },
                },
                "pronunciation": {
                    "audio": {
                        "source_file": f"word-{position}.wav",
                        "planned_asset_path": f"content-audio/word/4000-4499/{pronunciation_id}.mp3",
                    }
                },
            }
        )
    return {"schema_version": 1, "entries": entries}


def manifest() -> dict:
    result = []
    for spec in MODULE.media_specs(content_document()):
        result.append(
            {
                **{key: spec[key] for key in ("position", "kind", "source_file", "asset_path", "bucket", "object_key", "content_type")},
                "size_bytes": 100,
                "sha256": f"{spec['position']:02d}{spec['kind']:<13}".encode().hex().ljust(64, "0")[:64],
                "properties": {},
                "errors": [],
            }
        )
    return {
        "schema_version": 1,
        "source_document_sha256": "source",
        "objects": result,
        "summary": {"expected": 150, "staged": 150, "errors": 0},
        "errors": [],
    }


def receipt_for(value: dict) -> dict:
    return {
        "schema_version": 1,
        "supabase_url": "http://127.0.0.1:54321",
        "manifest_sha256": MODULE.canonical_json_sha256(value),
        "objects": [
            {
                "asset_path": item["asset_path"],
                "sha256": item["sha256"],
                "anonymous_get": True,
            }
            for item in value["objects"]
        ],
    }


class PrepareOfficialMediaTests(unittest.TestCase):
    def test_media_specs_are_exact_and_unique(self) -> None:
        specs = MODULE.media_specs(content_document())
        self.assertEqual(len(specs), 150)
        self.assertEqual(len({item["asset_path"] for item in specs}), 150)
        self.assertEqual({item["position"] for item in specs}, set(range(1, 51)))

    def test_media_specs_reject_missing_position_and_changed_bucket(self) -> None:
        document = content_document()
        document["entries"].pop()
        with self.assertRaisesRegex(MODULE.MediaError, "positions must be exactly"):
            MODULE.media_specs(document)
        document = content_document()
        document["entries"][0]["example"]["image"]["planned_asset_path"] = "private/1.webp"
        with self.assertRaisesRegex(MODULE.MediaError, "asset path is invalid"):
            MODULE.media_specs(document)

    def test_recorded_content_error_stops_before_conversion(self) -> None:
        document = content_document()
        document["validation"] = {"errors": ["source mismatch"]}
        with self.assertRaisesRegex(MODULE.MediaError, "validation errors"):
            MODULE.media_specs(document)

    def test_safe_paths_reject_traversal(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaisesRegex(MODULE.MediaError, "unsafe asset path"):
                MODULE.safe_asset_path(root, "../secret")
            with self.assertRaisesRegex(MODULE.MediaError, "unsafe or empty"):
                MODULE.safe_source(root, "../secret")

    def test_remote_sync_requires_explicit_flag(self) -> None:
        self.assertTrue(MODULE.is_loopback_url("http://127.0.0.1:54321"))
        self.assertTrue(MODULE.is_loopback_url("http://localhost:54321"))
        self.assertFalse(MODULE.is_loopback_url("https://project.supabase.co"))

    def test_local_storage_missing_object_response_is_recognized(self) -> None:
        self.assertTrue(MODULE.is_missing_object(404, b""))
        self.assertTrue(
            MODULE.is_missing_object(
                400, b'{"statusCode":"404","error":"not_found","message":"Object not found"}'
            )
        )
        self.assertFalse(
            MODULE.is_missing_object(400, b'{"statusCode":"404","message":"Bucket not found"}')
        )

    def test_state_sql_requires_matching_readback_receipt(self) -> None:
        staged = manifest()
        receipt = receipt_for(staged)
        sql = MODULE.render_state_sql(staged, receipt)
        self.assertIn("USL-288 verification failed", sql)
        self.assertIn("set image_state = 'present'", sql)
        self.assertIn("set audio_state = 'present'", sql)
        self.assertNotIn("service_role", sql)
        receipt["objects"].pop()
        with self.assertRaisesRegex(MODULE.MediaError, "all 150"):
            MODULE.render_state_sql(staged, receipt)

    def test_manifest_validation_rejects_changed_fixed_path(self) -> None:
        staged = manifest()
        staged["objects"][0]["asset_path"] = "content-audio/example/simple/3000-3499/3999.mp3"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            MODULE.write_json(path, staged)
            with self.assertRaisesRegex(MODULE.MediaError, "fixed ID"):
                MODULE.validated_manifest(path)


if __name__ == "__main__":
    unittest.main()

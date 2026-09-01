#!/usr/bin/env python3
"""Stage, validate, and safely publish the first 50 official media records.

The input is the operator-local JSON made by prepare-official-content.py. This
tool never reads the Anki database directly, never overwrites a Storage object,
and refuses remote Supabase writes unless --allow-remote is explicit.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
from typing import Any, Iterable
from urllib import error, parse, request


IMAGE_WIDTH = 768
IMAGE_HEIGHT = 432
IMAGE_LIMIT = 200 * 1024
WORD_AUDIO_LIMIT = 40 * 1024
EXAMPLE_AUDIO_LIMIT = 96 * 1024
WORD_AUDIO_SECONDS = 5.0
EXAMPLE_AUDIO_SECONDS = 12.0
EXPECTED_POSITIONS = set(range(1, 51))
EXPECTED_OBJECTS = 150
CACHE_SECONDS = 3600


class MediaError(ValueError):
    """A bounded validation or remote-safety failure."""


def load_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise MediaError(f"{path}: top-level JSON value must be an object")
    return value


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def canonical_json_sha256(value: dict[str, Any]) -> str:
    payload = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return sha256_bytes(payload.encode("utf-8"))


def command_path(name: str) -> str:
    result = shutil.which(name)
    if not result:
        raise MediaError(f"required command is missing: {name}")
    return result


def run(command: list[str]) -> None:
    completed = subprocess.run(command, text=True, capture_output=True, check=False)
    if completed.returncode:
        detail = completed.stderr.strip() or completed.stdout.strip()
        raise MediaError(f"command failed ({command[0]}): {detail}")


def ffprobe(path: Path, stream: str) -> dict[str, Any]:
    command = [
        command_path("ffprobe"),
        "-v",
        "error",
        "-select_streams",
        stream,
        "-show_entries",
        "format=duration,format_name:stream=codec_name,width,height,pix_fmt,sample_rate,channels,bit_rate",
        "-of",
        "json",
        str(path),
    ]
    completed = subprocess.run(command, text=True, capture_output=True, check=False)
    if completed.returncode:
        raise MediaError(f"ffprobe failed for {path.name}: {completed.stderr.strip()}")
    try:
        result = json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        raise MediaError(f"ffprobe returned invalid JSON for {path.name}") from exc
    streams = result.get("streams")
    if not isinstance(streams, list) or len(streams) != 1:
        raise MediaError(f"{path.name}: expected exactly one {stream} stream")
    return {"stream": streams[0], "format": result.get("format", {})}


def safe_source(media_dir: Path, filename: Any) -> Path:
    if not isinstance(filename, str) or not filename or Path(filename).name != filename:
        raise MediaError(f"unsafe or empty source filename: {filename!r}")
    root = media_dir.resolve(strict=True)
    try:
        source = (root / filename).resolve(strict=True)
        source.relative_to(root)
    except (FileNotFoundError, ValueError) as exc:
        raise MediaError(f"source file is missing: {filename}") from exc
    if not source.is_file():
        raise MediaError(f"source is not a file: {filename}")
    return source


def safe_asset_path(root: Path, asset_path: Any) -> Path:
    if not isinstance(asset_path, str) or not asset_path:
        raise MediaError("asset path is empty")
    relative = Path(asset_path)
    if relative.is_absolute() or ".." in relative.parts or len(relative.parts) < 2:
        raise MediaError(f"unsafe asset path: {asset_path!r}")
    target = root.joinpath(*relative.parts)
    target.resolve(strict=False).relative_to(root.resolve(strict=False))
    return target


def expected_asset_path(position: int, kind: str) -> str:
    if kind == "image":
        return f"content-images/simple/3000-3499/{3000 + position}.webp"
    if kind == "word_audio":
        return f"content-audio/word/4000-4499/{4000 + position}.mp3"
    if kind == "example_audio":
        return f"content-audio/example/simple/3000-3499/{3000 + position}.mp3"
    raise MediaError(f"unsupported media kind: {kind!r}")


def media_specs(document: dict[str, Any]) -> list[dict[str, Any]]:
    recorded_errors = document.get("validation", {}).get("errors", [])
    if recorded_errors:
        raise MediaError("input content document contains validation errors")
    entries = document.get("entries")
    if not isinstance(entries, list):
        raise MediaError("entries must be an array")
    positions: set[int] = set()
    specs: list[dict[str, Any]] = []
    for entry in entries:
        if not isinstance(entry, dict):
            raise MediaError("every entry must be an object")
        source = entry.get("source", {})
        position = source.get("position") if isinstance(source, dict) else None
        if not isinstance(position, int):
            raise MediaError(f"invalid source position: {position!r}")
        positions.add(position)
        example = entry.get("example", {})
        pronunciation = entry.get("pronunciation", {})
        records = (
            ("image", example.get("image", {}), "image/webp", IMAGE_LIMIT, None),
            (
                "word_audio",
                pronunciation.get("audio", {}),
                "audio/mpeg",
                WORD_AUDIO_LIMIT,
                WORD_AUDIO_SECONDS,
            ),
            (
                "example_audio",
                example.get("audio", {}),
                "audio/mpeg",
                EXAMPLE_AUDIO_LIMIT,
                EXAMPLE_AUDIO_SECONDS,
            ),
        )
        for kind, record, content_type, size_limit, duration_limit in records:
            if not isinstance(record, dict):
                raise MediaError(f"position {position}: {kind} record is invalid")
            asset_path = record.get("planned_asset_path")
            if not isinstance(asset_path, str) or not asset_path.startswith("content-"):
                raise MediaError(f"position {position}: {kind} asset path is invalid")
            bucket, _, object_key = asset_path.partition("/")
            expected_bucket = "content-images" if kind == "image" else "content-audio"
            expected_suffix = ".webp" if kind == "image" else ".mp3"
            if bucket != expected_bucket or not object_key or not object_key.endswith(expected_suffix):
                raise MediaError(f"position {position}: {kind} asset path violates the contract")
            if asset_path != expected_asset_path(position, kind):
                raise MediaError(f"position {position}: {kind} asset path does not match its fixed ID")
            specs.append(
                {
                    "position": position,
                    "kind": kind,
                    "source_file": record.get("source_file"),
                    "asset_path": asset_path,
                    "bucket": bucket,
                    "object_key": object_key,
                    "content_type": content_type,
                    "size_limit": size_limit,
                    "duration_limit": duration_limit,
                }
            )
    if positions != EXPECTED_POSITIONS:
        raise MediaError("source positions must be exactly 1 through 50")
    if len(specs) != EXPECTED_OBJECTS:
        raise MediaError(f"expected {EXPECTED_OBJECTS} media records, found {len(specs)}")
    paths = [spec["asset_path"] for spec in specs]
    if len(paths) != len(set(paths)):
        raise MediaError("asset paths contain duplicates")
    return sorted(specs, key=lambda item: (item["position"], item["kind"]))


def convert_image(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    intermediate = target.with_name(f".{target.stem}.staging.png")
    try:
        run(
            [
                command_path("ffmpeg"),
                "-nostdin",
                "-hide_banner",
                "-loglevel",
                "error",
                "-y",
                "-i",
                str(source),
                "-vf",
                f"scale={IMAGE_WIDTH}:{IMAGE_HEIGHT}:flags=lanczos,format=rgb24",
                "-frames:v",
                "1",
                "-an",
                "-map_metadata",
                "-1",
                str(intermediate),
            ]
        )
        run(
            [
                command_path("cwebp"),
                "-quiet",
                "-q",
                "80",
                "-metadata",
                "none",
                str(intermediate),
                "-o",
                str(target),
            ]
        )
    finally:
        intermediate.unlink(missing_ok=True)


def convert_audio(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    run(
        [
            command_path("ffmpeg"),
            "-nostdin",
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-i",
            str(source),
            "-vn",
            "-ac",
            "1",
            "-ar",
            "44100",
            "-c:a",
            "libmp3lame",
            "-b:a",
            "64k",
            "-map_metadata",
            "-1",
            str(target),
        ]
    )


def inspect_staged(spec: dict[str, Any], target: Path) -> dict[str, Any]:
    size = target.stat().st_size
    errors: list[str] = []
    if size > spec["size_limit"]:
        errors.append(f"size {size} exceeds {spec['size_limit']} bytes")
    details: dict[str, Any] = {}
    if spec["kind"] == "image":
        probe = ffprobe(target, "v:0")["stream"]
        details = {
            "codec": probe.get("codec_name"),
            "width": probe.get("width"),
            "height": probe.get("height"),
            "pixel_format": probe.get("pix_fmt"),
        }
        if probe.get("codec_name") != "webp":
            errors.append("codec is not WebP")
        if probe.get("width") != IMAGE_WIDTH or probe.get("height") != IMAGE_HEIGHT:
            errors.append(f"dimensions are not {IMAGE_WIDTH}x{IMAGE_HEIGHT}")
    else:
        probe = ffprobe(target, "a:0")
        stream = probe["stream"]
        try:
            duration = float(probe["format"].get("duration"))
        except (TypeError, ValueError):
            duration = -1.0
        details = {
            "codec": stream.get("codec_name"),
            "sample_rate": int(stream.get("sample_rate", 0)),
            "channels": stream.get("channels"),
            "bit_rate": int(stream.get("bit_rate", 0)),
            "duration_seconds": round(duration, 6),
        }
        if stream.get("codec_name") != "mp3":
            errors.append("codec is not MP3")
        if details["sample_rate"] != 44100 or stream.get("channels") != 1:
            errors.append("audio must be mono at 44.1 kHz")
        if details["bit_rate"] != 64000:
            errors.append("audio bit rate must be 64 kbps")
        if duration <= 0 or duration > spec["duration_limit"]:
            errors.append(f"duration {duration:.3f}s exceeds {spec['duration_limit']:.1f}s")
    return {
        **{key: spec[key] for key in ("position", "kind", "source_file", "asset_path", "bucket", "object_key", "content_type")},
        "size_bytes": size,
        "sha256": sha256_file(target),
        "properties": details,
        "errors": errors,
    }


def command_stage(args: argparse.Namespace) -> int:
    document = load_json(args.input)
    specs = media_specs(document)
    for required in ("ffmpeg", "ffprobe", "cwebp"):
        command_path(required)
    if args.output_dir.exists() and any(args.output_dir.iterdir()):
        raise MediaError(f"output directory is not empty: {args.output_dir}")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    objects: list[dict[str, Any]] = []
    errors: list[str] = []
    for spec in specs:
        label = f"position {spec['position']} {spec['kind']}"
        try:
            source = safe_source(args.media_dir, spec["source_file"])
            target = safe_asset_path(args.output_dir, spec["asset_path"])
            if spec["kind"] == "image":
                convert_image(source, target)
            else:
                convert_audio(source, target)
            record = inspect_staged(spec, target)
            objects.append(record)
            errors.extend(f"{label}: {detail}" for detail in record["errors"])
        except (MediaError, OSError) as exc:
            errors.append(f"{label}: {exc}")
    manifest = {
        "schema_version": 1,
        "source_document_sha256": canonical_json_sha256(document),
        "objects": objects,
        "summary": {
            "expected": EXPECTED_OBJECTS,
            "staged": len(objects),
            "images": sum(item["kind"] == "image" for item in objects),
            "word_audio": sum(item["kind"] == "word_audio" for item in objects),
            "example_audio": sum(item["kind"] == "example_audio" for item in objects),
            "total_bytes": sum(item["size_bytes"] for item in objects),
            "errors": len(errors),
        },
        "errors": errors,
    }
    write_json(args.output_dir / "manifest.json", manifest)
    print(
        f"staged={len(objects)}/{EXPECTED_OBJECTS} bytes={manifest['summary']['total_bytes']} "
        f"errors={len(errors)} manifest={args.output_dir / 'manifest.json'}"
    )
    for detail in errors:
        print(f"ERROR: {detail}", file=sys.stderr)
    return 1 if errors or len(objects) != EXPECTED_OBJECTS else 0


def validated_manifest(path: Path) -> dict[str, Any]:
    manifest = load_json(path)
    objects = manifest.get("objects")
    if manifest.get("schema_version") != 1 or not isinstance(objects, list):
        raise MediaError("manifest schema is invalid")
    if manifest.get("errors") or len(objects) != EXPECTED_OBJECTS:
        raise MediaError("manifest is incomplete or contains validation errors")
    paths = [item.get("asset_path") for item in objects if isinstance(item, dict)]
    if len(paths) != EXPECTED_OBJECTS or len(paths) != len(set(paths)):
        raise MediaError("manifest asset paths are incomplete or duplicated")
    if any(item.get("errors") for item in objects):
        raise MediaError("a staged object contains validation errors")
    seen: set[tuple[int, str]] = set()
    for item in objects:
        position = item.get("position")
        kind = item.get("kind")
        if not isinstance(position, int) or position not in EXPECTED_POSITIONS:
            raise MediaError("manifest contains an invalid source position")
        if kind not in {"image", "word_audio", "example_audio"}:
            raise MediaError("manifest contains an invalid media kind")
        pair = (position, kind)
        if pair in seen:
            raise MediaError("manifest contains a duplicate position and media kind")
        seen.add(pair)
        if item.get("asset_path") != expected_asset_path(position, kind):
            raise MediaError("manifest asset path does not match its fixed ID")
        expected_type = "image/webp" if kind == "image" else "audio/mpeg"
        if item.get("content_type") != expected_type:
            raise MediaError("manifest contains an invalid content type")
        digest = item.get("sha256")
        if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise MediaError("manifest contains an invalid SHA-256")
    expected_pairs = {
        (position, kind)
        for position in EXPECTED_POSITIONS
        for kind in ("image", "word_audio", "example_audio")
    }
    if seen != expected_pairs:
        raise MediaError("manifest does not contain the exact 50-word media set")
    return manifest


def normalized_base_url(value: str) -> str:
    parsed = parse.urlsplit(value)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise MediaError("Supabase URL must be an absolute HTTP(S) URL")
    if parsed.query or parsed.fragment:
        raise MediaError("Supabase URL must not contain query or fragment components")
    return value.rstrip("/")


def is_loopback_url(value: str) -> bool:
    hostname = parse.urlsplit(value).hostname
    return hostname in {"127.0.0.1", "localhost", "::1"}


def public_url(base_url: str, item: dict[str, Any]) -> str:
    path = "/".join(parse.quote(part, safe="") for part in item["asset_path"].split("/"))
    return f"{base_url}/storage/v1/object/public/{path}"


def object_url(base_url: str, item: dict[str, Any]) -> str:
    bucket = parse.quote(item["bucket"], safe="")
    key = "/".join(parse.quote(part, safe="") for part in item["object_key"].split("/"))
    return f"{base_url}/storage/v1/object/{bucket}/{key}"


def http_get(url: str) -> tuple[int, dict[str, str], bytes]:
    try:
        with request.urlopen(request.Request(url, method="GET"), timeout=30) as response:
            return response.status, {key.lower(): value for key, value in response.headers.items()}, response.read()
    except error.HTTPError as exc:
        return exc.code, {key.lower(): value for key, value in exc.headers.items()}, exc.read()
    except error.URLError as exc:
        raise MediaError(f"GET failed for {url}: {exc.reason}") from exc


def is_missing_object(status: int, payload: bytes) -> bool:
    if status == 404:
        return True
    if status != 400:
        return False
    try:
        detail = json.loads(payload)
    except json.JSONDecodeError:
        return False
    return isinstance(detail, dict) and detail.get("message") == "Object not found"


def upload_object(base_url: str, key: str, item: dict[str, Any], path: Path) -> None:
    headers = {
        "Authorization": f"Bearer {key}",
        "apikey": key,
        "Content-Type": item["content_type"],
        "cache-control": str(CACHE_SECONDS),
        "x-upsert": "false",
    }
    operation = request.Request(object_url(base_url, item), data=path.read_bytes(), headers=headers, method="POST")
    try:
        with request.urlopen(operation, timeout=60) as response:
            if response.status not in {200, 201}:
                raise MediaError(f"upload returned HTTP {response.status} for {item['asset_path']}")
    except error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")[:500]
        raise MediaError(f"upload returned HTTP {exc.code} for {item['asset_path']}: {body}") from exc
    except error.URLError as exc:
        raise MediaError(f"upload failed for {item['asset_path']}: {exc.reason}") from exc


def verify_payload(item: dict[str, Any], status: int, headers: dict[str, str], payload: bytes) -> list[str]:
    problems: list[str] = []
    if status != 200:
        return [f"public GET returned HTTP {status}"]
    content_type = headers.get("content-type", "").split(";", 1)[0].strip().lower()
    if content_type != item["content_type"]:
        problems.append(f"content-type is {content_type!r}, expected {item['content_type']!r}")
    cache_control = headers.get("cache-control", "")
    if str(CACHE_SECONDS) not in cache_control:
        problems.append(f"cache-control does not contain {CACHE_SECONDS}: {cache_control!r}")
    digest = sha256_bytes(payload)
    if digest != item["sha256"]:
        problems.append(f"SHA-256 differs: {digest}")
    return problems


def local_object_path(asset_root: Path, item: dict[str, Any]) -> Path:
    path = safe_asset_path(asset_root, item["asset_path"])
    if not path.is_file():
        raise MediaError(f"staged object is missing: {item['asset_path']}")
    if sha256_file(path) != item["sha256"]:
        raise MediaError(f"staged object SHA-256 changed: {item['asset_path']}")
    return path


def sync_objects(
    manifest: dict[str, Any], asset_root: Path, base_url: str, service_key: str
) -> dict[str, Any]:
    objects = manifest["objects"]
    pending: list[dict[str, Any]] = []
    errors: list[str] = []
    for item in objects:
        local_object_path(asset_root, item)
        status, headers, payload = http_get(public_url(base_url, item))
        if is_missing_object(status, payload):
            pending.append(item)
        elif status == 200:
            problems = verify_payload(item, status, headers, payload)
            errors.extend(f"{item['asset_path']}: existing object {problem}" for problem in problems)
        else:
            errors.append(f"{item['asset_path']}: preflight GET returned HTTP {status}")
    if errors:
        raise MediaError("preflight stopped before upload:\n- " + "\n- ".join(errors))
    for item in pending:
        upload_object(base_url, service_key, item, local_object_path(asset_root, item))

    verified: list[dict[str, Any]] = []
    errors = []
    for item in objects:
        status, headers, payload = http_get(public_url(base_url, item))
        problems = verify_payload(item, status, headers, payload)
        if problems:
            errors.extend(f"{item['asset_path']}: {problem}" for problem in problems)
        else:
            verified.append(
                {
                    "asset_path": item["asset_path"],
                    "sha256": item["sha256"],
                    "size_bytes": len(payload),
                    "content_type": item["content_type"],
                    "anonymous_get": True,
                }
            )
    if errors:
        raise MediaError("anonymous readback failed:\n- " + "\n- ".join(errors))
    return {
        "schema_version": 1,
        "supabase_url": base_url,
        "manifest_sha256": canonical_json_sha256(manifest),
        "objects": verified,
        "summary": {"uploaded": len(pending), "already_matching": len(objects) - len(pending), "verified": len(verified)},
    }


def command_sync(args: argparse.Namespace) -> int:
    import os

    manifest = validated_manifest(args.manifest)
    base_url = normalized_base_url(args.supabase_url)
    if not is_loopback_url(base_url) and not args.allow_remote:
        raise MediaError("remote Supabase writes require --allow-remote after separate approval")
    service_key = os.environ.get(args.service_role_key_env)
    if not service_key:
        raise MediaError(f"environment variable is missing: {args.service_role_key_env}")
    receipt = sync_objects(manifest, args.asset_root, base_url, service_key)
    write_json(args.receipt, receipt)
    summary = receipt["summary"]
    print(
        f"uploaded={summary['uploaded']} already_matching={summary['already_matching']} "
        f"verified={summary['verified']} receipt={args.receipt}"
    )
    return 0


def validate_receipt(manifest: dict[str, Any], receipt: dict[str, Any]) -> None:
    if receipt.get("schema_version") != 1:
        raise MediaError("receipt schema is invalid")
    if receipt.get("manifest_sha256") != canonical_json_sha256(manifest):
        raise MediaError("receipt does not belong to this manifest")
    objects = receipt.get("objects")
    if not isinstance(objects, list) or len(objects) != EXPECTED_OBJECTS:
        raise MediaError("receipt does not verify all 150 objects")
    expected = {(item["asset_path"], item["sha256"]) for item in manifest["objects"]}
    actual = {
        (item.get("asset_path"), item.get("sha256"))
        for item in objects
        if isinstance(item, dict) and item.get("anonymous_get") is True
    }
    if actual != expected:
        raise MediaError("receipt paths or SHA-256 values do not match the manifest")


def sql_text(value: Any) -> str:
    return "'" + str(value).replace("'", "''") + "'"


def values_sql(rows: Iterable[Iterable[Any]]) -> str:
    return ",\n".join("  (" + ", ".join(sql_text(value) for value in row) + ")" for row in rows)


def render_state_sql(manifest: dict[str, Any], receipt: dict[str, Any]) -> str:
    validate_receipt(manifest, receipt)
    by_position: dict[int, dict[str, dict[str, Any]]] = {}
    for item in manifest["objects"]:
        by_position.setdefault(item["position"], {})[item["kind"]] = item
    examples = []
    pronunciations = []
    for position in range(1, 51):
        records = by_position.get(position, {})
        if set(records) != {"image", "word_audio", "example_audio"}:
            raise MediaError(f"position {position}: manifest media set is incomplete")
        examples.append(
            (
                3000 + position,
                records["image"]["asset_path"],
                records["example_audio"]["asset_path"],
            )
        )
        pronunciations.append((4000 + position, records["word_audio"]["asset_path"]))
    return f"""-- Generated by scripts/prepare-official-media.py after anonymous readback.
-- This SQL changes only media states whose fixed IDs and paths match exactly.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create temporary table verified_examples (
  id integer primary key, image_asset_path text not null, audio_asset_path text not null
) on commit drop;
insert into verified_examples values
{values_sql(examples)};

create temporary table verified_pronunciations (
  id integer primary key, audio_asset_path text not null
) on commit drop;
insert into verified_pronunciations values
{values_sql(pronunciations)};

do $$
begin
  if (select count(*) from verified_examples) <> 50
     or (select count(*) from verified_pronunciations) <> 50 then
    raise exception 'USL-288 stopped: verification batch is not exactly 50 words.';
  end if;
  if exists (
    select 1 from verified_examples incoming
    left join public.example_contents existing using (id)
    where existing.id is null
       or existing.image_asset_path is distinct from incoming.image_asset_path
       or existing.audio_asset_path is distinct from incoming.audio_asset_path
  ) or exists (
    select 1 from verified_pronunciations incoming
    left join public.word_pronunciations existing using (id)
    where existing.id is null
       or existing.audio_asset_path is distinct from incoming.audio_asset_path
  ) or exists (
    select 1 from verified_examples incoming
    left join public.example_audio existing on existing.example_id = incoming.id and existing.is_primary
    where existing.id is null
       or existing.audio_asset_path is distinct from incoming.audio_asset_path
  ) then
    raise exception 'USL-288 stopped: a fixed media ID or path differs from the verified manifest.';
  end if;
end
$$;

update public.example_contents existing
set image_state = 'present', updated_at = now()
from verified_examples incoming
where existing.id = incoming.id;

update public.word_pronunciations existing
set audio_state = 'present', updated_at = now()
from verified_pronunciations incoming
where existing.id = incoming.id;

update public.example_audio existing
set audio_state = 'present', updated_at = now()
from verified_examples incoming
where existing.example_id = incoming.id and existing.is_primary;

do $$
begin
  if (select count(*) from public.example_contents existing
      join verified_examples incoming using (id)
      where existing.image_state = 'present') <> 50
     or (select count(*) from public.word_pronunciations existing
         join verified_pronunciations incoming using (id)
         where existing.audio_state = 'present') <> 50
     or (select count(*) from public.example_audio existing
         join verified_examples incoming on incoming.id = existing.example_id
         where existing.is_primary and existing.audio_state = 'present') <> 50 then
    raise exception 'USL-288 verification failed: media states are incomplete.';
  end if;
end
$$;

commit;
"""


def command_render_state_sql(args: argparse.Namespace) -> int:
    manifest = validated_manifest(args.manifest)
    receipt = load_json(args.receipt)
    sql = render_state_sql(manifest, receipt)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(sql, encoding="utf-8")
    print(f"wrote {args.output}")
    return 0


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)

    stage = commands.add_parser("stage", help="convert 50 images and 100 audio files")
    stage.add_argument("--input", required=True, type=Path)
    stage.add_argument("--media-dir", required=True, type=Path)
    stage.add_argument("--output-dir", required=True, type=Path)
    stage.set_defaults(function=command_stage)

    sync = commands.add_parser("sync", help="upload missing objects and verify anonymous readback")
    sync.add_argument("--manifest", required=True, type=Path)
    sync.add_argument("--asset-root", required=True, type=Path)
    sync.add_argument("--supabase-url", required=True)
    sync.add_argument("--service-role-key-env", default="SUPABASE_SERVICE_ROLE_KEY")
    sync.add_argument("--receipt", required=True, type=Path)
    sync.add_argument("--allow-remote", action="store_true")
    sync.set_defaults(function=command_sync)

    render = commands.add_parser(
        "render-state-sql", help="render state updates from an anonymous-readback receipt"
    )
    render.add_argument("--manifest", required=True, type=Path)
    render.add_argument("--receipt", required=True, type=Path)
    render.add_argument("--output", required=True, type=Path)
    render.set_defaults(function=command_render_state_sql)
    return root


def main() -> int:
    try:
        args = parser().parse_args()
        return args.function(args)
    except (MediaError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

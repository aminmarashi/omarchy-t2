#!/usr/bin/python3

import argparse
import os
import re
import struct
import sys
import time
from pathlib import Path


MAX_CHARS = 320
MAX_RIFF_BYTES = 512 * 1024 * 1024
MAX_READY = 4
STREAM_SIZE = 0x7FFFFFFF


def discard_reference(match: re.Match) -> str:
    trailing = re.search(r"[.,;:!?]+$", match.group(0))
    return f" {trailing.group(0)}" if trailing else " "


def clean_text(text: str) -> str:
    text = re.sub(r"!?\[([^\]]+)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"<https?://[^>]+>", " ", text, flags=re.IGNORECASE)
    text = re.sub(
        r"\b(?:https?://|www\.)\S+", discard_reference, text, flags=re.IGNORECASE
    )
    text = re.sub(
        r"(?<!\w)(?:~|\.{1,2})?/[^\s,;:!?()\[\]{}]+", discard_reference, text
    )
    text = re.sub(
        r"\b[A-Za-z]:\\[^\s,;:!?()\[\]{}]+", discard_reference, text
    )
    text = re.sub(
        r"(?<![\w.])[\w@+-][\w@+.-]*\.[A-Za-z][A-Za-z0-9]{1,7}"
        r"(?=$|[\s,;:!?()\[\]{}]|[.](?:\s|$))",
        " ",
        text,
    )
    text = text.replace("`", "")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r" *\n *", "\n", text)
    return text.strip()


def split_long_section(section: str, max_chars: int) -> list[str]:
    pieces = []
    while len(section) > max_chars:
        minimum = max_chars // 2
        cut = -1
        for pattern in (r"[;,:—–-]\s+", r"\s+"):
            matches = list(re.finditer(pattern, section[minimum:max_chars]))
            if matches:
                cut = minimum + matches[-1].end()
                break
        if cut < 1:
            cut = max_chars
        pieces.append(section[:cut].strip())
        section = section[cut:].strip()
    if section:
        pieces.append(section)
    return pieces


def split_text(text: str, max_chars: int = MAX_CHARS) -> list[str]:
    if max_chars < 80:
        raise ValueError("max_chars must be at least 80")

    text = clean_text(text)
    chunks = []
    paragraphs = re.split(r"\n\s*\n+", text)
    for paragraph in paragraphs:
        paragraph = re.sub(r"\s+", " ", paragraph).strip()
        if not re.search(r"\w", paragraph):
            continue

        marked = re.sub(r'([.!?]+["”’\)\]]*)\s+', r"\1\n", paragraph)
        sections = [item.strip() for item in marked.splitlines() if item.strip()]
        current = ""
        for section in sections:
            for piece in split_long_section(section, max_chars):
                candidate = f"{current} {piece}".strip()
                if current and len(candidate) > max_chars:
                    chunks.append(current)
                    current = piece
                else:
                    current = candidate
        if current:
            chunks.append(current)

    return chunks


def read_exact(stream, size: int) -> bytes:
    data = bytearray()
    while len(data) < size:
        block = stream.read(size - len(data))
        if not block:
            raise ValueError("truncated WAV stream")
        data.extend(block)
    return bytes(data)


def streaming_waves(stream, header: bytes):
    marker = header
    wave = bytearray(header)
    while block := stream.read(64 * 1024):
        wave.extend(block)
        if len(wave) > MAX_RIFF_BYTES:
            raise ValueError("Qwen emitted an invalid WAV size")
        while (boundary := wave.find(marker, len(marker))) >= 0:
            yield bytes(wave[:boundary])
            del wave[:boundary]
    if len(wave) < 44:
        raise ValueError("truncated WAV stream")
    yield bytes(wave)


def normalize_streaming_wave(wave: bytes) -> bytes:
    if wave[36:40] != b"data":
        raise ValueError("Qwen emitted an unsupported streaming WAV header")
    normalized = bytearray(wave)
    normalized[4:8] = struct.pack("<I", len(wave) - 8)
    normalized[40:44] = struct.pack("<I", len(wave) - 44)
    return bytes(normalized)


def publish_wave(wave: bytes, output_dir: Path, count: int, max_ready: int) -> None:
    while sum(path.name[:-4].isdigit() for path in output_dir.glob("*.wav")) >= max_ready:
        time.sleep(0.05)
    destination = output_dir / f"{count:06d}.wav"
    temporary = destination.with_suffix(".part")
    with temporary.open("xb") as handle:
        handle.write(wave)
    os.replace(temporary, destination)


def unpack_stream(stream, output_dir: Path, max_ready: int = MAX_READY) -> int:
    if max_ready < 1:
        raise ValueError("max_ready must be at least 1")
    output_dir.mkdir(parents=True, exist_ok=True)
    count = 0
    while True:
        first = stream.read(1)
        if not first:
            return count
        header = first + read_exact(stream, 11)
        if header[:4] != b"RIFF" or header[8:12] != b"WAVE":
            raise ValueError("Qwen emitted an invalid WAV stream")

        riff_size = struct.unpack("<I", header[4:8])[0]
        if riff_size == STREAM_SIZE:
            for wave in streaming_waves(stream, header):
                count += 1
                publish_wave(
                    normalize_streaming_wave(wave), output_dir, count, max_ready
                )
            return count
        if riff_size < 4 or riff_size + 8 > MAX_RIFF_BYTES:
            raise ValueError("Qwen emitted an invalid WAV size")
        wave = header + read_exact(stream, riff_size - 4)

        count += 1
        publish_wave(wave, output_dir, count, max_ready)


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    split_parser = subparsers.add_parser("split")
    split_parser.add_argument("--max-chars", type=int, default=MAX_CHARS)
    unpack_parser = subparsers.add_parser("unpack")
    unpack_parser.add_argument("output_dir", type=Path)
    unpack_parser.add_argument("--max-ready", type=int, default=MAX_READY)
    args = parser.parse_args()

    try:
        if args.command == "split":
            chunks = split_text(sys.stdin.read(), args.max_chars)
            for chunk in chunks:
                print(chunk)
            return 0
        unpack_stream(sys.stdin.buffer, args.output_dir, args.max_ready)
        return 0
    except (OSError, ValueError) as error:
        print(f"omarchy-tts-queue: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/python3

import io
import struct
import tempfile
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parent.parent
queue = SourceFileLoader(
    "omarchy_tts_queue", str(PROJECT_DIR / "libexec/omarchy-tts-queue.py")
).load_module()


def wav(payload: bytes) -> bytes:
    body = b"WAVE" + payload
    return b"RIFF" + struct.pack("<I", len(body)) + body


def streaming_wav(payload: bytes) -> bytes:
    return (
        b"RIFF\xff\xff\xff\x7fWAVE"
        b"fmt \x10\x00\x00\x00\x01\x00\x01\x00\xc0]\x00\x00"
        b"\x80\xbb\x00\x00\x02\x00\x10\x00data\xff\xff\xff\x7f"
        + payload
    )


class TextChunkTests(unittest.TestCase):
    def test_cleans_links_urls_paths_and_filenames(self):
        text = """
        Read [the installation guide](https://example.com/guide) before continuing.
        Skip https://example.com/raw?q=1, www.example.org and /home/amin/report.pdf.
        Open README.md next. Version 3.14 and U.S. English must remain.
        """

        chunks = queue.split_text(text)
        speech = " ".join(chunks)

        self.assertIn("the installation guide", speech)
        self.assertIn("before continuing. Skip", speech)
        self.assertIn("Version 3.14", speech)
        self.assertIn("U.S. English", speech)
        self.assertNotIn("http", speech)
        self.assertNotIn("www.", speech)
        self.assertNotIn("/home/", speech)
        self.assertNotIn("README.md", speech)

    def test_preserves_sentence_boundaries_and_limits_chunk_size(self):
        text = (
            "This is a complete opening sentence. "
            + "word " * 120
            + "This final sentence should remain complete."
        )

        chunks = queue.split_text(text, max_chars=120)

        self.assertGreater(len(chunks), 3)
        self.assertTrue(all(0 < len(chunk) <= 120 for chunk in chunks))
        self.assertTrue(chunks[0].startswith("This is a complete opening sentence."))
        self.assertTrue(chunks[-1].endswith("This final sentence should remain complete."))


class WavQueueTests(unittest.TestCase):
    def test_unpacks_concatenated_wavs_atomically(self):
        first = wav(b"first payload")
        second = wav(b"second payload")
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)

            count = queue.unpack_stream(io.BytesIO(first + second), output)

            self.assertEqual(2, count)
            self.assertEqual(first, (output / "000001.wav").read_bytes())
            self.assertEqual(second, (output / "000002.wav").read_bytes())
            self.assertEqual([], list(output.glob("*.part")))

    def test_rejects_truncated_stream(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, "truncated"):
                queue.unpack_stream(io.BytesIO(wav(b"payload")[:-2]), Path(directory))

    def test_frames_and_normalizes_qwen_streaming_wavs(self):
        first = streaming_wav(b"\x01\x02" * 100)
        second = streaming_wav(b"\x03\x04" * 120)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)

            count = queue.unpack_stream(io.BytesIO(first + second), output)

            self.assertEqual(2, count)
            for index, payload_size in ((1, 200), (2, 240)):
                result = (output / f"{index:06d}.wav").read_bytes()
                self.assertEqual(len(result) - 8, struct.unpack("<I", result[4:8])[0])
                self.assertEqual(payload_size, struct.unpack("<I", result[40:44])[0])


if __name__ == "__main__":
    unittest.main()

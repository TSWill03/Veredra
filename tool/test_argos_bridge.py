"""Test the exact embedded worker, without installing translation models."""
import json
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest.mock import patch

DART = Path(__file__).resolve().parents[1] / "lib/services/translation_service_io.dart"

def worker():
    source = DART.read_text(encoding="utf-8").split("const String _helperScriptSource = r"+chr(39)*3, 1)[1].rsplit(chr(39)*3, 1)[0]
    ns = {"__name__": "argos_bridge_test"}
    exec(compile(source, "argos_bridge.py", "exec"), ns)
    return ns

class FakeTranslation:
    def __init__(self):
        self.calls = []
        self.fail = None
    def translate(self, text):
        self.calls.append(text)
        if text == self.fail:
            raise RuntimeError("interrupted")
        return text.upper()

class CheckpointTest(unittest.TestCase):
    def test_layout(self):
        ns = worker()
        t = FakeTranslation()
        batch = ns["BatchTranslation"](t)
        batch.enabled = False
        self.assertEqual(ns["translate_document"](batch, "one\n\n  \n\n two"), "ONE\n\n  \n\n TWO")

    def test_interruption_resume_and_isolation(self):
        ns = worker()
        settings = types.SimpleNamespace(device="cpu", compute_type="auto",
            chunk_type="default", beam_size=4, batch_size=32, intra_threads=4, inter_threads=1)
        argos = types.ModuleType("argostranslate")
        argos.settings = settings
        argos.translate = types.SimpleNamespace(PackageTranslation=type("PackageTranslation", (), {}))
        t = FakeTranslation()
        target = types.SimpleNamespace(code="pt")
        source = types.SimpleNamespace(code="en", get_translation=lambda _: t)
        ns["safe_import_argos"] = lambda: (None, types.SimpleNamespace(get_installed_languages=lambda: [source,target]))
        ns["emit"] = lambda _: None
        with tempfile.TemporaryDirectory() as folder, patch.dict(sys.modules, {"argostranslate":argos}):
            root = Path(folder); inp = root / "input.json"; out = root / "out.json"
            payload = {"title":"book", "chapters":[{"title":"one","content":"first"},{"title":"two","content":"second"}]}
            inp.write_text(json.dumps(payload), encoding="utf-8")
            ns["translate_book"]("en","pt",str(inp),str(out),1)
            self.assertEqual(len(json.loads(out.read_text())["chapters"]),1)
            out.unlink()
            t.calls.clear()
            t.fail = "second"
            with self.assertRaises(RuntimeError):
                ns["translate_book"]("en","pt",str(inp),str(out))
            self.assertFalse(out.exists())
            self.assertNotIn("first",t.calls)
            files = list(root.glob("checkpoints/*/00000000.json"))
            self.assertEqual(len(files),1)
            self.assertEqual(ns["load_checkpoint"](files[0],0)["content"],"FIRST")
            t.fail = None; t.calls.clear()
            ns["translate_book"]("en","pt",str(inp),str(out))
            self.assertNotIn("first",t.calls)
            self.assertEqual([x["content"] for x in json.loads(out.read_text())["chapters"]],["FIRST","SECOND"])
            # A corrupt cache must not silently return modified content.
            cached = json.loads(files[0].read_text()); cached["content"] = "wrong"
            files[0].write_text(json.dumps(cached))
            self.assertIsNone(ns["load_checkpoint"](files[0],0))
            t.calls.clear()
            ns["translate_book"]("en","pt",str(inp),str(out))
            self.assertIn("first",t.calls)
            # Changed original content creates an independent checkpoint.
            payload["chapters"][0]["content"]="changed"
            inp.write_text(json.dumps(payload),encoding="utf-8")
            t.calls.clear()
            ns["translate_book"]("en","pt",str(inp),str(out))
            self.assertIn("changed",t.calls)

if __name__ == "__main__":
    unittest.main()

"""Test the exact embedded worker, without installing translation models."""
import json
import os
import hashlib
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

class CtsContractTest(unittest.TestCase):
    def test_pinned_cts_bundle(self):
        directory = DART.parents[2] / "assets/cts"
        pin = json.loads((directory / "SOURCE.json").read_text(encoding="utf-8"))
        self.assertEqual(pin["api_version"], 1)
        self.assertEqual(hashlib.sha256((directory/"cts_text.py").read_bytes()).hexdigest(),pin["sha256"])

    def test_cts_events_are_emitted_only_after_checkpoint_commit(self):
        ns=worker()
        argos=types.ModuleType("argostranslate")
        argos.settings=types.SimpleNamespace()
        t=FakeTranslation()
        target=types.SimpleNamespace(code="pt")
        source=types.SimpleNamespace(code="en",get_translation=lambda _:t)
        ns["safe_import_argos"]=lambda:(None,types.SimpleNamespace(get_installed_languages=lambda:[source,target]))
        got=[]
        cts=types.ModuleType("cts_text")
        cts.API_VERSION=1
        class Engine:
            def __init__(self,src,tgt,**kwargs):
                self.profile=kwargs["profile"]
                self.batch_tokens=kwargs["batch_tokens"]
                self.beam_size=kwargs["beam_size"]
                self.fallback_reason=None
                self.identity={"api":1,"src":src,"tgt":tgt,"profile":self.profile,"batch":self.batch_tokens}
            def translate(self,text):
                return text.upper()
        cts.TextEngine=Engine
        with tempfile.TemporaryDirectory() as folder, patch.dict(sys.modules,{"argostranslate":argos,"cts_text":cts}), patch.dict(os.environ,{"VEREDRA_CTS_PROFILE":"cuda","VEREDRA_CTS_BATCH_TOKENS":"1024"}):
            root=Path(folder); inp=root/"input.json"; out=root/"out.json"
            inp.write_text(json.dumps({"title":"book","chapters":[{"title":"one","content":"first"},{"title":"two","content":"second"}]}),encoding="utf-8")
            def emit(event):
                if event["type"]=="chapter_ready":
                    path=root/"checkpoints"/event["key"]/f'{event["index"]:08d}.json'
                    self.assertTrue(path.exists())
                    self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),event["fileDigest"])
                    self.assertFalse(out.exists())
                    got.append(event["index"])
            ns["emit"]=emit
            ns["translate_book"]("en","pt",str(inp),str(out))
            self.assertEqual(got,[0,1])
            self.assertEqual(len(json.loads(out.read_text())["chapters"]),2)

if __name__ == "__main__":
    unittest.main()

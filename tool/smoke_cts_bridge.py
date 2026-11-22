"""Run real CTS worker in isolation. No existing book/profile is touched."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[1]

def run(profile,batch,beam):
    source=(ROOT/"lib/services/translation_service_io.dart").read_text(encoding="utf-8")
    source=source.split("const String _helperScriptSource = r"+chr(39)*3,1)[1].rsplit(chr(39)*3,1)[0]
    with tempfile.TemporaryDirectory(prefix="veredra-cts-smoke-") as folder:
        work=Path(folder)
        helper=work/"argos_bridge.py";helper.write_text(source,encoding="utf-8")
        shutil.copyfile(ROOT/"assets/cts/cts_text.py",work/"cts_text.py")
        inp=work/"input.json";out=work/"output.json";log=work/"stderr.txt"
        inp.write_text(json.dumps({"title":"QA only","description":"Original synthetic text.",
            "chapters":[{"title":"Chapter 1","content":"The gate was locked. Mira held a sword."},
                        {"title":"Chapter 2","content":("The knight crossed the bridge. Ada remained at the gate. The light disappeared after sunset.\n\n"*50)},
                        {"title":"Chapter 3","content":"The sun rose over the valley."}]}),encoding="utf-8")
        env=os.environ.copy()
        env.update(VEREDRA_CTS_PROFILE=profile, VEREDRA_CTS_BATCH_TOKENS=str(batch),
                   VEREDRA_CTS_BEAM_SIZE=str(beam), PYTHONIOENCODING="utf-8", VEREDRA_ARGOS_BATCH="0")
        cmd=[sys.executable,str(helper),"translate-book","en","pt",str(inp),str(out)]
        def child(environment,stop_after_one=False):
            messages=[]
            with log.open("w",encoding="utf-8") as err:
                proc=subprocess.Popen(cmd,env=environment,stdout=subprocess.PIPE,stderr=err,text=True,encoding="utf-8")
                try:
                    for line in proc.stdout:
                        try: event=json.loads(line)
                        except ValueError:continue
                        messages.append(event)
                        if event.get("type")=="chapter_ready":
                            path=work/"checkpoints"/event["key"]/f'{event["index"]:08d}.json'
                            assert path.exists()
                            assert hashlib.sha256(path.read_bytes()).hexdigest()==event["fileDigest"]
                            assert json.loads(path.read_text(encoding="utf-8"))["index"]==event["index"]
                            print("ready",event["index"],"profile",environment["VEREDRA_CTS_PROFILE"],flush=True)
                            if stop_after_one:
                                proc.terminate()
                                break
                    rc=proc.wait(timeout=60)
                finally:
                    if proc.poll() is None:proc.kill();proc.wait()
                if not stop_after_one and rc:
                    raise RuntimeError("worker failed: "+log.read_text(encoding="utf-8")[-500:])
            return messages
        first=child(env,True)
        r=next(e for e in first if e.get("type")=="chapter_ready")
        key=r["key"];path=work/"checkpoints"/key/"00000000.json"
        mtime=path.stat().st_mtime_ns
        assert not out.exists(),"partial job must not publish final output"
        events=child(env)
        ready=[x for x in events if x.get("type")=="chapter_ready"]
        assert [x["index"] for x in ready]==[0,1,2]
        assert {x["key"] for x in ready}=={key}
        assert path.stat().st_mtime_ns==mtime,"completed chapter was recomputed"
        result=json.loads(out.read_text(encoding="utf-8"))
        assert len(result["chapters"])==3 and all(c["content"].strip() for c in result["chapters"])
        labels=[x.get("message","") for x in events if x.get("type")=="progress"]
        if profile=="cuda":
            assert any("CTS CUDA" in x and "fallback" not in x for x in labels),"GPU not used"
            out.unlink()
            fallback=env.copy();fallback["CTS_CUDA_DLL_DIRS"]=str(work/"missing-dll-directory")
            fallback_events=child(fallback)
            fready=[x for x in fallback_events if x.get("type")=="chapter_ready"]
            assert all(x["key"]!=key for x in fready)
            assert any("fallback CUDA -> CPU" in x.get("message","") for x in fallback_events)
            print("CPU startup fallback: verified; separate checkpoint identity",flush=True)
        print("CTS bridge: real worker, chapter events, pause/resume, checksum and final output PASS",flush=True)
if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--profile",choices=["cpu","cuda"],default="cpu")
    p.add_argument("--batch",type=int,default=512)
    p.add_argument("--beam",type=int,default=4)
    a=p.parse_args()
    run(a.profile,a.batch,a.beam)

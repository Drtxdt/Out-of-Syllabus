"""Fetch only Windows x64 entries from the official version-pinned template ZIP."""
import io, os, time, zipfile, urllib.request, hashlib, json
from pathlib import Path
URL = "https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
SIZE = 1281349702
class Remote(io.RawIOBase):
 def __init__(self): self.pos=0
 def seekable(self): return True
 def readable(self): return True
 def tell(self): return self.pos
 def seek(self, off, whence=0):
  self.pos=off if whence==0 else self.pos+off if whence==1 else SIZE+off
  return self.pos
 def read(self, n=-1):
  n=min(n if n>=0 else SIZE-self.pos,SIZE-self.pos);chunks=[]
  while n>0:
   amount=min(n,1024*1024)
   for attempt in range(8):
    try:
     req=urllib.request.Request(URL,headers={"Range":f"bytes={self.pos}-{self.pos+amount-1}","User-Agent":"OutOfSyllabus-build"})
     with urllib.request.urlopen(req,timeout=90) as response:
      if response.status!=206: raise RuntimeError("Server ignored byte range")
      part=response.read()
      if len(part)!=amount: raise IOError("Short range")
     break
    except Exception:
     if attempt==7: raise
     time.sleep(min(2**attempt,10))
   chunks.append(part);self.pos+=len(part);n-=len(part)
  return b"".join(chunks)
out=Path(os.environ['APPDATA'])/'Godot/export_templates/4.7.2.stable'
out.mkdir(parents=True,exist_ok=True)
manifest={}
with zipfile.ZipFile(Remote()) as z:
 for name in ['version.txt','windows_release_x86_64.exe','windows_debug_x86_64.exe']:
  entry=next(x for x in z.infolist() if x.filename.split('/')[-1]==name)
  target=out/name
  if not target.exists() or target.stat().st_size!=entry.file_size:
   print('Fetching',name,entry.compress_size,flush=True)
   data=z.read(entry)
   target.with_suffix('.download').write_bytes(data)
   target.with_suffix('.download').replace(target)
  manifest[name]={'size':target.stat().st_size,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'zip_crc':entry.CRC}
  print('Verified',name,flush=True)
(Path(__file__).resolve().parents[1]/'reports/templates.json').write_text(json.dumps(manifest,indent=2))

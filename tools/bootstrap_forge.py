"""Rebuild the pinned MCP server. The addon itself is already versioned in the repo."""
import json,subprocess,urllib.request,zipfile,io
from pathlib import Path
root=Path(__file__).resolve().parents[1]
lock=json.loads((root/'toolchain.lock.json').read_text())['forge']
target=root/'tools/godot-forge'
if not (target/'package-lock.json').exists():
 url=f"https://codeload.github.com/{lock['repo']}/zip/{lock['commit']}"
 with urllib.request.urlopen(url,timeout=120) as response: archive=zipfile.ZipFile(io.BytesIO(response.read()))
 for info in archive.infolist():
  parts=Path(info.filename).parts[1:]
  if not parts or info.is_dir(): continue
  out=target.joinpath(*parts).resolve()
  if not out.is_relative_to(target.resolve()): raise ValueError('Unsafe archive path')
  out.parent.mkdir(parents=True,exist_ok=True);out.write_bytes(archive.read(info))
subprocess.run(['D:/nodejs/npm.cmd','ci','--ignore-scripts','--no-audit','--no-fund'],cwd=target,check=True)
subprocess.run(['D:/nodejs/npm.cmd','run','build'],cwd=target,check=True)

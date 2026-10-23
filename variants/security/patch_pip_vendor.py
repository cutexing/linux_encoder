"""Patch pip's bundled urllib3 from a hash-verified upstream wheel.

pip 26.2.2 still vendors urllib3 2.7.0. Keep the change inside pip, preserve
licensing, and update its vendor manifest, SBOM, and installed-file RECORD.
"""

import base64
import csv
import hashlib
import importlib.metadata as metadata
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

import pip


source = json.loads(Path("/tmp/pip-vendor.json").read_text())
vendor = Path(pip.__file__).resolve().parent / "_vendor"
target = vendor / "urllib3"
assert target.parent == vendor and target.is_dir()
with tempfile.TemporaryDirectory(prefix="pip-vendor-security-") as temporary:
    wheel = Path(temporary) / "urllib3.whl"
    subprocess.run(["curl", "-4", "--fail", "--location", "--silent", "--show-error",
                    "--connect-timeout", "15", "--max-time", "90", "--output", str(wheel),
                    source["url"]], check=True)
    assert hashlib.sha256(wheel.read_bytes()).hexdigest() == source["sha256"]
    shutil.rmtree(target)
    with zipfile.ZipFile(wheel) as archive:
        for name in archive.namelist():
            if name.startswith("urllib3/") and not name.endswith("/"):
                path = (vendor / name).resolve()
                assert path.is_relative_to(target)
                path.parent.mkdir(parents=True, exist_ok=True)
                content = archive.read(name)
                if name == "urllib3/contrib/emscripten/__init__.py":
                    content = content.replace(b"import urllib3.connection",
                        b"from pip._vendor import urllib3\nimport pip._vendor.urllib3.connection")
                path.write_bytes(content)
        licenses = [n for n in archive.namelist() if ".dist-info/" in n and n.endswith("LICENSE.txt")]
        assert len(licenses) == 1, licenses
        (target / "LICENSE.txt").write_bytes(archive.read(licenses[0]))

manifest = vendor / "vendor.txt"
previous = manifest.read_text()
updated, count = re.subn(r"(?m)^(\s*urllib3)==2\.7\.0$",
                        r"\g<1>==" + source["version"], previous)
assert count == 1
manifest.write_text(updated)
sbom = vendor / "bom.cdx.json"
document = json.loads(sbom.read_text())
old_reference = "pkg:pypi/urllib3@2.7.0"
new_reference = "pkg:pypi/urllib3@" + source["version"]
for component in document["components"]:
    if component.get("name") == "urllib3":
        assert component["version"] == "2.7.0"
        component["version"] = source["version"]
sbom.write_text(json.dumps(document, indent=2).replace(old_reference, new_reference) + "\n")

distribution = metadata.distribution("pip")
record = Path(distribution.locate_file("pip-26.2.2.dist-info/RECORD"))
site = vendor.parent.parent
changed = [manifest, sbom] + sorted(p for p in target.rglob("*") if p.is_file())
names = {p.relative_to(site).as_posix() for p in changed}
with record.open(newline="") as stream:
    rows = [r for r in csv.reader(stream) if r[0] not in names
            and not r[0].startswith("pip/_vendor/urllib3/")]
for path in changed:
    data = path.read_bytes()
    digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b"=").decode()
    rows.append([path.relative_to(site).as_posix(), "sha256=" + digest, str(len(data))])
with record.open("w", newline="") as stream:
    csv.writer(stream).writerows(rows)

provenance = Path("/usr/share/encoder-security")
provenance.mkdir(parents=True, exist_ok=True)
(provenance / "pip-urllib3.json").write_text(json.dumps(source, indent=2) + "\n")
subprocess.run([sys.executable, "-c",
                "from pip._vendor import urllib3; assert urllib3.__version__ == '2.8.0'"], check=True)
# Exercise pip's HTTP/download path after replacing its private networking dependency.
with tempfile.TemporaryDirectory(prefix="pip-download-smoke-") as temporary:
    subprocess.run([sys.executable, "-m", "pip", "--isolated", "download", "--no-cache-dir",
                    "--no-deps", "--only-binary=:all:", "--index-url", "https://pypi.org/simple",
                    "--require-hashes", "--dest", temporary, "-r", "/tmp/security-requirements.txt"],
                   check=True)
print("pip vendored urllib3 2.8.0: source hash, SBOM, RECORD, HTTPS downloads verified")

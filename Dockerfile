# syntax=docker/dockerfile:1.7

# Preserve the tested encoder runtime; rebuild only the pinned security updates.
# Sources, hashes, and build guards are embedded to keep this Dockerfile standalone.
ARG BASE_IMAGE=cutexing/encoder:main-pre-security-20261023@sha256:344e4b660394b93610f7ef50c4fba21b90980abc37bcd9c9a7c537fc1204f018

# Build patched auxiliary CLIs without shipping Go or source archives.
FROM cutexing/encoder:5fish-av1-pre-security-20261023@sha256:8246c80841c8990283d9a9dfdcdd4e24d316c7aa1fa8aaa40a4d3af774e8f1e8 AS security-tools

COPY <<'ENCODER_BUILD_TOOLS_PY' /tmp/build_tools.py
"""Rebuild auxiliary Go CLIs with patched Go, without changing encoder tools."""

import hashlib
import json
import os
from pathlib import Path
import subprocess


root = Path("/tmp/security-tools")
root.mkdir()
for source in json.loads(Path("/tmp/tool-sources.json").read_text()):
    archive = root / (source["name"] + ".tar.gz")
    subprocess.run(["curl", "-4", "--fail", "--location", "--silent", "--show-error",
                    "--connect-timeout", "15", "--max-time", "180", "--output", str(archive),
                    source["url"]], check=True)
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == source["sha256"], archive
    destination = root / source["name"]
    destination.mkdir()
    subprocess.run(["tar", "-xzf", str(archive), "--strip-components=1", "-C", str(destination)],
                   check=True)

environment = dict(os.environ, PATH=str(root / "go/bin") + ":" + os.environ["PATH"],
                   CGO_ENABLED="0", GOTOOLCHAIN="local", GOFLAGS="-mod=readonly",
                   GOMAXPROCS="8")
out = Path("/out")
out.mkdir()
tools = [
    ("rclone", "rclone", "1.75.2-2", "1.75.2", ".",
     "-s -w -X github.com/rclone/rclone/fs.Version=v1.75.2"),
    ("gh", "github-cli", "2.103.0-1", "2.103.0", "./cmd/gh",
     "-s -w -X github.com/cli/cli/v2/internal/build.Version=2.103.0 "
     "-X github.com/cli/cli/v2/internal/build.Date=2026-10-21"),
]
for binary, package, release, version, target, flags in tools:
    staging = root / (package + "-pkg")
    bindir = staging / "usr/bin"
    bindir.mkdir(parents=True)
    executable = bindir / binary
    subprocess.run(["go", "build", "-p", "8", "-trimpath", "-ldflags", flags,
                    "-o", str(executable), target], cwd=root / binary, env=environment, check=True)
    subprocess.run([str(executable), "version" if binary == "rclone" else "--version"], check=True)
    (staging / ".PKGINFO").write_text(
        f"pkgname = {package}\npkgbase = {package}\npkgver = {release}\n"
        f"pkgdesc = Upstream {binary} {version} rebuilt with Go 1.27.3 for security\n"
        f"url = https://github.com/{'rclone/rclone' if binary == 'rclone' else 'cli/cli'}\n"
        f"builddate = 1792531200\npackager = linux_encoder security build\n"
        f"size = {executable.stat().st_size}\narch = x86_64\nlicense = MIT\n"
    )
    subprocess.run(["tar", "--zstd", "-cf", str(out / (package + ".pkg.tar.zst")),
                    "-C", str(staging), ".PKGINFO", "usr"], check=True)
ENCODER_BUILD_TOOLS_PY

COPY <<'ENCODER_TOOL_SOURCES_JSON' /tmp/tool-sources.json
[
  {
    "name": "go",
    "url": "https://go.dev/dl/go1.27.3.linux-amd64.tar.gz",
    "sha256": "65efbc80fdc1fa2cd2631cad5b481777a68e8725f34e89f50fc6ac714e379b40"
  },
  {
    "name": "rclone",
    "url": "https://github.com/rclone/rclone/archive/refs/tags/v1.75.2.tar.gz",
    "sha256": "68afd7f68c84bd978966feae2116339aa7bf454b39c573910c462e87c3774d5a"
  },
  {
    "name": "gh",
    "url": "https://github.com/cli/cli/archive/refs/tags/v2.103.0.tar.gz",
    "sha256": "c15a3794f56f6b9c0dca05d5f5b357f27da3c1b7031523fb42c0870ef16c6aff"
  }
]
ENCODER_TOOL_SOURCES_JSON

RUN python /tmp/build_tools.py

FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="auto_encoder main VapourSynth runtime"
LABEL org.opencontainers.image.description="Python 3.14.8, OpenSSL 3.6.5, Expat 2.8.5, pip 26.2.2; frozen VapourSynth and plugins verified by SHA256."
LABEL org.opencontainers.image.base.name="docker.io/cutexing/encoder:main-pre-security-20261023"
LABEL org.opencontainers.image.base.digest="sha256:344e4b660394b93610f7ef50c4fba21b90980abc37bcd9c9a7c537fc1204f018"

COPY <<'ENCODER_VERIFY_RUNTIME_PY' /tmp/verify_runtime.py
"""Guard the frozen encoder stack while applying explicitly allowed pip updates."""

import hashlib
import importlib.metadata as metadata
import json
from pathlib import Path
import shutil
import subprocess
import sys

OS_UPDATES = {"python": "3.14.8-1", "openssl": "3.6.5-1", "expat": "2.8.5-1",
              "glibc": "2.44+r50+g1848099f063e-1", "ca-certificates-mozilla": "3.132-1",
              "rclone": "1.75.2-2", "github-cli": "2.103.0-1"}
PYTHON_UPDATES = {"pip": "26.2.2", "cryptography": "50.0.2", "setuptools": "83.0.0"}


def snapshot():
    packages = {}
    files = {}
    for dist in metadata.distributions():
        name = dist.metadata["Name"].lower().replace("_", "-")
        if name in PYTHON_UPDATES:
            continue
        packages[name] = dist.version
        for entry in dist.files or []:
            path = Path(dist.locate_file(entry)).resolve()
            if path.is_file() and path.suffix != ".pyc":
                files[str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
    native = list(Path("/usr/lib").glob("libvapoursynth*"))
    native += list(Path("/usr/lib/vapoursynth").rglob("*"))
    native += list(Path("/usr/local/lib/vapoursynth").rglob("*"))
    for tool in ("vspipe", "ffmpeg", "av1an", "SvtAv1EncApp", "mkvmerge"):
        executable = shutil.which(tool)
        if not executable:
            raise SystemExit(f"Missing encoder tool: {tool}")
        native.append(Path(executable))
    native += list(Path("/usr/local/libexec").glob("av1an*"))
    for path in native:
        if path.is_file():
            files[str(path.resolve())] = hashlib.sha256(path.read_bytes()).hexdigest()
    system_packages = dict(line.split(maxsplit=1) for line in
                           subprocess.check_output(["pacman", "-Q"], text=True).splitlines())
    return {
        "python_abi": list(sys.version_info[:2]),
        "packages": dict(sorted(packages.items())),
        "files": dict(sorted(files.items())),
        "system_packages": {k: v for k, v in system_packages.items() if k not in OS_UPDATES},
    }


def smoke():
    import vapoursynth as vs
    from vsaa import NNEDI3, pre_aa
    from vsdehalo import hq_dering
    from vsdenoise import bm3d
    from vsdenoise.fft import DFTTest
    from vsmasktools import Morpho, dre_edgemask
    from vssource import BestSource
    from vstools import depth, get_y

    core = vs.core
    assert metadata.version("VapourSynth") == "77"
    assert metadata.version("vsjetpack") == "1.5.0"
    assert metadata.version("vapoursynth-vszip") == "17.0.0"
    source = core.std.BlankClip(width=720, height=480, format=vs.YUV420P8,
                                length=30, fpsnum=30000, fpsden=1001)
    core.vszip.BoxBlur(source).get_frame(0)
    if "vapoursynth-vivtc" in snapshot()["packages"]:
        import vsdeinterlace
        output = core.vivtc.VDecimate(core.vivtc.VFM(source, order=1))
        assert output.num_frames == 24
        for frame in output.frames():
            frame.close()
        print("IVTC: 30 -> 24 frames rendered")
    print("VapourSynth R77 / JET 1.5.0 / vszip 17 imports and frame rendering passed")


if __name__ == "__main__":
    command = sys.argv[1]
    if command == "snapshot":
        Path(sys.argv[2]).write_text(json.dumps(snapshot(), indent=2) + "\n")
    elif command == "verify":
        before = json.loads(Path(sys.argv[2]).read_text())
        after = snapshot()
        if before != after:
            for section in before:
                if before[section] != after[section]:
                    print(f"Frozen runtime changed: {section}", file=sys.stderr)
            raise SystemExit(1)
        print(f"Unchanged: {len(after['packages'])} distributions, "
              f"{len(after['files'])} file hashes, Python ABI, other system packages")
        for name, version in OS_UPDATES.items():
            actual = subprocess.check_output(["pacman", "-Q", name], text=True).split()[1]
            assert actual == version, (name, actual, version)
        assert sys.version_info[:3] == (3, 14, 8)
        for name, version in PYTHON_UPDATES.items():
            assert metadata.version(name) == version, name
        smoke()
    elif command == "smoke":
        smoke()
    else:
        raise SystemExit(f"Unknown command: {command}")
ENCODER_VERIFY_RUNTIME_PY

COPY <<'ENCODER_REQUIREMENTS_TXT' /tmp/security-requirements.txt
pip==26.2.2 --hash=sha256:fd7f4dfa8190e014013b9f08f3e973f4e4c26ffd179a204895533a7254813a70
cryptography==50.0.2 --hash=sha256:9dab55f57c74c3cad24c323bacbbd04be4705ba6eb0d92e920b1fc4837ed5079
setuptools==83.0.0 --hash=sha256:29b23c360f22f414dc7336bb39178cc7bcbf6021ed2733cde173f09dba19abb3
ENCODER_REQUIREMENTS_TXT

COPY <<'ENCODER_OS_PACKAGES_JSON' /tmp/os-packages.json
[
  {
    "name": "python",
    "version": "3.14.8-1",
    "url": "https://archive.archlinux.org/packages/p/python/python-3.14.8-1-x86_64.pkg.tar.zst",
    "sha256": "5195a93a744ca27725e6f6c4128d460899a8c3d5b887baaed9e42d582130a4f0",
    "signature_sha256": "04114821a3c1fe7e14de82a68a05edd4766a75c18f2f25c96b06729c6ac2940c"
  },
  {
    "name": "openssl",
    "version": "3.6.5-1",
    "url": "https://archive.archlinux.org/packages/o/openssl/openssl-3.6.5-1-x86_64.pkg.tar.zst",
    "sha256": "be0a07ef3d8ffa878732b138e98dee26559527212cb941fc5f6c282545c787cc",
    "signature_sha256": "787059e6ec5ad33b6d730c8bb5d7c578adebac71ddd9cf7183d062155a649d8e"
  },
  {
    "name": "expat",
    "version": "2.8.5-1",
    "url": "https://archive.archlinux.org/packages/e/expat/expat-2.8.5-1-x86_64.pkg.tar.zst",
    "sha256": "25b7b51074df3c851b315a116e3a7a30a5d37b63cbbbc6e18e3a6563ba4e3f27",
    "signature_sha256": "6b813da7fcd7dac8c33738528fae196c196d2d18437bed83971d2e3d6f2a3d05"
  },
  {
    "name": "glibc",
    "version": "2.44+r50+g1848099f063e-1",
    "url": "https://archive.archlinux.org/packages/g/glibc/glibc-2.44%2Br50%2Bg1848099f063e-1-x86_64.pkg.tar.zst",
    "sha256": "e8e4d50d45cb2bd21c9f7eabacc6a01bd5eb93dbd476f3f44d44038fc1eba417",
    "signature_sha256": "efa937dd709b4c3635d3a855e6a588b4442040648d2d3847d8ad9ddce4254a0a"
  },
  {
    "name": "ca-certificates-mozilla",
    "version": "3.132-1",
    "url": "https://archive.archlinux.org/packages/c/ca-certificates-mozilla/ca-certificates-mozilla-3.132-1-x86_64.pkg.tar.zst",
    "sha256": "d2305ed8c1426e018ad611cb6e7fa387c3cac0f2e7040401dae2f1f78e0867ab",
    "signature_sha256": "78f8739c0dda56e32318c1c3c743c1f8c94663f3cb4a5588e143cb936d9e5a4c"
  }
]
ENCODER_OS_PACKAGES_JSON

COPY <<'ENCODER_INSTALL_OS_UPDATES_PY' /tmp/install_os_updates.py
"""Install only signed, hash-pinned ABI-compatible security package revisions.

This is a narrowly tested patch layer, not a supported full Arch rolling upgrade.
No sync databases or dependency upgrades are used; missing dependencies fail closed.
"""

import hashlib
import json
from pathlib import Path
import subprocess
import tempfile


packages = json.loads(Path("/tmp/os-packages.json").read_text())
with tempfile.TemporaryDirectory(prefix="encoder-security-") as temporary:
    root = Path(temporary)
    archives = []
    for package in packages:
        archive = root / package["url"].rsplit("/", 1)[1]
        for suffix, expected in (("", package["sha256"]),
                                 (".sig", package["signature_sha256"])):
            target = Path(str(archive) + suffix)
            subprocess.run(["curl", "-4", "--fail", "--location", "--silent", "--show-error",
                            "--connect-timeout", "15", "--max-time", "180", "--output",
                            str(target), package["url"] + suffix], check=True)
            assert hashlib.sha256(target.read_bytes()).hexdigest() == expected, target
        subprocess.run(["pacman-key", "--verify", str(archive) + ".sig"], check=True)
        archives.append(str(archive))
    subprocess.run(["pacman", "-U", "--noconfirm", *archives], check=True)
ENCODER_INSTALL_OS_UPDATES_PY

COPY <<'ENCODER_PIP_VENDOR_JSON' /tmp/pip-vendor.json
{
  "version": "2.8.0",
  "url": "https://files.pythonhosted.org/packages/92/9d/c4e665119135114480843e7ab388fa94d8480650450e6f8e26b70d323a4c/urllib3-2.8.0-py3-none-any.whl",
  "sha256": "0cf3cae568d36aa9576b28dfb35f11328f1cb974ca7647d9475ebb86c75ac6e3"
}
ENCODER_PIP_VENDOR_JSON

COPY <<'ENCODER_PATCH_PIP_VENDOR_PY' /tmp/patch_pip_vendor.py
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
ENCODER_PATCH_PIP_VENDOR_PY

COPY --from=security-tools /out/ /tmp/security-tools/

# Do not resolve or upgrade the VapourSynth stack or Python minor version.
# captree is an unused Go diagnostic from libcap; retain the libcap library/tools.
# --isolated ignores user pip configuration and extra indexes inherited at build time.
RUN python /tmp/verify_runtime.py snapshot /tmp/runtime-before.json \
    && python /tmp/install_os_updates.py \
    && pacman -U --noconfirm /tmp/security-tools/*.pkg.tar.zst \
    && rm /usr/bin/captree \
    && python -m pip --isolated install \
        --break-system-packages --no-cache-dir --no-deps --only-binary=:all: \
        --index-url https://pypi.org/simple --require-hashes \
        -r /tmp/security-requirements.txt \
    && python /tmp/patch_pip_vendor.py \
    && python -m pip check \
    && python /tmp/verify_runtime.py verify /tmp/runtime-before.json \
    && python -c "import importlib.metadata as m; assert m.version('pip') == '26.2.2'" \
    && rm /tmp/runtime-before.json /tmp/security-requirements.txt /tmp/verify_runtime.py \
          /tmp/os-packages.json /tmp/install_os_updates.py /tmp/security-tools/*.pkg.tar.zst \
          /tmp/pip-vendor.json /tmp/patch_pip_vendor.py \
    && rmdir /tmp/security-tools

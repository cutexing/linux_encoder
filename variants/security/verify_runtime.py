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

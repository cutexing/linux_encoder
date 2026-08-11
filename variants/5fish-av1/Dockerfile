# syntax=docker/dockerfile:1.7

# Keep the known-good 5fish runtime immutable. This base tag is retained on
# Docker Hub, and the digest prevents any tag movement from changing the build.
ARG BASE_IMAGE=cutexing/encoder:5fish-av1-base-c540c113@sha256:c540c113c5973173580518152d57de63af8ca5f6acdccc0760978a47a4a0b4d9

FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="auto_encoder VapourSynth runtime with IVTC"
LABEL org.opencontainers.image.description="Pinned 5fish runtime based on encoder digest c540c113; adds only vapoursynth-vivtc 2.0 without updating existing tools."
LABEL org.opencontainers.image.base.name="docker.io/cutexing/encoder:5fish-av1-base-c540c113"
LABEL org.opencontainers.image.base.digest="sha256:c540c113c5973173580518152d57de63af8ca5f6acdccc0760978a47a4a0b4d9"

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONUNBUFFERED=1

COPY variants/5fish-av1/requirements-ivtc.txt /tmp/requirements-ivtc.txt

# --no-deps is intentional: the base image already contains the known-good
# VapourSynth/JET stack, and dependency resolution would upgrade those tools.
RUN set -eux; \
    python -m pip install \
        --break-system-packages \
        --no-cache-dir \
        --no-deps \
        -r /tmp/requirements-ivtc.txt; \
    rm -f /tmp/requirements-ivtc.txt

RUN python - <<'PY'
import importlib.metadata as metadata

import vapoursynth as vs
from vsaa import NNEDI3, pre_aa
from vsdehalo import hq_dering
import vsdeinterlace
from vsdenoise import bm3d
from vsdenoise.fft import DFTTest
from vsmasktools import Morpho, dre_edgemask
from vssource import BestSource
from vstools import depth, get_y

expected_versions = {
    "VapourSynth": "77",
    "vsjetpack": "1.5.0",
    "vapoursynth-vszip": "17.0.0",
    "numpy": "2.5.0",
    "vapoursynth-vivtc": "2.0",
}
for distribution, expected in expected_versions.items():
    actual = metadata.version(distribution)
    if actual != expected:
        raise SystemExit(
            f"Unexpected {distribution} version: expected {expected}, got {actual}"
        )

core = vs.core
missing = [namespace for namespace in ("vivtc", "vszip") if not hasattr(core, namespace)]
if missing:
    raise SystemExit(f"Missing VapourSynth plugin namespace(s): {', '.join(missing)}")

# Exercise the new IVTC plugin instead of checking only that it can be imported.
source = core.std.BlankClip(
    width=720,
    height=480,
    format=vs.YUV420P8,
    length=30,
    fpsnum=30000,
    fpsden=1001,
)
ivtc = core.vivtc.VDecimate(core.vivtc.VFM(source, order=1))
if ivtc.num_frames != 24:
    raise SystemExit(f"Unexpected IVTC frame count: expected 24, got {ivtc.num_frames}")
ivtc.get_frame(0)

print(str(core))
print("Pinned legacy tool versions and IVTC checks passed")
PY

RUN set -eux; \
    vspipe --version; \
    av1an --version; \
    SvtAv1EncApp --version; \
    ffmpeg -hide_banner -version | head -n 1; \
    mkvmerge --version; \
    rclone version; \
    gh --version

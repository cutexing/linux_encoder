# syntax=docker/dockerfile:1.7

ARG SVT_AV1_PSY_REPO=https://github.com/5fish/svt-av1-psy.git
ARG SVT_AV1_PSY_REF=b8f24a7113ddc4d12a1b5ccfe47ca1c4626c58d5
ARG AV1AN_REPO=https://github.com/rust-av/Av1an.git
ARG AV1AN_REF=962c57a1170e12e3ed0a287cc409ee1bc342821c
ARG ARCH_MIRROR=https://mirror.rackspace.com/archlinux

FROM archlinux:base-devel AS svt-av1-psy-builder

ARG ARCH_MIRROR
ARG SVT_AV1_PSY_REPO
ARG SVT_AV1_PSY_REF
ARG MAKEPKG_CFLAGS="-march=x86-64-v3 -mtune=generic -O3 -pipe -fno-plt"
ARG MAKEPKG_MAKEFLAGS=auto

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -eux; \
    printf 'Server = %s/$repo/os/$arch\n' "${ARCH_MIRROR}" > /etc/pacman.d/mirrorlist; \
    sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf; \
    pacman -Syu --noconfirm; \
    pacman -S --noconfirm --needed ca-certificates clang cmake git lld llvm nasm ninja; \
    rm -rf /var/cache/pacman/pkg/* /var/lib/pacman/sync/*

RUN set -eux; \
    git init /opt/svt-av1-psy; \
    cd /opt/svt-av1-psy; \
    git remote add origin "${SVT_AV1_PSY_REPO}"; \
    git fetch --depth 1 origin "${SVT_AV1_PSY_REF}"; \
    git checkout --detach FETCH_HEAD; \
    test "$(git rev-parse HEAD)" = "${SVT_AV1_PSY_REF}"; \
    if [ "${MAKEPKG_MAKEFLAGS}" = "auto" ]; then jobs="$(nproc)"; else jobs="${MAKEPKG_MAKEFLAGS}"; fi; \
    AR=llvm-ar RANLIB=llvm-ranlib \
        Build/linux/build.sh \
            --disable-native \
            --disable-avx512 \
            --static \
            --release \
            --enable-lto \
            --enable-pgo \
            --asm nasm \
            --cc clang \
            --cxx clang++ \
            --gen Ninja \
            --jobs "${jobs}" \
            --prefix /opt/svt-av1-psy-install \
            --install \
            -- \
            -DCMAKE_C_FLAGS="${MAKEPKG_CFLAGS}" \
            -DCMAKE_CXX_FLAGS="${MAKEPKG_CFLAGS}" \
            -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld" \
            -DCMAKE_SHARED_LINKER_FLAGS="-fuse-ld=lld" \
            -DCMAKE_MODULE_LINKER_FLAGS="-fuse-ld=lld"; \
    new_bin="$(find /opt/svt-av1-psy -type f -name SvtAv1EncApp -perm -111 -print -quit)"; \
    test -n "${new_bin}"; \
    install -Dm755 "${new_bin}" /opt/svt-av1-psy-install/bin/SvtAv1EncApp; \
    test -n "$(find /opt/svt-av1-psy-install -type f -name SvtAv1EncApp -print -quit)"; \
    /opt/svt-av1-psy-install/bin/SvtAv1EncApp --version

FROM archlinux:base-devel AS av1an-builder

ARG ARCH_MIRROR
ARG AV1AN_REPO
ARG AV1AN_REF
ARG MAKEPKG_RUSTFLAGS="-C target-cpu=x86-64-v3"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -eux; \
    printf 'Server = %s/$repo/os/$arch\n' "${ARCH_MIRROR}" > /etc/pacman.d/mirrorlist; \
    sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf; \
    pacman -Syu --noconfirm; \
    pacman -S --noconfirm --needed ca-certificates git nasm rust vapoursynth; \
    rm -rf /var/cache/pacman/pkg/* /var/lib/pacman/sync/*

RUN set -eux; \
    git init /opt/av1an; \
    cd /opt/av1an; \
    git remote add origin "${AV1AN_REPO}"; \
    git fetch --depth 1 origin "${AV1AN_REF}"; \
    git checkout --detach FETCH_HEAD; \
    test "$(git rev-parse HEAD)" = "${AV1AN_REF}"; \
    CARGO_NET_GIT_FETCH_WITH_CLI=true RUSTFLAGS="${MAKEPKG_RUSTFLAGS}" cargo build --release --locked -p av1an; \
    strip target/release/av1an; \
    vapoursynth config; \
    VSSCRIPT_PATH="$(vapoursynth get-vsscript)" target/release/av1an --version

FROM archlinux:base-devel

ARG ARCH_MIRROR
ARG MAKEPKG_CFLAGS="-march=x86-64-v3 -mtune=generic -O3 -pipe -fno-plt"
ARG MAKEPKG_RUSTFLAGS="-C target-cpu=x86-64-v3"
ARG MAKEPKG_MAKEFLAGS=auto

LABEL org.opencontainers.image.title="auto_encoder VapourSynth runtime"
LABEL org.opencontainers.image.description="Arch Linux runtime for auto_encoder's VapourSynth R76/JET/vszip templates with 5fish SVT-AV1-PSY b8f24a7 built static for AVX2/x86-64-v3 with LLVM clang, LLD, NASM, LTO, and PGO."

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONUNBUFFERED=1

RUN set -eux; \
    printf 'Server = %s/$repo/os/$arch\n' "${ARCH_MIRROR}" > /etc/pacman.d/mirrorlist; \
    sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf; \
    pacman -Syu --noconfirm; \
    pacman -S --noconfirm --needed \
        aom \
        bash \
        ca-certificates \
        curl \
        ffmpeg \
        fuse3 \
        git \
        github-cli \
        jq \
        libvpx \
        mediainfo \
        mkvtoolnix-cli \
        mktorrent \
        nano \
        opencc \
        opus-tools \
        python \
        python-pip \
        rclone \
        svt-av1 \
        vapoursynth \
        vmaf \
        wget \
        x265 \
        xz \
        zimg; \
    rm -rf /var/cache/pacman/pkg/* /var/lib/pacman/sync/*

RUN set -eux; \
    sed -i "s|^CFLAGS=.*|CFLAGS=\"${MAKEPKG_CFLAGS}\"|" /etc/makepkg.conf; \
    sed -i "s|^CXXFLAGS=.*|CXXFLAGS=\"${MAKEPKG_CFLAGS}\"|" /etc/makepkg.conf; \
    if grep -q '^RUSTFLAGS=' /etc/makepkg.conf; then \
        sed -i "s|^RUSTFLAGS=.*|RUSTFLAGS=\"${MAKEPKG_RUSTFLAGS}\"|" /etc/makepkg.conf; \
    else \
        printf '\nRUSTFLAGS="%s"\n' "${MAKEPKG_RUSTFLAGS}" >> /etc/makepkg.conf; \
    fi; \
    if [ "${MAKEPKG_MAKEFLAGS}" = "auto" ]; then jobs="$(nproc)"; else jobs="${MAKEPKG_MAKEFLAGS}"; fi; \
    if grep -q '^#\?MAKEFLAGS=' /etc/makepkg.conf; then \
        sed -i "s|^#\?MAKEFLAGS=.*|MAKEFLAGS=\"-j${jobs}\"|" /etc/makepkg.conf; \
    else \
        printf '\nMAKEFLAGS="-j%s"\n' "${jobs}" >> /etc/makepkg.conf; \
    fi; \
    grep -E '^(CFLAGS|CXXFLAGS|RUSTFLAGS|MAKEFLAGS)=' /etc/makepkg.conf

COPY requirements-vapoursynth.txt /tmp/requirements-vapoursynth.txt

RUN set -eux; \
    python -m pip install --break-system-packages --upgrade pip setuptools wheel; \
    python -m pip install --break-system-packages --no-cache-dir -r /tmp/requirements-vapoursynth.txt; \
    vapoursynth config

RUN python - <<'PY'
import vapoursynth as vs
from vsaa import NNEDI3, pre_aa
from vsdehalo import hq_dering
from vsdenoise import bm3d
from vsdenoise.fft import DFTTest
from vsmasktools import Morpho, dre_edgemask
from vssource import BestSource
from vstools import depth, get_y

core = vs.core
missing = [namespace for namespace in ("vszip",) if not hasattr(core, namespace)]
if missing:
    raise SystemExit(f"Missing VapourSynth plugin namespace(s): {', '.join(missing)}")
print(core.version())
print("auto_encoder VapourSynth imports ok")
PY

COPY --from=av1an-builder /opt/av1an/target/release/av1an /usr/local/libexec/av1an

RUN set -eux; \
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'set -e' \
        'if [ -z "${VSSCRIPT_PATH:-}" ]; then' \
        '  VSSCRIPT_PATH="$(vapoursynth get-vsscript 2>/dev/null || true)"' \
        '  export VSSCRIPT_PATH' \
        'fi' \
        'exec /usr/local/libexec/av1an "$@"' \
        > /usr/local/bin/av1an; \
    chmod 755 /usr/local/bin/av1an

COPY --from=svt-av1-psy-builder /opt/svt-av1-psy-install /tmp/svt-av1-psy

RUN set -eux; \
    new_bin="$(find /tmp/svt-av1-psy -type f -name SvtAv1EncApp -print -quit)"; \
    test -n "${new_bin}"; \
    mkdir -p /usr/lib; \
    install -Dm755 "${new_bin}" /usr/local/bin/SvtAv1EncApp; \
    find /tmp/svt-av1-psy \( -type f -o -type l \) -name 'libSvtAv1*.so*' -exec cp -a {} /usr/lib/ \; ; \
    if command -v ldconfig >/dev/null 2>&1; then ldconfig; fi; \
    rm -rf /tmp/svt-av1-psy; \
    SvtAv1EncApp --version

RUN set -eux; \
    mkdir -p /videos /work; \
    if [ -f /etc/fuse.conf ]; then sed -i 's/^#user_allow_other/user_allow_other/' /etc/fuse.conf || true; fi; \
    test -e "$(vapoursynth get-vsscript)"; \
    vspipe --version; \
    av1an --version; \
    ffmpeg -hide_banner -version | head -n 1; \
    mkvmerge --version; \
    opusenc --version; \
    mediainfo --Version; \
    mktorrent -h >/dev/null; \
    rclone version; \
    gh --version

VOLUME ["/videos", "/work"]
WORKDIR /work

CMD ["bash"]

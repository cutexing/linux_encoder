# syntax=docker/dockerfile:1

ARG BASE_IMAGE=cutexing/encoder:latest
ARG ARCH_REPO_DATE=2026/05/22
ARG MEDIAINFO_ARCH_REPO_DATE=2025/10/23
ARG MAKEPKG_CFLAGS="-march=x86-64-v3 -mtune=generic -O3 -pipe -fno-plt"
ARG MAKEPKG_RUSTFLAGS="-C target-cpu=x86-64-v3"
ARG MAKEPKG_MAKEFLAGS=auto
ARG SVT_AV1_PSYEX_URL=https://github.com/BlueSwordM/svt-av1-psyex/releases/download/v3.0.2-B/Linux_svt-av1-psyex-v3.0.2B_x86-64-v3_avx2.tar.lzma

FROM debian:bookworm-slim AS svt-av1-psyex

ARG SVT_AV1_PSYEX_URL

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl xz-utils; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    mkdir -p /opt/svt-av1-psyex; \
    curl -fL "${SVT_AV1_PSYEX_URL}" -o /tmp/svt-av1-psyex.tar.lzma; \
    xz -dc /tmp/svt-av1-psyex.tar.lzma | tar -x -C /opt/svt-av1-psyex; \
    test -n "$(find /opt/svt-av1-psyex -type f -name SvtAv1EncApp -print -quit)"

FROM ${BASE_IMAGE}

ARG ARCH_REPO_DATE
ARG MEDIAINFO_ARCH_REPO_DATE
ARG MAKEPKG_CFLAGS
ARG MAKEPKG_RUSTFLAGS
ARG MAKEPKG_MAKEFLAGS

USER root

RUN set -eux; \
    printf 'Server = https://archive.archlinux.org/repos/%s/$repo/os/$arch\n' "${ARCH_REPO_DATE}" > /etc/pacman.d/mirrorlist; \
    pacman-key --init; \
    pacman-key --populate archlinux; \
    pacman -Syy --noconfirm --needed archlinux-keyring; \
    pacman-key --populate archlinux; \
    pacman -S --noconfirm --needed ca-certificates github-cli rclone fuse3 mktorrent opencc; \
    printf 'Server = https://archive.archlinux.org/repos/%s/$repo/os/$arch\n' "${MEDIAINFO_ARCH_REPO_DATE}" > /etc/pacman.d/mirrorlist; \
    pacman -Syy --noconfirm --needed mediainfo; \
    if [ -f /etc/fuse.conf ]; then sed -i 's/^#user_allow_other/user_allow_other/' /etc/fuse.conf || true; fi; \
    rm -rf /var/cache/pacman/pkg/* /var/lib/pacman/sync/*; \
    git --version; \
    gh --version; \
    rclone version; \
    command -v mktorrent; \
    mktorrent -h >/dev/null; \
    opencc --version; \
    mediainfo --Version

RUN set -eux; \
    sed -i "s|^CFLAGS=.*|CFLAGS=\"${MAKEPKG_CFLAGS}\"|" /etc/makepkg.conf; \
    sed -i "s|^CXXFLAGS=.*|CXXFLAGS=\"${MAKEPKG_CFLAGS}\"|" /etc/makepkg.conf; \
    if grep -q '^RUSTFLAGS=' /etc/makepkg.conf; then sed -i "s|^RUSTFLAGS=.*|RUSTFLAGS=\"${MAKEPKG_RUSTFLAGS}\"|" /etc/makepkg.conf; else printf '\nRUSTFLAGS="%s"\n' "${MAKEPKG_RUSTFLAGS}" >> /etc/makepkg.conf; fi; \
    if [ "${MAKEPKG_MAKEFLAGS}" = "auto" ]; then jobs="$(nproc)"; else jobs="${MAKEPKG_MAKEFLAGS}"; fi; \
    if grep -q '^#\?MAKEFLAGS=' /etc/makepkg.conf; then sed -i "s|^#\?MAKEFLAGS=.*|MAKEFLAGS=\"-j${jobs}\"|" /etc/makepkg.conf; else printf '\nMAKEFLAGS="-j%s"\n' "${jobs}" >> /etc/makepkg.conf; fi; \
    grep -E '^(CFLAGS|CXXFLAGS|RUSTFLAGS|MAKEFLAGS)=' /etc/makepkg.conf

USER user
WORKDIR /home/user

RUN set -eux; \
    wget -qO /tmp/rustup-init.sh https://sh.rustup.rs; \
    sh /tmp/rustup-init.sh -y --profile minimal --default-toolchain stable --no-modify-path; \
    . "${HOME}/.cargo/env"; \
    git clone https://github.com/kageru/adaptivegrain.git; \
    cd adaptivegrain; \
    RUSTFLAGS="${MAKEPKG_RUSTFLAGS}" cargo build --release --locked; \
    rm -rf "${HOME}/.cargo" "${HOME}/.rustup" /tmp/rustup-init.sh

USER root
WORKDIR /videos

RUN set -eux; \
    install -Dm755 /home/user/adaptivegrain/target/release/libadaptivegrain_rs.so /usr/lib/vapoursynth/libadaptivegrain.so; \
    rm -rf /home/user/adaptivegrain; \
    python -m pip install --break-system-packages --no-cache-dir --no-deps vapoursynth-akarin vsutil; \
    site_packages="$(python -c 'import site; print(site.getsitepackages()[0])')"; \
    wget -O "${site_packages}/kagefunc.py" https://raw.githubusercontent.com/Irrational-Encoding-Wizardry/kagefunc/refs/heads/master/kagefunc.py; \
    wget -O "${site_packages}/fvsfunc.py" https://raw.githubusercontent.com/Irrational-Encoding-Wizardry/fvsfunc/refs/heads/master/fvsfunc.py; \
    wget -O /tmp/mvsfunc-r10.zip https://github.com/HomeOfVapourSynthEvolution/mvsfunc/archive/refs/tags/r10.zip; \
    unzip -o /tmp/mvsfunc-r10.zip -d /tmp; \
    mv /tmp/mvsfunc-r10/mvsfunc.py "${site_packages}/mvsfunc.py"; \
    rm -rf /tmp/mvsfunc-r10 /tmp/mvsfunc-r10.zip; \
    python -c "import vapoursynth as vs, kagefunc as kgf; core = vs.core; clip = core.std.BlankClip(width=128, height=72, format=vs.YUV420P8, length=1); kgf.adaptive_grain(clip, strength=0.1).get_frame(0); print('kagefunc adaptive_grain ok')"

COPY --from=svt-av1-psyex /opt/svt-av1-psyex /tmp/svt-av1-psyex

ENV LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH}

RUN set -eux; \
    new_bin="$(find /tmp/svt-av1-psyex -type f -name SvtAv1EncApp -print -quit)"; \
    test -n "${new_bin}"; \
    target_bin="$(command -v SvtAv1EncApp || true)"; \
    if [ -z "${target_bin}" ]; then target_bin=/usr/local/bin/SvtAv1EncApp; fi; \
    mkdir -p "$(dirname "${target_bin}")" /usr/local/lib; \
    cp "${new_bin}" "${target_bin}"; \
    chmod 0755 "${target_bin}"; \
    find /tmp/svt-av1-psyex \( -type f -o -type l \) -name 'libSvtAv1*.so*' -exec cp -a {} /usr/local/lib/ \; ; \
    if command -v ldconfig >/dev/null 2>&1; then ldconfig; fi; \
    rm -rf /tmp/svt-av1-psyex; \
    "${target_bin}" --version

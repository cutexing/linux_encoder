# syntax=docker/dockerfile:1

ARG BASE_IMAGE=cutexing/encoder:latest
ARG ARCH_REPO_DATE=2026/05/22
ARG MEDIAINFO_ARCH_REPO_DATE=2025/10/23
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

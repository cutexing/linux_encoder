# syntax=docker/dockerfile:1.7

# For main, explicitly pass its known-good immutable digest as BASE_IMAGE.
ARG BASE_IMAGE=cutexing/encoder:5fish-av1@sha256:8246c80841c8990283d9a9dfdcdd4e24d316c7aa1fa8aaa40a4d3af774e8f1e8

# This stage is identical for both frozen encoder bases and does not ship Go or sources.
FROM cutexing/encoder:5fish-av1@sha256:8246c80841c8990283d9a9dfdcdd4e24d316c7aa1fa8aaa40a4d3af774e8f1e8 AS security-tools
COPY variants/security/build_tools.py /tmp/build_tools.py
COPY variants/security/tool-sources.json /tmp/tool-sources.json
RUN python /tmp/build_tools.py

FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.description="Security overlay: Python 3.14.8, OpenSSL 3.6.5, Expat 2.8.5, pip 26.2.2; frozen VapourSynth and plugins verified by SHA256."

COPY variants/security/verify_runtime.py /tmp/verify_runtime.py
COPY variants/security/requirements.txt /tmp/security-requirements.txt
COPY variants/security/os-packages.json /tmp/os-packages.json
COPY variants/security/install_os_updates.py /tmp/install_os_updates.py
COPY variants/security/pip-vendor.json /tmp/pip-vendor.json
COPY variants/security/patch_pip_vendor.py /tmp/patch_pip_vendor.py
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

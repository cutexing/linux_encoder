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

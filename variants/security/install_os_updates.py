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

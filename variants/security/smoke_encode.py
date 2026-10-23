"""Exercise the frozen video pipeline and local rclone copy without credentials."""

import hashlib
import json
from pathlib import Path
import subprocess
import sys

import numpy as np
import vapoursynth as vs


script = Path("/tmp/encoder-security-smoke.vpy")
script.write_text('''import numpy as np
import vapoursynth as vs
core = vs.core
core.num_threads = 2
base = core.std.BlankClip(width=320, height=240, format=vs.YUV420P8,
                          length=30, fpsnum=30000, fpsden=1001)
def paint(n, f):
    frame = f.copy()
    for plane in range(3):
        target = np.asarray(frame[plane])
        if plane == 0:
            y, x = np.indices(target.shape)
            target[:] = (x + y + n * 3) % 220 + 16
        else:
            target[:] = 128
    return frame
source = core.std.ModifyFrame(base, base, paint)
source = core.vszip.BoxBlur(source)
if hasattr(core, "vivtc"):
    source = core.vivtc.VDecimate(core.vivtc.VFM(source, order=1))
source.set_output()
''')
video = Path("/tmp/encoder-security-smoke.ivf")
with Path("/tmp/encoder-security-smoke.log").open("wb") as log:
    producer = subprocess.Popen(["vspipe", "--container", "y4m", str(script), "-"], stdout=subprocess.PIPE,
                                stderr=log)
    try:
        encoded = subprocess.run(["SvtAv1EncApp", "-i", "stdin", "-b", str(video),
                                  "--preset", "12", "--crf", "35", "--lp", "2", "--keyint", "24"],
                                 stdin=producer.stdout, stdout=log, stderr=log, timeout=120)
        producer.stdout.close()
        assert producer.wait(timeout=20) == 0, "vspipe failed"
        assert encoded.returncode == 0, "SvtAv1EncApp failed"
    except Exception:
        log.flush()
        print(Path("/tmp/encoder-security-smoke.log").read_text(errors="replace")[-8000:],
              file=sys.stderr)
        raise
    finally:
        if producer.poll() is None:
            producer.kill()
            producer.wait()

probe = json.loads(subprocess.check_output([
    "ffprobe", "-v", "error", "-count_frames", "-select_streams", "v:0",
    "-show_entries", "stream=codec_name,nb_read_frames", "-of", "json", str(video)
]))["streams"][0]
assert probe["codec_name"] == "av1"
assert int(probe["nb_read_frames"]) in (24, 30)
decoded = subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(video),
                                   "-f", "rawvideo", "-pix_fmt", "yuv420p", "-"])
vs.core.num_threads = 2
source = vs.core.bs.VideoSource(source=str(video), cachemode=0, threads=2)
assert source.num_frames == int(probe["nb_read_frames"])
source_digest = hashlib.sha256()
for frame in source.frames():
    for plane in frame:
        source_digest.update(np.asarray(plane).tobytes())
    frame.close()
assert source_digest.hexdigest() == hashlib.sha256(decoded).hexdigest(), "BestSource decode drift"
destination = Path("/tmp/encoder-security-copy")
subprocess.run(["rclone", "copyto", "--config", "/dev/null", str(video),
                str(destination)], check=True, capture_output=True)
assert video.read_bytes() == destination.read_bytes()
print(json.dumps({"codec": "av1", "frames": int(probe["nb_read_frames"]),
                  "encoded_sha256": hashlib.sha256(video.read_bytes()).hexdigest(),
                  "decoded_sha256": hashlib.sha256(decoded).hexdigest(),
                  "bestsource_decode": "matched FFmpeg",
                  "rclone_local_copy": "passed"}))

# linux_encoder

這個分支專供 `C:\Users\user\Documents\auto_encoder` 的新版 VapourSynth/JET 模板使用。

根目錄 `Dockerfile` 已不再維護舊模板需要的大量 AUR plugin 清單，改成以 `auto_encoder` 目前產生的 `.vpy` 為準：

- VapourSynth R76+
- `vsjetpack[deband]`
- `vapoursynth-vszip`
- `BestSource` / `vssource`
- `vstools`、`vsmasktools`、`vsaa`、`vsdehalo`
- upstream `av1an` pinned build、`ffmpeg`、`mkvtoolnix`、`opus-tools`
- `mktorrent`、`rclone`、`gh`、`mediainfo`、`opencc`

伺服器假設支援 AVX2，因此 image 會把 `SvtAv1EncApp` 換成 `SVT-AV1-PSYEX v3.0.2-B` 的 `x86-64-v3_avx2` build。`makepkg.conf` 也預設成 `-march=x86-64-v3`，方便之後在 container 內補編譯工具時沿用同一個 CPU baseline。

Arch 官方 `av1an` package 目前仍會在 VapourSynth R76 上觸發舊 VSScript API panic，因此這個分支改從 upstream `rust-av/Av1an` pinned commit 編譯 `av1an`，避免部署時被 distro package 的更新節奏卡住。

VapourSynth R74+ 的 VSScript library 由 Python wheel 提供，不能可靠地硬綁 `/usr/lib/libvapoursynth-script.so` symlink；image 內的 `av1an` wrapper 會在啟動時用 `vapoursynth get-vsscript` 動態設定 `VSSCRIPT_PATH`。

## Build

```bash
docker build -t cutexing/encoder:auto-encoder-vs76 .
```

可覆寫 PSYEX 來源：

```bash
docker build \
  --build-arg SVT_AV1_PSYEX_URL=https://example/SVT-AV1-PSYEX.tar.lzma \
  -t cutexing/encoder:auto-encoder-vs76 .
```

可覆寫 Arch mirror：

```bash
docker build \
  --build-arg ARCH_MIRROR=https://mirror.rackspace.com/archlinux \
  -t cutexing/encoder:auto-encoder-vs76 .
```

可覆寫 upstream `av1an` 來源或 commit：

```bash
docker build \
  --build-arg AV1AN_REPO=https://github.com/rust-av/Av1an.git \
  --build-arg AV1AN_REF=962c57a1170e12e3ed0a287cc409ee1bc342821c \
  -t cutexing/encoder:auto-encoder-vs76 .
```

Build 過程會檢查：

- `vapoursynth config`
- `from vssource import BestSource`
- `from vstools/vsmasktools/vsaa/vsdehalo import ...`
- `core.vszip`
- `vspipe --version`
- `av1an --version`
- `SvtAv1EncApp --version`
- 發布流程會用到的 CLI 工具版本

## Run

將 `auto_encoder` 掛到 `/work`，影片資料夾掛到 `/videos`：

```bash
docker run --rm -it \
  -v /path/to/auto_encoder:/work \
  -v /path/to/videos:/videos \
  cutexing/encoder:auto-encoder-vs76
```

進入容器後可以直接跑：

```bash
python /work/auto_encoder.py plan \
  --source-dir "/videos/Some.Show.S01.2026.1080p.WEB-DL.x264.AAC-GROUP"
```

完整流程：

```bash
python /work/auto_encoder.py all \
  --source-dir "/videos/Some.Show.S01.2026.1080p.WEB-DL.x264.AAC-GROUP"
```

## Publish Mounts

若要跑 `publish`，通常還會額外掛入站點 repo、rclone config 與 GitHub CLI config：

```bash
docker run --rm -it \
  -v /path/to/auto_encoder:/work \
  -v /path/to/videos:/videos \
  -v /path/to/site:/work/site \
  -v "$HOME/.config/rclone:/root/.config/rclone:ro" \
  -v "$HOME/.config/gh:/root/.config/gh:ro" \
  cutexing/encoder:auto-encoder-vs76
```

`rclone mount` 需要 FUSE 權限：

```bash
docker run --rm -it \
  --cap-add SYS_ADMIN \
  --device /dev/fuse \
  --security-opt apparmor:unconfined \
  -v "$HOME/.config/rclone:/root/.config/rclone:ro" \
  -v "$PWD/rclone-mount:/mnt/rclone:shared" \
  cutexing/encoder:auto-encoder-vs76 \
  sh -lc 'mkdir -p /mnt/rclone && rclone mount <remote>:<path> /mnt/rclone --allow-other --vfs-cache-mode writes'
```

## Dependency Sync

`requirements-vapoursynth.txt` 應與 `auto_encoder/requirements-vapoursynth.txt` 保持同步。這份檔案放在本 repo，是為了讓 Docker build context 可以獨立完成，不需要在 build 時讀取旁邊的 `auto_encoder` 工作區。

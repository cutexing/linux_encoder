# linux_encoder

這個 repository 保存 `cutexing/encoder` 系列 image 的 Dockerfile。根目錄 `Dockerfile` 是原始 Arch Linux 壓片環境；額外變體會放在 `variants/` 底下，方便之後擴充而不混在同一個檔案裡。

[手動部署說明](https://blog.cutexing.com/2025/03/20/linux-%e5%a3%93%e7%89%87%e7%92%b0%e5%a2%83%e5%bb%ba%e7%ab%8b%e6%8c%87%e5%8d%97/)

## Image 版本

| Docker tag | Dockerfile | 內容 |
| --- | --- | --- |
| `cutexing/encoder:latest` | `Dockerfile` | 原始 Arch Linux 壓片環境。包含 `git`、`yay`、`aom`、`vapoursynth`、`ffms2`、`libvpx`、`mkvtoolnix-cli`、官方 `svt-av1`、`vmaf`、`av1an`、`wget`、`unzip`、`nano`、`opus-tools`、`python-pip`，以及多個 VapourSynth AUR plugins、`kagefunc.py`、`fvsfunc.py`、`mvsfunc.py`。 |
| `cutexing/encoder:psyex-v3.0.2B-tools` | `variants/psyex-tools/Dockerfile` | 以 `cutexing/encoder:latest` 為 base，將 `SvtAv1EncApp` 替換為 `SVT-AV1-PSYEX v3.0.2-B`，並加入 `rclone`、`gh`、`fuse3` / `fusermount3`、`mktorrent`、`opencc`、`mediainfo`。目前已推送 digest：`sha256:82816c638df270ab096b5223c59250c407eed022be5991856d76dba3b481777e`。 |

## 基本使用

把本機影片資料夾掛到容器內 `/videos`：

```bash
docker run --privileged \
  -v /your/video/dir:/videos \
  -it --rm \
  cutexing/encoder:latest
```

使用 PSYEX + tools 版本：

```bash
docker run --privileged \
  -v /your/video/dir:/videos \
  -it --rm \
  cutexing/encoder:psyex-v3.0.2B-tools
```

確認工具版本：

```bash
docker run --rm cutexing/encoder:psyex-v3.0.2B-tools SvtAv1EncApp --version
docker run --rm cutexing/encoder:psyex-v3.0.2B-tools rclone version
docker run --rm cutexing/encoder:psyex-v3.0.2B-tools gh --version
docker run --rm cutexing/encoder:psyex-v3.0.2B-tools mktorrent -h
docker run --rm cutexing/encoder:psyex-v3.0.2B-tools opencc --version
docker run --rm cutexing/encoder:psyex-v3.0.2B-tools mediainfo --Version
```

## rclone config 掛載

一般使用者的 rclone config 通常在 `$HOME/.config/rclone`：

```bash
docker run --rm -it \
  -v "$HOME/.config/rclone:/root/.config/rclone:ro" \
  cutexing/encoder:psyex-v3.0.2B-tools \
  sh -lc 'rclone config file && rclone listremotes'
```

如果 config 放在 server 的 root 底下，使用 sudo 執行時可以掛 `/root/.config/rclone`：

```bash
sudo docker run --rm -it \
  -v /root/.config/rclone:/root/.config/rclone:ro \
  cutexing/encoder:psyex-v3.0.2B-tools \
  sh -lc 'rclone config file && rclone listremotes'
```

## rclone mount

`rclone mount` 需要 FUSE 權限。下面範例會把 remote 掛到 host 的 `./rclone-mount`：

```bash
mkdir -p "$PWD/rclone-mount"

docker run --rm -it \
  --cap-add SYS_ADMIN \
  --device /dev/fuse \
  --security-opt apparmor:unconfined \
  -v "$HOME/.config/rclone:/root/.config/rclone:ro" \
  -v "$PWD/rclone-mount:/mnt/rclone:shared" \
  cutexing/encoder:psyex-v3.0.2B-tools \
  sh -lc 'mkdir -p /mnt/rclone && rclone mount <remote>:<path> /mnt/rclone --allow-other --vfs-cache-mode writes'
```

使用 root config 的版本：

```bash
sudo mkdir -p /mnt/rclone

sudo docker run --rm -it \
  --cap-add SYS_ADMIN \
  --device /dev/fuse \
  --security-opt apparmor:unconfined \
  -v /root/.config/rclone:/root/.config/rclone:ro \
  -v /mnt/rclone:/mnt/rclone:shared \
  cutexing/encoder:psyex-v3.0.2B-tools \
  sh -lc 'mkdir -p /mnt/rclone && rclone mount <remote>:<path> /mnt/rclone --allow-other --vfs-cache-mode writes'
```

把 `<remote>:<path>` 換成自己的 rclone remote，例如 `nc:/videos`、`r2:bucket/path`。

## GitHub CLI config 掛載

容器內有 `gh`，但不會內建 GitHub token。把 host 的 gh config 掛進去即可檢查登入狀態：

```bash
docker run --rm -it \
  -v "$HOME/.config/gh:/root/.config/gh:ro" \
  cutexing/encoder:psyex-v3.0.2B-tools \
  gh auth status
```

若需要在容器內操作 repo，也可以一起掛 SSH key 與 git config：

```bash
docker run --rm -it \
  -v "$HOME/.config/gh:/root/.config/gh:ro" \
  -v "$HOME/.ssh:/root/.ssh:ro" \
  -v "$HOME/.gitconfig:/root/.gitconfig:ro" \
  -v "$PWD:/work" \
  -w /work \
  cutexing/encoder:psyex-v3.0.2B-tools \
  sh -lc 'gh auth status && git status'
```

## mktorrent

```bash
docker run --rm -it \
  -v "$PWD:/work" \
  -w /work \
  cutexing/encoder:psyex-v3.0.2B-tools \
  mktorrent -a <tracker-url> <path>
```

## 注意事項

- image 不會包入 rclone 或 GitHub 憑證；請用 volume mount 掛入 config。
- config 建議使用 `:ro` 唯讀掛載，除非需要在容器內更新登入狀態。
- `rclone mount` 的 host 掛載點需要使用 shared propagation；Docker Desktop、rootless Docker 或部分 VPS kernel 設定可能需要額外調整。

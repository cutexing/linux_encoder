# linux_encoder

這個 repository 保存 `cutexing/encoder` 系列 image 的 Dockerfile。現在只保留新版 `auto_encoder` / VapourSynth R76 環境，以及使用 5fish `svt-av1-psy` 的 AVX2 變體。

[手動部署說明](https://blog.cutexing.com/2025/03/20/linux-%e5%a3%93%e7%89%87%e7%92%b0%e5%a2%83%e5%bb%ba%e7%ab%8b%e6%8c%87%e5%8d%97/)

## Image 版本

| Docker tag | Dockerfile | 內容 |
| --- | --- | --- |
| `cutexing/encoder:main` | `Dockerfile` | 專供新版 `auto_encoder` VapourSynth/JET 模板使用。使用 VapourSynth R76+、`vsjetpack[deband,denoise]`、`vapoursynth-vszip`、`BestSource` / `vssource`、upstream pinned `av1an`，並以 `SVT-AV1-PSYEX v3.0.2-B` 的 `x86-64-v3_avx2` build 作為 AVX2 server baseline。目前已推送 digest：`sha256:344e4b660394b93610f7ef50c4fba21b90980abc37bcd9c9a7c537fc1204f018`。 |
| `cutexing/encoder:5fish-av1` | `variants/5fish-av1/Dockerfile` | 基於 `main` 的 VapourSynth R76/JET/vszip 環境，將 `SvtAv1EncApp` 替換為 5fish `svt-av1-psy` commit `b8f24a7113ddc4d12a1b5ccfe47ca1c4626c58d5`，並以 AVX2 / `x86-64-v3` 編譯。目前已推送 digest：`sha256:c540c113c5973173580518152d57de63af8ca5f6acdccc0760978a47a4a0b4d9`。 |

## 基本使用

使用新版 `auto_encoder` / VapourSynth R76 版本：

```bash
docker run --rm -it \
  -v /path/to/auto_encoder:/work \
  -v /path/to/videos:/videos \
  cutexing/encoder:main
```

使用 5fish `svt-av1-psy` 版本：

```bash
docker run --rm -it \
  -v /path/to/auto_encoder:/work \
  -v /path/to/videos:/videos \
  cutexing/encoder:5fish-av1
```

進入容器後可以直接跑：

```bash
python /work/auto_encoder.py plan \
  --source-dir "/videos/Some.Show.S01.2026.1080p.WEB-DL.x264.AAC-GROUP"
```

確認工具版本：

```bash
docker run --rm cutexing/encoder:main sh -lc 'vapoursynth get-vsscript && vspipe --version && av1an --version && SvtAv1EncApp --version'
docker run --rm cutexing/encoder:5fish-av1 sh -lc 'vapoursynth get-vsscript && vspipe --version && av1an --version && SvtAv1EncApp --version'
```

## Build

建置 `main`：

```bash
docker build -t cutexing/encoder:main .
```

建置 5fish `svt-av1-psy` 版本：

```bash
docker build \
  -f variants/5fish-av1/Dockerfile \
  -t cutexing/encoder:5fish-av1 .
```

## rclone config 掛載

容器內有 `rclone`，但不會內建憑證。把 host 的 rclone config 掛進去即可：

```bash
docker run --rm -it \
  -v "$HOME/.config/rclone:/root/.config/rclone:ro" \
  cutexing/encoder:main \
  sh -lc 'rclone config file && rclone listremotes'
```

如果 config 放在 server 的 root 底下，使用 sudo 執行時可以掛 `/root/.config/rclone`：

```bash
sudo docker run --rm -it \
  -v /root/.config/rclone:/root/.config/rclone:ro \
  cutexing/encoder:main \
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
  cutexing/encoder:main \
  sh -lc 'mkdir -p /mnt/rclone && rclone mount <remote>:<path> /mnt/rclone --allow-other --vfs-cache-mode writes'
```

把 `<remote>:<path>` 換成自己的 rclone remote，例如 `nc:/videos`、`r2:bucket/path`。

## GitHub CLI config 掛載

容器內有 `gh`，但不會內建 GitHub token。把 host 的 gh config 掛進去即可檢查登入狀態：

```bash
docker run --rm -it \
  -v "$HOME/.config/gh:/root/.config/gh:ro" \
  cutexing/encoder:main \
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
  cutexing/encoder:main \
  sh -lc 'gh auth status && git status'
```

## mktorrent

```bash
docker run --rm -it \
  -v "$PWD:/work" \
  -w /work \
  cutexing/encoder:main \
  mktorrent -a <tracker-url> <path>
```

## 注意事項

- image 不會包入 rclone 或 GitHub 憑證；請用 volume mount 掛入 config。
- config 建議使用 `:ro` 唯讀掛載，除非需要在容器內更新登入狀態。
- `rclone mount` 的 host 掛載點需要使用 shared propagation；Docker Desktop、rootless Docker 或部分 VPS kernel 設定可能需要額外調整。
- `requirements-vapoursynth.txt` 是 `main` / `5fish-av1` 的 build context 依賴清單；更新 `auto_encoder` 模板依賴時要一起同步。

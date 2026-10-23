# linux_encoder

這個 repository 保存 `cutexing/encoder` 系列 image 的 Dockerfile。目前提供新版 `auto_encoder` 環境，以及使用 5fish `svt-av1-psy` 的 AVX2 變體；兩個已發布映像均保留 VapourSynth 77。

[手動部署說明](https://blog.cutexing.com/2025/03/20/linux-%e5%a3%93%e7%89%87%e7%92%b0%e5%a2%83%e5%bb%ba%e7%ab%8b%e6%8c%87%e5%8d%97/)

## Image 版本

| Docker tag | Dockerfile | 內容 |
| --- | --- | --- |
| `cutexing/encoder:main` | `Dockerfile` | 新版 `auto_encoder` VapourSynth/JET 模板、`BestSource` / `vssource`、upstream pinned `av1an`，以及 `SVT-AV1-PSYEX v3.0.2-B` 的 AVX2 build，加入下列安全更新。已推送 digest：`sha256:f02d9a292298fc325220fa9834f81769dc53fa15852e61ae7def2b5a0e7d6583`。 |
| `cutexing/encoder:5fish-av1` | `variants/5fish-av1/Dockerfile` | 保留 VapourSynth 77、`vsjetpack` 1.5.0、`vapoursynth-vszip` 17.0.0、FFmpeg 8.1.2、5fish `svt-av1-psy` `b8f24a7` 與 `vapoursynth-vivtc` 2.0，加入下列安全更新。已推送 digest：`sha256:5d63ac07d36f096aa8710ee5287f8ab1d5b4d97d3af7a000da312156d959e8dd`。 |

## 已整合的安全更新（2026-10-23）

根目錄 `Dockerfile` 與 `variants/5fish-av1/Dockerfile` 已直接整合通過測試的安全更新。兩者分別從更新前的不可變 main／5fish image digest 建置，對應的 `main-pre-security-20261023`／`5fish-av1-pre-security-20261023` 標籤已保留於 Docker Hub。下載來源、SHA256、修補程式與版本／檔案驗證均內嵌於 Dockerfile，不再需要獨立的安全 patch 目錄。

建置保留 VapourSynth 77、JET 1.5.0、vszip 17.0.0、5fish 的 IVTC 2.0，以及原有 FFmpeg／encoder。更新前後會逐一比對其餘 Python 套件版本、檔案 SHA256 與系統套件版本，不會重新解析或升級 VapourSynth、插件、NumPy 等依賴。建置入口沿用下方的標準 Build 指令。

| 項目 | 安全更新版本 |
| --- | --- |
| 宿主機 Docker／containerd／runc | 29.9.2／2.4.2／1.5.2 |
| Python | 3.14.8，維持 Python 3.14 ABI |
| pip／其內嵌 urllib3 | 26.2.2／2.8.0 |
| cryptography／setuptools | 50.0.2／83.0.0 |
| OpenSSL／Expat | 3.6.5／2.8.5 |
| glibc／Mozilla CA bundle | 2.44+r50+g1848099f063e／3.132 |
| rclone／GitHub CLI | 1.75.2／2.103.0，均以 Go 1.27.3 重建 |

Python 的官方 Arch 套件需要 glibc 2.44，因此兩者一起更新。只安裝 Dockerfile 內嵌套件清單列出的版本，並驗證下載 SHA256 與 Arch 簽章；Go、CLI 原始碼與 Python wheels 也固定來源及 SHA256。未使用的 `captree` 診斷執行檔已移除，`libcap` 函式庫保留。

pip 26.2.2 原本仍內嵌 urllib3 2.7.0，因此額外以官方 urllib3 2.8.0 wheel 修補 **pip 內部**的網路函式庫，並同步更新其 `vendor.txt`、SBOM、`RECORD` 與來源紀錄 `/usr/share/encoder-security/pip-urllib3.json`。這是本映像的安全覆蓋層，與未修改的官方 pip wheel 有差異；建置會實際測試修補後的 HTTPS 下載。

一般不需要 FUSE 的編碼作業可使用 `--cap-drop ALL --security-opt no-new-privileges`，並依並行程序數設定 `--pids-limit`。短片回歸測試還使用了 `--network none`、唯讀 root filesystem 與 `/tmp` tmpfs；實際上傳需要網路及相應的可寫掛載。

主要查核依據：

- Docker registry 憑證驗證：[CVE-2026-92543](https://github.com/moby/moby/security/advisories/GHSA-7cfq-22r6-qp73)。containerd 映像 manifest 處理：[CVE-2026-95839](https://github.com/containerd/containerd/security/advisories/GHSA-vwhp-8p66-mq4f)。
- pip URL 路徑處理：[CVE-2026-13346 與 pip 修補紀錄](https://pip.pypa.io/en/stable/news/)。urllib3 內嵌依賴：[CVE-2026-97687](https://github.com/urllib3/urllib3/security/advisories/GHSA-8988-9cw3-xx77)、[CVE-2026-97688](https://github.com/urllib3/urllib3/security/advisories/GHSA-gh4c-6fx4-qh6g)、[CVE-2026-97689](https://github.com/urllib3/urllib3/security/advisories/GHSA-vxq7-64xx-v4gw)。
- Python：[3.14.8 安全修補](https://www.python.org/downloads/release/python-3148/)。OpenSSL：[3.6 系列安全公告](https://openssl-library.org/news/vulnerabilities-3.6/)。Expat：[2.8.5 修補紀錄](https://github.com/libexpat/libexpat/blob/R_2_8_5/expat/Changes)。
- rclone S3／RC 驗證：[CVE-2026-88018](https://github.com/rclone/rclone/security/advisories/GHSA-xwwr-4h3p-r22c)、[CVE-2026-88044](https://github.com/rclone/rclone/security/advisories/GHSA-p569-5gjg-9cmj)。這兩項涉及特定 server 設定，不能僅由版本推定主機正遭利用。
- cryptography：[CVE-2026-69247](https://github.com/pyca/cryptography/security/advisories/GHSA-g6cj-pr64-35w5)。setuptools：[CVE-2026-59890](https://github.com/pypa/setuptools/security/advisories/GHSA-h35f-9h28-mq5c)，其平台條件主要是 macOS 的 Unicode 正規化。

驗證範圍：此為保留舊版編碼工具的受控安全更新，Arch 官方不支援部分系統升級，完整長片、所有插件功能及所有 OS CVE 並未因此獲得驗證。[Trivy 支援列表](https://trivy.dev/docs/latest/coverage/os/) 不包含 Arch OS 漏洞掃描；Python／Go 掃描結果不能代表整個 image 已沒有漏洞。既有或外部掛載的 virtualenv 也需要分別檢查。宿主機僅更新 Docker 相關套件，未執行整機 `apt upgrade` 或重開機。

[前次部署與掃描報告](https://github.com/cutexing/linux_encoder/blob/dfd9da2443817c69f0b8644ef26990580d5c5677/security-results/2026-10-23.json)記錄了安全更新的驗證結果：兩個 image 的原始通報數各由 157 降為 5（包含同一漏洞在不同 binary 的重複通報）。5fish 保留 52 個 Python distribution／3,618 個檔案雜湊，main 保留 51 個／3,611 個；AV1 編碼檔、FFmpeg 解碼影格與原 image 的 SHA256 均一致，BestSource 解碼也與 FFmpeg 相符，rclone 本地複製測試通過。這是短片測試結果，不代表所有長片或插件路徑都已驗證。

保留原始 5 項通報及適用性判斷，沒有透過 ignore 清單隱藏結果：

| 原始通報 | 已核對的適用範圍 |
| --- | --- |
| [msgpack GHSA-6v7p-g79w-8964](https://github.com/msgpack/msgpack-python/security/advisories/GHSA-6v7p-g79w-8964) | pip 只內嵌純 Python fallback，沒有通報所涉的 C 擴展。 |
| setuptools CVE-2025-47273／CVE-2026-59890 | pip 的 SBOM 列出 70.3.0，但只保留 `pkg_resources` 子集，未包含有問題的 `package_index.py`／sdist 程式；實際安裝版本為 83.0.0，且後者通報的 macOS 條件不適用。 |
| [GO-2026-5932](https://vuln.go.dev/ID/GO-2026-5932.json)，兩個 binary 各一筆 | 通報只針對 `golang.org/x/crypto/openpgp`。逐一檢查兩個 binary 的 `go list -deps`，均未使用該子套件。 |

主機本地與 Docker Hub 的 `main`／`5fish-av1` 已切換至上表的安全版本，同時發布 `main-security-20261023`／`5fish-av1-security-20261023`，方便固定本次版本。原映像也已發布於 `main-pre-security-20261023`／`5fish-av1-pre-security-20261023`，可拉取並重新標記回退。完整原始證據亦保留於部署主機的 `/home/codex/encoder-security-20261023`。

## 基本使用

使用新版 `auto_encoder` / VapourSynth 77 版本：

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
- `requirements-vapoursynth.txt` 與 `variants/5fish-av1/requirements-ivtc.txt` 保留原始環境的套件清單。正式建置以 Dockerfile 指定的不可變 image digest 鎖定完整編碼環境，不會重新安裝或解析這兩份清單。

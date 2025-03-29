可以使用 `docker pull cutexing/encoder` 快速部屬的壓制環境。

[對於手動部屬的說明](https://blog.cutexing.com/2025/03/20/linux-%e5%a3%93%e7%89%87%e7%92%b0%e5%a2%83%e5%bb%ba%e7%ab%8b%e6%8c%87%e5%8d%97/)

## 使用方法

使用 `docker run --privileged -v /your/video/dir:/videos -it --rm cutexing/encoder` 即可進入容器內

`/your/video/dir`部分改成自己要映射到容器內的 /videos 目錄

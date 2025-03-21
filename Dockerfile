# 使用 Arch Linux 基本映像
FROM archlinux:base-devel AS base

# 更新鏡像並安裝必要的依賴
RUN pacman -Syu --noconfirm && \
   pacman -S --noconfirm git base-devel

# 使用 pacman 安裝套件
RUN pacman -S --noconfirm --needed aom vapoursynth ffms2 libvpx mkvtoolnix-cli svt-av1 vmaf av1an wget unzip nano opus-tools python-pip

# 解決搭建時卡在 Entering fakeroot environment
RUN pacman -U --noconfirm https://archive.archlinux.org/packages/f/fakeroot/fakeroot-1.34-1-x86_64.pkg.tar.zst

# 創建用戶以非 root 身份執行 yay
RUN useradd -m user && \
   echo "user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER user
WORKDIR /home/user

# 安裝 yay
RUN git clone https://aur.archlinux.org/yay.git && \
   cd yay && \
   makepkg -si --noconfirm

# 使用 yay 安裝插件
RUN yay -S --noconfirm vapoursynth-plugin-lsmashsource 
RUN yay -S --noconfirm vapoursynth-plugin-fmtconv-git 
RUN yay -S --noconfirm vapoursynth-plugin-eedi2-git 
RUN yay -S --noconfirm vapoursynth-plugin-neo_f3kdb-git
RUN yay -S --noconfirm vapoursynth-plugin-addgrain-git 
RUN yay -S --noconfirm vapoursynth-plugin-awarpsharp2-git 
RUN yay -S --noconfirm vapoursynth-plugin-bm3d-git
RUN yay -S --noconfirm vapoursynth-plugin-nnedi3-git
RUN yay -S --noconfirm vapoursynth-plugin-nnedi3_weights_bin 
RUN yay -S --noconfirm vapoursynth-plugin-nnedi3_resample-git 
RUN yay -S --noconfirm vapoursynth-plugin-sangnom-git 
RUN yay -S --noconfirm vapoursynth-plugin-tcanny-git 
RUN yay -S --noconfirm vapoursynth-plugin-mvtools-git 
RUN yay -S --noconfirm vapoursynth-plugin-retinex-git 
RUN yay -S --noconfirm vapoursynth-plugin-fluxsmooth-git
RUN yay -S --noconfirm vapoursynth-plugin-bwdif-git 
RUN yay -S --noconfirm vapoursynth-plugin-cas-git 
RUN yay -S --noconfirm vapoursynth-plugin-ctmf-git 
RUN yay -S --noconfirm vapoursynth-plugin-dctfilter-git 
RUN yay -S --noconfirm vapoursynth-plugin-deblock-git 
RUN yay -S --noconfirm vapoursynth-plugin-dfttest-git 
RUN yay -S --noconfirm vapoursynth-plugin-fft3dfilter-git
RUN yay -S --noconfirm vapoursynth-plugin-hqdn3d-git 
RUN yay -S --noconfirm vapoursynth-plugin-knlmeanscl-git 
RUN yay -S --noconfirm vapoursynth-miscfilters-obsolete-git 
RUN yay -S --noconfirm vapoursynth-plugin-removegrain-git 
RUN yay -S --noconfirm vapoursynth-plugin-znedi3-git 
RUN yay -S --noconfirm vapoursynth-plugin-vsdenoise-git
RUN yay -S --noconfirm vapoursynth-plugin-vstaambk-git
RUN yay -S --noconfirm vapoursynth-plugin-havsfunc
RUN yay -S --noconfirm vapoursynth-plugin-adjust-git

USER root
RUN wget https://raw.githubusercontent.com/Irrational-Encoding-Wizardry/kagefunc/refs/heads/master/kagefunc.py
RUN mv kagefunc.py /lib64/python3.13
RUN wget https://raw.githubusercontent.com/Irrational-Encoding-Wizardry/fvsfunc/refs/heads/master/fvsfunc.py
RUN mv fvsfunc.py /lib64/python3.13
RUN wget https://github.com/HomeOfVapourSynthEvolution/mvsfunc/archive/refs/tags/r10.zip
RUN unzip r10.zip
RUN mv mvsfunc-r10/mvsfunc.py /lib64/python3.13

VOLUME ["/videos"]
WORKDIR /videos

FROM debian:bookworm-slim@sha256:98f4b71de414932439ac6ac690d7060df1f27161073c5036a7553723881bffbe

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8

RUN sed -i 's/deb.debian.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list.d/debian.sources

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash ca-certificates chromium curl \
    fonts-noto-cjk \
    fontconfig \
    novnc python3 socat websockify x11vnc xvfb locales x11-xserver-utils \
  && sed -i '/zh_CN.UTF-8/s/^# //g' /etc/locale.gen && locale-gen \
  && rm -rf /var/lib/apt/lists/*

# --- 关键：强制开启字体抗锯齿和渲染平滑 ---
RUN mkdir -p /etc/fonts/conf.d/
RUN echo '<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "fonts.dtd"><fontconfig>\
  <match target="font"><edit mode="assign" name="antialias"><bool>true</bool></edit></match>\
  <match target="font"><edit mode="assign" name="hinting"><bool>true</bool></edit></match>\
  <match target="font"><edit mode="assign" name="hintstyle"><const>hintslight</const></edit></match>\
  <match target="font"><edit mode="assign" name="lcdfilter"><const>lcddefault</const></edit></match>\
</fontconfig>' > /etc/fonts/local.conf

COPY entrypoint.sh /usr/local/bin/sandbox-browser
RUN chmod +x /usr/local/bin/sandbox-browser

RUN useradd --create-home --shell /bin/bash sandbox
USER sandbox
WORKDIR /home/sandbox

EXPOSE 9222 5900 6080
CMD ["sandbox-browser"]
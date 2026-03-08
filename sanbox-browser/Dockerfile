FROM debian:bookworm-slim@sha256:98f4b71de414932439ac6ac690d7060df1f27161073c5036a7553723881bffbe

ENV DEBIAN_FRONTEND=noninteractive
# 设置语言环境变量
ENV LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN:zh \
    LC_ALL=zh_CN.UTF-8

# 使用清华大学镜像源
RUN sed -i 's/deb.debian.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list.d/debian.sources

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    chromium \
    curl \
    # --- 添加中文字体 ---
    fonts-wqy-microhei \
    fonts-wqy-zenhei \
    xfonts-intl-chinese \
    # ------------------
    fonts-liberation \
    fonts-noto-color-emoji \
    git \
    jq \
    novnc \
    python3 \
    socat \
    websockify \
    x11vnc \
    xvfb \
    locales \
  # 生成中文 Locale
  && sed -i '/zh_CN.UTF-8/s/^# //g' /etc/locale.gen && locale-gen \
  && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/sandbox-browser
RUN chmod +x /usr/local/bin/sandbox-browser

RUN useradd --create-home --shell /bin/bash sandbox
USER sandbox
WORKDIR /home/sandbox

EXPOSE 9222 5900 6080

CMD ["sandbox-browser"]
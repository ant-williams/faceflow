# FaceFlow: GPU desktop in the browser (Selkies, WebRTC) with FaceFusion + Chrome.
#
# Base: Selkies NVIDIA EGL desktop (Ubuntu + KDE Plasma), served on port 8080.
# `latest` is the current Selkies, which forwards your mic and webcam.
ARG BASE_TAG=latest
FROM ghcr.io/selkies-project/nvidia-egl-desktop:${BASE_TAG}

USER root
ENV DEBIAN_FRONTEND=noninteractive

# Google Chrome + what FaceFusion needs.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates wget gnupg ffmpeg python3 python3-venv \
    && wget -q -O- https://dl.google.com/linux/linux_signing_key.pub \
        | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
        > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update && apt-get install -y --no-install-recommends google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# FaceFusion with CUDA. The venv is activated so its installer's pip calls
# install into the venv, not the system Python.
RUN git clone --depth 1 https://github.com/facefusion/facefusion.git /opt/facefusion \
    && python3 -m venv /opt/facefusion/venv \
    && . /opt/facefusion/venv/bin/activate \
    && pip install --no-cache-dir --upgrade pip \
    && python /opt/facefusion/install.py cuda@12 --skip-conda \
    && chown -R 1000:1000 /opt/facefusion

COPY start-facefusion.sh /usr/local/bin/start-facefusion
RUN chmod +x /usr/local/bin/start-facefusion

# Forward your microphone and webcam into the desktop.
ENV SELKIES_MICROPHONE_ENABLED=true \
    SELKIES_MICROPHONE_ON_START=true \
    SELKIES_WEBCAM_ENABLED=true \
    SELKIES_WEBCAM_ON_START=true

EXPOSE 8080 7860
USER 1000

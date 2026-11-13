# FaceFlow: GPU desktop in the browser (Selkies, WebRTC) with FaceFusion + Chrome.
#
# Base: Selkies NVIDIA EGL desktop (Ubuntu + KDE Plasma), served on port 8080.
# `latest` is the current Selkies, which forwards your mic and webcam.
ARG BASE_TAG=latest
FROM ghcr.io/selkies-project/nvidia-egl-desktop:${BASE_TAG}

USER root
ENV DEBIAN_FRONTEND=noninteractive

# Tools FaceFusion needs, plus Google Chrome if the base image doesn't already
# include it (current Selkies bases do).
RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates wget gnupg ffmpeg x11-xserver-utils \
    && if ! command -v google-chrome >/dev/null 2>&1; then \
         if ! grep -rqs "dl.google.com/linux/chrome" /etc/apt/sources.list /etc/apt/sources.list.d/; then \
           wget -q -O- https://dl.google.com/linux/linux_signing_key.pub \
             | gpg --batch --yes --dearmor -o /usr/share/keyrings/google-chrome.gpg \
           && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
             > /etc/apt/sources.list.d/google-chrome.list; \
         fi \
         && apt-get update && apt-get install -y --no-install-recommends google-chrome-stable; \
       fi \
    && rm -rf /var/lib/apt/lists/*

# Chrome's sandbox can't start in RunPod's unprivileged container, so Chrome
# opens and closes immediately. Launch it without the sandbox, and without
# relying on the container's small /dev/shm, from both the menu and terminal.
RUN for f in /usr/share/applications/google-chrome*.desktop; do \
      [ -f "$f" ] && sed -i -E 's#^(Exec=[^ ]*google-chrome[^ ]*)#\1 --no-sandbox --disable-dev-shm-usage#' "$f"; \
    done; \
    if [ -x /usr/bin/google-chrome-stable ]; then \
      printf '#!/bin/sh\nexec /usr/bin/google-chrome-stable --no-sandbox --disable-dev-shm-usage "$@"\n' \
        > /usr/local/bin/google-chrome \
      && chmod +x /usr/local/bin/google-chrome; \
    fi

# FaceFusion with CUDA, on its own Python 3.12 (via uv) so it doesn't depend on
# the base image's system Python. The venv is activated so the installer's pip
# calls go into it.
COPY --from=ghcr.io/astral-sh/uv:0.8.0 /uv /usr/local/bin/uv
ENV UV_PYTHON_INSTALL_DIR=/opt/uv-python
RUN git clone --depth 1 https://github.com/facefusion/facefusion.git /opt/facefusion \
    && uv venv --seed --python 3.12 /opt/facefusion/venv \
    && . /opt/facefusion/venv/bin/activate \
    && python /opt/facefusion/install.py cuda@12 --skip-conda \
    && chown -R 1000:1000 /opt/facefusion

# Turn off keyboard auto-repeat so a delayed key release over the stream doesn't
# type a long run of characters.
RUN printf '[Keyboard]\nKeyRepeat=nothing\n' >> /etc/xdg/kcminputrc \
    && mkdir -p /etc/xdg/autostart \
    && printf '[Desktop Entry]\nType=Application\nName=Disable key repeat\nExec=sh -c "xset r off"\nNoDisplay=true\n' \
        > /etc/xdg/autostart/faceflow-no-key-repeat.desktop

COPY start-facefusion.sh /usr/local/bin/start-facefusion
RUN chmod +x /usr/local/bin/start-facefusion

# Forward your microphone and webcam into the desktop.
ENV SELKIES_MICROPHONE_ENABLED=true \
    SELKIES_MICROPHONE_ON_START=true \
    SELKIES_WEBCAM_ENABLED=true \
    SELKIES_WEBCAM_ON_START=true

EXPOSE 8080 7860
USER 1000

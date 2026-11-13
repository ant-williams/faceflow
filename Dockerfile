# FaceFlow: GPU desktop in the browser (Selkies, WebRTC) with FaceFusion.
#
# Base: the Selkies desktop release (Ubuntu 26.04), served on port 8080. It
# includes Chrome and Firefox, NVIDIA NVENC streaming, Cloudflare TURN support,
# and the V4L2 interposer that forwards your webcam to apps.
ARG BASE_TAG=2.2.1-ubuntu26.04
FROM ghcr.io/selkies-project/selkies/desktop:${BASE_TAG}

USER root
ENV DEBIAN_FRONTEND=noninteractive

# Tools FaceFusion needs.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates ffmpeg x11-xserver-utils \
    && rm -rf /var/lib/apt/lists/*

# FaceFusion with CUDA, on its own Python 3.12 (via uv) so it doesn't depend on
# the base image's system Python. The installer runs from FaceFusion's folder
# with the venv active so its pip calls go into the venv.
COPY --from=ghcr.io/astral-sh/uv:0.8.0 /uv /usr/local/bin/uv
ENV UV_PYTHON_INSTALL_DIR=/opt/uv-python
RUN git clone --depth 1 https://github.com/facefusion/facefusion.git /opt/facefusion \
    && uv venv --seed --python 3.12 /opt/facefusion/venv \
    && cd /opt/facefusion \
    && . venv/bin/activate \
    && python install.py cuda@12 --skip-conda \
    && pip install --no-cache-dir nvidia-cuda-runtime-cu12 nvidia-cublas-cu12 \
        nvidia-cudnn-cu12 nvidia-cufft-cu12 nvidia-curand-cu12 \
    && chown -R 1000:1000 /opt/facefusion

# Turn off keyboard auto-repeat at login so a delayed key release over the
# stream doesn't type a long run of characters.
RUN mkdir -p /etc/xdg/autostart \
    && printf '[Desktop Entry]\nType=Application\nName=Disable key repeat\nExec=sh -c "xset r off"\nNoDisplay=true\n' \
        > /etc/xdg/autostart/faceflow-no-key-repeat.desktop

COPY start-facefusion.sh /usr/local/bin/start-facefusion
RUN chmod +x /usr/local/bin/start-facefusion

# Allow this pod's RunPod web address to open Selkies' streaming connection.
COPY selkies-wrapper.py /tmp/selkies-wrapper.py
RUN test -f /usr/local/bin/selkies \
    && mv /usr/local/bin/selkies /usr/local/bin/selkies-real \
    && install -m 755 /tmp/selkies-wrapper.py /usr/local/bin/selkies \
    && rm /tmp/selkies-wrapper.py

# Serve plain HTTP on all interfaces so RunPod's proxy (which adds HTTPS itself)
# can reach port 8080, stream over WebRTC (Selkies defaults to WebSocket), and
# forward your microphone and webcam.
ENV SELKIES_PUBLIC=true \
    SELKIES_ENABLE_HTTPS=false \
    SELKIES_MODE=webrtc \
    SELKIES_MICROPHONE_ENABLED=true \
    SELKIES_MICROPHONE_ON_START=true \
    SELKIES_WEBCAM_ENABLED=true \
    SELKIES_WEBCAM_ON_START=true

EXPOSE 8080 7860
USER 1000

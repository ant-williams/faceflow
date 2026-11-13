# FaceFlow — GPU browser desktop with FaceFusion + Chrome.
#
# Built on a KasmVNC desktop (the same streaming approach as RunPod's official
# "RunPod Desktop" template, which streams smoothly over HTTP/WebSocket through
# RunPod's proxy). The desktop stream does NOT need the GPU; only FaceFusion
# does, via onnxruntime-gpu + the host NVIDIA driver RunPod injects.
#
# Base: Kasm workspace core image (KasmVNC built in).
#   Serves an HTTPS desktop on port 6901, user "kasm_user", password via VNC_PW.
#   Tags: https://hub.docker.com/r/kasmweb/core-ubuntu-jammy/tags
ARG BASE_TAG=1.16.1
FROM kasmweb/core-ubuntu-jammy:${BASE_TAG}

USER root
ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_BREAK_SYSTEM_PACKAGES=1

# ---------------------------------------------------------------------------
# 1. System packages + Google Chrome
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        git git-lfs curl wget ca-certificates gnupg \
        ffmpeg libgl1 libglib2.0-0 \
        python3 python3-pip python3-venv \
        fonts-liberation xdg-utils \
    && install -d -m 0755 /etc/apt/keyrings \
    && wget -q -O- https://dl.google.com/linux/linux_signing_key.pub \
        | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] \
        http://dl.google.com/linux/chrome/deb/ stable main" \
        > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update && apt-get install -y --no-install-recommends google-chrome-stable \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 2. FaceFusion (installed into /opt/facefusion; onnxruntime-gpu brings CUDA
#    runtime libs via pip, so no CUDA base image is required — the host driver
#    is provided by the GPU pod).
# ---------------------------------------------------------------------------
ARG FACEFUSION_VERSION=master
RUN git clone --depth 1 --branch ${FACEFUSION_VERSION} \
        https://github.com/facefusion/facefusion.git /opt/facefusion \
    && python3 -m venv /opt/facefusion/venv \
    && /opt/facefusion/venv/bin/pip install --no-cache-dir --upgrade pip
RUN /opt/facefusion/venv/bin/python /opt/facefusion/install.py \
        cuda@12 --skip-conda || \
    echo "WARNING: facefusion install at build time failed; run scripts/install-facefusion.sh in the pod"
# Give the desktop user ownership so FaceFusion can write models without root.
RUN chown -R 1000:0 /opt/facefusion && chmod -R g+w /opt/facefusion

# ---------------------------------------------------------------------------
# 3. FaceFlow helper scripts + a desktop launcher for the Kasm user
# ---------------------------------------------------------------------------
COPY scripts/ /opt/faceflow/scripts/
RUN chmod +x /opt/faceflow/scripts/*.sh && mkdir -p /home/kasm-user/Desktop && \
    printf '%s\n' \
      '[Desktop Entry]' \
      'Type=Application' \
      'Name=FaceFusion' \
      'Comment=Start the FaceFusion web UI' \
      'Exec=/opt/faceflow/scripts/run-facefusion.sh' \
      'Icon=applications-graphics' \
      'Terminal=true' \
      > /home/kasm-user/Desktop/FaceFusion.desktop && \
    chmod +x /home/kasm-user/Desktop/FaceFusion.desktop && \
    chown -R 1000:0 /home/kasm-user/Desktop

# KasmVNC desktop (HTTPS). RunPod: Connect -> HTTP port 6901.
EXPOSE 6901
# FaceFusion web UI.
EXPOSE 7860

ENV FACEFUSION_HOME=/workspace/facefusion
USER 1000

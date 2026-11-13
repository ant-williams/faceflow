# FaceFlow — GPU Ubuntu desktop in the browser, with FaceFusion + Chrome.
#
# Base image: Selkies "NVIDIA EGL desktop" — Ubuntu + XFCE + Selkies streaming
# with hardware (NVENC) video encoding, served over a single web port.
# It streams the desktop to your browser and forwards your keyboard, mouse,
# microphone and (where supported) webcam back into the container.
#
# NOTE: pin a real, existing tag before building. Check the tags here:
#   https://github.com/selkies-project/docker-nvidia-egl-desktop/pkgs/container/nvidia-egl-desktop
# The CUDA suffix must match (or be older than) the host driver on your pod.
ARG BASE_TAG=24.04-20250101
FROM ghcr.io/selkies-project/nvidia-egl-desktop:${BASE_TAG}

# The base image runs as a non-root user ("ubuntu"); become root to install.
USER root
ENV DEBIAN_FRONTEND=noninteractive

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
# 2. FaceFusion (installed into /opt/facefusion, data kept in /workspace)
# ---------------------------------------------------------------------------
ARG FACEFUSION_VERSION=master
RUN git clone --depth 1 --branch ${FACEFUSION_VERSION} \
        https://github.com/facefusion/facefusion.git /opt/facefusion \
    && python3 -m venv /opt/facefusion/venv \
    && /opt/facefusion/venv/bin/pip install --no-cache-dir --upgrade pip

# FaceFusion ships an installer that selects the right onnxruntime build.
# "cuda" pulls onnxruntime-gpu so face-swap runs on the GPU.
RUN /opt/facefusion/venv/bin/python /opt/facefusion/install.py \
        --onnxruntime cuda --skip-conda || \
    echo "WARNING: facefusion install.py failed at build time; run scripts/install-facefusion.sh on first boot"

# Models and user data live on the mounted volume so they survive pod restarts.
ENV FACEFUSION_HOME=/workspace/facefusion

# ---------------------------------------------------------------------------
# 3. FaceFlow startup
# ---------------------------------------------------------------------------
COPY scripts/ /opt/faceflow/scripts/
RUN chmod +x /opt/faceflow/scripts/*.sh

# Run faceflow-init.sh automatically when the XFCE desktop session starts.
RUN mkdir -p /etc/xdg/autostart \
    && cat > /etc/xdg/autostart/faceflow-init.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=FaceFlow Init
Exec=/opt/faceflow/scripts/faceflow-init.sh
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF

# Selkies serves the desktop here; RunPod exposes it via "Connect via HTTP".
EXPOSE 8080
# FaceFusion's own web UI (optional, headless use without the desktop).
EXPOSE 7860

# The base image has its own entrypoint that starts the desktop. We layer our
# first-run setup on top of it via an autostart hook instead of replacing it.
USER 1000

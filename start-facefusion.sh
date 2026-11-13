#!/usr/bin/env bash
# Start FaceFusion on port 7860 using the GPU, with the normal and live-webcam screens.
set -euo pipefail

cd /opt/facefusion

# Load Selkies' webcam interposer so FaceFusion sees your forwarded camera.
for INTERPOSER in /usr/lib/selkies_v4l2_interposer.so \
                  /usr/lib/x86_64-linux-gnu/selkies_v4l2_interposer.so \
                  /opt/add-ons/usr/lib/selkies_v4l2_interposer.so; do
    if [ -f "$INTERPOSER" ]; then
        if [[ ":${LD_PRELOAD:-}:" != *":$INTERPOSER:"* ]]; then
            export LD_PRELOAD="${LD_PRELOAD:+$LD_PRELOAD:}$INTERPOSER"
        fi
        break
    fi
done

# Keep downloaded models on the RunPod volume when one is mounted at /workspace.
if [ -w /workspace ] && [ ! -e .assets ]; then
    mkdir -p /workspace/facefusion-models
    ln -s /workspace/facefusion-models .assets
fi

# Listen on all interfaces so RunPod's port 7860 link can reach the web page.
export GRADIO_SERVER_NAME="${GRADIO_SERVER_NAME:-0.0.0.0}"
export GRADIO_SERVER_PORT="${GRADIO_SERVER_PORT:-7860}"

. venv/bin/activate
exec python facefusion.py run --execution-providers cuda --ui-layouts default webcam

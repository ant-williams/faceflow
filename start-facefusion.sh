#!/usr/bin/env bash
# Start FaceFusion on port 7860 using the GPU, with the normal and live-webcam screens.
set -euo pipefail

cd /opt/facefusion

# Load Selkies' webcam interposer so FaceFusion sees your forwarded camera
# (the desktop session usually preloads it already).
if [[ "${LD_PRELOAD:-}" != *selkies_v4l2_interposer.so* ]]; then
    for INTERPOSER in /usr/lib/x86_64-linux-gnu/selkies_v4l2_interposer.so \
                      /usr/lib/selkies_v4l2_interposer.so; do
        if [ -f "$INTERPOSER" ]; then
            export LD_PRELOAD="${LD_PRELOAD:+$LD_PRELOAD:}$INTERPOSER"
            break
        fi
    done
fi

# Point the GPU runtime at the CUDA libraries installed in FaceFusion's venv
# (the base image has no system CUDA).
for lib in /opt/facefusion/venv/lib/python3*/site-packages/nvidia/*/lib; do
    [ -d "$lib" ] && LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$lib"
done
export LD_LIBRARY_PATH

# Listen on all interfaces so RunPod's port 7860 link can reach the web page.
export GRADIO_SERVER_NAME="${GRADIO_SERVER_NAME:-0.0.0.0}"
export GRADIO_SERVER_PORT="${GRADIO_SERVER_PORT:-7860}"

. venv/bin/activate
exec python facefusion.py run --execution-providers cuda --ui-layouts default webcam

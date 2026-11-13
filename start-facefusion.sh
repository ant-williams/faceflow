#!/usr/bin/env bash
# Start FaceFusion on port 7860 using the GPU.
set -euo pipefail

cd /opt/facefusion

# Keep downloaded models on the RunPod volume when one is mounted at /workspace.
if [ -w /workspace ] && [ ! -e .assets ]; then
    mkdir -p /workspace/facefusion-models
    ln -s /workspace/facefusion-models .assets
fi

. venv/bin/activate
exec python facefusion.py run --execution-providers cuda

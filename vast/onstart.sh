#!/usr/bin/env bash
# FaceFlow — Vast.ai VM on-start script.
#
# Creates a virtual camera device (/dev/video0) so Selkies can forward your
# browser webcam into it and FaceFusion can read it. This needs real kernel
# access, so it ONLY works on a Vast.ai **VM instance**, not a plain Docker
# instance (same container limit as RunPod). The microphone needs no module.
set -eux

# 1. Virtual camera device via v4l2loopback (camera path).
if ! lsmod | grep -q v4l2loopback; then
    apt-get update || true
    apt-get install -y --no-install-recommends \
        v4l2loopback-dkms v4l2loopback-utils kmod || true
    # exclusive_caps=1 makes Chrome/FaceFusion accept it as a normal webcam.
    modprobe v4l2loopback devices=1 video_nr=0 \
        card_label="FaceFlowCam" exclusive_caps=1 \
        || echo "modprobe v4l2loopback FAILED — are you on a Vast VM instance (not Docker)?"
fi

echo "Video devices:"; ls -l /dev/video* 2>&1 || echo "  (none — camera will not work without /dev/video0)"
echo "FaceFlow on-start done."

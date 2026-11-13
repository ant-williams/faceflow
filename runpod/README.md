# Running FaceFlow on RunPod

## 1. Build and push the image

RunPod pulls from a registry, so build and push first (from any machine with Docker):

```bash
docker build -t YOUR_DOCKERHUB_USER/faceflow:latest .
docker push YOUR_DOCKERHUB_USER/faceflow:latest
```

(GPU is **not** needed to build — only to run.)

## 2. Create a RunPod template

In the RunPod console: **Templates → New Template**

| Field | Value |
|-------|-------|
| Container Image | `YOUR_DOCKERHUB_USER/faceflow:latest` |
| Container Disk | 20 GB |
| Volume Disk | 50 GB |
| Volume Mount Path | `/workspace` |
| Expose HTTP Ports | `8080,7860` |

### Environment variables

| Name | Value |
|------|-------|
| `SELKIES_ENABLE_BASIC_AUTH` | `true` |
| `SELKIES_BASIC_AUTH_USER` | a username |
| `SELKIES_BASIC_AUTH_PASSWORD` | a strong password |
| `SELKIES_FRAMERATE` | `30` |
| `SELKIES_VIDEO_BITRATE` | `8000` |

## 3. Pick a GPU — this matters

**Choose a GPU with a hardware video encoder (NVENC):**
RTX 4090, RTX 3090, RTX A5000, A4000, L4, L40.

**Avoid A100 / H100** — they have no NVENC, so the desktop stream falls back to the
CPU and stutters.

## 4. Deploy and connect

1. Deploy the pod from the template (Community Cloud is cheaper for testing).
2. Click **Connect → HTTP Service → port 8080**.
3. Log in with the username/password you set. The Ubuntu desktop loads in the browser.
4. Double-click the **FaceFusion** icon, or open a terminal and run
   `/opt/faceflow/scripts/run-facefusion.sh`.

## 5. Stop the pod when done

A running pod bills by the hour. **Stop it** when you finish. The `/workspace`
volume (models, inputs, outputs) persists; anything installed elsewhere does not.

## Notes / limits

- **Microphone:** forwarded by Selkies from your browser; should appear as a mic
  inside the desktop. Allow mic access when the browser asks.
- **Webcam into apps / live video calls:** a virtual camera device needs a kernel
  module (`v4l2loopback`) that RunPod containers can't load. Live
  webcam → FaceFusion → call app does **not** work directly here. Options:
  run the call on your own PC with OBS Virtual Camera, or use a Vast.ai VM.
- First FaceFusion run downloads models into `/workspace` (a few GB) — give it time.

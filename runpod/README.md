# Running FaceFlow on RunPod

## 1. Build the image (GitHub Actions → Docker Hub private)

RunPod pulls a prebuilt image from a registry; it does not build from this repo.
GitHub Actions builds it for free and pushes it to your **private Docker Hub**
repo. No local Docker needed.

### One-time setup

1. **Docker Hub account** at hub.docker.com (free — includes 1 private repo).
2. **Access token:** Docker Hub → **Account Settings → Personal access tokens →
   Generate new token** (Read/Write). Copy it.
3. **Add two GitHub secrets:** your repo → **Settings → Secrets and variables →
   Actions → New repository secret**:
   - `DOCKERHUB_USERNAME` = your Docker Hub username
   - `DOCKERHUB_TOKEN` = the token from step 2
4. (Optional) Pre-create a **private** repo named `faceflow` on Docker Hub. If you
   skip this, the first push creates it — then set it to Private in its settings.

### Run the build

- It runs automatically when you change the `Dockerfile` or `scripts/`.
- Or trigger it manually: repo → **Actions** tab → *Build FaceFlow image* →
  **Run workflow**.
- Wait for the green check (the build takes a while — it's a big image).

The image is pushed to: `docker.io/<your-username>/faceflow:latest`

### Let RunPod pull your private image

RunPod → **Settings → Container Registry Auth → Add Registry Credentials**:
- Registry: `docker.io`
- Username: your Docker Hub username
- Password: the same Docker Hub access token

Select this credential when you create the template below.

## 2. Create a RunPod template

In the RunPod console: **Templates → New Template**

| Field | Value |
|-------|-------|
| Container Image | `docker.io/<your-username>/faceflow:latest` |
| Registry Credentials | the Docker Hub credential you added above |
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
| `KASMVNC_ENABLE` | `true` **(required on RunPod)** |

> **Why `KASMVNC_ENABLE=true` is required on RunPod.** The default (WebRTC/Selkies)
> transport needs a direct media path or a reachable TURN server, which RunPod's
> HTTP-only proxy doesn't provide — the browser shows "Waiting for stream" and the
> logs show `[webrtc] [ERROR] Peer connection failed`. KasmVNC streams over
> HTTP/WebSocket on port 8080, so it works through the proxy. Trade-off: weaker
> audio and slightly higher latency; webcam forwarding is not available either way.
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

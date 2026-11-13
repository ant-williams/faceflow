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
| Volume Disk | 20 GB (raise later if needed) |
| Volume Mount Path | `/workspace` |
| Expose HTTP Ports | `6901,7860` |

### Environment variables

| Name | Value |
|------|-------|
| `VNC_PW` | a strong password (desktop login) |

The desktop username is always **`kasm_user`**. FaceFlow uses a **KasmVNC**
desktop — the same HTTP/WebSocket streaming RunPod's official "RunPod Desktop"
template uses — so it stays responsive through RunPod's proxy. No WebRTC, no
TURN, no NVENC needed for the desktop.

## 3. Pick a GPU

The desktop stream does **not** need the GPU — only FaceFusion does. Any current
NVIDIA GPU works. Best value from typical availability:

- **A40 (~$0.59/hr)** — cheapest, lots of VRAM. Good default.
- **RTX 4090 (~$0.89/hr)** — fastest face-swapping.

Avoid MIG slices (e.g. "PRO 6000 MIG") for FaceFusion if you want full GPU.

## 4. Deploy and connect

1. Deploy the pod from the template (Community Cloud is cheaper for testing).
2. Click **Connect → HTTP Service → port 6901**.
3. Log in: user `kasm_user`, password = your `VNC_PW`. The desktop loads
   (accept the self-signed certificate if the browser warns).
4. Double-click the **FaceFusion** icon, or open a terminal and run
   `/opt/faceflow/scripts/run-facefusion.sh`. Then open port 7860 for its UI.

## 5. Stop the pod when done

A running pod bills by the hour. **Stop it** when you finish. The `/workspace`
volume (models, inputs, outputs) persists; anything installed elsewhere does not.

## Notes / limits

- **Audio & microphone:** KasmVNC carries desktop sound to your browser and can
  forward your mic. Allow audio/mic when the browser asks.
- **Webcam:** the `:kasmvnc` image doesn't forward your camera. Use the
  `:selkies` image instead — its V4L2 Interposer forwards your browser camera
  without a kernel module (see `selkies-turn.md`).
- First FaceFusion run downloads models into `/workspace` (a few GB) — give it time.

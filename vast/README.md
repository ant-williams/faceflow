# FaceFlow on Vast.ai — live camera + microphone

Fallback setup. Try the `:selkies` image on RunPod first — its V4L2 Interposer
forwards your camera without a kernel module. Use this Vast.ai **VM** setup only
if an app can't see the camera through the interposer: a VM can load
`v4l2loopback` and give apps a real `/dev/video0`.

> **You MUST pick a VM instance, not a Docker instance.** On a plain Docker
> instance the camera won't work (same limit as RunPod). The microphone works
> on either.

---

## 1. Pick the right instance

On vast.ai → **Search/Create**:
- Choose a template/instance type that is a **Virtual Machine (VM)**, not a
  Docker container. (Vast labels these; look for VM / "virtual machine".)
- GPU: anything with NVENC is fine (RTX 4090 / A6000 / etc.).
- Disk: ~40 GB.

## 2. Image + credentials

- **Image:** `docker.io/<your-username>/faceflow:selkies`
- **Private image:** add your Docker Hub username + token in Vast's image
  registry credentials (same as RunPod).

## 3. Ports (Docker options)

Add to the instance's Docker options / port config:

```
-p 8080:8080 -p 7860:7860
```

## 4. Environment variables

| Name | Value |
|------|-------|
| `SELKIES_ENABLE_BASIC_AUTH` | `true` |
| `SELKIES_BASIC_AUTH_USER` | a username |
| `SELKIES_BASIC_AUTH_PASSWORD` | a strong password |
| `SELKIES_MICROPHONE_ENABLED` | `true` |
| `SELKIES_MICROPHONE_ON_START` | `true` |
| `SELKIES_WEBCAM_ENABLED` | `true` |
| `SELKIES_WEBCAM_ON_START` | `true` |

(On a VM you usually don't need an external TURN server — the VM's own
networking lets WebRTC connect. If the stream won't start, add the Cloudflare
TURN vars from `runpod/selkies-turn.md`.)

## 5. On-start script (creates the camera device)

Put the contents of [`onstart.sh`](onstart.sh) in the instance's **On-start
script** field (or run it in the VM terminal once after boot). It loads
`v4l2loopback` and creates `/dev/video0`. Verify after boot:

```bash
ls -l /dev/video*        # expect /dev/video0
```

If `/dev/video0` is missing, you're on a Docker instance, not a VM — recreate as
a VM instance.

## 6. Connect and use

1. Open the instance's mapped **port 8080**, log in.
2. **Allow** the browser camera + microphone prompts.
3. In the Selkies side menu, make sure **webcam** and **microphone** are on.
4. Test the camera at e.g. `webcammictest.com` in the desktop browser — you
   should now see **FaceFlowCam**.
5. Start FaceFusion (`/opt/faceflow/scripts/run-facefusion.sh`), open its webcam
   mode — it should now list the camera. Live swap works.

## Troubleshooting

- **No `/dev/video0`:** not a VM instance, or `v4l2loopback` didn't load. Re-run
  `onstart.sh`, check `dmesg | tail`. Must be a VM.
- **Camera device exists but FaceFusion/Chrome don't see it:** ensure
  `exclusive_caps=1` was used (it is in `onstart.sh`), and that Selkies webcam
  forwarding is toggled on.
- **Stream won't connect:** add Cloudflare TURN env vars (see
  `runpod/selkies-turn.md`).
- **Mic choppy:** VM networking is better than RunPod's; if still poor, lower the
  Selkies bitrate/framerate in the side menu.

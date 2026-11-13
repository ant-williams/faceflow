#!/usr/bin/python3
# Runs in place of Selkies' launcher on every pod start. It:
# 1. allows this pod's RunPod web address (https://<pod-id>-8080.proxy.runpod.net)
#    to open Selkies' streaming connection — Selkies only accepts its own address
#    by default. A SELKIES_ALLOWED_ORIGINS set on the pod still takes priority.
# 2. starts FaceFusion in the background (log: ~/facefusion.log) so port 7860 is
#    ready without opening a terminal, unless it's already running.
# Then it hands over to the real Selkies.
import os
import subprocess
import sys

pod_id = os.environ.get("RUNPOD_POD_ID")
if pod_id and not os.environ.get("SELKIES_ALLOWED_ORIGINS"):
    os.environ["SELKIES_ALLOWED_ORIGINS"] = f"https://{pod_id}-8080.proxy.runpod.net"


def facefusion_running(pid_file):
    # Alive (not a zombie) and really FaceFusion, not a reused process ID.
    try:
        with open(pid_file) as f:
            pid = int(f.read().strip())
        with open(f"/proc/{pid}/stat") as f:
            state = f.read().rsplit(")", 1)[1].split()[0]
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            cmdline = f.read()
        return state != "Z" and b"facefusion" in cmdline
    except (OSError, ValueError, IndexError):
        return False


try:
    pid_file = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "facefusion.pid")
    if not facefusion_running(pid_file):
        log = open(os.path.expanduser("~/facefusion.log"), "ab")
        proc = subprocess.Popen(["/usr/local/bin/start-facefusion"], stdout=log,
                                stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                                start_new_session=True)
        with open(pid_file, "w") as f:
            f.write(str(proc.pid))
except Exception as error:  # never let FaceFusion problems stop the desktop
    print(f"faceflow: could not start FaceFusion: {error}", file=sys.stderr)

os.execv(sys.executable, [sys.executable, "/usr/local/bin/selkies-real", *sys.argv[1:]])

#!/usr/bin/python3
# Starts Selkies with this pod's RunPod web address allowed to open the
# streaming connection. Selkies only accepts its own address by default, and
# RunPod's proxy address (https://<pod-id>-8080.proxy.runpod.net) changes with
# every pod. A SELKIES_ALLOWED_ORIGINS set on the pod still takes priority.
import os
import sys

pod_id = os.environ.get("RUNPOD_POD_ID")
if pod_id and not os.environ.get("SELKIES_ALLOWED_ORIGINS"):
    os.environ["SELKIES_ALLOWED_ORIGINS"] = f"https://{pod_id}-8080.proxy.runpod.net"

os.execv(sys.executable, [sys.executable, "/usr/local/bin/selkies-real", *sys.argv[1:]])

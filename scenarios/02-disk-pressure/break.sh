#!/usr/bin/env bash
# Scenario 02 — Node Disk Pressure
# Fills disk on a worker node to trigger kubelet DiskPressure eviction
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${RED}[BREAK]${NC} Scenario 02 — Node Disk Pressure"
echo ""

# ── Detect cluster type and fill strategy ─────────────────────────────────────
if kind get clusters 2>/dev/null | grep -q .; then
  CLUSTER_NAME=$(kind get clusters | head -1)
  WORKER=$(docker ps --format '{{.Names}}' | grep "${CLUSTER_NAME}-worker" | head -1)
  if [[ -z "$WORKER" ]]; then
    echo -e "${RED}No worker node found.${NC}"; exit 1
  fi
  echo -e "${YELLOW}Cluster type:${NC}  kind  |  ${YELLOW}Target node:${NC} $WORKER"
  echo "Writing ~3.8 GB to $WORKER to trigger DiskPressure ..."
  docker exec "$WORKER" bash -c "
    mkdir -p /disk-pressure-lab
    dd if=/dev/zero of=/disk-pressure-lab/fill.img bs=1M count=3800 2>&1 | tail -1
    echo 'Disk usage:'; df -h / | tail -1
  "

elif k3d cluster list 2>/dev/null | grep -q .; then
  WORKER=$(k3d node list 2>/dev/null | grep agent | awk '{print $1}' | head -1)
  if [[ -z "$WORKER" ]]; then
    echo -e "${RED}No k3d agent node found.${NC}"; exit 1
  fi
  echo -e "${YELLOW}Cluster type:${NC}  k3d  |  ${YELLOW}Target node:${NC} $WORKER"
  echo "Writing ~3.8 GB to $WORKER to trigger DiskPressure ..."
  docker exec "$WORKER" bash -c "
    mkdir -p /disk-pressure-lab
    dd if=/dev/zero of=/disk-pressure-lab/fill.img bs=1M count=3800 2>&1 | tail -1
    echo 'Disk usage:'; df -h / | tail -1
  "

else
  # k3s / bare cluster — fill disk safely via a pod writing to a hostPath
  echo -e "${YELLOW}Cluster type:${NC}  k3s (or bare)"
  echo ""
  echo -e "${YELLOW}NOTE:${NC} Filling the node disk directly is risky on a real host."
  echo "Instead, we deploy a pod that writes a large file under /tmp/disk-pressure-lab"
  echo "on the node. The kubelet eviction manager monitors /tmp (nodefs) and will"
  echo "report DiskPressure once the threshold is crossed."
  echo ""

  # Pick a real node name
  NODE=$(kubectl get nodes --no-headers | grep -v "control-plane\|master" | awk '{print $1}' | head -1)
  if [[ -z "$NODE" ]]; then
    NODE=$(kubectl get nodes --no-headers | awk '{print $1}' | head -1)
  fi

  echo "Target node: $NODE"
  echo ""

  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: disk-filler
  namespace: default
  labels:
    scenario: "02"
spec:
  nodeName: ${NODE}
  restartPolicy: Never
  volumes:
  - name: hostpath-fill
    hostPath:
      path: /tmp/disk-pressure-lab
      type: DirectoryOrCreate
  containers:
  - name: filler
    image: busybox:latest
    command:
    - sh
    - -c
    - |
      echo "Starting disk fill on node..."
      dd if=/dev/zero of=/fill/fill.img bs=1M count=3800 2>&1 | tail -1
      echo "Done. Sleeping so pod stays up."
      sleep 3600
    volumeMounts:
    - name: hostpath-fill
      mountPath: /fill
EOF

  echo ""
  echo "Pod 'disk-filler' writing ~3.8 GB to /tmp/disk-pressure-lab on node $NODE"
  echo "Follow with: kubectl logs -f disk-filler"
fi

echo ""
echo -e "${YELLOW}[SCENARIO ACTIVE]${NC} Wait ~60 seconds for kubelet to detect DiskPressure."
echo ""
echo "Your tasks:"
echo "  1. Identify which node has DiskPressure"
echo "  2. Find what is consuming the disk"
echo "  3. Free the disk and confirm the node recovers"
echo ""
echo "Useful starting point: kubectl describe nodes | grep -A5 Conditions"

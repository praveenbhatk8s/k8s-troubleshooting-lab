#!/usr/bin/env bash
# Scenario 02 — Node Disk Pressure
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${RED}[BREAK]${NC} Scenario 02 — Node Disk Pressure"
echo ""

_orb_exec() { orb run --machine k8s -- "$@" 2>/dev/null; }

_fill_via_pod() {
  # Safe for any cluster: deploy a pod that writes to a hostPath
  local NODE="$1"
  echo "Deploying disk-filler pod on node $NODE ..."
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
  - name: fill
    hostPath:
      path: /tmp/disk-pressure-lab
      type: DirectoryOrCreate
  containers:
  - name: filler
    image: busybox:latest
    command: ["sh", "-c",
      "dd if=/dev/zero of=/fill/fill.img bs=1M count=3800 2>&1 | tail -1; echo Done; sleep 3600"]
    volumeMounts:
    - name: fill
      mountPath: /fill
EOF
  echo "Follow fill progress: kubectl logs -f disk-filler"
}

if kind get clusters 2>/dev/null | grep -q .; then
  CLUSTER_NAME=$(kind get clusters | head -1)
  WORKER=$(docker ps --format '{{.Names}}' | grep "${CLUSTER_NAME}-worker" | head -1)
  if [[ -z "$WORKER" ]]; then echo -e "${RED}No worker node found.${NC}"; exit 1; fi
  echo -e "${YELLOW}Cluster type:${NC}  kind  |  ${YELLOW}Target:${NC} $WORKER"
  docker exec "$WORKER" bash -c "
    mkdir -p /disk-pressure-lab
    dd if=/dev/zero of=/disk-pressure-lab/fill.img bs=1M count=3800 2>&1 | tail -1
    df -h / | tail -1"

elif k3d cluster list 2>/dev/null | grep -q .; then
  WORKER=$(k3d node list 2>/dev/null | grep agent | awk '{print $1}' | head -1)
  if [[ -z "$WORKER" ]]; then echo -e "${RED}No k3d agent node found.${NC}"; exit 1; fi
  echo -e "${YELLOW}Cluster type:${NC}  k3d  |  ${YELLOW}Target:${NC} $WORKER"
  docker exec "$WORKER" bash -c "
    mkdir -p /disk-pressure-lab
    dd if=/dev/zero of=/disk-pressure-lab/fill.img bs=1M count=3800 2>&1 | tail -1
    df -h / | tail -1"

elif command -v orb &>/dev/null && orb run --machine k8s -- true &>/dev/null; then
  NODE=$(kubectl get nodes --no-headers | awk '{print $1}' | head -1)
  echo -e "${YELLOW}Cluster type:${NC}  OrbStack k3s  |  ${YELLOW}Target:${NC} $NODE"
  echo "Writing ~3.8 GB inside OrbStack VM ..."
  _orb_exec bash -c "
    sudo mkdir -p /tmp/disk-pressure-lab
    sudo dd if=/dev/zero of=/tmp/disk-pressure-lab/fill.img bs=1M count=3800 2>&1 | tail -1
    df -h / | tail -1"

else
  NODE=$(kubectl get nodes --no-headers | grep -v "control-plane\|master" | awk '{print $1}' | head -1)
  [[ -z "$NODE" ]] && NODE=$(kubectl get nodes --no-headers | awk '{print $1}' | head -1)
  echo -e "${YELLOW}Cluster type:${NC}  bare k3s  |  ${YELLOW}Target:${NC} $NODE"
  _fill_via_pod "$NODE"
fi

echo ""
echo -e "${YELLOW}[SCENARIO ACTIVE]${NC} Wait ~60s for kubelet to detect DiskPressure."
echo ""
echo "Tasks:"
echo "  1. Identify which node has DiskPressure"
echo "  2. Find what is consuming the disk"
echo "  3. Free the disk and confirm the node recovers"
echo ""
echo "Starting point: kubectl describe nodes | grep -A5 Conditions"

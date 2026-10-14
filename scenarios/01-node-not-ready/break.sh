#!/usr/bin/env bash
# Scenario 01 — Node Not Ready
set -euo pipefail

# Auto-detect OrbStack Docker socket
if [[ -S "${HOME}/.orbstack/run/docker.sock" ]]; then
  export DOCKER_HOST="unix://${HOME}/.orbstack/run/docker.sock"
fi

RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${RED}[BREAK]${NC} Scenario 01 — Node Not Ready"
echo ""

_k3d_cluster() {
  kubectl get nodes --no-headers -o custom-columns=N:.metadata.name 2>/dev/null \
    | grep "k3d-" | grep -o "k3d-[^-]*" | head -1 | sed "s/^k3d-//"
}

_stop_kubelet() {
  local container="$1"
  # k3d containers run k3s directly (no systemd) — kill the process
  if docker exec "$container" which systemctl &>/dev/null; then
    docker exec "$container" systemctl stop kubelet 2>/dev/null \
      || docker exec "$container" systemctl stop k3s-agent 2>/dev/null
  else
    # No systemd — kill k3s agent process directly
    docker exec "$container" sh -c 'pkill -f "k3s agent" || pkill -f "k3s-agent" || kill $(cat /var/run/k3s-agent.pid 2>/dev/null) 2>/dev/null || true'
    sleep 1
    # Verify it's gone
    if docker exec "$container" pgrep -f "k3s" &>/dev/null; then
      docker exec "$container" sh -c 'kill -9 $(pgrep -f "k3s") 2>/dev/null || true'
    fi
  fi
}

if kind get clusters 2>/dev/null | grep -q .; then
  CLUSTER_NAME=$(kind get clusters | head -1)
  WORKER=$(docker ps --format '{{.Names}}' | grep "${CLUSTER_NAME}-worker" | head -1)
  if [[ -z "$WORKER" ]]; then
    echo -e "${RED}No worker node found.${NC}"; exit 1
  fi
  echo -e "${YELLOW}Cluster type:${NC}  kind  |  ${YELLOW}Target:${NC} $WORKER"
  docker exec "$WORKER" systemctl stop kubelet

elif kubectl get nodes --no-headers 2>/dev/null | grep -q 'k3d-'; then
  C=$(_k3d_cluster)
  WORKER=$(docker ps --format '{{.Names}}' 2>/dev/null | grep "k3d-${C}-agent" | head -1)
  if [[ -z "$WORKER" ]]; then
    echo -e "${RED}No k3d agent container found.${NC}"; exit 1
  fi
  echo -e "${YELLOW}Cluster type:${NC}  k3d (${C})  |  ${YELLOW}Target:${NC} $WORKER"
  echo "Stopping k3s agent process on $WORKER ..."
  _stop_kubelet "$WORKER"

elif command -v orb &>/dev/null; then
  NODE=$(kubectl get nodes --no-headers | awk '{print $1}' | head -1)
  echo -e "${YELLOW}Cluster type:${NC}  OrbStack  |  ${YELLOW}Target:${NC} $NODE"
  orb sudo systemctl stop k3s 2>/dev/null || orb sudo systemctl stop k3s-agent 2>/dev/null

elif systemctl is-active --quiet k3s-agent 2>/dev/null; then
  echo -e "${YELLOW}Cluster type:${NC}  k3s bare (agent)"
  sudo systemctl stop k3s-agent

elif systemctl is-active --quiet k3s 2>/dev/null; then
  echo -e "${YELLOW}Cluster type:${NC}  k3s bare (server)"
  echo "Stopping in 5s ... Ctrl-C to abort."; sleep 5
  sudo systemctl stop k3s

else
  echo -e "${RED}Could not detect cluster type.${NC}"; exit 1
fi

echo ""
echo -e "${YELLOW}[SCENARIO ACTIVE]${NC} kubelet stopped. Node will be NotReady in ~40s."
echo ""
echo "Tasks:"
echo "  1. Find which node is NotReady"
echo "  2. WHY? (kubectl describe node <name>)"
echo "  3. Fix it — return the node to Ready"
echo ""
echo "Starting point: kubectl get nodes -w"

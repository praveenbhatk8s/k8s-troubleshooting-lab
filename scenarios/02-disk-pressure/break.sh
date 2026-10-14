#!/usr/bin/env bash
# Scenario 02 — Node Disk Pressure
# Simulates: disk fills up on a worker node, triggering eviction threshold
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${RED}[BREAK]${NC} Scenario 02 — Node Disk Pressure"
echo ""

CLUSTER_NAME=$(kind get clusters 2>/dev/null | head -1 || echo "")
if [[ -z "$CLUSTER_NAME" ]]; then
  echo -e "${RED}No kind cluster found.${NC}"; exit 1
fi

WORKER=$(docker ps --format '{{.Names}}' | grep "${CLUSTER_NAME}-worker" | head -1)
if [[ -z "$WORKER" ]]; then
  echo -e "${RED}No worker node found.${NC}"; exit 1
fi

echo -e "${YELLOW}Target node:${NC} $WORKER"
echo ""

# Create a large file inside the node container to fill disk
# We use /tmp inside the container (not the real host disk) — safe for lab
echo "Filling disk on $WORKER (writing ~4GB sparse file to /disk-pressure-lab) ..."
docker exec "$WORKER" bash -c "
  mkdir -p /disk-pressure-lab
  # Write actual data (not sparse) to trigger real disk pressure
  dd if=/dev/zero of=/disk-pressure-lab/fill.img bs=1M count=3800 2>&1 | tail -1
  echo 'Fill complete. Disk usage:'
  df -h / | tail -1
"

echo ""
echo -e "${YELLOW}[SCENARIO ACTIVE]${NC} Disk nearly full on $WORKER"
echo ""
echo "Wait ~60 seconds for kubelet to detect and report DiskPressure."
echo ""
echo "Your tasks:"
echo "  1. Identify which node has DiskPressure"
echo "  2. Find what is consuming the disk"
echo "  3. Free the disk and confirm the node recovers"
echo ""
echo "Useful starting point: kubectl describe node $WORKER | grep -A5 Conditions"

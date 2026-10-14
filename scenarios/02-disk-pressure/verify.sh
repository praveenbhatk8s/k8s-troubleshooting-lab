#!/usr/bin/env bash
set -euo pipefail
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo -e "  ${GREEN}PASS${NC}  $desc"; ((PASS++))
  else
    echo -e "  ${RED}FAIL${NC}  $desc"; ((FAIL++))
  fi
}

_orb_exec() { orb run --machine k8s -- "$@" 2>/dev/null; }

echo ""
echo "=== Scenario 02 — Disk Pressure: Verification ==="
echo ""

DISK_PRESSURE=$(kubectl get nodes -o json | \
  jq -r '.items[].status.conditions[] | select(.type=="DiskPressure") | .status' | \
  grep -c "True" || true)
check "No node reports DiskPressure=True" test "$DISK_PRESSURE" -eq 0

if kind get clusters 2>/dev/null | grep -q .; then
  CLUSTER_NAME=$(kind get clusters | head -1)
  for node in $(docker ps --format '{{.Names}}' | grep "${CLUSTER_NAME}-worker"); do
    check "Fill file removed from $node" \
      docker exec "$node" test "!" -f /disk-pressure-lab/fill.img
  done
elif k3d cluster list 2>/dev/null | grep -q .; then
  for node in $(k3d node list 2>/dev/null | grep agent | awk '{print $1}'); do
    check "Fill file removed from $node" \
      docker exec "$node" test "!" -f /disk-pressure-lab/fill.img
  done
elif command -v orb &>/dev/null && orb run --machine k8s -- true &>/dev/null; then
  check "Fill file removed from OrbStack VM" \
    bash -c '! _orb_exec test -f /tmp/disk-pressure-lab/fill.img'
else
  check "disk-filler pod deleted" \
    bash -c '! kubectl get pod disk-filler 2>/dev/null | grep -q disk-filler'
fi

NOT_READY=$(kubectl get nodes --no-headers | grep -vc " Ready" || true)
check "All nodes Ready" test "$NOT_READY" -eq 0

echo ""
if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}ALL CHECKS PASSED!${NC}  Read SOLUTION.md for the full explanation."
else
  echo -e "${RED}$FAIL check(s) failed.${NC}"
  echo "Hint: find large files with 'du -sh /tmp/* | sort -rh' on the node"
fi
echo ""

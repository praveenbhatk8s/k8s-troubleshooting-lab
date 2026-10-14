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

_k3d_cluster() {
  kubectl get nodes --no-headers -o custom-columns=N:.metadata.name 2>/dev/null \
    | grep "k3d-" | grep -o "k3d-[^-]*" | head -1 | sed "s/^k3d-//"
}

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
elif kubectl get nodes --no-headers 2>/dev/null | grep -q 'k3d-'; then
  C=$(_k3d_cluster)
  for node in $(docker ps --format '{{.Names}}' 2>/dev/null | grep "k3d-${C}-agent"); do
    check "Fill file removed from $node" \
      docker exec "$node" test "!" -f /disk-pressure-lab/fill.img
  done
elif command -v orb &>/dev/null; then
  check "Fill directory removed from OrbStack VM" \
    bash -c '! orb test -d /tmp/disk-pressure-lab 2>/dev/null'
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
  echo "Hint: find large files with 'du -sh /* | sort -rh' inside the node"
fi
echo ""

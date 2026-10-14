#!/usr/bin/env bash
set -euo pipefail
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo -e "  ${GREEN}PASS${NC}  $desc"
    ((PASS++))
  else
    echo -e "  ${RED}FAIL${NC}  $desc"
    ((FAIL++))
  fi
}

echo ""
echo "=== Scenario 02 — Disk Pressure: Verification ==="
echo ""

# No node should have DiskPressure=True
DISK_PRESSURE=$(kubectl get nodes -o json | jq -r '.items[].status.conditions[] | select(.type=="DiskPressure") | .status' | grep -c "True" || true)
check "No node reports DiskPressure=True" test "$DISK_PRESSURE" -eq 0

# Fill file should be gone from the worker
CLUSTER_NAME=$(kind get clusters 2>/dev/null | head -1 || echo "")
if [[ -n "$CLUSTER_NAME" ]]; then
  for node in $(docker ps --format '{{.Names}}' | grep "${CLUSTER_NAME}-worker"); do
    FILE_GONE=$(docker exec "$node" test ! -f /disk-pressure-lab/fill.img && echo "gone" || echo "exists")
    check "Fill file removed from $node" test "$FILE_GONE" = "gone"
  done
fi

# All nodes Ready
NOT_READY=$(kubectl get nodes --no-headers | grep -v " Ready" | wc -l)
check "All nodes Ready" test "$NOT_READY" -eq 0

echo ""
if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}ALL CHECKS PASSED!${NC}"
else
  echo -e "${RED}$FAIL check(s) failed.${NC}"
  echo "Hint: du -sh /* inside the node to find large files"
fi
echo ""

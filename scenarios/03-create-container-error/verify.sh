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
echo "=== Scenario 03 — CreateContainerError: Verification ==="
echo ""

# A pod in lab-03 with scenario=03 label must be Running
STATUS=$(kubectl get pods -n lab-03 -l scenario=03 --no-headers 2>/dev/null | awk '{print $3}' | head -1)
check "A pod with label scenario=03 exists in lab-03" kubectl get pods -n lab-03 -l scenario=03
check "Pod is in Running state" test "$STATUS" = "Running"

echo ""
if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}ALL CHECKS PASSED!${NC}"
else
  echo -e "${RED}$FAIL check(s) failed.${NC}"
  echo "Hint: kubectl describe pod broken-pod -n lab-03 | grep -A5 'State:'"
fi
echo ""

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
echo "=== Scenario 06 — RunContainerError: Verification ==="
echo ""

STATUS_A=$(kubectl get pod bad-command -n lab-06 --no-headers 2>/dev/null | awk '{print $3}')
check "bad-command pod is Running" test "$STATUS_A" = "Running"

STATUS_B=$(kubectl get pod permission-denied -n lab-06 --no-headers 2>/dev/null | awk '{print $3}')
check "permission-denied pod is Running" test "$STATUS_B" = "Running"

echo ""
if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}ALL CHECKS PASSED!${NC}"
else
  echo -e "${RED}$FAIL check(s) failed.${NC}"
  echo "Hint: kubectl logs <pod> -n lab-06 to see the exit error"
fi
echo ""

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
echo "=== Scenario 04 — CreateContainerConfigError: Verification ==="
echo ""

check "Secret 'app-credentials' exists in lab-04" kubectl get secret app-credentials -n lab-04
check "ConfigMap 'db-config' exists in lab-04" kubectl get configmap db-config -n lab-04
check "ConfigMap has key 'host'" bash -c "kubectl get configmap db-config -n lab-04 -o jsonpath='{.data.host}' | grep -q ."

STATUS=$(kubectl get pods -n lab-04 -l scenario=04 --no-headers 2>/dev/null | awk '{print $3}' | head -1)
check "Pod is in Running state" test "$STATUS" = "Running"

echo ""
if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}ALL CHECKS PASSED!${NC}"
else
  echo -e "${RED}$FAIL check(s) failed.${NC}"
  echo "Hint: kubectl describe pod broken-pod -n lab-04 | grep -A5 Events"
fi
echo ""

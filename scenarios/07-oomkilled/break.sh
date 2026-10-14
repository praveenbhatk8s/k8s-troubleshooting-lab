#!/usr/bin/env bash
# Scenario 07 — OOMKilled
# Two sub-cases: memory limit too low, memory leak (no limit set, hog evicted)
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${RED}[BREAK]${NC} Scenario 07 — OOMKilled"
echo ""

kubectl create namespace lab-07 --dry-run=client -o yaml | kubectl apply -f -

# Case A: Container has a 32Mi limit but tries to allocate 128Mi
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: memory-hog
  namespace: lab-07
  labels:
    scenario: "07"
    case: "a"
spec:
  containers:
  - name: hog
    image: polinux/stress
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "128M", "--vm-hang", "1"]
    resources:
      requests:
        memory: "16Mi"
      limits:
        memory: "32Mi"   # limit too low — will be OOMKilled
  restartPolicy: OnFailure
EOF

# Case B: Pod with NO memory limit consuming too much (will be evicted by kubelet)
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: no-limit-hog
  namespace: lab-07
  labels:
    scenario: "07"
    case: "b"
spec:
  containers:
  - name: hog
    image: polinux/stress
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "64M", "--vm-hang", "60"]
    resources:
      requests:
        memory: "10Mi"
      # NO limits — bad practice
  restartPolicy: OnFailure
EOF

echo ""
echo -e "${YELLOW}[SCENARIO ACTIVE]${NC} 2 pods deployed in namespace lab-07"
echo ""
echo "Your tasks:"
echo "  - memory-hog:    OOMKilled immediately due to limit too low — fix the limit"
echo "  - no-limit-hog:  no memory limit set — add appropriate limits"
echo ""
echo "Useful starting point: kubectl get pods -n lab-07 -w"

#!/usr/bin/env bash
# Scenario 06 — RunContainerError
# Two sub-cases: bad entrypoint, permission denied on executable
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${RED}[BREAK]${NC} Scenario 06 — RunContainerError"
echo ""

kubectl create namespace lab-06 --dry-run=client -o yaml | kubectl apply -f -

# Case A: command that doesn't exist in the image
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: bad-command
  namespace: lab-06
  labels:
    scenario: "06"
    case: "a"
spec:
  containers:
  - name: app
    image: nginx:alpine
    command: ["/usr/local/bin/nonexistent-binary"]
    args: ["--start"]
  restartPolicy: Never
EOF

# Case B: permission denied — running as non-root, trying to bind port 80
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: permission-denied
  namespace: lab-06
  labels:
    scenario: "06"
    case: "b"
spec:
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      runAsUser: 1000
      runAsNonRoot: true
  restartPolicy: Never
EOF

echo ""
echo -e "${YELLOW}[SCENARIO ACTIVE]${NC} 2 pods deployed in namespace lab-06"
echo ""
echo "Your tasks:"
echo "  - bad-command:       container can't start because the command doesn't exist"
echo "  - permission-denied: nginx fails because non-root can't bind port 80"
echo ""
echo "Useful starting point: kubectl get pods -n lab-06"

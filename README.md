# k8s-troubleshooting-lab

> **Interactive Kubernetes troubleshooting scenarios — break it, fix it, learn it.**

A hands-on lab that simulates real-world Kubernetes failures. Each scenario injects a specific problem into your cluster. You diagnose and fix it. Then verify your solution.

Works with **kind**, **k3s**, **k3d**, or any kubeadm cluster.

---

## Scenarios

| # | Scenario | Difficulty |
|---|----------|-----------|
| 01 | Node Not Ready | ⭐⭐ |
| 02 | Node Disk Pressure | ⭐⭐ |
| 03 | CreateContainerError | ⭐⭐ |
| 04 | CreateContainerConfigError | ⭐⭐⭐ |
| 05 | ImagePullBackOff | ⭐⭐ |
| 06 | RunContainerError | ⭐⭐⭐ |
| 07 | OOMKilled | ⭐⭐ |

---

## Quick Start

```bash
# Clone
git clone https://github.com/praveenbhat/k8s-troubleshooting-lab
cd k8s-troubleshooting-lab

# Pick a scenario and break your cluster
./scenarios/01-node-not-ready/break.sh

# Investigate, diagnose, fix it yourself
# Then verify
./scenarios/01-node-not-ready/verify.sh

# Stuck? Read the hint
cat scenarios/01-node-not-ready/HINTS.md

# See the solution
cat scenarios/01-node-not-ready/SOLUTION.md
```

---

## How Each Scenario Is Structured

```
scenarios/XX-name/
├── break.sh        # Injects the failure
├── verify.sh       # Confirms your fix is correct
├── reset.sh        # Clean slate — removes everything this scenario created
├── HINTS.md        # Progressive hints (read one at a time!)
└── SOLUTION.md     # Full explanation + fix commands
```

---

## Lab Rules

1. Run `break.sh` → cluster is now broken
2. Use only `kubectl`, `crictl`, `systemctl`, `journalctl`, `docker exec` — no peeking at the scripts
3. Fix it
4. Run `verify.sh` — it tells you pass or fail
5. Read `SOLUTION.md` after you're done (win or lose)

---

## Prerequisites

- A running Kubernetes cluster (kind, k3d, k3s, kubeadm)
- `kubectl` configured
- `docker` (for kind node exec) or `ssh` access to nodes
- `crictl` available on nodes
- Helm (for Falco scenarios, optional)

---

## ArgoCD / GitOps

This repo ships an ArgoCD Application manifest. Point it at your cluster:

```bash
kubectl apply -f argocd/application.yaml
```

---

## Backstage

Register this lab in your Backstage catalog:

```bash
# Already in repo root
cat catalog-info.yaml
```

---

## Adding More Scenarios

PRs welcome. Follow the structure above — `break.sh`, `verify.sh`, `reset.sh`, `HINTS.md`, `SOLUTION.md`.

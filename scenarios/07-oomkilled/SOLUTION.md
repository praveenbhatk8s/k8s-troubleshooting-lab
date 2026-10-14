# Solution — OOMKilled

## What Happened

| Pod | Cause |
|-----|-------|
| `memory-hog` | Memory limit (32Mi) < actual allocation needed (128Mi) → kernel OOM kills the process |
| `no-limit-hog` | No memory limit → can consume unbounded node memory → kubelet eviction or node pressure |

## How OOMKilled Works

When a container exceeds its `resources.limits.memory`, the Linux kernel's **OOM (Out-Of-Memory) killer** sends `SIGKILL` (signal 9) to the container's main process. This results in:

- Exit code **137** (128 + 9)
- Container state: `OOMKilled`
- `restartPolicy: OnFailure` / `Always` → pod restarts → eventually `CrashLoopBackOff`

This is a **cgroup** enforcement — the kernel prevents the container from using more memory than its cgroup limit allows.

## Diagnosis

```bash
kubectl get pods -n lab-07
# memory-hog    0/1   OOMKilled         3   (or CrashLoopBackOff)
# no-limit-hog  1/1   Running           0   (currently running, may not be killed yet)

kubectl describe pod memory-hog -n lab-07 | grep -A 15 "Containers:"
# State:          Waiting
#   Reason:       CrashLoopBackOff
# Last State:     Terminated
#   Reason:       OOMKilled
#   Exit Code:    137

# Check actual memory usage
kubectl top pod -n lab-07    # requires metrics-server

# Node-level OOM events
kubectl get events -n lab-07 --field-selector reason=OOMKilling
dmesg | grep -i "oom\|killed"   # on the node
```

## Fix — memory-hog (raise the limit)

```bash
kubectl delete pod memory-hog -n lab-07
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
        memory: "64Mi"
      limits:
        memory: "256Mi"   # headroom above 128M allocation
  restartPolicy: OnFailure
EOF
```

## Fix — no-limit-hog (add a limit)

```bash
kubectl delete pod no-limit-hog -n lab-07
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
        memory: "32Mi"
      limits:
        memory: "128Mi"
  restartPolicy: OnFailure
EOF
```

## Request vs Limit

| | `requests` | `limits` |
|--|-----------|----------|
| Used for | Scheduling (where to place pod) | Enforcement (cgroup max) |
| Breach | Never — it's just a reservation | OOMKilled (memory), throttled (CPU) |
| Rule | requests ≤ limits | — |

## QoS Classes

| Class | Condition | OOM Priority |
|-------|-----------|-------------|
| `Guaranteed` | requests == limits for ALL containers | Killed last |
| `Burstable` | requests < limits, at least one has limit | Killed based on usage |
| `BestEffort` | No requests OR limits | Killed first |

## Key Commands

```bash
kubectl describe pod <name> -n <ns> | grep -A 5 "Last State"   # confirm OOMKilled
kubectl top pod -n <ns>                                          # live memory usage
kubectl top node                                                  # node memory pressure
kubectl get events -n <ns> --sort-by='.lastTimestamp'           # OOM events
```

## Installing metrics-server on kind

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# kind needs --kubelet-insecure-tls flag:
kubectl patch deployment metrics-server -n kube-system \
  --type json \
  -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

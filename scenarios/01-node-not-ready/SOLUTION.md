# Solution — Node Not Ready

## What Happened

The `kubelet` systemd service was stopped on a worker node.

The kubelet is responsible for:
- Sending heartbeats (node lease updates) to the API server every 10s (default)
- Running pod lifecycle (start, stop, health checks)
- Reporting node conditions

When the node controller stops receiving heartbeats for `node-monitor-grace-period` (default: **40 seconds**), it marks the node as `NotReady` and sets the `KubeletReady` condition to `Unknown`.

After another ~5 minutes (`pod-eviction-timeout`), pods on the NotReady node are evicted to healthy nodes.

## Diagnosis Steps

```bash
# Step 1 — identify the problem node
kubectl get nodes
# NAME                 STATUS     ROLES           AGE   VERSION
# cks-control-plane    Ready      control-plane   10m   v1.30.0
# cks-worker           NotReady   <none>          10m   v1.30.0  ← here

# Step 2 — understand why
kubectl describe node cks-worker | grep -A 10 Conditions
# KubeletReady    Unknown   ...   Kubelet stopped posting node status.

# Step 3 — check the kubelet on the node
docker exec cks-worker systemctl status kubelet
# ● kubelet.service - kubelet: The Kubernetes Node Agent
#    Loaded: loaded
#    Active: inactive (dead) ← STOPPED

# Step 4 — check kubelet logs for the cause
docker exec cks-worker journalctl -u kubelet --no-pager -n 30
```

## Fix

```bash
# Start kubelet
docker exec cks-worker systemctl start kubelet

# Watch node recover (~30-60s)
kubectl get nodes -w
```

## Real-World Causes of Node Not Ready

| Cause | Signal |
|-------|--------|
| kubelet crashed / OOM killed | `journalctl -u kubelet` shows OOM or panic |
| kubelet config error after upgrade | kubelet exits immediately after start |
| Node ran out of disk (eviction threshold) | `DiskPressure=True` in node conditions |
| Node ran out of memory | `MemoryPressure=True` |
| Network partition | Node conditions `Unknown`, not `False` |
| Container runtime (containerd/dockerd) crash | kubelet logs: "unable to connect to runtime" |

## Key Commands to Remember

```bash
kubectl get nodes
kubectl describe node <name>
kubectl get events --field-selector involvedObject.name=<node-name>
docker exec <node> systemctl status kubelet
docker exec <node> journalctl -u kubelet -f
crictl ps   # list containers via CRI (run inside node)
```

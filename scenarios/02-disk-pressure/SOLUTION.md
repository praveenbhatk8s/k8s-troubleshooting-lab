# Solution — Node Disk Pressure

## What Happened

A 3.8GB file was written to `/disk-pressure-lab/fill.img` inside the worker node container, consuming most of the available disk space.

The kubelet monitors disk usage via its **eviction manager**. When available disk drops below the `nodefs.available` threshold (default: **10%** or **100Mi**), it:
1. Sets `DiskPressure=True` on the node condition
2. Stops scheduling new pods on this node
3. Begins evicting pods (BestEffort first, then Burstable, then Guaranteed)

## Diagnosis

```bash
# Identify the node
kubectl get nodes
# NAME          STATUS     ROLES    CONDITION
# cks-worker    Ready,SchedulingDisabled   ... DiskPressure

kubectl describe node cks-worker | grep -A 5 Conditions
# DiskPressure   True    ...   nodefs is available(5%)

# Check disk inside the node
docker exec cks-worker df -h /
docker exec cks-worker du -sh /* 2>/dev/null | sort -rh | head -10
# 3.8G  /disk-pressure-lab  ← culprit

# Also check container logs for eviction events
kubectl get events --field-selector reason=Evicted
```

## Fix

```bash
# Remove the fill file
docker exec cks-worker rm -rf /disk-pressure-lab

# Verify disk free
docker exec cks-worker df -h /

# Kubelet clears DiskPressure automatically within ~30s
kubectl get nodes -w
```

## Real-World Causes

| Cause | Fix |
|-------|-----|
| Container logs filling disk | Configure log rotation in containerd/kubelet |
| Large container images | `crictl rmi` unused images; set `imageGCHighThresholdPercent` |
| Application writing to hostPath / emptyDir | Add resource limits or use PVC |
| Crash-loop writing core dumps | Disable core dumps or set limits |
| Old container overlays | `crictl rmp` stopped containers |

## Key kubelet Eviction Config

```yaml
# In kubelet config:
evictionHard:
  nodefs.available: "10%"
  nodefs.inodesFree: "5%"
  imagefs.available: "15%"
evictionSoft:
  nodefs.available: "15%"
evictionSoftGracePeriod:
  nodefs.available: "1m30s"
```

## Commands to Know

```bash
kubectl describe node <name> | grep -A 10 Conditions
kubectl get events --field-selector reason=Evicted
docker exec <node> df -h
docker exec <node> du -sh /* 2>/dev/null | sort -rh | head -20
docker exec <node> crictl images   # check image disk usage
docker exec <node> crictl rmi $(crictl images -q)   # prune images
```

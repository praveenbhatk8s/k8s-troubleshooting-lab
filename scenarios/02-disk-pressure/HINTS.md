# Hints — Node Disk Pressure

## Hint 1

```bash
kubectl get nodes
kubectl describe node <worker-node> | grep -A 5 "Conditions:"
```

Look for `DiskPressure: True`.

## Hint 2

Get into the node and check disk usage:

```bash
docker exec <worker-container> df -h
docker exec <worker-container> du -sh /* 2>/dev/null | sort -rh | head -20
```

Find the directory eating disk.

## Hint 3

The large file is at `/disk-pressure-lab/fill.img`. Remove it:

```bash
docker exec <worker-container> rm -rf /disk-pressure-lab
```

## Hint 4

After removing the file, the kubelet will detect available disk space on its next sync (default every 10s) and clear the DiskPressure condition. Watch it:

```bash
kubectl get nodes -w
```

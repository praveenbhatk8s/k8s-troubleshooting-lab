# Hints — Node Not Ready

Read one hint at a time. Try to fix it before moving to the next.

---

## Hint 1

Start with the obvious:

```bash
kubectl get nodes
kubectl get nodes -o wide
```

Which node is NotReady? What does the `STATUS` column say?

---

## Hint 2

Describe the node and look at the Conditions section:

```bash
kubectl describe node <node-name> | grep -A 10 "Conditions:"
```

Look at `KubeletReady`, `MemoryPressure`, `DiskPressure`, `PIDPressure`.
What condition is `False` or `Unknown`?

---

## Hint 3

The node controller sets a node to `NotReady` when it stops receiving heartbeats from the kubelet.
The kubelet is the agent that runs on every node and sends these heartbeats.

Check whether the kubelet process is running on the node.
For a kind cluster, nodes are Docker containers:

```bash
# Find the node's container name
docker ps | grep worker

# Check kubelet status inside the container
docker exec <container-name> systemctl status kubelet
```

---

## Hint 4

If kubelet is stopped (inactive/dead), you need to start it:

```bash
docker exec <container-name> systemctl start kubelet
```

Then watch the node recover:

```bash
kubectl get nodes -w
```

It takes ~30–60 seconds for the node to transition back to Ready.

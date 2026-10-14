# Hints — CreateContainerError

## Hint 1

```bash
kubectl get pods -n lab-03
kubectl describe pod broken-pod -n lab-03
```

Look at the `State` field under `Containers`. What does the `Reason` say?

## Hint 2

Scroll to the `Events` section in the describe output. The event message will tell you exactly what the container runtime rejected.

```bash
kubectl describe pod broken-pod -n lab-03 | grep -A 20 Events
```

## Hint 3

`CreateContainerError` means the kubelet handed the pod spec to the container runtime (containerd), which then failed to create the container. This is different from `CreateContainerConfigError` (which is a config validation issue before the runtime).

Common causes: invalid seccomp profile path, invalid AppArmor profile, missing device/volume mount point.

Look at the `securityContext` section of the pod spec.

## Hint 4

The pod references a `Localhost` seccomp profile that doesn't exist on the node:

```bash
kubectl get pod broken-pod -n lab-03 -o yaml | grep -A5 seccompProfile
```

Fix: change the seccomp profile to `RuntimeDefault` (or remove the seccompProfile block entirely):

```bash
kubectl delete pod broken-pod -n lab-03
```

Then re-apply with the corrected spec.

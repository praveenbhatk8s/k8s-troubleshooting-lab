# Hints — ImagePullBackOff

Three pods, three different root causes.

## General Approach

```bash
kubectl get pods -n lab-05
kubectl describe pod <name> -n lab-05 | grep -A 20 Events
```

The Events section will show the exact pull error message.

---

## Pod: wrong-tag

**Hint 1:** The image `nginx:this-tag-does-not-exist-99999` doesn't exist on Docker Hub.
Fix: delete the pod and re-create with `nginx:alpine` or `nginx:latest`.

```bash
kubectl delete pod wrong-tag -n lab-05
kubectl run wrong-tag --image=nginx:alpine -n lab-05 --restart=Never -l scenario=05,case=a
```

---

## Pod: wrong-registry

**Hint 1:** The registry `nonexistent-registry.internal.corp` can't be resolved by DNS.

Fix: replace with a valid public image:

```bash
kubectl delete pod wrong-registry -n lab-05
kubectl run wrong-registry --image=nginx:alpine -n lab-05 --restart=Never -l scenario=05,case=b
```

---

## Pod: no-pull-secret

**Hint 1:** The image is on `ghcr.io` (GitHub Container Registry) and requires authentication.

**Hint 2:** Create a fake imagePullSecret (for this lab, we'll switch to a public image instead):

```bash
kubectl delete pod no-pull-secret -n lab-05
kubectl run no-pull-secret --image=nginx:alpine -n lab-05 --restart=Never -l scenario=05,case=c
```

**OR** create a real imagePullSecret:
```bash
kubectl create secret docker-registry ghcr-creds \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USER \
  --docker-password=YOUR_PAT \
  -n lab-05
```

Then reference it in the pod spec via `imagePullSecrets`.

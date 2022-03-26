# Smoke Test

```bash
sh config/05_smoketest.sh
```

## Data Encryption

```bash
INSTANCE_ID=$(aws ec2 describe-instances  \
  --filters Name=tag:Name,Values=controller-0 Name=instance-state-name,Values=running  \
  --query 'Reservations[*].Instances[*].InstanceId' --output text)

ssh ubuntu@${INSTANCE_ID} "sudo ETCDCTL_API=3 etcdctl get \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem \
  /registry/secrets/default/kubernetes-the-hard-way | hexdump -C"
```

## Port Forwarding

```bash
POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}")

kubectl port-forward $POD_NAME 8080:80

curl --head http://127.0.0.1:8080
```

## Logs

```bash
kubectl logs $POD_NAME
```

## Exec

```bash
kubectl exec -ti $POD_NAME -- nginx -v
```

## Services

```bash
NODE_PORT=$(kubectl get svc nginx \
  --output=jsonpath='{range .spec.ports[0]}{.nodePort}')

NODE_IP=$(kubectl get pods -l app=nginx \
  --output=jsonpath="{.items[0].status.hostIP}")

ssh ubuntu@${INSTANCE_ID} "curl -sI http://${NODE_IP}:${NODE_PORT}"
```

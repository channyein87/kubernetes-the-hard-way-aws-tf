# Smoke Test

```bash
sh 05_smoketest.sh
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
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: nginx-lb
  labels:
    app: nginx
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
  - name: http
    port: 80
    protocol: TCP
EOF

ELB_DNS=$(kubectl get svc nginx-lb -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")

curl http://ELB_DNS
```

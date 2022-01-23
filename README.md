# Kubernetes The Hard Way AWS & Terraform

## Pre-requisites

1. `cfssl` and `cfssljson`
1. `kubectl`
1. `awscli` and `session-manager-plugin`
1. `terraform`

## Build Infrastruture

```bash
terraform apply -var "aws_profile=default" -var "aws_region=ap-southeast-2" \
    -var "vpc_id=vpc-12345" -var "controller_count=2" -var "worker_count=2"
```

## Generate TLS

```bash
cd config
sh 01_tlscerts.sh -c 2 -w 2
```

## Generate Kube Configs

```bash
sh 02_kubeconfigs.sh -c 2 -w 2
```

## Bootstrap Controllers and Workers

```bash
sh 03_bootstrap.sh -c 2 -w 2
```

## Local Authentication and DNS

```bash
sh 04_dns.sh

kubectl run busybox --image=busybox:1.28 --command -- sleep 3600

kubectl get pods -l run=busybox

kubectl exec -ti busybox -- nslookup kubernetes
```

## Smoke Test

[Smoke test](https://github.com/channyein87/kubernetes-the-hard-way-aws-tf/blob/master/config/05_smoketest.md)

## Cleaning Up

```bash
terraform destroy

kubectl config unset users.admin
kubectl config unset clusters.kubernetes-the-hard-way
kubectl config unset contexts.kubernetes-the-hard-way
kubectl config unset current-context

rm config/*.kubeconfig config/*.yaml config/*.json config/*.csr config/*.pem
```

## More Hard Ways

- [Cloud Provider](https://github.com/channyein87/kubernetes-the-hard-way-aws-tf/blob/3e696dc8f7f015de135898c32767424288e24370/README.md)

# Kubernetes The Hard Way AWS & Terraform w/ Cloud Provider

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
```

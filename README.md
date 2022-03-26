# Kubernetes The Hard Way AWS & Terraform (AWS Load Balancer Controller) - WIP

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

## Local SSH Config

`~/.ssh/config` file.

```config
host i-* mi-*
    ProxyCommand sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"
```

## Generate TLS

```bash
sh config/01_tlscerts.sh -c 2 -w 2
```

## Generate Kube Configs

```bash
sh config/02_kubeconfigs.sh -c 2 -w 2
```

## Bootstrap Controllers and Workers

```bash
sh config/03_bootstrap.sh -c 2 -w 2
```

## Local Authentication and DNS

```bash
sh config/04_dns.sh

kubectl run busybox --image=busybox:1.28 --command -- sleep 3600

kubectl get pods -l run=busybox

kubectl exec -ti busybox -- nslookup kubernetes
```

## Smoke Test

[Smoke test](config/05_smoketest.md)

## OIDC Test

[OIDC test](config/06_oidc.md)

## Cleaning Up

```bash
kubectl config unset users.admin
kubectl config unset clusters.kubernetes-the-hard-way
kubectl config unset contexts.kubernetes-the-hard-way
kubectl config unset current-context

rm config/*.kubeconfig config/*.yaml config/*.json config/*.csr config/*.pem

terraform destroy
```

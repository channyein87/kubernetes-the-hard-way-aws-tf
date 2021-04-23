# Kubernetes The Hard Way AWS & Terraform

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

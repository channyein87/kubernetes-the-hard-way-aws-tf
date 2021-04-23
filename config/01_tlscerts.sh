#!/bin/bash

while getopts c:w: flag
do
    case "${flag}" in
        c) controller=${OPTARG};;
        w) worker=${OPTARG};;
    esac
done
echo "No. of controllers: $controller";
echo "No. of workers: $worker";

CONTROLLERS=()
for ((i=0; i<${controller}; i++)); do
    CONTROLLERS+=("controller-${i}")
done
echo "Controllers name: ${CONTROLLERS[@]}"

WORKERS=()
for ((i=0; i<${worker}; i++)); do
    WORKERS+=("worker-${i}")
done
echo "Workers name: ${WORKERS[@]}"

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

for instance in ${WORKERS[@]}; do
HOST_DNS=$(aws ec2 describe-instances \
    --filters Name=tag:Name,Values=${instance} Name=instance-state-name,Values=running \
    --query 'Reservations[*].Instances[*].PrivateDnsName' --output text)

HOST_NAME=$(echo ${HOST_DNS} | sed 's/\..*//')

cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${HOST_NAME}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

INTERNAL_IP=$(aws ec2 describe-instances \
  --filters Name=tag:Name,Values=${instance} Name=instance-state-name,Values=running \
  --query 'Reservations[*].Instances[*].PrivateIpAddress' --output text)

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${HOST_NAME},${INTERNAL_IP} \
  -profile=kubernetes \
  ${instance}-csr.json | cfssljson -bare ${instance}
done

cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler

export KUBERNETES_NLB_DNS=$(aws elbv2 describe-load-balancers --names kubernetes-the-hard-way-nlb --query 'LoadBalancers[*].DNSName' --output text)
echo "KUBERNETES_NLB_DNS: ${KUBERNETES_NLB_DNS}"

export KUBERNETES_NLB_IPS=$(aws ec2 describe-network-interfaces --filters Name=description,Values="*kubernetes-the-hard-way-nlb*" \
  --query 'NetworkInterfaces[*].PrivateIpAddresses[*].PrivateIpAddress' --output text)
echo "KUBERNETES_NLB_IPS: ${KUBERNETES_NLB_IPS}"

export NLB_IPS=$(echo ${KUBERNETES_NLB_IPS} | sed 's/ /,/g')
echo "NLB_IPS: ${NLB_IPS}"

export CONTROLLER_IPS=$(aws ec2 describe-instances \
  --filters Name=tag:Name,Values="controller-*" Name=instance-state-name,Values=running \
  --query 'Reservations[*].Instances[*].PrivateIpAddress' --output text)

export CONTROLLER_IPS=$(echo ${CONTROLLER_IPS} | sed 's/ /,/g')
echo "CONTROLLER_IPS: ${CONTROLLER_IPS}"

export KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,${CONTROLLER_IPS},${NLB_IPS},127.0.0.1,${KUBERNETES_NLB_DNS},${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account

for instance in ${WORKERS[@]}; do
  INSTANCE_ID=$(aws ec2 describe-instances \
    --filters Name=tag:Name,Values=${instance} Name=instance-state-name,Values=running \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)

  scp -o "StrictHostKeyChecking no" ca.pem ${instance}-key.pem ${instance}.pem ubuntu@${INSTANCE_ID}:~/
done

for instance in ${CONTROLLERS[@]}; do
  INSTANCE_ID=$(aws ec2 describe-instances \
    --filters Name=tag:Name,Values=${instance} Name=instance-state-name,Values=running \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)

  scp -o "StrictHostKeyChecking no" ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem ubuntu@${INSTANCE_ID}:~/
done

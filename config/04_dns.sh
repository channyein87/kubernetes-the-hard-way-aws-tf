#!/bin/bash

export KUBERNETES_NLB_DNS=$(/usr/local/bin/aws elbv2 describe-load-balancers --names kubernetes-the-hard-way-nlb --query 'LoadBalancers[*].DNSName' --output text)

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_NLB_DNS}

kubectl config set-credentials admin \
  --client-certificate=admin.pem \
  --client-key=admin-key.pem

kubectl config set-context kubernetes-the-hard-way \
  --cluster=kubernetes-the-hard-way \
  --user=admin

kubectl config use-context kubernetes-the-hard-way

kubectl apply -f https://storage.googleapis.com/kubernetes-the-hard-way/coredns-1.7.0.yaml

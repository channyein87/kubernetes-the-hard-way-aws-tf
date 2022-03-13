#!/bin/bash
cd "$(dirname "$0")"

kubectl config unset users.admin
kubectl config unset clusters.kubernetes-the-hard-way
kubectl config unset contexts.kubernetes-the-hard-way
kubectl config unset current-context

rm *.kubeconfig *.yaml *.json *.csr *.pem
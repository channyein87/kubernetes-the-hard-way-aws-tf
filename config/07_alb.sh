#!/bin/bash
cd "$(dirname "$0")"

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cert-manager.yaml

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: alb-controller-role
data:
  AWS_DEFAULT_REGION: ap-southeast-2
  AWS_ROLE_ARN: arn:aws:iam::487523894433:role/kubernetes-the-hard-way-alb-role
  AWS_WEB_IDENTITY_TOKEN_FILE: /var/run/secrets/oidc-iam/serviceaccount/token
EOF

kubectl apply -f ../files/alb_controller.yaml

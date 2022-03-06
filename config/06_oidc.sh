#!/bin/bash
cd "$(dirname "$0")"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: oidc-iam-pod-role
data:
  AWS_DEFAULT_REGION: ap-southeast-2
  AWS_ROLE_ARN: arn:aws:iam::487523894433:role/kubernetes-the-hard-way-pod-role
  AWS_WEB_IDENTITY_TOKEN_FILE: /var/run/secrets/oidc-iam/serviceaccount/token
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: oidc-iam-pod
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: awscli
spec:
  containers:
    - image: amazon/aws-cli
      name: awscli
      command: ["sleep"]
      args: ["3600"]
      envFrom:
        - configMapRef:
            name: oidc-iam-pod-role
      volumeMounts:
        - mountPath: /var/run/secrets/oidc-iam/serviceaccount/
          name: aws-token
  serviceAccountName: oidc-iam-pod
  volumes:
    - name: aws-token
      projected:
        sources:
        - serviceAccountToken:
            path: token
            expirationSeconds: 600
            audience: kubernetes-the-hard-way
EOF

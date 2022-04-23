#!/bin/bash
cd "$(dirname "$0")"

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.0/cert-manager.yaml
kubectl delete mutatingwebhookconfiguration.admissionregistration.k8s.io cert-manager-webhook
kubectl delete validatingwebhookconfiguration.admissionregistration.k8s.io cert-manager-webhook

# cat <<EOF | kubectl apply -f -
# apiVersion: v1
# kind: ConfigMap
# metadata:
#   name: alb-controller-role
# data:
#   AWS_DEFAULT_REGION: ap-southeast-2
#   AWS_ROLE_ARN: arn:aws:iam::487523894433:role/kubernetes-the-hard-way-alb-role
#   AWS_WEB_IDENTITY_TOKEN_FILE: /var/run/secrets/oidc-iam/serviceaccount/token
# EOF

export ALB_IAM_ROLE_ARN=$(aws iam get-role --role-name kubernetes-the-hard-way-alb-role \
  --query 'Role.Arn' --output text)

eval "cat <<EOF
$(<../files/alb-controller.yaml)
EOF" | kubectl apply -f -

export ROUTE53_ZONE_ID=$(aws route53 list-hosted-zones \
  --query 'HostedZones[?Config.Comment == `kubernetes-the-hard-way`].Id' --output text | grep -Eo '([A-Z])\w+')

export ROUTE53_ZONE_NAME=$(aws route53 list-tags-for-resource --resource-type hostedzone \
  --resource-id ${ROUTE53_ZONE_ID} --query 'ResourceTagSet.Tags[?Key == `Name`].Value' --output text)

export ROUTE53_IAM_ROLE_ARN=$(aws iam get-role --role-name kubernetes-the-hard-way-externaldns-role \
  --query 'Role.Arn' --output text)

eval "cat <<EOF
$(<../files/external-dns.yaml)
EOF" | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: echoserver
EOF

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echoserver
  namespace: echoserver
spec:
  selector:
    matchLabels:
      app: echoserver
  replicas: 1
  template:
    metadata:
      labels:
        app: echoserver
    spec:
      containers:
      - image: k8s.gcr.io/e2e-test-images/echoserver:2.5
        imagePullPolicy: Always
        name: echoserver
        ports:
        - containerPort: 8080
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: echoserver
  namespace: echoserver
spec:
  ports:
    - port: 80
      targetPort: 8080
      protocol: TCP
  type: NodePort
  selector:
    app: echoserver
EOF

export ACM_ARN=$(aws acm list-certificates \
  --query 'CertificateSummaryList[?contains(DomainName, `echoserver`) == `true`].CertificateArn' --output text)

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: echoserver
  namespace: echoserver
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/tags: Name=kubernetes-the-hard-way
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/certificate-arn: ${ACM_ARN}
spec:
  ingressClassName: alb
  defaultBackend:
    service:
      name: echoserver
      port:
        number: 80
  rules:
    - host: echoserver.${ROUTE53_ZONE_NAME}
      http:
        paths:
          - path: /
            pathType: Exact
            backend:
              service:
                name: echoserver
                port:
                  number: 80
EOF

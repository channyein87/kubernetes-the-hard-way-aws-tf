#!/bin/bash
cd "$(dirname "$0")"

while getopts c:w: flag
do
    case "${flag}" in
        c) controller=${OPTARG};;
        w) worker=${OPTARG};;
    esac
done
echo "No. of controllers: $controller";
echo "No. of workers: $worker";

rm *.kubeconfig *.yaml

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

export KUBERNETES_NLB_DNS=$(aws elbv2 describe-load-balancers --names kubernetes-the-hard-way-nlb --query 'LoadBalancers[*].DNSName' --output text)

for instance in ${WORKERS[@]}; do
  HOST_DNS=$(aws ec2 describe-instances \
      --filters Name=tag:Name,Values=${instance} Name=instance-state-name,Values=running \
      --query 'Reservations[*].Instances[*].PrivateDnsName' --output text)

  HOST_NAME=$(echo ${HOST_DNS} | sed 's/\..*//')

  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_NLB_DNS} \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-credentials system:node:${HOST_NAME} \
    --client-certificate=${instance}.pem \
    --client-key=${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${HOST_NAME} \
    --kubeconfig=${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=${instance}.kubeconfig
done

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_NLB_DNS} \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate=kube-proxy.pem \
  --client-key=kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=kube-controller-manager.pem \
  --client-key=kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=kube-scheduler.pem \
  --client-key=kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=admin.pem \
  --client-key=admin-key.pem \
  --embed-certs=true \
  --kubeconfig=admin.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=admin \
  --kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig

for instance in ${WORKERS[@]}; do
  INSTANCE_ID=$(aws ec2 describe-instances  \
    --filters Name=tag:Name,Values=${instance} Name=instance-state-name,Values=running  \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)

  scp -o "StrictHostKeyChecking no" ${instance}.kubeconfig kube-proxy.kubeconfig bootstrap-workers.sh ubuntu@${INSTANCE_ID}:~/
done

export ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

for instance in ${CONTROLLERS[@]}; do
  INSTANCE_ID=$(aws ec2 describe-instances  \
    --filters Name=tag:Name,Values=${instance} Name=instance-state-name,Values=running  \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)

  scp -o "StrictHostKeyChecking no" admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig encryption-config.yaml bootstrap-controllers.sh ubuntu@${INSTANCE_ID}:~/
done

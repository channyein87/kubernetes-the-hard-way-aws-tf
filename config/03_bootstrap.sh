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

export SSM_RUN_CMD_CON=$(aws ssm send-command --targets Key=tag:Role,Values=controller \
  --document-name "AWS-RunShellScript" --output text --query "Command.CommandId" \
  --parameters workingDirectory="/home/ubuntu",commands="sh bootstrap-controllers.sh")
echo ${SSM_RUN_CMD_CON}

for instance in ${CONTROLLERS[@]}; do
  INSTANCE_ID=$(aws ec2 describe-instances  \
    --filters Name=tag:Name,Values=${instance} Name=instance-state-name,Values=running  \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)

  aws ssm wait command-executed --command-id ${SSM_RUN_CMD_CON} --instance-id ${INSTANCE_ID}

  SSM_CMD_STATUS=$(aws ssm list-command-invocations --command-id ${SSM_RUN_CMD_CON} --instance-id ${INSTANCE_ID} \
    --query 'CommandInvocations[*].Status' --output text)

  echo "${instance} : ${SSM_CMD_STATUS}"
done

export SSM_RUN_CMD_WRK=$(aws ssm send-command --targets Key=tag:Role,Values=worker \
  --document-name "AWS-RunShellScript" --output text --query "Command.CommandId" \
  --parameters workingDirectory="/home/ubuntu",commands="sh bootstrap-workers.sh")
echo ${SSM_RUN_CMD_WRK}

for instance in ${WORKERS[@]}; do
  INSTANCE_ID=$(aws ec2 describe-instances  \
    --filters Name=tag:Name,Values=${instance} Name=instance-state-name,Values=running  \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)

  aws ssm wait command-executed --command-id ${SSM_RUN_CMD_WRK} --instance-id ${INSTANCE_ID}

  SSM_CMD_STATUS=$(aws ssm list-command-invocations --command-id ${SSM_RUN_CMD_WRK} --instance-id ${INSTANCE_ID} \
    --query 'CommandInvocations[*].Status' --output text)

  echo "${instance} : ${SSM_CMD_STATUS}"
done

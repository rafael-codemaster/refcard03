#!/usr/bin/env bash
# EX-03: Einmaliges Setup von ECR, RDS (MariaDB), Secrets Manager, ECS-Cluster,
# Security Groups, Application Load Balancer und ECS-Service im AWS Academy Learner Lab.
#
# Ausführen in der AWS CloudShell (Konsole oben rechts ">_"), Datei vorher hochladen:
#   bash aws-ecs-setup.sh
# Mehrfaches Ausführen ist unkritisch: bestehende Ressourcen werden wiederverwendet.
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
APP=biztrips-backend
export AWS_DEFAULT_REGION="$REGION"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "==> Account $ACCOUNT_ID, Region $REGION"

echo "==> 1. ECR-Repository"
aws ecr describe-repositories --repository-names "$APP" > /dev/null 2>&1 \
  || aws ecr create-repository --repository-name "$APP" > /dev/null

echo "==> Netzwerk (Default-VPC, Subnets in ${REGION}a und ${REGION}b)"
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
read -r SUBNET_A SUBNET_B _ <<< "$(aws ec2 describe-subnets \
  --filters Name=vpc-id,Values="$VPC_ID" Name=default-for-az,Values=true \
            Name=availability-zone,Values="${REGION}a","${REGION}b" \
  --query 'Subnets[].SubnetId' --output text)"
echo "    VPC $VPC_ID, Subnets $SUBNET_A $SUBNET_B"

create_sg() {
  local id
  id=$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values="$1" Name=vpc-id,Values="$VPC_ID" \
    --query 'SecurityGroups[0].GroupId' --output text)
  if [ "$id" = "None" ]; then
    id=$(aws ec2 create-security-group --group-name "$1" --description "$2" \
      --vpc-id "$VPC_ID" --query GroupId --output text)
  fi
  echo "$id"
}
allow() { aws ec2 authorize-security-group-ingress "$@" > /dev/null 2>&1 || true; }

SG_ALB=$(create_sg "$APP-alb-sg" "ALB: HTTP 80 aus dem Internet")
SG_TASKS=$(create_sg "$APP-tasks-sg" "Fargate-Tasks: 8080 nur vom ALB")
SG_DB=$(create_sg "$APP-db-sg" "RDS: 3306 nur von den Fargate-Tasks")
allow --group-id "$SG_ALB" --protocol tcp --port 80 --cidr 0.0.0.0/0
allow --group-id "$SG_TASKS" --protocol tcp --port 8080 --source-group "$SG_ALB"
allow --group-id "$SG_DB" --protocol tcp --port 3306 --source-group "$SG_TASKS"

echo "==> 3. RDS-Instanz (MariaDB) + Passwort in Secrets Manager"
DB_ID="$APP-db"
SECRET_NAME="$APP-db-password"
if ! aws rds describe-db-instances --db-instance-identifier "$DB_ID" > /dev/null 2>&1; then
  DB_PASSWORD=$(openssl rand -hex 16)
  aws rds create-db-instance \
    --db-instance-identifier "$DB_ID" \
    --db-instance-class db.t3.micro \
    --engine mariadb \
    --engine-version 10.11 \
    --master-username admin \
    --master-user-password "$DB_PASSWORD" \
    --allocated-storage 20 \
    --db-name db_biztrips \
    --vpc-security-group-ids "$SG_DB" \
    --no-publicly-accessible \
    --backup-retention-period 0 > /dev/null
  if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" > /dev/null 2>&1; then
    aws secretsmanager put-secret-value --secret-id "$SECRET_NAME" --secret-string "$DB_PASSWORD" > /dev/null
  else
    aws secretsmanager create-secret --name "$SECRET_NAME" --secret-string "$DB_PASSWORD" > /dev/null
  fi
  unset DB_PASSWORD
fi
DB_SECRET_ARN=$(aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --query ARN --output text)
echo "    Warte, bis RDS verfügbar ist (ca. 5–10 Minuten) ..."
aws rds wait db-instance-available --db-instance-identifier "$DB_ID"
RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier "$DB_ID" \
  --query 'DBInstances[0].Endpoint.Address' --output text)

echo "==> 4. ECS-Cluster + Log-Group"
aws ecs create-cluster --cluster-name "$APP-cluster" > /dev/null
aws logs create-log-group --log-group-name "/ecs/$APP" > /dev/null 2>&1 || true

echo "==> 5. Target Group + Application Load Balancer"
TG_ARN=$(aws elbv2 describe-target-groups --names "$APP-tg" \
  --query 'TargetGroups[0].TargetGroupArn' --output text 2> /dev/null) \
  || TG_ARN=$(aws elbv2 create-target-group --name "$APP-tg" \
       --protocol HTTP --port 8080 --vpc-id "$VPC_ID" --target-type ip \
       --health-check-path /actuator/health --health-check-interval-seconds 15 \
       --healthy-threshold-count 2 --unhealthy-threshold-count 3 \
       --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 modify-target-group-attributes --target-group-arn "$TG_ARN" \
  --attributes Key=deregistration_delay.timeout_seconds,Value=30 > /dev/null

ALB_ARN=$(aws elbv2 describe-load-balancers --names "$APP-alb" \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text 2> /dev/null) \
  || ALB_ARN=$(aws elbv2 create-load-balancer --name "$APP-alb" \
       --subnets "$SUBNET_A" "$SUBNET_B" --security-groups "$SG_ALB" \
       --query 'LoadBalancers[0].LoadBalancerArn' --output text)
if [ "$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --query 'length(Listeners)' --output text)" = "0" ]; then
  aws elbv2 create-listener --load-balancer-arn "$ALB_ARN" --protocol HTTP --port 80 \
    --default-actions Type=forward,TargetGroupArn="$TG_ARN" > /dev/null
fi
ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" \
  --query 'LoadBalancers[0].DNSName' --output text)

echo "==> 6. Task-Definition registrieren"
# task-definition.json liegt entweder im Repo (../) oder wurde neben das Skript hochgeladen
TASKDEF_SRC="$(dirname "$0")/../task-definition.json"
[ -f "$TASKDEF_SRC" ] || TASKDEF_SRC="$(dirname "$0")/task-definition.json"
TASKDEF_FILE=$(mktemp)
sed -e "s|__AWS_ACCOUNT_ID__|$ACCOUNT_ID|g" \
    -e "s|__AWS_REGION__|$REGION|g" \
    -e "s|__RDS_ENDPOINT__|$RDS_ENDPOINT|g" \
    -e "s|__DB_SECRET_ARN__|$DB_SECRET_ARN|g" \
    "$TASKDEF_SRC" > "$TASKDEF_FILE"
aws ecs register-task-definition --cli-input-json "file://$TASKDEF_FILE" > /dev/null
rm -f "$TASKDEF_FILE"

echo "==> 7. ECS-Service (startet mit 0 Tasks; die Pipeline pusht das erste Image und skaliert auf 2)"
SERVICE_ACTIVE=$(aws ecs describe-services --cluster "$APP-cluster" --services "$APP-service" \
  --query "length(services[?status=='ACTIVE'])" --output text)
if [ "$SERVICE_ACTIVE" = "0" ]; then
  aws ecs create-service \
    --cluster "$APP-cluster" \
    --service-name "$APP-service" \
    --task-definition "$APP" \
    --desired-count 0 \
    --launch-type FARGATE \
    --health-check-grace-period-seconds 120 \
    --deployment-configuration "deploymentCircuitBreaker={enable=true,rollback=true},maximumPercent=200,minimumHealthyPercent=50" \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_A,$SUBNET_B],securityGroups=[$SG_TASKS],assignPublicIp=ENABLED}" \
    --load-balancers "targetGroupArn=$TG_ARN,containerName=$APP,containerPort=8080" > /dev/null
fi

cat <<EOF

================================================================
Fertig. In GitHub unter Settings -> Secrets and variables -> Actions -> Variables eintragen:

  AWS_REGION     = $REGION
  RDS_ENDPOINT   = $RDS_ENDPOINT
  DB_SECRET_ARN  = $DB_SECRET_ARN
  ALB_DNS        = $ALB_DNS
  DEPLOY_ECS     = true

Danach einen Commit auf main pushen (oder den Workflow manuell starten).
App-URL nach dem Deploy: http://$ALB_DNS/actuator/info
================================================================
EOF

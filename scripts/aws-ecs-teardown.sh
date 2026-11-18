#!/usr/bin/env bash
# EX-03: Alle Ressourcen aus aws-ecs-setup.sh wieder löschen (Learner-Lab-Budget schonen).
# Ausführen in der AWS CloudShell:  bash aws-ecs-teardown.sh
set -uo pipefail

REGION="${AWS_REGION:-us-east-1}"
APP=biztrips-backend
export AWS_DEFAULT_REGION="$REGION"

echo "==> ECS-Service und Cluster"
aws ecs update-service --cluster "$APP-cluster" --service "$APP-service" --desired-count 0 > /dev/null 2>&1
aws ecs delete-service --cluster "$APP-cluster" --service "$APP-service" --force > /dev/null 2>&1
aws ecs delete-cluster --cluster "$APP-cluster" > /dev/null 2>&1

echo "==> Load Balancer und Target Group"
ALB_ARN=$(aws elbv2 describe-load-balancers --names "$APP-alb" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2> /dev/null)
[ -n "$ALB_ARN" ] && aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN"
aws elbv2 wait load-balancers-deleted --load-balancer-arns "$ALB_ARN" 2> /dev/null
TG_ARN=$(aws elbv2 describe-target-groups --names "$APP-tg" --query 'TargetGroups[0].TargetGroupArn' --output text 2> /dev/null)
[ -n "$TG_ARN" ] && aws elbv2 delete-target-group --target-group-arn "$TG_ARN"

echo "==> RDS, Secret, ECR, Logs"
aws rds delete-db-instance --db-instance-identifier "$APP-db" --skip-final-snapshot > /dev/null 2>&1
aws secretsmanager delete-secret --secret-id "$APP-db-password" --force-delete-without-recovery > /dev/null 2>&1
aws ecr delete-repository --repository-name "$APP" --force > /dev/null 2>&1
aws logs delete-log-group --log-group-name "/ecs/$APP" > /dev/null 2>&1

echo "==> Security Groups (nach dem Löschen von RDS)"
aws rds wait db-instance-deleted --db-instance-identifier "$APP-db" 2> /dev/null
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
for name in "$APP-db-sg" "$APP-tasks-sg" "$APP-alb-sg"; do
  id=$(aws ec2 describe-security-groups --filters Name=group-name,Values="$name" Name=vpc-id,Values="$VPC_ID" \
    --query 'SecurityGroups[0].GroupId' --output text)
  [ "$id" != "None" ] && aws ec2 delete-security-group --group-id "$id"
done

echo "Aufgeräumt."

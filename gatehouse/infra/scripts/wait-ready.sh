#!/usr/bin/env bash
set -euo pipefail

region="$1"
instance_id="$2"
target_group_arn="$3"

for _ in $(seq 1 60); do
  ping="$(
    aws --region "$region" ssm describe-instance-information \
      --filters "Key=InstanceIds,Values=$instance_id" \
      --query 'InstanceInformationList[0].PingStatus' \
      --output text 2>/dev/null || true
  )"
  if [ "$ping" = "Online" ]; then
    break
  fi
  sleep 5
done

if [ "${ping:-}" != "Online" ]; then
  echo "SSM did not become ready for $instance_id."
  exit 1
fi

parameters="$(cat <<'JSON'
{
  "commands": [
    "set -uo pipefail",
    "if ! cloud-init status --wait; then cloud-init status --long; tail -n 160 /var/log/cloud-init-output.log; exit 1; fi",
    "if ! test -f /opt/gatehouse-ready; then echo 'Gatehouse readiness marker is missing.'; docker ps -a || true; docker logs --tail=80 gatehouse || true; exit 1; fi",
    "if ! curl -fsS http://127.0.0.1:3000/health >/dev/null; then echo 'Gatehouse health check failed.'; docker logs --tail=80 gatehouse || true; exit 1; fi",
    "if ! docker inspect -f '{{.State.Running}}' gatehouse | grep -qx true; then echo 'Gatehouse container is not running.'; docker ps -a || true; exit 1; fi",
    "docker logs --tail=20 gatehouse"
  ]
}
JSON
)"

command_id="$(
  aws --region "$region" ssm send-command \
    --instance-ids "$instance_id" \
    --document-name "AWS-RunShellScript" \
    --parameters "$parameters" \
    --query 'Command.CommandId' \
    --output text
)"

for _ in $(seq 1 180); do
  status="$(
    aws --region "$region" ssm get-command-invocation \
      --command-id "$command_id" \
      --instance-id "$instance_id" \
      --query 'Status' \
      --output text 2>/dev/null || true
  )"
  case "$status" in
    Success|Failed|Cancelled|TimedOut)
      break
      ;;
  esac
  sleep 2
done

if [ "${status:-}" != "Success" ]; then
  aws --region "$region" ssm get-command-invocation \
    --command-id "$command_id" \
    --instance-id "$instance_id" \
    --query '{Status:Status,Stdout:StandardOutputContent,Stderr:StandardErrorContent}' \
    --output json
  exit 1
fi

for _ in $(seq 1 90); do
  target_health="$(
    aws --region "$region" elbv2 describe-target-health \
      --target-group-arn "$target_group_arn" \
      --targets "Id=$instance_id,Port=3000" \
      --query 'TargetHealthDescriptions[0].TargetHealth.State' \
      --output text 2>/dev/null || true
  )"
  if [ "$target_health" = "healthy" ]; then
    break
  fi
  sleep 5
done

if [ "${target_health:-}" != "healthy" ]; then
  echo "Gatehouse did not pass the load balancer health check."
  aws --region "$region" elbv2 describe-target-health \
    --target-group-arn "$target_group_arn" \
    --targets "Id=$instance_id,Port=3000" \
    --output json
  exit 1
fi

echo "Gatehouse passed its local and load balancer health checks."

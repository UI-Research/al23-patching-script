#!/bin/bash
# Retry patching for every instance in a Patch Group, a few at a time.
# Usage: ./patching_per_tag_group.sh <aws-profile> <patch-group> [max-concurrency] [max-errors]
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <aws-profile> <patch-group> [max-concurrency] [max-errors]" >&2
  exit 1
fi

PROFILE="$1"
PATCH_GROUP="$2"
MAX_CONCURRENCY="${3:-1}"
MAX_ERRORS="${4:-1}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

COMMAND_ID=$(aws ssm send-command \
  --profile "$PROFILE" \
  --targets "Key=tag:Patch Group,Values=$PATCH_GROUP" \
  --max-concurrency "$MAX_CONCURRENCY" \
  --max-errors "$MAX_ERRORS" \
  --document-name "AWS-RunPatchBaselineWithHooks" \
  --parameters "file://$SCRIPT_DIR/params.json" \
  --timeout-seconds 86400 \
  --comment "Retry patch - DeliveryTimedOut recovery" \
  --query "Command.CommandId" \
  --output text)

echo "Command ID: $COMMAND_ID"
echo "Check status with:"
echo "  aws ssm list-command-invocations --profile $PROFILE --command-id $COMMAND_ID --query \"CommandInvocations[].[InstanceId,Status]\" --output table"

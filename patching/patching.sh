#!/bin/bash
# Retry patching for one or more specific instances.
# Usage: ./patching.sh <aws-profile> <instance-id> [instance-id ...]
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <aws-profile> <instance-id> [instance-id ...]" >&2
  exit 1
fi

PROFILE="$1"
shift
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

COMMAND_ID=$(aws ssm send-command \
  --profile "$PROFILE" \
  --instance-ids "$@" \
  --document-name "AWS-RunPatchBaselineWithHooks" \
  --parameters "file://$SCRIPT_DIR/params.json" \
  --timeout-seconds 86400 \
  --comment "Retry patch - DeliveryTimedOut recovery" \
  --query "Command.CommandId" \
  --output text)

echo "Command ID: $COMMAND_ID"
echo "Check status with:"
echo "  aws ssm list-command-invocations --profile $PROFILE --command-id $COMMAND_ID --query \"CommandInvocations[].[InstanceId,Status]\" --output table"

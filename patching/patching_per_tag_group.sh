aws ssm send-command \
  --profile "your-aws-profile" \
  --targets "Key=tag:Patch Group,Values=linux-aws" \
  --document-name "AWS-RunShellScript" \
  --parameters file://params.json \
  --comment "Retry patch - DeliveryTimedOut recovery" \
  --debug 2>&1 | tail -50

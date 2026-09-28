aws ssm send-command \
  --profile "your-aws-profile" \
  --instance-ids "i-xxxxxx" \
  --document-name "AWS-RunShellScript" \
  --parameters file://params.json \
  --comment "Retry patch - DeliveryTimedOut recovery" \
  --debug 2>&1 | tail -50

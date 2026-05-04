---
name: tool-aws-cli
description: "AWS CLI patterns covering S3, Lambda, CloudFormation, IAM, EC2, common debugging, profile management, and SSO configuration"
---

## Profile and SSO Config

### ~/.aws/config

```ini
[default]
region = us-east-1
output = json

[profile dev]
sso_start_url = https://myorg.awsapps.com/start
sso_region = us-east-1
sso_account_id = 111111111111
sso_role_name = DeveloperAccess
region = us-east-1

[profile prod]
sso_start_url = https://myorg.awsapps.com/start
sso_region = us-east-1
sso_account_id = 222222222222
sso_role_name = AdministratorAccess
region = us-east-1
```

### SSO Login

```bash
aws sso login --profile dev
aws sts get-caller-identity --profile dev
export AWS_PROFILE=dev
```

### Profile Switching

```bash
aws configure list-profiles
aws sts get-caller-identity
export AWS_PROFILE=prod
```

## S3 Operations

| Command | Purpose |
|---------|---------|
| `aws s3 ls` | List buckets |
| `aws s3 ls s3://bucket/prefix/` | List objects |
| `aws s3 cp file.txt s3://bucket/` | Upload file |
| `aws s3 cp s3://bucket/file.txt .` | Download file |
| `aws s3 sync ./dist s3://bucket/` | Sync directory |
| `aws s3 rm s3://bucket/file.txt` | Delete object |
| `aws s3 rm s3://bucket/ --recursive` | Delete all objects |
| `aws s3 presign s3://bucket/file.txt --expires-in 3600` | Generate presigned URL |

### Sync with Exclusions

```bash
aws s3 sync ./build s3://my-bucket \
  --delete \
  --exclude "*.map" \
  --exclude ".DS_Store" \
  --cache-control "max-age=31536000"
```

### Large File Upload

```bash
aws s3 cp large-file.zip s3://bucket/ \
  --storage-class INTELLIGENT_TIERING \
  --expected-size 5368709120
```

## Lambda Management

```bash
aws lambda list-functions --query 'Functions[].FunctionName'

aws lambda invoke \
  --function-name my-function \
  --payload '{"key": "value"}' \
  output.json

aws lambda update-function-code \
  --function-name my-function \
  --zip-file fileb://function.zip

aws lambda get-function-configuration \
  --function-name my-function

aws lambda update-function-configuration \
  --function-name my-function \
  --timeout 30 \
  --memory-size 512

aws logs tail /aws/lambda/my-function --follow
```

### Invoke with Payload from File

```bash
aws lambda invoke \
  --function-name my-function \
  --payload file://event.json \
  --cli-binary-format raw-in-base64-out \
  response.json
```

## CloudFormation

```bash
aws cloudformation deploy \
  --template-file template.yaml \
  --stack-name my-stack \
  --parameter-overrides Env=prod \
  --capabilities CAPABILITY_IAM \
  --no-fail-on-empty-changeset

aws cloudformation describe-stacks --stack-name my-stack
aws cloudformation describe-stack-events --stack-name my-stack
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE
aws cloudformation delete-stack --stack-name my-stack

aws cloudformation validate-template --template-body file://template.yaml
```

### Wait for Stack

```bash
aws cloudformation wait stack-create-complete --stack-name my-stack
aws cloudformation wait stack-update-complete --stack-name my-stack
```

## IAM

```bash
aws iam get-user
aws iam list-users --query 'Users[].UserName'
aws iam list-roles --query 'Roles[].RoleName'
aws iam list-attached-role-policies --role-name my-role

aws iam create-role \
  --role-name lambda-exec \
  --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
  --role-name lambda-exec \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789:role/my-role \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::my-bucket/*
```

## EC2

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=production" \
  --query 'Reservations[].Instances[].{Id:InstanceId,Type:InstanceType,State:State.Name,IP:PublicIpAddress}'

aws ec2 start-instances --instance-ids i-1234567890
aws ec2 stop-instances --instance-ids i-1234567890

aws ec2 describe-security-groups --group-ids sg-12345
aws ssm start-session --target i-1234567890
```

## Common Debugging

| Issue | Command |
|-------|---------|
| Who am I? | `aws sts get-caller-identity` |
| Permission denied | `aws iam simulate-principal-policy ...` |
| Service quotas | `aws service-quotas list-service-quotas --service-code ec2` |
| CloudTrail events | `aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=RunInstances` |
| Check region | `aws configure get region` |

### Debug Mode

```bash
aws s3 ls --debug 2>&1 | head -50
aws --no-verify-ssl s3 ls  # skip TLS (testing only)
```

## Output Formatting

| Format | Flag | Use Case |
|--------|------|----------|
| JSON | `--output json` | Programmatic parsing |
| Table | `--output table` | Human reading |
| Text | `--output text` | Simple scripting |

### JMESPath Queries

```bash
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`].Value|[0],Id:InstanceId,State:State.Name}' \
  --output table

aws lambda list-functions \
  --query 'Functions[?Runtime==`nodejs20.x`].FunctionName'

aws s3api list-objects-v2 \
  --bucket my-bucket \
  --query 'Contents[?Size>`1000000`].{Key:Key,Size:Size}' \
  --output table
```

### Pagination

```bash
aws s3api list-objects-v2 \
  --bucket my-bucket \
  --max-items 100 \
  --starting-token $NEXT_TOKEN
```

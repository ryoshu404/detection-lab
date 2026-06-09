# State Backend Bootstrap

State locking uses S3-native locking (`use_lockfile = true` in `backend.tf`)

## Bucket configuration

| Setting | Value |
|---|---|
| Name | `ryoshu404-detection-lab-tfstate` |
| Region | `us-east-1` |
| Versioning | Enabled (required for safe S3-native locking) |
| Encryption | SSE-S3 (AES256) |
| Public access | Fully blocked (all four settings) |
| Lifecycle | Abort incomplete multipart uploads after 7 days |

## Recreate via CLI

Run with `AWS_PROFILE=detection-lab` set. JSON args shown in bash form; on PowerShell, run from CloudShell or pass JSON via `file://` to avoid quote-escaping.

```bash
aws s3api create-bucket --bucket ryoshu404-detection-lab-tfstate --region us-east-1

aws s3api put-bucket-versioning --bucket ryoshu404-detection-lab-tfstate \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption --bucket ryoshu404-detection-lab-tfstate \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'

aws s3api put-public-access-block --bucket ryoshu404-detection-lab-tfstate \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api put-bucket-lifecycle-configuration --bucket ryoshu404-detection-lab-tfstate \
  --lifecycle-configuration \
  '{"Rules":[{"ID":"abort-incomplete-multipart-uploads","Status":"Enabled","Filter":{},"AbortIncompleteMultipartUpload":{"DaysAfterInitiation":7}}]}'
```

## Notes

- Credentials supplied via `AWS_PROFILE` env var, not hardcoded in `backend.tf` (keeps the repo portable).
- The IAM identity needs `s3:ListBucket` plus `s3:GetObject` / `s3:PutObject` / `s3:DeleteObject` on the state and lock paths. `s3:DeleteObject` is required because Terraform removes the `.tflock` file when an operation completes.

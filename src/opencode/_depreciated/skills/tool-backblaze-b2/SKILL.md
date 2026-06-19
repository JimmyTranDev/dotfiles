---
name: tool-backblaze-b2
description: Backblaze B2 S3-compatible storage patterns covering presigned URLs, upload/download, bucket config, AWS SDK v3 usage, and B2-specific quirks
---

## AWS SDK v3 Configuration for B2

```ts
import { S3Client } from '@aws-sdk/client-s3';

const s3Client = new S3Client({
  endpoint: `https://s3.${B2_REGION}.backblazeb2.com`,
  region: B2_REGION,
  credentials: {
    accessKeyId: B2_APPLICATION_KEY_ID,
    secretAccessKey: B2_APPLICATION_KEY,
  },
});
```

## Presigned URLs

### Generate Upload URL (PUT)

```ts
import { PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

const command = new PutObjectCommand({
  Bucket: BUCKET_NAME,
  Key: `databases/${userId}/database.gz`,
  ContentType: 'application/gzip',
});

const presignedUrl = await getSignedUrl(s3Client, command, { expiresIn: 3600 });
```

### Generate Download URL (GET)

```ts
import { GetObjectCommand } from '@aws-sdk/client-s3';

const command = new GetObjectCommand({
  Bucket: BUCKET_NAME,
  Key: `databases/${userId}/database.gz`,
});

const presignedUrl = await getSignedUrl(s3Client, command, { expiresIn: 3600 });
```

### Client-Side Upload

```ts
const xhr = new XMLHttpRequest();
xhr.open('PUT', presignedUrl);
xhr.setRequestHeader('Content-Type', 'application/gzip');
xhr.upload.onprogress = (e) => { /* progress tracking */ };
xhr.send(compressedData);
```

## Common Operations

### Check if Object Exists

```ts
import { HeadObjectCommand } from '@aws-sdk/client-s3';

try {
  await s3Client.send(new HeadObjectCommand({ Bucket, Key }));
  return true;
} catch (error) {
  if (error.name === 'NotFound') { return false; }
  throw error;
}
```

### Delete Object

```ts
import { DeleteObjectCommand } from '@aws-sdk/client-s3';
await s3Client.send(new DeleteObjectCommand({ Bucket, Key }));
```

### List Objects

```ts
import { ListObjectsV2Command } from '@aws-sdk/client-s3';

const response = await s3Client.send(new ListObjectsV2Command({
  Bucket: BUCKET_NAME,
  Prefix: `databases/${userId}/`,
}));
```

## B2-Specific Quirks

| Feature | B2 Behavior |
|---------|-------------|
| Presigned POST | NOT supported — use PUT only |
| Endpoint format | `s3.{region}.backblazeb2.com` |
| Region | Usually `us-west-004` or similar |
| Max file size | 5GB single upload, 10TB multipart |
| Presigned URL expiry | Max 7 days (604800 seconds) |
| Content-Type | Must be set on upload; not changeable after |
| Versioning | Supported but costs more (each version stored) |
| Lifecycle rules | Via B2 console/API, not S3 lifecycle XML |
| CORS | Must configure via B2 console or b2 CLI |

## Bucket Configuration

### CORS (required for browser/mobile uploads)

Configure via B2 CLI or console:
```json
[{
  "corsRuleName": "allowUploads",
  "allowedOrigins": ["*"],
  "allowedOperations": ["s3_put", "s3_get", "s3_head"],
  "allowedHeaders": ["*"],
  "maxAgeSeconds": 3600
}]
```

### Lifecycle Rules

- Set via B2 console: "Keep only last version" to save costs
- Auto-delete incomplete multipart uploads after X days

## Key Naming Patterns

```
databases/{userId}/database.gz          # User's synced database
databases/{userId}/metadata.json        # Database metadata
databases/{userId}/backups/{timestamp}  # Versioned backups
```

## Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `403 Forbidden` | Expired presigned URL or wrong key | Regenerate URL |
| `RequestTimeout` | Upload too slow | Increase timeout, check network |
| `ServiceUnavailable` | B2 rate limit | Exponential backoff |
| `InvalidArgument` | Missing Content-Type on PUT | Set header to match presigned command |

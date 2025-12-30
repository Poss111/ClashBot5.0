import { S3Client, PutObjectCommand, ListObjectsV2Command, DeleteObjectsCommand } from '@aws-sdk/client-s3';
import { readdirSync, statSync, readFileSync } from 'fs';
import { join, relative } from 'path';
import { lookup as mimeLookup } from 'mime-types';
import { gzipSync } from 'zlib';

const bucket = process.env.BUCKET_NAME;
const sourceDir = process.env.SOURCE_DIR ?? join(__dirname, '..', '..', 'frontend', 'build', 'web');
const region = process.env.AWS_REGION ?? process.env.AWS_DEFAULT_REGION ?? 'us-east-1';

if (!bucket) {
  console.error('BUCKET_NAME env var is required');
  process.exit(1);
}

const s3 = new S3Client({ region, profile: 'PowerUserAccess-816923827429' });

async function listAllKeys(): Promise<string[]> {
  const keys: string[] = [];
  let token: string | undefined;
  do {
    const resp = await s3.send(new ListObjectsV2Command({ Bucket: bucket, ContinuationToken: token }));
    resp.Contents?.forEach((o) => o.Key && keys.push(o.Key));
    token = resp.NextContinuationToken;
  } while (token);
  return keys;
}

async function deleteAll(keys: string[]) {
  const chunks: string[][] = [];
  for (let i = 0; i < keys.length; i += 1000) {
    chunks.push(keys.slice(i, i + 1000));
  }
  for (const chunk of chunks) {
    await s3.send(
      new DeleteObjectsCommand({
        Bucket: bucket,
        Delete: { Objects: chunk.map((Key) => ({ Key })) }
      })
    );
  }
}

function walk(dir: string): string[] {
  const entries = readdirSync(dir);
  const files: string[] = [];
  for (const entry of entries) {
    const full = join(dir, entry);
    const st = statSync(full);
    if (st.isDirectory()) {
      files.push(...walk(full));
    } else {
      files.push(full);
    }
  }
  return files;
}

async function main() {
  console.log(`Uploading from ${sourceDir} to s3://${bucket}`);
  const existing = await listAllKeys();
  if (existing.length) {
    console.log(`Clearing ${existing.length} existing objects...`);
    await deleteAll(existing);
  }

  const files = walk(sourceDir);
  for (const file of files) {
    const key = relative(sourceDir, file).replace(/\\/g, '/');
    const body = readFileSync(file);
    const contentType = mimeLookup(file) || undefined;
    const gzBody = gzipSync(body);
    const cacheControl = key === 'index.html' ? 'no-cache, no-store, must-revalidate' : 'public, max-age=31536000';
    await s3.send(
      new PutObjectCommand({
        Bucket: bucket,
        Key: key,
        Body: gzBody,
        ContentType: contentType,
        ContentEncoding: 'gzip',
        CacheControl: cacheControl
      })
    );
    console.log(`Uploaded ${key}`);
  }
  console.log('Done.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});


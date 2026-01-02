import { APIGatewayTokenAuthorizerEvent, APIGatewayRequestAuthorizerEvent } from 'aws-lambda';
import { KMSClient, GetPublicKeyCommand } from '@aws-sdk/client-kms';
import { createVerify } from 'crypto';
import { logInfo } from '../shared/logger';

const kmsClient = new KMSClient({});
let cachedPublicKeyPem: string | null = null;

async function getPublicKey(): Promise<string> {
  if (cachedPublicKeyPem) return cachedPublicKeyPem;
  const keyId = process.env.KMS_JWT_KEY_ID;
  if (!keyId) throw new Error('KMS_JWT_KEY_ID not set');
  const resp = await kmsClient.send(new GetPublicKeyCommand({ KeyId: keyId }));
  const der = Buffer.from(resp.PublicKey as Uint8Array);
  const pem = `-----BEGIN PUBLIC KEY-----\n${der.toString('base64').match(/.{1,64}/g)?.join('\n')}\n-----END PUBLIC KEY-----\n`;
  cachedPublicKeyPem = pem;
  return pem;
}

const allowPolicy = (principalId: string, resource: string) => ({
  principalId,
  policyDocument: {
    Version: '2012-10-17',
    Statement: [
      {
        Action: 'execute-api:Invoke',
        Effect: 'Allow',
        Resource: resource
      }
    ]
  },
  context: {}
});

const denyPolicy = (principalId: string, resource: string) => ({
  principalId,
  policyDocument: {
    Version: '2012-10-17',
    Statement: [
      {
        Action: 'execute-api:Invoke',
        Effect: 'Deny',
        Resource: resource
      }
    ]
  },
  context: {}
});

export const handler = async (event: APIGatewayTokenAuthorizerEvent | APIGatewayRequestAuthorizerEvent) => {
  let tokenString: string | undefined;
  logInfo('authValidator.received', { event });
  if (event.type === 'TOKEN') {
    logInfo('authValidator.token', { event });
    tokenString = event.authorizationToken;
  } else if (event.type === 'REQUEST') {
    logInfo('authValidator.request', { event });
    tokenString = event.headers?.authorization || (event.queryStringParameters as any)?.auth;
  }

  logInfo('authValidator.tokenString', { tokenString });
  const resource = event.methodArn;

  if (!tokenString?.startsWith('Bearer ')) {
    return denyPolicy('unauthorized', resource);
  }

  const token = tokenString.replace(/^Bearer\s+/i, '');
  try {
    const [headerB64, payloadB64, sigB64] = token.split('.');
    if (!headerB64 || !payloadB64 || !sigB64) {
      return denyPolicy('unauthorized', resource);
    }
    const publicKey = await getPublicKey();
    const verifier = createVerify('RSA-SHA256');
    verifier.update(`${headerB64}.${payloadB64}`);
    verifier.end();
    const signature = Buffer.from(sigB64.replace(/-/g, '+').replace(/_/g, '/'), 'base64');
    const isValid = verifier.verify(publicKey, signature);
    if (!isValid) {
      return denyPolicy('unauthorized', resource);
    }
    const payloadJson = Buffer.from(payloadB64, 'base64').toString('utf8');
    const payload = JSON.parse(payloadJson);
    const principal = (payload.sub as string) || 'user';
    return allowPolicy(principal, resource);
  } catch (err) {
    console.error('JWT verify failed', err);
    return denyPolicy('unauthorized', resource);
  }
};


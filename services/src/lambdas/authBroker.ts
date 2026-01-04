import { PutCommand, GetCommand } from '@aws-sdk/lib-dynamodb';
import { KMSClient, SignCommand } from '@aws-sdk/client-kms';
import { docClient } from '../shared/db';
import { jsonResponse } from '../shared/http';
import { logInfo, logError } from '../shared/logger';
import { createSign } from 'crypto';

const GOOGLE_TOKENINFO = 'https://oauth2.googleapis.com/tokeninfo';
const GOOGLE_USERINFO = 'https://www.googleapis.com/oauth2/v3/userinfo';
const ADMIN_EMAIL = 'rixxroid@gmail.com';

const kmsClient = new KMSClient({});

const b64url = (buf: Buffer) =>
  buf
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');

async function signJwt(payload: Record<string, any>): Promise<string> {
  const kid = process.env.KMS_JWT_KEY_ID;
  if (!kid) throw new Error('KMS_JWT_KEY_ID not set');

  const header = {
    alg: 'RS256',
    typ: 'JWT',
    kid
  };

  const encHeader = b64url(Buffer.from(JSON.stringify(header)));
  const encPayload = b64url(Buffer.from(JSON.stringify(payload)));
  const signingInput = `${encHeader}.${encPayload}`;

  const signResp = await kmsClient.send(
    new SignCommand({
      KeyId: kid,
      Message: Buffer.from(signingInput),
      MessageType: 'RAW',
      SigningAlgorithm: 'RSASSA_PKCS1_V1_5_SHA_256'
    })
  );

  const signature = b64url(Buffer.from(signResp.Signature as Uint8Array));
  return `${signingInput}.${signature}`;
}

export const handler = async (event: any) => {
  try {
    logInfo('authBroker.start', {
      hasBody: !!event?.body,
      hasAuthHeader: !!(event?.headers?.authorization || event?.headers?.Authorization),
      requestId: event?.requestContext?.requestId
    });
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body ?? {};
    const idToken =
      body.idToken ||
      body.id_token ||
      event.headers?.authorization?.replace(/^Bearer\s+/i, '') ||
      event.headers?.Authorization?.replace(/^Bearer\s+/i, '');
    const accessToken = body.accessToken || body.access_token;
    if (!idToken && !accessToken) {
      logError('authBroker.missingToken', { bodyKeys: Object.keys(body || {}) });
      return jsonResponse(400, { message: 'idToken or accessToken required' });
    }

    let email: string | undefined;
    let name: string | undefined;
    let picture: string | undefined;
    let emailVerified = false;

    if (idToken) {
      const tokenInfoUrl = `${GOOGLE_TOKENINFO}?id_token=${encodeURIComponent(idToken)}`;
      logInfo('authBroker.verifyIdToken', { url: tokenInfoUrl });
      const resp = await fetch(tokenInfoUrl);
      if (!resp.ok) {
        const text = await resp.text();
        logError('authBroker.googleValidationFailed', { status: resp.status, text });
        return jsonResponse(401, { message: 'Invalid Google token' });
      }
      const info = (await resp.json()) as any;
      email = info.email as string | undefined;
      name = info.name as string | undefined;
      picture = info.picture as string | undefined;
      emailVerified = info.email_verified === 'true' || info.email_verified === true;
    } else if (accessToken) {
      logInfo('authBroker.verifyAccessToken', { url: GOOGLE_USERINFO });
      const resp = await fetch(GOOGLE_USERINFO, {
        headers: { Authorization: `Bearer ${accessToken}` }
      });
      if (!resp.ok) {
        const text = await resp.text();
        logError('authBroker.googleUserInfoFailed', { status: resp.status, text });
        return jsonResponse(401, { message: 'Invalid Google token' });
      }
      const info = (await resp.json()) as any;
      email = info.email as string | undefined;
      name = info.name as string | undefined;
      picture = info.picture as string | undefined;
      emailVerified = info.email_verified === true;
    }

    if (!email || !emailVerified) {
      logError('authBroker.emailNotVerified', { email, emailVerified });
      return jsonResponse(401, { message: 'Email not verified or missing' });
    }

    const role = email.toLowerCase() === ADMIN_EMAIL ? 'ADMIN' : 'GENERAL_USER';
    const now = Math.floor(Date.now() / 1000);
    const exp = now + 60 * 60 * 12; // 12 hours
    const token = await signJwt({
      sub: email,
      email,
      name,
      picture,
      role,
      iat: now,
      exp
    });

    const existing = await docClient.send(
      new GetCommand({
        TableName: process.env.USERS_TABLE,
        Key: { userId: email }
      })
    );
    const wasNewUser = !existing.Item;
    const existingDisplayName = (existing.Item as any)?.displayName as string | undefined;
    const timestamp = new Date().toISOString();

    await docClient.send(
      new PutCommand({
        TableName: process.env.USERS_TABLE,
        Item: {
          userId: email,
          email,
          role,
          provider: 'google',
          emailVerified,
          name,
          picture,
          displayName: existingDisplayName,
          lastLogin: timestamp,
          createdAt: (existing.Item as any)?.createdAt ?? timestamp
        }
      })
    );

    logInfo('authBroker.issued', { email, role, wasNewUser });
    return jsonResponse(200, { token, role, exp, isNewUser: wasNewUser, hasDisplayName: !!existingDisplayName, displayName: existingDisplayName });
  } catch (err) {
    logError('authBroker.failed', { error: String(err), stack: (err as Error)?.stack });
    return jsonResponse(500, { message: 'Authentication failed' });
  }
};


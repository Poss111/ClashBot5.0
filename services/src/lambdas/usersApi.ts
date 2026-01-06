import { GetCommand, PutCommand } from '@aws-sdk/lib-dynamodb';
import { docClient } from '../shared/db';
import { jsonResponse } from '../shared/http';
import { logError, logInfo } from '../shared/logger';
import { withApiMetrics } from '../shared/observability';

type UserRecord = {
  userId: string;
  email?: string;
  displayName?: string;
  name?: string;
  picture?: string;
  role?: string;
  provider?: string;
  createdAt?: string;
  lastLogin?: string;
};

const USERS_TABLE = process.env.USERS_TABLE;

const sanitizeDisplayName = (value: string | undefined): string | null => {
  const trimmed = (value ?? '').trim();
  if (!trimmed) return null;
  if (trimmed.length < 3 || trimmed.length > 32) return null;
  if (trimmed.includes('@')) return null; // discourage emails as display names
  // Allow letters, numbers, spaces and a few safe separators.
  const valid = /^[a-zA-Z0-9 _.'-]+$/.test(trimmed);
  return valid ? trimmed : null;
};

const baseHandler = async (event: any) => {
  if (!USERS_TABLE) {
    logError('usersApi.misconfigured', { USERS_TABLE });
    return jsonResponse(500, { message: 'Users table not configured' });
  }

  const userId = event.requestContext?.authorizer?.principalId as string | undefined;
  const method = event.httpMethod as string;
  const path: string = event.path || event.resource || '';

  if (!userId) {
    return jsonResponse(401, { message: 'Unauthorized' });
  }

  try {
    // GET /users/me
    if (method === 'GET') {
      const existing = await docClient.send(
        new GetCommand({
          TableName: USERS_TABLE,
          Key: { userId }
        })
      );
      const item = (existing.Item as UserRecord | undefined) ?? { userId };
      const response = {
        userId: item.userId,
        email: item.email ?? item.userId,
        displayName: item.displayName ?? item.name ?? null,
        name: item.name ?? null,
        picture: item.picture ?? null,
        role: item.role ?? null,
        createdAt: item.createdAt ?? null,
        lastLogin: item.lastLogin ?? null
      };
      logInfo('usersApi.me', { userId });
      return jsonResponse(200, response);
    }

    // PUT /users/me/display-name
    if (method === 'PUT' && path.includes('/display-name')) {
      const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
      const desired = sanitizeDisplayName(body?.displayName as string | undefined);
      if (!desired) {
        return jsonResponse(400, { message: 'displayName must be 3-32 characters and not an email' });
      }

      const existing = await docClient.send(
        new GetCommand({
          TableName: USERS_TABLE,
          Key: { userId }
        })
      );
      const item = (existing.Item as UserRecord | undefined) ?? { userId };
      const nowIso = new Date().toISOString();

      await docClient.send(
        new PutCommand({
          TableName: USERS_TABLE,
          Item: {
            ...item,
            userId,
            email: item.email ?? item.userId,
            displayName: desired,
            lastLogin: item.lastLogin ?? nowIso,
            createdAt: item.createdAt ?? nowIso
          }
        })
      );

      logInfo('usersApi.displayNameUpdated', { userId });
      return jsonResponse(200, {
        userId,
        email: item.email ?? userId,
        displayName: desired,
        name: item.name ?? null,
        picture: item.picture ?? null,
        role: item.role ?? null,
        createdAt: item.createdAt ?? nowIso,
        lastLogin: item.lastLogin ?? nowIso
      });
    }

    return jsonResponse(405, { message: 'Method not allowed' });
  } catch (err) {
    logError('usersApi.failed', { error: String(err), stack: (err as Error)?.stack });
    return jsonResponse(500, { message: 'Failed to handle user request' });
  }
};

export const handler = withApiMetrics({
  defaultRoute: '/users/me',
  feature: (event) => ((event as any)?.httpMethod === 'GET' ? 'user.me' : 'user.displayName')
})(baseHandler);



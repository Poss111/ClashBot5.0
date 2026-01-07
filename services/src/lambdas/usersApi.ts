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
  favoriteChampions?: Record<string, string[]>;
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

  const normalizeRole = (value: string | undefined): string | null => {
    if (!value) return null;
    const trimmed = value.trim();
    if (!trimmed) return null;
    const lower = trimmed.toLowerCase();
    const allowed = new Set(['top', 'jungle', 'mid', 'bot', 'support']);
    if (!allowed.has(lower)) return null;
    return lower[0].toUpperCase() + lower.substring(1);
  };

  const sanitizeFavoriteChampions = (value: any): Record<string, string[]> | null => {
    if (value == null || typeof value !== 'object') return null;
    const result: Record<string, string[]> = {};
    for (const [role, champ] of Object.entries(value)) {
      const normalizedRole = normalizeRole(role);
      if (!normalizedRole) continue;
      const values: string[] = Array.isArray(champ)
        ? (champ as any[]).map((c) => `${c ?? ''}`.trim()).filter((c) => c.length > 0)
        : typeof champ === 'string'
            ? [`${champ}`.trim()]
            : [];
      const unique = Array.from(new Set(values)).slice(0, 3);
      if (unique.length > 0) {
        result[normalizedRole] = unique;
      }
    }
    return result;
  };

  const coerceFavoriteChampions = (value: any): Record<string, string[]> | null => {
    if (value == null || typeof value !== 'object') return null;
    const result: Record<string, string[]> = {};
    for (const [role, champ] of Object.entries(value)) {
      const normalizedRole = normalizeRole(role);
      if (!normalizedRole) continue;
      const arr = Array.isArray(champ) ? champ : [champ];
      const cleaned = arr.map((c) => `${c ?? ''}`.trim()).filter((c) => c.length > 0);
      if (cleaned.length > 0) {
        result[normalizedRole] = Array.from(new Set(cleaned)).slice(0, 3);
      }
    }
    return Object.keys(result).length === 0 ? null : result;
  };

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
    const favoriteChampions = coerceFavoriteChampions(item.favoriteChampions) ?? item.favoriteChampions ?? null;
      const response = {
        userId: item.userId,
        email: item.email ?? item.userId,
        displayName: item.displayName ?? item.name ?? null,
        name: item.name ?? null,
        picture: item.picture ?? null,
        role: item.role ?? null,
      favoriteChampions,
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
      const favoriteChampions = coerceFavoriteChampions(item.favoriteChampions) ?? item.favoriteChampions ?? null;
      return jsonResponse(200, {
        userId,
        email: item.email ?? userId,
        displayName: desired,
        name: item.name ?? null,
        picture: item.picture ?? null,
        role: item.role ?? null,
        favoriteChampions,
        createdAt: item.createdAt ?? nowIso,
        lastLogin: item.lastLogin ?? nowIso
      });
    }

    // PUT /users/me/favorite-champions
    if (method === 'PUT' && path.includes('/favorite-champions')) {
      const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
      const desired = sanitizeFavoriteChampions(body?.favoriteChampions ?? body);
      if (!desired || Object.keys(desired).length === 0) {
        return jsonResponse(400, { message: 'favoriteChampions must include at least one valid role/champion' });
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
            favoriteChampions: desired,
            lastLogin: item.lastLogin ?? nowIso,
            createdAt: item.createdAt ?? nowIso
          }
        })
      );

      logInfo('usersApi.favoriteChampionsUpdated', { userId, roles: Object.keys(desired) });
      return jsonResponse(200, {
        userId,
        email: item.email ?? userId,
        displayName: item.displayName ?? item.name ?? null,
        name: item.name ?? null,
        picture: item.picture ?? null,
        role: item.role ?? null,
        favoriteChampions: desired,
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
  feature: (event) => {
    const method = (event as any)?.httpMethod;
    const path: string = (event as any)?.path || (event as any)?.resource || '';
    if (method === 'GET') return 'user.me';
    if (method === 'PUT' && path.includes('/display-name')) return 'user.displayName';
    if (method === 'PUT' && path.includes('/favorite-champions')) return 'user.favoriteChampions';
    return undefined;
  }
})(baseHandler);



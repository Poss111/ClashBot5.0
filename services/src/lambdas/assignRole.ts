import { UpdateCommand, GetCommand, QueryCommand, PutCommand, DeleteCommand } from '@aws-sdk/lib-dynamodb';
import { createMetricsLogger, Unit } from 'aws-embedded-metrics';
import { docClient } from '../shared/db';
import { jsonResponse } from '../shared/http';
import { logError, logInfo } from '../shared/logger';
import { withApiMetrics } from '../shared/observability';

const USERS_TABLE = process.env.USERS_TABLE;
const METRIC_NAMESPACE = process.env.METRICS_NAMESPACE ?? 'ClashOps';
const SERVICE_NAME = process.env.SERVICE_NAME ?? 'clash-api';
const ENV_NAME = process.env.ENV_NAME ?? 'prod';

const maskIdentifier = (value: string | undefined): string | null => {
  if (!value) return null;
  let hash = 0;
  for (let i = 0; i < value.length; i++) {
    hash = (hash * 31 + value.charCodeAt(i)) >>> 0;
  }
  const code = hash.toString(16).padStart(6, '0').slice(0, 6);
  return `Player-${code}`;
};

const lookupDisplayName = async (userId: string | undefined): Promise<string | null> => {
  if (!userId || !USERS_TABLE) return null;
  const result = await docClient.send(
    new GetCommand({
      TableName: USERS_TABLE,
      Key: { userId }
    })
  );
  const item = result.Item as any;
  return (item?.displayName as string) ?? (item?.name as string) ?? null;
};

const baseHandler = async (event: any) => {
  const tournamentId = event.pathParameters?.id;
  const teamId = event.pathParameters?.teamId;
  const role = event.pathParameters?.role;
  const user = event.requestContext?.authorizer?.principalId;
  const method = event.httpMethod;
  const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
  const requestedStatus =
    body?.status === 'maybe' || body?.status === 'all_in' ? (body.status as 'maybe' | 'all_in') : undefined;

  if (!tournamentId || !teamId || !role) {
    return jsonResponse(400, { message: 'tournamentId, teamId, and role are required' });
  }
  if (!user) {
    return jsonResponse(401, { message: 'Unauthorized' });
  }

  try {
    const key = { tournamentId, teamId };
    const existing = await docClient.send(
      new GetCommand({
        TableName: process.env.TEAMS_TABLE,
        Key: key
      })
    );
    const item = existing.Item as any;
    if (!item) {
      return jsonResponse(404, { message: 'team not found' });
    }

    const isCaptain = item.captainSummoner === user || item.createdBy === user;
    const members = item.members || {};
    const memberStatuses: Record<string, 'maybe' | 'all_in'> = item.memberStatuses || {};
    const current = members[role];

    // Rule: user cannot be on multiple teams in the same tournament (check membership table).
    const membershipCheck = await docClient.send(
      new QueryCommand({
        TableName: process.env.USER_TEAMS_TABLE,
        KeyConditionExpression: 'userId = :uid AND begins_with(teamKey, :tk)',
        ExpressionAttributeValues: {
          ':uid': user,
          ':tk': `${tournamentId}#`
        }
      })
    );
    const inAnotherTeam =
      membershipCheck.Items?.some((m: any) => m.teamId !== teamId) ?? false;
    if (inAnotherTeam) {
      return jsonResponse(400, { message: 'user already belongs to another team in this tournament' });
    }

    // Allow swapping roles within the same team: clear the user's old role if targeting a new slot.
    const existingRoleForUser = Object.entries(members).find(([, v]) => v === user)?.[0];
    if (existingRoleForUser && existingRoleForUser !== role) {
      if (current && current !== 'Open' && current !== user) {
        return jsonResponse(400, { message: 'role is already filled' });
      }
      members[existingRoleForUser] = 'Open';
      delete memberStatuses[existingRoleForUser];
      await docClient.send(
        new DeleteCommand({
          TableName: process.env.USER_TEAMS_TABLE,
          Key: {
            userId: user,
            teamKey: `${tournamentId}#${teamId}`
          }
        })
      );
    }

    if (method === 'DELETE') {
      if (!current || current === 'Open') {
        return jsonResponse(404, { message: 'role is already open' });
      }
      const normalizedCurrent = typeof current === 'string' ? current.toLowerCase() : `${current}`.toLowerCase();
      const normalizedUser = typeof user === 'string' ? user.toLowerCase() : `${user}`.toLowerCase();
      const isSelfRemoval = normalizedCurrent === normalizedUser;

      // Allow the occupant to leave; otherwise require captain.
      if (!isSelfRemoval && !isCaptain) {
        return jsonResponse(403, { message: 'only the captain can remove members' });
      }

      members[role] = 'Open';
      delete memberStatuses[role];

      await docClient.send(
        new DeleteCommand({
          TableName: process.env.USER_TEAMS_TABLE,
          Key: {
            userId: current,
            teamKey: `${tournamentId}#${teamId}`
          }
        })
      );

      await docClient.send(
        new UpdateCommand({
          TableName: process.env.TEAMS_TABLE,
          Key: key,
          UpdateExpression: 'SET #members = :members, #memberStatuses = :memberStatuses',
          ExpressionAttributeNames: { '#members': 'members', '#memberStatuses': 'memberStatuses' },
          ExpressionAttributeValues: { ':members': members, ':memberStatuses': memberStatuses }
        })
      );

      logInfo('assignRole.removed', { tournamentId, teamId, role, removed: current, by: user });
      await recordMembershipMetric('leave', { tournamentId, teamId });
      const removedName = await lookupDisplayName(current);
      return jsonResponse(200, {
        tournamentId,
        teamId,
        role,
        removed: current,
        removedDisplayName: removedName ?? maskIdentifier(current),
        status: memberStatuses[role]
      });
    }

    if (current && current !== 'Open' && current !== user) {
      return jsonResponse(400, { message: 'role is already filled' });
    }

    members[role] = user;
    if (requestedStatus) {
      memberStatuses[role] = requestedStatus;
    } else if (!memberStatuses[role]) {
      memberStatuses[role] = 'all_in';
    }

    await docClient.send(
      new UpdateCommand({
        TableName: process.env.TEAMS_TABLE,
        Key: key,
        UpdateExpression: 'SET #members = :members, #memberStatuses = :memberStatuses',
        ExpressionAttributeNames: { '#members': 'members', '#memberStatuses': 'memberStatuses' },
        ExpressionAttributeValues: { ':members': members, ':memberStatuses': memberStatuses }
      })
    );

    await docClient.send(
      new PutCommand({
        TableName: process.env.USER_TEAMS_TABLE,
        Item: {
          userId: user,
          teamKey: `${tournamentId}#${teamId}`,
          teamId,
          tournamentId,
          role,
          isCaptain: item.captainSummoner === user,
          updatedAt: new Date().toISOString()
        }
      })
    );

    const playerDisplayName = (await lookupDisplayName(user)) ?? maskIdentifier(user);

    logInfo('assignRole.assigned', { tournamentId, teamId, role, user });
    await recordMembershipMetric('join', { tournamentId, teamId });
    return jsonResponse(200, {
      tournamentId,
      teamId,
      role,
      playerId: user,
      playerDisplayName,
      status: memberStatuses[role]
    });
  } catch (err) {
    logError('assignRole.failed', { error: String(err) });
    return jsonResponse(500, { message: 'failed to assign role' });
  }
};

export const handler = withApiMetrics({
  defaultRoute: '/tournaments/{id}/teams/{teamId}/roles/{role}',
  feature: (event) => ((event as any)?.httpMethod === 'DELETE' ? 'roles.remove' : 'roles.assign')
})(baseHandler);

const recordMembershipMetric = async (
  action: 'join' | 'leave',
  { tournamentId, teamId }: { tournamentId: string; teamId: string }
) => {
  const metrics = createMetricsLogger();
  metrics.setNamespace(METRIC_NAMESPACE);
  metrics.putDimensions({ Service: SERVICE_NAME, Env: ENV_NAME });
  metrics.setProperty('tournamentId', tournamentId);
  metrics.setProperty('teamId', teamId);
  metrics.putMetric(action === 'join' ? 'TeamJoins' : 'TeamLeaves', 1, Unit.Count);
  await metrics.flush();
};


import { UpdateCommand, GetCommand, QueryCommand, PutCommand, DeleteCommand } from '@aws-sdk/lib-dynamodb';
import { docClient } from '../shared/db';
import { jsonResponse } from '../shared/http';
import { logError, logInfo } from '../shared/logger';

const USERS_TABLE = process.env.USERS_TABLE;

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

export const handler = async (event: any) => {
  const tournamentId = event.pathParameters?.id;
  const teamId = event.pathParameters?.teamId;
  const role = event.pathParameters?.role;
  const user = event.requestContext?.authorizer?.principalId;
  const method = event.httpMethod;

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
      if (!isCaptain) {
        return jsonResponse(403, { message: 'only the captain can remove members' });
      }
      if (!current || current === 'Open') {
        return jsonResponse(404, { message: 'role is already open' });
      }
      if (current === user) {
        return jsonResponse(400, { message: 'captain cannot kick themselves' });
      }

      members[role] = 'Open';

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
          UpdateExpression: 'SET #members = :members',
          ExpressionAttributeNames: { '#members': 'members' },
          ExpressionAttributeValues: { ':members': members }
        })
      );

      logInfo('assignRole.removed', { tournamentId, teamId, role, removed: current, by: user });
      const removedName = await lookupDisplayName(current);
      return jsonResponse(200, {
        tournamentId,
        teamId,
        role,
        removed: current,
        removedDisplayName: removedName ?? maskIdentifier(current)
      });
    }

    if (current && current !== 'Open') {
      return jsonResponse(400, { message: 'role is already filled' });
    }

    members[role] = user;

    await docClient.send(
      new UpdateCommand({
        TableName: process.env.TEAMS_TABLE,
        Key: key,
        UpdateExpression: 'SET #members = :members',
        ExpressionAttributeNames: { '#members': 'members' },
        ExpressionAttributeValues: { ':members': members }
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
    return jsonResponse(200, { tournamentId, teamId, role, playerId: user, playerDisplayName });
  } catch (err) {
    logError('assignRole.failed', { error: String(err) });
    return jsonResponse(500, { message: 'failed to assign role' });
  }
};


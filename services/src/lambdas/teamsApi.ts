import { QueryCommand, PutCommand, GetCommand, DeleteCommand } from '@aws-sdk/lib-dynamodb';
import { randomUUID } from 'crypto';
import { docClient } from '../shared/db';
import { jsonResponse } from '../shared/http';
import { logInfo } from '../shared/logger';

export const handler = async (event: any) => {
  const tournamentId = event.pathParameters?.id;
  const teamIdParam = event.pathParameters?.teamId;
  const method = event.httpMethod;
  const user = event.requestContext?.authorizer?.principalId;
  if (!tournamentId) {
    return jsonResponse(400, { message: 'tournamentId required' });
  }

  if (method === 'GET' && !teamIdParam) {
    const teams = await docClient.send(
      new QueryCommand({
        TableName: process.env.TEAMS_TABLE,
        IndexName: 'teams-by-tournament',
        KeyConditionExpression: 'tournamentId = :tid',
        ExpressionAttributeValues: { ':tid': tournamentId }
      })
    );

    logInfo('teamsApi.list', { tournamentId, count: teams.Count ?? 0 });
    return jsonResponse(200, { items: teams.Items ?? [] });
  }

  if (method === 'POST' && !teamIdParam) {
    if (!user) {
      return jsonResponse(401, { message: 'Unauthorized' });
    }
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const displayName =
      (body?.displayName as string | undefined)?.trim() ||
      (body?.teamName as string | undefined)?.trim();
    const role = (body?.role as string | undefined)?.trim();
    if (!displayName) {
      return jsonResponse(400, { message: 'displayName is required' });
    }
    if (!role) {
      return jsonResponse(400, { message: 'role is required' });
    }

    // Enforce: user cannot already be on a team (any role) in this tournament.
    const existingTeams = await docClient.send(
      new QueryCommand({
        TableName: process.env.TEAMS_TABLE,
        IndexName: 'teams-by-tournament',
        KeyConditionExpression: 'tournamentId = :tid',
        ExpressionAttributeValues: { ':tid': tournamentId }
      })
    );
    const inAnotherTeam =
      existingTeams.Items?.some((t: any) => {
        const mm = t.members || {};
        return Object.values(mm).some((v) => v === user);
      }) ?? false;
    if (inAnotherTeam) {
      return jsonResponse(400, { message: 'user already belongs to a team for this tournament; disband first' });
    }

    const members = (body?.members && typeof body.members === 'object') ? body.members : {};
    members[role] = user;
    const teamId = randomUUID();
    const teamKey = `${tournamentId}#${teamId}`;

    const item = {
      teamId,
      tournamentId,
      displayName,
      captainSummoner: user,
      createdBy: user,
      createdAt: new Date().toISOString(),
      members,
      status: body?.status ?? 'open'
    };

    await docClient.send(
      new PutCommand({
        TableName: process.env.TEAMS_TABLE,
        Item: item,
        ConditionExpression: 'attribute_not_exists(teamId)'
      })
    );

    // Write membership row for captain.
    await docClient.send(
      new PutCommand({
        TableName: process.env.USER_TEAMS_TABLE,
        Item: {
          userId: user,
          teamKey,
          teamId,
          tournamentId,
          role,
          isCaptain: true,
          createdAt: item.createdAt
        }
      })
    );

    logInfo('teamsApi.created', { tournamentId, teamId, captain: user });
    return jsonResponse(201, item);
  }

  if (method === 'DELETE' && teamIdParam) {
    if (!user) {
      return jsonResponse(401, { message: 'Unauthorized' });
    }

    const key = { tournamentId, teamId: teamIdParam };
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
    if (!isCaptain) {
      return jsonResponse(403, { message: 'only the captain can delete the team' });
    }

    // Remove membership rows for all members.
    const memberValues = Object.values(item.members || {});
    await Promise.all(
      memberValues
        .filter((m) => typeof m === 'string' && m.length > 0 && m !== 'Open')
        .map((m) =>
          docClient.send(
            new DeleteCommand({
              TableName: process.env.USER_TEAMS_TABLE,
              Key: {
                userId: m as string,
                teamKey: `${tournamentId}#${teamIdParam}`
              }
            })
          )
        )
    );

    await docClient.send(
      new DeleteCommand({
        TableName: process.env.TEAMS_TABLE,
        Key: key
      })
    );

    logInfo('teamsApi.deleted', { tournamentId, teamId: teamIdParam, deletedBy: user });
    return jsonResponse(200, { teamId: teamIdParam, tournamentId, deleted: true });
  }

  return jsonResponse(405, { message: 'Method not allowed' });
};


import { QueryCommand, PutCommand } from '@aws-sdk/lib-dynamodb';
import { docClient } from '../shared/db';
import { jsonResponse } from '../shared/http';
import { logInfo } from '../shared/logger';

export const handler = async (event: any) => {
  const tournamentId = event.pathParameters?.id;
  if (!tournamentId) {
    return jsonResponse(400, { message: 'tournamentId required' });
  }

  if (event.httpMethod === 'GET') {
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

  if (event.httpMethod === 'POST') {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const teamId = body?.teamId;
    if (!teamId) {
      return jsonResponse(400, { message: 'teamId is required' });
    }

    const item = {
      teamId,
      tournamentId,
      captainSummoner: body?.captainSummoner,
      members: body?.members ?? [],
      status: body?.status ?? 'open'
    };

    await docClient.send(
      new PutCommand({
        TableName: process.env.TEAMS_TABLE,
        Item: item
      })
    );

    logInfo('teamsApi.created', { tournamentId, teamId });
    return jsonResponse(201, { teamId, tournamentId });
  }

  return jsonResponse(405, { message: 'Method not allowed' });
};


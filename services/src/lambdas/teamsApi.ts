import { QueryCommand } from '@aws-sdk/lib-dynamodb';
import { docClient } from '../shared/db';
import { jsonResponse } from '../shared/http';
import { logInfo } from '../shared/logger';

export const handler = async (event: any) => {
  if (event.httpMethod !== 'GET') {
    return jsonResponse(405, { message: 'Method not allowed' });
  }

  const tournamentId = event.pathParameters?.id;
  if (!tournamentId) {
    return jsonResponse(400, { message: 'tournamentId required' });
  }

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
};


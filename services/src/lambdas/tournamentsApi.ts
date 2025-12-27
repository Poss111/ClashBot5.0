import { ScanCommand } from '@aws-sdk/lib-dynamodb';
import { docClient } from '../shared/db';
import { jsonResponse } from '../shared/http';
import { logInfo } from '../shared/logger';

export const handler = async (event: any) => {
  const tournamentId = event.pathParameters?.id;

  if (event.httpMethod === 'GET') {
    if (tournamentId) {
      const scan = await docClient.send(
        new ScanCommand({
          TableName: process.env.TOURNAMENTS_TABLE,
          FilterExpression: 'tournamentId = :tid',
          ExpressionAttributeValues: { ':tid': tournamentId }
        })
      );
      const item = scan.Items?.[0];
      if (!item) {
        return jsonResponse(404, { message: 'Not found' });
      }
      logInfo('tournamentsApi.detail', { tournamentId });
      return jsonResponse(200, item);
    }

    const result = await docClient.send(
      new ScanCommand({
        TableName: process.env.TOURNAMENTS_TABLE,
        FilterExpression: '#status IN (:upcoming, :active)',
        ExpressionAttributeNames: { '#status': 'status' },
        ExpressionAttributeValues: { ':upcoming': 'upcoming', ':active': 'active' }
      })
    );
    logInfo('tournamentsApi.list', { count: result.Count ?? 0 });
    return jsonResponse(200, { items: result.Items ?? [] });
  }

  return jsonResponse(405, { message: 'Method not allowed' });
};


import { PutCommand } from '@aws-sdk/lib-dynamodb';
import { docClient } from '../shared/db';
import { jsonResponse } from '../shared/http';
import { logInfo } from '../shared/logger';
import { withApiMetrics } from '../shared/observability';

const baseHandler = async (event: any) => {
  if (event.httpMethod !== 'POST') {
    return jsonResponse(405, { message: 'Method not allowed' });
  }

  const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
  const tournamentId = event.pathParameters?.id;
  const playerId = body?.playerId;

  if (!tournamentId || !playerId) {
    return jsonResponse(400, { message: 'tournamentId and playerId are required' });
  }

  await docClient.send(
    new PutCommand({
      TableName: process.env.REGISTRATIONS_TABLE,
      Item: {
        tournamentId,
        playerId,
        preferredRoles: body?.preferredRoles ?? [],
        availability: body?.availability,
        status: 'pending',
        createdAt: new Date().toISOString()
      }
    })
  );

  logInfo('registrationsApi.created', { tournamentId, playerId });
  return jsonResponse(201, { tournamentId, playerId, status: 'pending' });
};

export const handler = withApiMetrics({
  defaultRoute: '/tournaments/{id}/registrations',
  feature: 'registration.create'
})(baseHandler);


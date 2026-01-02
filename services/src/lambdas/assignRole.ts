import { UpdateCommand, GetCommand } from '@aws-sdk/lib-dynamodb';
import { docClient } from '../shared/db';
import { jsonResponse } from '../shared/http';
import { logError, logInfo } from '../shared/logger';

export const handler = async (event: any) => {
  const tournamentId = event.pathParameters?.id;
  const teamId = event.pathParameters?.teamId;
  const role = event.pathParameters?.role;
  const user = event.requestContext?.authorizer?.principalId;

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

    const members = item.members || {};
    const current = members[role];
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

    logInfo('assignRole.assigned', { tournamentId, teamId, role, user });
    return jsonResponse(200, { tournamentId, teamId, role, playerId: user });
  } catch (err) {
    logError('assignRole.failed', { error: String(err) });
    return jsonResponse(500, { message: 'failed to assign role' });
  }
};


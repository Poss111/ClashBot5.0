import { QueryCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { docClient } from '../shared/db';
import { logInfo } from '../shared/logger';

interface EventInput {
  tournamentId: string;
}

export const handler = async (event: EventInput) => {
  const tournamentId = event.tournamentId;
  if (!tournamentId) {
    throw new Error('tournamentId is required');
  }

  logInfo('assignPlayers.start', { tournamentId });

  // Placeholder: simply mark all registrations as assigned to a single team
  const teamId = `team-${tournamentId}`;

  const registrations = await docClient.send(
    new QueryCommand({
      TableName: process.env.REGISTRATIONS_TABLE,
      KeyConditionExpression: 'tournamentId = :tid',
      ExpressionAttributeValues: {
        ':tid': tournamentId
      }
    })
  );

  await Promise.all(
    (registrations.Items ?? []).map((item) =>
      docClient.send(
        new UpdateCommand({
          TableName: process.env.REGISTRATIONS_TABLE,
          Key: { tournamentId, playerId: item.playerId },
          UpdateExpression: 'SET #status = :status, teamId = :teamId',
          ExpressionAttributeNames: { '#status': 'status' },
          ExpressionAttributeValues: { ':status': 'assigned', ':teamId': teamId }
        })
      )
    )
  );

  await docClient.send(
    new UpdateCommand({
      TableName: process.env.TEAMS_TABLE,
      Key: { teamId, tournamentId },
      UpdateExpression: 'SET #status = :status',
      ExpressionAttributeNames: { '#status': 'status' },
      ExpressionAttributeValues: { ':status': 'open' }
    })
  );

  const assignedCount = registrations.Count ?? 0;
  logInfo('assignPlayers.completed', { tournamentId, teamId, assignedCount });
  return { tournamentId, teamId, assignedCount };
};


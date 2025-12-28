import { QueryCommand } from '@aws-sdk/lib-dynamodb';
import { docClient } from '../shared/db';

interface EventInput {
  tournamentId?: string;
}

export const handler = async (event: EventInput) => {
  const tournamentId = event.tournamentId;
  if (!tournamentId) {
    throw new Error('tournamentId is required');
  }

  const result = await docClient.send(
    new QueryCommand({
      TableName: process.env.TOURNAMENTS_TABLE,
      KeyConditionExpression: 'tournamentId = :tid',
      ExpressionAttributeValues: {
        ':tid': tournamentId
      },
      ScanIndexForward: false,
      Limit: 1
    })
  );

  const item = result.Items?.[0];
  if (!item) {
    const err: any = new Error('Tournament not found');
    err.code = 'TournamentNotFound';
    throw err;
  }

  return item;
};


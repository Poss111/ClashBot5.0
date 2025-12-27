import { PutCommand } from '@aws-sdk/lib-dynamodb';
import { docClient } from '../shared/db';
import { Tournament } from '../shared/types';
import { logInfo } from '../shared/logger';

interface EventInput {
  tournament?: Tournament;
  tournamentId?: string;
}

export const handler = async (event: EventInput) => {
  const tournament = event.tournament ?? {
    tournamentId: event.tournamentId,
    startTime: new Date().toISOString(),
    status: 'upcoming'
  };

  if (!tournament?.tournamentId) {
    throw new Error('tournamentId is required');
  }

  const startTime = tournament.startTime || new Date().toISOString();

  await docClient.send(
    new PutCommand({
      TableName: process.env.TOURNAMENTS_TABLE,
      Item: {
        ...tournament,
        startTime,
        status: tournament.status ?? 'upcoming'
      }
    })
  );

  logInfo('registerTournament.upserted', { tournamentId: tournament.tournamentId, startTime });
  return { tournamentId: tournament.tournamentId, startTime };
};


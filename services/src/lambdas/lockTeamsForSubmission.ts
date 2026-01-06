import { UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { docClient } from '../shared/db';
import { logInfo } from '../shared/logger';
import { withFunctionMetrics } from '../shared/observability';

interface EventInput {
  tournamentId: string;
  teamId?: string;
}

const baseHandler = async (event: EventInput & { assignment?: { teamId?: string } }) => {
  const tournamentId = event.tournamentId;
  if (!tournamentId) {
    throw new Error('tournamentId is required');
  }

  const teamId = event.teamId ?? event.assignment?.teamId ?? `team-${tournamentId}`;

  await docClient.send(
    new UpdateCommand({
      TableName: process.env.TEAMS_TABLE,
      Key: { teamId, tournamentId },
      UpdateExpression: 'SET #status = :status',
      ExpressionAttributeNames: { '#status': 'status' },
      ExpressionAttributeValues: { ':status': 'locked' }
    })
  );

  logInfo('lockTeams.locked', { tournamentId, teamId });
  return { tournamentId, teamId, status: 'locked' };
};

export const handler = withFunctionMetrics('lockTeams')(baseHandler);


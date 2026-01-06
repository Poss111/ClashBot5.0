import { ScanCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { docClient } from '../shared/db';
import { logInfo } from '../shared/logger';
import { withFunctionMetrics } from '../shared/observability';

const baseHandler = async () => {
  const now = new Date().toISOString();
  const tournaments = await docClient.send(
    new ScanCommand({
      TableName: process.env.TOURNAMENTS_TABLE,
      FilterExpression: '#start < :now AND #status <> :closed',
      ExpressionAttributeNames: { '#start': 'startTime', '#status': 'status' },
      ExpressionAttributeValues: { ':now': now, ':closed': 'closed' }
    })
  );

  await Promise.all(
    (tournaments.Items ?? []).map((t) =>
      docClient.send(
        new UpdateCommand({
          TableName: process.env.TOURNAMENTS_TABLE,
          Key: { tournamentId: t.tournamentId, startTime: t.startTime },
          UpdateExpression: 'SET #status = :closed',
          ExpressionAttributeNames: { '#status': 'status' },
          ExpressionAttributeValues: { ':closed': 'closed' }
        })
      )
    )
  );

  const closed = tournaments.Count ?? 0;
  logInfo('deactivatePast.closed', { closed });
  return { closed };
};

export const handler = withFunctionMetrics('deactivatePastTournaments')(baseHandler);


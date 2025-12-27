import { SFNClient, StartExecutionCommand } from '@aws-sdk/client-sfn';
import { logInfo, logError } from '../shared/logger';

const sfnClient = new SFNClient({});

export const handler = async (event: any) => {
  const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body ?? {};
  const tournamentId = body.tournamentId ?? event.tournamentId;

  if (!process.env.STATE_MACHINE_ARN) {
    throw new Error('STATE_MACHINE_ARN not configured');
  }
  if (!tournamentId) {
    return { statusCode: 400, body: JSON.stringify({ message: 'tournamentId required' }) };
  }

  const input = JSON.stringify({ tournamentId });

  try {
    const resp = await sfnClient.send(
      new StartExecutionCommand({
        stateMachineArn: process.env.STATE_MACHINE_ARN,
        input
      })
    );
    logInfo('startAssignmentWorkflow.started', {
      tournamentId,
      executionArn: resp.executionArn
    });
    return {
      statusCode: 202,
      body: JSON.stringify({ executionArn: resp.executionArn, tournamentId })
    };
  } catch (err) {
    logError('startAssignmentWorkflow.failed', { tournamentId, error: String(err) });
    return { statusCode: 500, body: JSON.stringify({ message: 'Failed to start workflow' }) };
  }

};


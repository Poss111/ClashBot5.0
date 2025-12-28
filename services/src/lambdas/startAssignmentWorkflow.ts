import { SFNClient, StartExecutionCommand } from '@aws-sdk/client-sfn';
import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';
import { logInfo, logError } from '../shared/logger';

const sfnClient = new SFNClient({});
const lambdaClient = new LambdaClient({});

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

    // Broadcast workflow started event
    if (process.env.BROADCAST_FUNCTION_NAME) {
      try {
        await lambdaClient.send(
          new InvokeCommand({
            FunctionName: process.env.BROADCAST_FUNCTION_NAME,
            InvocationType: 'Event',
            Payload: JSON.stringify({
              type: 'workflow.started',
              tournamentId,
              data: {
                tournamentId,
                executionArn: resp.executionArn
              }
            })
          })
        );
      } catch (err) {
        // Don't fail if broadcast fails
        logError('startAssignmentWorkflow.broadcastFailed', { tournamentId, error: String(err) });
      }
    }

    return {
      statusCode: 202,
      body: JSON.stringify({ executionArn: resp.executionArn, tournamentId })
    };
  } catch (err) {
    logError('startAssignmentWorkflow.failed', { tournamentId, error: String(err) });
    return { statusCode: 500, body: JSON.stringify({ message: 'Failed to start workflow' }) };
  }

};


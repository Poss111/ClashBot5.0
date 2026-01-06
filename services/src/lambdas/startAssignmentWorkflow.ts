import { SFNClient, StartExecutionCommand } from '@aws-sdk/client-sfn';
import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';
import { logInfo, logError } from '../shared/logger';
import { withApiMetrics } from '../shared/observability';

const sfnClient = new SFNClient({});
const lambdaClient = new LambdaClient({});

const baseHandler = async (event: any) => {
  const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body ?? {};
  const tournamentId = body.tournamentId ?? event.pathParameters?.id ?? event.tournamentId;
  const causedBy =
    event.requestContext?.authorizer?.principalId ??
    body.causedBy ??
    'unknown';

  if (!process.env.STATE_MACHINE_ARN) {
    throw new Error('STATE_MACHINE_ARN not configured');
  }
  if (!tournamentId) {
    return {
      statusCode: 400,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': '*',
        'Access-Control-Allow-Methods': '*'
      },
      body: JSON.stringify({ message: 'tournamentId required' })
    };
  }

  const input = JSON.stringify({ tournamentId });
  const enrichedInput = JSON.stringify({ tournamentId, causedBy });

  try {
    const resp = await sfnClient.send(
      new StartExecutionCommand({
        stateMachineArn: process.env.STATE_MACHINE_ARN,
        input: enrichedInput
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
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': '*',
        'Access-Control-Allow-Methods': '*'
      },
      body: JSON.stringify({ executionArn: resp.executionArn, tournamentId })
    };
  } catch (err) {
    logError('startAssignmentWorkflow.failed', { tournamentId, error: String(err) });
    return {
      statusCode: 500,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': '*',
        'Access-Control-Allow-Methods': '*'
      },
      body: JSON.stringify({ message: 'Failed to start workflow' })
    };
  }

};

export const handler = withApiMetrics({
  defaultRoute: '/tournaments/{id}/assign',
  feature: 'workflow.start'
})(baseHandler);


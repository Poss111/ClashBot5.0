import { QueryCommand, PutCommand } from '@aws-sdk/lib-dynamodb';
import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';
import { APIGatewayProxyEvent } from 'aws-lambda';
import { randomUUID } from 'crypto';
import { docClient } from '../shared/db';
import { jsonResponse } from '../shared/http';
import { logInfo, logError } from '../shared/logger';
import { withApiMetrics } from '../shared/observability';

const baseHandler = async (event: APIGatewayProxyEvent) => {
  const traceId = randomUUID();

  try {
    const user = event.requestContext?.authorizer?.principalId;
    if (!user) {
      return jsonResponse(401, { statusCode: 401, message: 'Unauthorized', traceId });
    }

    const tournamentId = event.pathParameters?.id;
    if (!tournamentId) {
      return jsonResponse(400, { statusCode: 400, message: 'tournamentId is required in path', traceId });
    }

    let payload: any = {};
    try {
      payload = event.body ? JSON.parse(event.body) : {};
    } catch {
      return jsonResponse(400, { statusCode: 400, message: 'Invalid JSON body', traceId });
    }

    const existing = await docClient.send(
      new QueryCommand({
        TableName: process.env.TOURNAMENTS_TABLE,
        KeyConditionExpression: 'tournamentId = :tid',
        ExpressionAttributeValues: { ':tid': tournamentId },
        Limit: 1
      })
    );
    const existingItem = existing.Items?.[0];
    if (!existingItem) {
      return jsonResponse(404, { statusCode: 404, message: 'Tournament not found', traceId });
    }

    const schedule = payload.schedule ?? payload.tournament?.schedule;
    const primarySchedule = schedule?.[0];

    const missing: string[] = [];
    if (payload.themeId === undefined && payload.tournament?.themeId === undefined) missing.push('themeId');
    if (!payload.nameKey && !payload.tournament?.nameKey) missing.push('nameKey');
    if (!payload.nameKeySecondary && !payload.tournament?.nameKeySecondary) missing.push('nameKeySecondary');
    if (!primarySchedule?.registrationTime) missing.push('schedule[0].registrationTime');
    if (!primarySchedule?.startTime) missing.push('schedule[0].startTime');

    if (missing.length > 0) {
      return jsonResponse(400, {
        statusCode: 400,
        message: `Missing required fields: ${missing.join(', ')}`,
        traceId
      });
    }

    const tournament = {
      tournamentId,
      themeId: payload.themeId ?? payload.tournament?.themeId,
      nameKey: payload.nameKey ?? payload.tournament?.nameKey,
      nameKeySecondary: payload.nameKeySecondary ?? payload.tournament?.nameKeySecondary,
      schedule,
      startTime: new Date(primarySchedule!.startTime).toISOString(),
      registrationTime: new Date(primarySchedule!.registrationTime).toISOString(),
      status: payload.status ?? payload.tournament?.status ?? existingItem.status ?? 'upcoming',
      updatedBy: user,
      updatedAt: new Date().toISOString()
    };

    await docClient.send(
      new PutCommand({
        TableName: process.env.TOURNAMENTS_TABLE,
        Item: tournament
      })
    );

    const broadcastFunctionName = process.env.BROADCAST_FUNCTION_NAME;
    if (broadcastFunctionName) {
      try {
        const lambdaClient = new LambdaClient({});
        await lambdaClient.send(
          new InvokeCommand({
            FunctionName: broadcastFunctionName,
            InvocationType: 'Event',
            Payload: JSON.stringify({
              type: 'tournament.updated',
              tournamentId,
              causedBy: user,
              data: {
                tournamentId,
                nameKey: tournament.nameKey,
                nameKeySecondary: tournament.nameKeySecondary,
                startTime: tournament.startTime
              }
            })
          })
        );
      } catch (err) {
        logError('updateTournament.broadcastFailed', { traceId, error: String(err) });
      }
    }

    logInfo('updateTournament.updated', { tournamentId, traceId, updatedBy: user });
    return jsonResponse(200, { tournamentId, startTime: tournament.startTime, traceId });
  } catch (err) {
    logError('updateTournament.failed', { traceId, error: String(err), stack: err});
    return jsonResponse(500, { statusCode: 500, message: 'Failed to update tournament', traceId });
  }
};

export const handler = withApiMetrics({
  defaultRoute: '/tournaments/{id}',
  feature: 'tournament.update'
})(baseHandler);



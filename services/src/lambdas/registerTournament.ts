import { PutCommand } from '@aws-sdk/lib-dynamodb';
import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';
import { APIGatewayProxyEvent } from 'aws-lambda';
import { docClient } from '../shared/db';
import { logInfo, logError } from '../shared/logger';
import { randomUUID } from 'crypto';
import { jsonResponse } from '../shared/http';

export const handler = async (event: APIGatewayProxyEvent) => {
  const traceId = randomUUID();

  try {
    // Find user from the requestContext
    const user = event.requestContext?.authorizer?.principalId;
    if (!user) {
      return jsonResponse(401, {
        statusCode: 401,
        message: 'Unauthorized',
        traceId
      });
    }

    logInfo('User information', { user });

    let payload: any = {};
    try {
      payload = event.body ? JSON.parse(event.body) : {};
    } catch (err) {
      return jsonResponse(400, {
        statusCode: 400,
        message: 'Invalid JSON body',
        traceId
      });
    }

    logInfo('Tournament information trying to be created', { tournamentDetails: payload });

    // Required fields matching Riot Clash tournament DTO
    const schedule = payload.schedule ?? payload.tournament?.schedule;
    const primarySchedule = schedule?.[0];

    logInfo('registerTournament.start', { traceId, event });

    const missing: string[] = [];
    const tournamentId = payload.tournamentId ?? payload.tournament?.tournamentId;
    if (!tournamentId) missing.push('tournamentId');
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
      tournamentId: tournamentId!,
      themeId: payload.themeId ?? payload.tournament?.themeId,
      nameKey: payload.nameKey ?? payload.tournament?.nameKey,
      nameKeySecondary: payload.nameKeySecondary ?? payload.tournament?.nameKeySecondary,
      schedule,
      startTime: new Date(primarySchedule!.startTime).toISOString(),
      registrationTime: new Date(primarySchedule!.registrationTime).toISOString(),
      status: payload.tournament?.status ?? 'upcoming',
      createdBy: user,
      createdAt: new Date().toISOString()
    };

    await docClient.send(
      new PutCommand({
        TableName: process.env.TOURNAMENTS_TABLE,
        Item: {
          ...tournament,
          status: tournament.status ?? 'upcoming'
        }
      })
    );

    // Broadcast tournament registered (causedBy: system)
    const broadcastFunctionName = process.env.BROADCAST_FUNCTION_NAME;
    if (broadcastFunctionName) {
      try {
        const lambdaClient = new LambdaClient({});
        await lambdaClient.send(
          new InvokeCommand({
            FunctionName: broadcastFunctionName,
            InvocationType: 'Event',
            Payload: JSON.stringify({
              type: 'tournament.registered',
              tournamentId: tournament.tournamentId,
              causedBy: 'system',
              data: {
                tournamentId: tournament.tournamentId,
                nameKey: tournament.nameKey,
                nameKeySecondary: tournament.nameKeySecondary,
                startTime: tournament.startTime,
                registrationTime: tournament.registrationTime
              }
            })
          })
        );
      } catch (err) {
        logError('registerTournament.broadcastFailed', { traceId, error: String(err) });
      }
    }

    logInfo('registerTournament.upserted', {
      tournamentId: tournament.tournamentId,
      nameKey: tournament.nameKey,
      nameKeySecondary: tournament.nameKeySecondary,
      startTime: tournament.startTime,
      registrationTime: tournament.registrationTime,
      traceId
    });
    return jsonResponse(201, { tournamentId: tournament.tournamentId, startTime: tournament.startTime, traceId });
  } catch (err) {
    logError('registerTournament.failed', { traceId, error: String(err) });
    return jsonResponse(500, {
      statusCode: 500,
      message: 'Failed to register tournament',
      traceId
    });
  }
};


import { PutCommand } from '@aws-sdk/lib-dynamodb';
import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';
import { docClient } from '../shared/db';
import { Tournament } from '../shared/types';
import { logInfo, logError } from '../shared/logger';
import { randomUUID } from 'crypto';
import { jsonResponse } from '../shared/http';

interface EventInput {
  tournament?: Tournament;
  tournamentId?: string;
  themeId?: number;
  nameKey?: string;
  nameKeySecondary?: string;
  schedule?: Array<{
    id: number;
    registrationTime: number;
    startTime: number;
    cancelledDate?: number;
  }>;
}

export const handler = async (event: EventInput) => {
  const traceId = randomUUID();

  try {
    // Required fields matching Riot Clash tournament DTO
    const schedule = event.schedule ?? event.tournament?.schedule;
    const primarySchedule = schedule?.[0];

    const missing: string[] = [];
    const tournamentId = event.tournamentId ?? event.tournament?.tournamentId;
    if (!tournamentId) missing.push('tournamentId');
    if (event.themeId === undefined && event.tournament?.themeId === undefined) missing.push('themeId');
    if (!event.nameKey && !event.tournament?.nameKey) missing.push('nameKey');
    if (!event.nameKeySecondary && !event.tournament?.nameKeySecondary) missing.push('nameKeySecondary');
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
      themeId: event.themeId ?? event.tournament?.themeId,
      nameKey: event.nameKey ?? event.tournament?.nameKey,
      nameKeySecondary: event.nameKeySecondary ?? event.tournament?.nameKeySecondary,
      schedule,
      startTime: new Date(primarySchedule!.startTime).toISOString(),
      registrationTime: new Date(primarySchedule!.registrationTime).toISOString(),
      status: event.tournament?.status ?? 'upcoming'
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
                startTime: tournament.startTime
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
      startTime: tournament.startTime,
      traceId
    });
    return jsonResponse(201, { tournamentId: tournament.tournamentId, startTime, traceId });
  } catch (err) {
    logError('registerTournament.failed', { traceId, error: String(err) });
    return jsonResponse(500, {
      statusCode: 500,
      message: 'Failed to register tournament',
      traceId
    });
  }
};


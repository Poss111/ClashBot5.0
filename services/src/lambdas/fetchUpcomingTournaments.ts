import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';
import { PutCommand } from '@aws-sdk/lib-dynamodb';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';
import { docClient } from '../shared/db';
import { logInfo, logError } from '../shared/logger';

interface ClashTournament {
  id: number;
  themeId?: number;
  nameKey?: string;
  nameKeySecondary?: string;
  schedule?: Array<{ id: number; registrationTime: number; startTime: number; cancelledDate?: number }>;
}

interface FetchResult {
  tournaments: Array<{
    tournamentId: string;
    name?: string;
    startTime: string;
    region?: string;
    status: 'upcoming' | 'active';
  }>;
}

const secretsClient = new SecretsManagerClient({});
const snsClient = new SNSClient({});

const resolveApiKey = (secretString?: string): string => {
  if (!secretString) throw new Error('RIOT API secret empty');
  try {
    const parsed = JSON.parse(secretString);
    if (typeof parsed === 'string') return parsed;
    if (parsed.apiKey) return parsed.apiKey as string;
    if (parsed.token) return parsed.token as string;
  } catch {
    // not JSON, treat as raw key
  }
  return secretString;
};

export const handler = async (): Promise<FetchResult> => {
  const platform = process.env.RIOT_PLATFORM ?? 'na1';
  const secret = await secretsClient.send(
    new GetSecretValueCommand({
      SecretId: process.env.RIOT_SECRET_NAME
    })
  );
  const apiKey = resolveApiKey(secret.SecretString);

  const url = `https://${platform}.api.riotgames.com/lol/clash/v1/tournaments`;
  logInfo('fetchUpcomingTournaments.start', { platform, url });

  const resp = await fetch(url, {
    headers: {
      'X-Riot-Token': apiKey
    }
  });

  if (!resp.ok) {
    const text = await resp.text();
    logError('fetchUpcomingTournaments.riotError', { status: resp.status, text });
    throw new Error(`Riot API error: ${resp.status}`);
  }

  const raw = (await resp.json()) as ClashTournament[];

  const tournaments: FetchResult['tournaments'] = [];

  for (const t of raw) {
    const schedule = t.schedule?.[0];
    if (!schedule?.startTime) continue;
    const tournamentId = String(t.id);
    const item = {
      tournamentId,
      name: t.nameKeySecondary ?? t.nameKey,
      startTime: new Date(schedule.startTime).toISOString(),
      registrationTime: new Date(schedule.registrationTime).toISOString(),
      region: platform.toUpperCase(),
      status: 'upcoming' as const
    };

    tournaments.push(item);

    // upsert into DynamoDB
    await docClient.send(
      new PutCommand({
        TableName: process.env.TOURNAMENTS_TABLE,
        Item: item
      })
    );
  }

  logInfo('fetchUpcomingTournaments.success', { count: tournaments.length });

  // Send notification if configured
  if (process.env.NOTIFY_TOPIC_ARN) {
    const summary = tournaments.map((t) => `${t.tournamentId} @ ${t.startTime}`).join('\n') || 'No tournaments found';
    await snsClient.send(
      new PublishCommand({
        TopicArn: process.env.NOTIFY_TOPIC_ARN,
        Subject: `Clash tournaments fetch (${tournaments.length})`,
        Message: `Fetched ${tournaments.length} tournaments from Riot.\n\n${summary}`
      })
    );
  }

  return { tournaments };
};


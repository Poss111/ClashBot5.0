import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';
import { logInfo } from '../shared/logger';

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

export const handler = async (): Promise<FetchResult> => {
  logInfo('fetchUpcomingTournaments.start', { secret: process.env.RIOT_SECRET_NAME });

  // Retrieve Riot key (real API call omitted for brevity)
  await secretsClient.send(
    new GetSecretValueCommand({
      SecretId: process.env.RIOT_SECRET_NAME
    })
  );

  // TODO: Replace with real Riot API fetch for Clash tournaments
  const tournaments: FetchResult['tournaments'] = [
    {
      tournamentId: 'sample-clash',
      name: 'Clash Sample Cup',
      startTime: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
      region: 'NA1',
      status: 'upcoming'
    }
  ];

  logInfo('fetchUpcomingTournaments.success', { count: tournaments.length });
  return { tournaments };
};


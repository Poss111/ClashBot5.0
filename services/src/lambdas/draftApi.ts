import { GetCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { docClient } from '../shared/db';
import { jsonResponse } from '../shared/http';
import { logError, logInfo } from '../shared/logger';
import { withApiMetrics } from '../shared/observability';

type DraftSide = {
  firstRoundBans: string[];
  secondRoundBans: string[];
  firstRoundPicks: string[];
  secondRoundPicks: string[];
};

type DraftProposal = {
  tournamentId: string;
  teamId: string;
  ourSide: DraftSide;
  enemySide: DraftSide;
  notes?: string;
  updatedBy: string;
  updatedAt: string;
};

const normalizeList = (value: any, expectedLength: number): string[] => {
  const arr = Array.isArray(value) ? value : [];
  const mapped = arr.map((v) => (v ?? '').toString());
  const trimmed = mapped.slice(0, expectedLength);
  while (trimmed.length < expectedLength) {
    trimmed.push('');
  }
  return trimmed;
};

const normalizeSide = (input: any): DraftSide => ({
  firstRoundBans: normalizeList(input?.firstRoundBans, 3),
  secondRoundBans: normalizeList(input?.secondRoundBans, 2),
  firstRoundPicks: normalizeList(input?.firstRoundPicks, 3),
  secondRoundPicks: normalizeList(input?.secondRoundPicks, 2)
});

const isTeamMember = (team: any, userId: string): boolean => {
  const members = team?.members || {};
  const normalized = userId.toLowerCase();
  const isCaptain =
    (team?.captainSummoner && `${team.captainSummoner}`.toLowerCase() === normalized) ||
    (team?.createdBy && `${team.createdBy}`.toLowerCase() === normalized);
  const isListed =
    Object.values(members).some((m) => typeof m === 'string' && m.toLowerCase() === normalized) ?? false;
  return isCaptain || isListed;
};

const baseHandler = async (event: any) => {
  const tournamentId = event.pathParameters?.id;
  const teamId = event.pathParameters?.teamId;
  const method = event.httpMethod;
  const user = event.requestContext?.authorizer?.principalId;

  if (!tournamentId || !teamId) {
    return jsonResponse(400, { message: 'tournamentId and teamId are required' });
  }
  if (!user) {
    return jsonResponse(401, { message: 'Unauthorized' });
  }

  try {
    const key = { tournamentId, teamId };
    const teamResp = await docClient.send(
      new GetCommand({
        TableName: process.env.TEAMS_TABLE,
        Key: key
      })
    );
    const team = teamResp.Item as any;
    if (!team) {
      return jsonResponse(404, { message: 'team not found' });
    }

    if (!isTeamMember(team, user)) {
      return jsonResponse(403, { message: 'forbidden: team members only' });
    }

    if (method === 'GET') {
      const draft = team.draftProposal;
      if (!draft) {
        return jsonResponse(404, { message: 'draft not found' });
      }
      return jsonResponse(200, draft);
    }

    if (method === 'PUT') {
      const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
      const incoming = body ?? {};
      const draft: DraftProposal = {
        tournamentId,
        teamId,
        ourSide: normalizeSide(incoming.ourSide ?? {}),
        enemySide: normalizeSide(incoming.enemySide ?? {}),
        notes: typeof incoming.notes === 'string' ? incoming.notes : team.draftProposal?.notes ?? '',
        updatedBy: user,
        updatedAt: new Date().toISOString()
      };

      await docClient.send(
        new UpdateCommand({
          TableName: process.env.TEAMS_TABLE,
          Key: key,
          UpdateExpression: 'SET #draft = :draft',
          ExpressionAttributeNames: { '#draft': 'draftProposal' },
          ExpressionAttributeValues: { ':draft': draft }
        })
      );

      logInfo('draftApi.saved', { tournamentId, teamId, user });
      return jsonResponse(200, draft);
    }

    return jsonResponse(405, { message: 'Method not allowed' });
  } catch (err) {
    logError('draftApi.error', { error: String(err) });
    return jsonResponse(500, { message: 'failed to process draft request' });
  }
};

export const handler = withApiMetrics({
  defaultRoute: '/tournaments/{id}/teams/{teamId}/draft',
  feature: (event) => {
    const method = (event as any)?.httpMethod;
    if (method === 'GET') return 'draft.get';
    if (method === 'PUT') return 'draft.save';
    return undefined;
  }
})(baseHandler);


import { describe, expect, it, jest, beforeEach } from '@jest/globals';
import { GetCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { handler } from '../draftApi';
import { docClient } from '../../shared/db';

jest.mock('../../shared/db', () => ({
  docClient: { send: jest.fn() }
}));

// Use var to avoid TDZ with hoisted jest.mock
var sendMock = docClient.send as unknown as jest.MockedFunction<(...args: any[]) => Promise<any>>;

describe('draftApi', () => {
  beforeEach(() => {
    jest.resetAllMocks();
    process.env.TEAMS_TABLE = 'Teams';
  });

  const baseEvent = {
    pathParameters: { id: 't1', teamId: 'team-1' },
    requestContext: { authorizer: { principalId: 'user-1' } }
  };

  it('requires auth and params', async () => {
    const resp = await handler({ pathParameters: {}, requestContext: {} } as any);
    expect(resp.statusCode).toBe(400);
    const unauth = await handler({ ...baseEvent, requestContext: {} } as any);
    expect(unauth.statusCode).toBe(401);
  });

  it('returns 404 when team missing', async () => {
    sendMock.mockResolvedValue({ Item: undefined });
    const resp = await handler({ ...baseEvent, httpMethod: 'GET' } as any);
    expect(resp.statusCode).toBe(404);
  });

  it('forbids non-team member', async () => {
    sendMock.mockResolvedValue({
      Item: { tournamentId: 't1', teamId: 'team-1', members: { top: 'other' } }
    });
    const resp = await handler({ ...baseEvent, httpMethod: 'GET' } as any);
    expect(resp.statusCode).toBe(403);
  });

  it('GET returns draft when present', async () => {
    sendMock.mockResolvedValue({
      Item: {
        tournamentId: 't1',
        teamId: 'team-1',
        captainSummoner: 'user-1',
        draftProposal: { notes: 'hi', ourSide: {}, enemySide: {} }
      }
    });
    const resp = await handler({ ...baseEvent, httpMethod: 'GET' } as any);
    expect(resp.statusCode).toBe(200);
  });

  it('GET returns 404 when draft missing', async () => {
    sendMock.mockResolvedValue({
      Item: { tournamentId: 't1', teamId: 'team-1', captainSummoner: 'user-1' }
    });
    const resp = await handler({ ...baseEvent, httpMethod: 'GET' } as any);
    expect(resp.statusCode).toBe(404);
  });

  it('PUT saves draft with normalized lengths', async () => {
    sendMock.mockImplementation((cmd) => {
      if (cmd instanceof GetCommand) {
        return Promise.resolve({
          Item: {
            tournamentId: 't1',
            teamId: 'team-1',
            captainSummoner: 'user-1',
            members: { top: 'user-1' }
          }
        });
      }
      if (cmd instanceof UpdateCommand) {
        return Promise.resolve({});
      }
      throw new Error('unexpected command');
    });

    const body = {
      ourSide: { firstRoundBans: ['A'], secondRoundBans: ['B'], firstRoundPicks: ['C'], secondRoundPicks: ['D'] },
      enemySide: {}
    };
    const resp = await handler({
      ...baseEvent,
      httpMethod: 'PUT',
      body: JSON.stringify(body)
    } as any);

    expect(resp.statusCode).toBe(200);
    expect(sendMock).toHaveBeenCalledWith(expect.any(UpdateCommand));
  });

  it('returns 405 for other methods', async () => {
    sendMock.mockResolvedValue({
      Item: {
        tournamentId: 't1',
        teamId: 'team-1',
        captainSummoner: 'user-1',
        members: { top: 'user-1' }
      }
    });
    const resp = await handler({ ...baseEvent, httpMethod: 'POST' } as any);
    expect(resp.statusCode).toBe(405);
  });
});

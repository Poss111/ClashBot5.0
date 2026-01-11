import { describe, expect, it, jest, beforeEach } from '@jest/globals';
import { BatchGetCommand, DeleteCommand, GetCommand, PutCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { handler } from '../teamsApi';
import { docClient } from '../../shared/db';

jest.mock('../../shared/db', () => ({
  docClient: { send: jest.fn() }
}));

// Use var to avoid TDZ when Jest hoists mocks.
var observedFeature: ((event: any) => string | undefined) | undefined;
jest.mock('../../shared/observability', () => ({
  withApiMetrics: (opts: any = {}) => {
    observedFeature = opts.feature;
    return (fn: any) => async (event: any, ...rest: any[]) => {
      if (observedFeature) {
        observedFeature(event);
      }
      return fn(event, ...rest);
    };
  }
}));

jest.mock('../../shared/logger', () => ({
  logInfo: jest.fn(),
  logError: jest.fn()
}));

const sendMock = docClient.send as unknown as jest.MockedFunction<(...args: any[]) => Promise<any>>;

describe('teamsApi', () => {
  beforeEach(() => {
    jest.resetAllMocks();
    process.env.TEAMS_TABLE = 'TeamsTable';
    process.env.USER_TEAMS_TABLE = 'UserTeamsTable';
    process.env.USERS_TABLE = 'UsersTable';
  });

  it('returns 400 when tournamentId is missing', async () => {
    const response = await handler({
      httpMethod: 'GET',
      pathParameters: {}
    });
    expect(response.statusCode).toBe(400);
  });

  it('lists teams with masked display names when no user records', async () => {
    sendMock.mockResolvedValueOnce({
      Items: [
        {
          tournamentId: 't1',
          teamId: 'team-1',
          members: { mid: 'user-999', top: 'Open' },
          captainSummoner: 'user-999',
          createdBy: 'user-999',
          memberStatuses: { mid: 'all_in' }
        }
      ],
      Count: 1
    });

    const response = await handler({
      httpMethod: 'GET',
      pathParameters: { id: 't1' }
    });

    expect(response.statusCode).toBe(200);
    const body = JSON.parse(response.body);
    expect(body.items[0].memberDisplayNames.mid).toMatch(/^Player-/);
    expect(body.items[0].captainDisplayName).toMatch(/^Player-/);
    expect(body.items[0].memberStatuses.mid).toBe('all_in');
  });

  it('lists teams with masked display names when no users table entries', async () => {
    sendMock
      .mockResolvedValueOnce({
        Items: [
          {
            tournamentId: 't1',
            teamId: 'team-1',
            members: { mid: 'user-123', top: 'Open' },
            captainSummoner: 'user-123',
            createdBy: 'user-123',
            memberStatuses: { mid: 'all_in' }
          }
        ],
        Count: 1
      })
      .mockResolvedValueOnce({
        Responses: {
          [process.env.USERS_TABLE!]: []
        }
      });

    const response = await handler({
      httpMethod: 'GET',
      pathParameters: { id: 't1' }
    });

    expect(response.statusCode).toBe(200);
    const body = JSON.parse(response.body);
    expect(body.items[0].memberDisplayNames.mid).toMatch(/^Player-/);
    expect(body.items[0].captainDisplayName).toMatch(/^Player-/);
  });

  it('lists teams when only open slots (no userIds)', async () => {
    sendMock
      .mockResolvedValueOnce({
        Items: [
          {
            tournamentId: 't1',
            teamId: 'team-1',
            members: { mid: 'Open', top: 'Open' },
            memberStatuses: { mid: 'open' }
          }
        ],
        Count: 1
      })
      .mockResolvedValueOnce({
        Responses: { [process.env.USERS_TABLE!]: [] }
      });

    const response = await handler({
      httpMethod: 'GET',
      pathParameters: { id: 't1' }
    });

    expect(response.statusCode).toBe(200);
    const body = JSON.parse(response.body);
    expect(body.items[0].memberDisplayNames).toEqual({});
  });

  it('rejects unauthenticated team creation', async () => {
    const response = await handler({
      httpMethod: 'POST',
      pathParameters: { id: 't1' },
      body: JSON.stringify({ displayName: 'My Team', role: 'top' })
    });

    expect(response.statusCode).toBe(401);
  });

  it('prevents joining multiple teams in the same tournament', async () => {
    sendMock.mockImplementation((cmd: any) => {
      if (cmd instanceof QueryCommand) {
        return Promise.resolve({
          Items: [{ members: { top: 'user-123' } }]
        });
      }
      throw new Error(`Unexpected command: ${cmd.constructor.name}`);
    });

    const response = await handler({
      httpMethod: 'POST',
      pathParameters: { id: 't1' },
      requestContext: { authorizer: { principalId: 'user-123' } },
      body: JSON.stringify({ displayName: 'My Team', role: 'jungle' })
    });

    expect(response.statusCode).toBe(400);
    expect(JSON.parse(response.body).message).toMatch(/already belongs/i);
  });

  it('validates displayName is required', async () => {
    const response = await handler({
      httpMethod: 'POST',
      pathParameters: { id: 't1' },
      requestContext: { authorizer: { principalId: 'user-123' } },
      body: JSON.stringify({ role: 'mid', displayName: '' })
    });

    expect(response.statusCode).toBe(400);
    expect(JSON.parse(response.body).message).toMatch(/displayName/);
  });

  it('validates role is required', async () => {
    const response = await handler({
      httpMethod: 'POST',
      pathParameters: { id: 't1' },
      requestContext: { authorizer: { principalId: 'user-123' } },
      body: JSON.stringify({ displayName: 'My Team' })
    });

    expect(response.statusCode).toBe(400);
    expect(JSON.parse(response.body).message).toMatch(/role/);
  });

  it('creates a team and returns display names', async () => {
    sendMock
      .mockResolvedValueOnce({ Items: [] }) // Query teams-by-tournament
      .mockResolvedValueOnce({
        Responses: {
          [process.env.USERS_TABLE!]: [{ userId: 'user-123', displayName: 'Alice' }]
        }
      }) // BatchGet user display names
      .mockResolvedValueOnce({}) // Put team
      .mockResolvedValueOnce({}); // Put user-team membership

    // Create mask identiefier for name
    const maskIdentifier = (value: string | undefined): string | null => {
      if (!value) return null;
      // Keep identifiers non-identifying if display names are missing.
      let hash = 0;
      for (let i = 0; i < value.length; i++) {
        hash = (hash * 31 + value.charCodeAt(i)) >>> 0;
      }
      const code = hash.toString(16).padStart(6, '0').slice(0, 6);
      return `Player-${code}`;
    };
    const newLocal = 'user-123';
    const expectedDisplayName = maskIdentifier(newLocal);

    const response = await handler({
      httpMethod: 'POST',
      pathParameters: { id: 't1' },
      requestContext: { authorizer: { principalId: newLocal } },
      body: JSON.stringify({ displayName: 'My Team', role: 'mid' })
    });

    expect(sendMock).toHaveBeenCalledWith(expect.any(PutCommand));
    expect(response.statusCode).toBe(201);
    const body = JSON.parse(response.body);
    expect(body.memberDisplayNames.mid).toBe(expectedDisplayName);
    expect(body.captainDisplayName).toBe(expectedDisplayName);
  });

  it('only allows captains to delete a team', async () => {
    sendMock.mockImplementation((cmd: any) => {
      if (cmd instanceof GetCommand) {
        return Promise.resolve({
          Item: {
            teamId: 'team-1',
            tournamentId: 't1',
            captainSummoner: 'captain-1',
            createdBy: 'captain-1',
            members: { top: 'captain-1' }
          }
        });
      }
      throw new Error(`Unexpected command: ${cmd.constructor.name}`);
    });

    const response = await handler({
      httpMethod: 'DELETE',
      pathParameters: { id: 't1', teamId: 'team-1' },
      requestContext: { authorizer: { principalId: 'not-captain' } }
    });

    expect(response.statusCode).toBe(403);
    expect(JSON.parse(response.body).message).toMatch(/captain/i);
  });

  it('returns 404 when deleting a missing team', async () => {
    sendMock.mockImplementation((cmd: any) => {
      if (cmd instanceof GetCommand) {
        return Promise.resolve({ Item: undefined });
      }
      throw new Error(`Unexpected command: ${cmd.constructor.name}`);
    });

    const response = await handler({
      httpMethod: 'DELETE',
      pathParameters: { id: 't1', teamId: 'missing-team' },
      requestContext: { authorizer: { principalId: 'captain-1' } }
    });

    expect(response.statusCode).toBe(404);
  });

  it('rejects delete when unauthenticated', async () => {
    const response = await handler({
      httpMethod: 'DELETE',
      pathParameters: { id: 't1', teamId: 'team-1' }
    });

    expect(response.statusCode).toBe(401);
  });

  it('deletes membership rows for all members then deletes team', async () => {
    sendMock.mockImplementation((cmd: any) => {
      if (cmd instanceof GetCommand) {
        return Promise.resolve({
          Item: {
            teamId: 'team-1',
            tournamentId: 't1',
            captainSummoner: 'captain-1',
            createdBy: 'captain-1',
            members: { top: 'captain-1', mid: 'user-2', fill: 'Open' }
          }
        });
      }
      if (cmd instanceof DeleteCommand) {
        return Promise.resolve({});
      }
      throw new Error(`Unexpected command: ${cmd.constructor.name}`);
    });

    const response = await handler({
      httpMethod: 'DELETE',
      pathParameters: { id: 't1', teamId: 'team-1' },
      requestContext: { authorizer: { principalId: 'captain-1' } }
    });

    expect(response.statusCode).toBe(200);
    const deleteCalls = sendMock.mock.calls.filter(([c]: any[]) => c instanceof DeleteCommand);
    expect(deleteCalls.length).toBe(3); // two members + team delete
  });

  it('returns 405 for unsupported methods', async () => {
    const response = await handler({
      httpMethod: 'PUT',
      pathParameters: { id: 't1' }
    });

    expect(response.statusCode).toBe(405);
  });
});

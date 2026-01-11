import { describe, expect, it, jest, beforeEach } from '@jest/globals';
import { UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { handler } from '../lockTeamsForSubmission';
import { docClient } from '../../shared/db';

jest.mock('../../shared/db', () => ({
  docClient: { send: jest.fn() }
}));

const sendMock = docClient.send as unknown as jest.MockedFunction<(...args: any[]) => Promise<any>>;

describe('lockTeamsForSubmission', () => {
  beforeEach(() => {
    jest.resetAllMocks();
    process.env.TEAMS_TABLE = 'Teams';
  });

  it('throws if tournamentId missing', async () => {
    await expect(handler({} as any)).rejects.toThrow(/tournamentId/);
  });

  it('locks provided team id', async () => {
    sendMock.mockResolvedValue({});
    const result = await handler({ tournamentId: 't1', teamId: 'team-123' });
    expect(sendMock).toHaveBeenCalledWith(expect.any(UpdateCommand));
    expect(result).toEqual({ tournamentId: 't1', teamId: 'team-123', status: 'locked' });
  });

  it('locks default team id when not provided', async () => {
    sendMock.mockResolvedValue({});
    const result = await handler({ tournamentId: 't1' });
    expect(result.teamId).toBe('team-t1');
  });
});

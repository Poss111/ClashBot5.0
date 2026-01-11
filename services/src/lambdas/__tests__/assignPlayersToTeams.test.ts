import { describe, expect, it, jest, beforeEach } from '@jest/globals';
import { QueryCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { handler } from '../assignPlayersToTeams';
import { docClient } from '../../shared/db';

jest.mock('../../shared/db', () => ({
  docClient: { send: jest.fn() }
}));

const sendMock = docClient.send as unknown as jest.MockedFunction<(...args: any[]) => Promise<any>>;

describe('assignPlayersToTeams', () => {
  beforeEach(() => {
    jest.resetAllMocks();
    process.env.REGISTRATIONS_TABLE = 'Registrations';
    process.env.TEAMS_TABLE = 'Teams';
  });

  it('throws when tournamentId missing', async () => {
    await expect(handler({} as any)).rejects.toThrow(/tournamentId/);
  });

  it('assigns registrations to team and opens team', async () => {
    sendMock.mockImplementation((cmd) => {
      if (cmd instanceof QueryCommand) {
        return Promise.resolve({
          Items: [{ playerId: 'p1' }, { playerId: 'p2' }],
          Count: 2
        });
      }
      if (cmd instanceof UpdateCommand) {
        return Promise.resolve({});
      }
      throw new Error('unexpected command');
    });

    const result = await handler({ tournamentId: 't1' });
    expect(result.assignedCount).toBe(2);
    expect(sendMock).toHaveBeenCalledWith(expect.any(UpdateCommand));
  });
});

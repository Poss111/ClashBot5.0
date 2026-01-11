import { describe, expect, it, jest, beforeEach } from '@jest/globals';
import { ScanCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { handler } from '../deactivatePastTournaments';
import { docClient } from '../../shared/db';

jest.mock('../../shared/db', () => ({
  docClient: { send: jest.fn() }
}));

// Use var to avoid TDZ with hoisted jest.mock
var sendMock = docClient.send as unknown as jest.MockedFunction<(...args: any[]) => Promise<any>>;

describe('deactivatePastTournaments', () => {
  beforeEach(() => {
    jest.resetAllMocks();
    process.env.TOURNAMENTS_TABLE = 'Tournaments';
  });

  it('closes past tournaments and returns count', async () => {
    sendMock.mockImplementation((cmd) => {
      if (cmd instanceof ScanCommand) {
        return Promise.resolve({
          Items: [
            { tournamentId: 't1', startTime: '2020-01-01T00:00:00Z' },
            { tournamentId: 't2', startTime: '2020-02-01T00:00:00Z' }
          ],
          Count: 2
        });
      }
      if (cmd instanceof UpdateCommand) {
        return Promise.resolve({});
      }
      throw new Error('Unexpected command');
    });

    const result = await handler({} as any);
    expect(result.closed).toBe(2);
    expect(sendMock).toHaveBeenCalledWith(expect.any(UpdateCommand));
  });
});

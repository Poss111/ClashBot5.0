import { describe, expect, it, jest, beforeEach } from '@jest/globals';
import { QueryCommand } from '@aws-sdk/lib-dynamodb';
import { handler } from '../loadTournament';
import { docClient } from '../../shared/db';

jest.mock('../../shared/db', () => ({
  docClient: { send: jest.fn() }
}));

const sendMock = docClient.send as unknown as jest.MockedFunction<(...args: any[]) => Promise<any>>;

describe('loadTournament', () => {
  beforeEach(() => {
    jest.resetAllMocks();
    process.env.TOURNAMENTS_TABLE = 'TournamentsTable';
  });

  it('throws when tournamentId missing', async () => {
    await expect(handler({} as any)).rejects.toThrow(/required/);
  });

  it('returns tournament when found', async () => {
    sendMock.mockResolvedValue({
      Items: [{ tournamentId: 't1', nameKey: 'Foo' }]
    });

    const result = await handler({ tournamentId: 't1' });
    expect(sendMock).toHaveBeenCalledWith(expect.any(QueryCommand));
    expect((result as any).tournamentId).toBe('t1');
  });

  it('throws typed error when not found', async () => {
    sendMock.mockResolvedValue({ Items: [] });
    await expect(handler({ tournamentId: 'missing' })).rejects.toMatchObject({ code: 'TournamentNotFound' });
  });
});

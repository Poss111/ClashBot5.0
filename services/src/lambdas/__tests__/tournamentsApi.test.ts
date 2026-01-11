import { describe, expect, it, jest, beforeEach } from '@jest/globals';
import { ScanCommand } from '@aws-sdk/lib-dynamodb';
import { handler } from '../tournamentsApi';
import { docClient } from '../../shared/db';

jest.mock('../../shared/db', () => ({
  docClient: { send: jest.fn() }
}));

jest.mock('../../shared/observability', () => ({
  withApiMetrics: () => (fn: any) => fn
}));

jest.mock('../../shared/logger', () => ({
  logInfo: jest.fn(),
  logError: jest.fn()
}));

const sendMock = docClient.send as unknown as jest.MockedFunction<(...args: any[]) => Promise<any>>;

describe('tournamentsApi', () => {
  beforeEach(() => {
    jest.resetAllMocks();
    process.env.TOURNAMENTS_TABLE = 'TournamentsTable';
  });

  it('returns tournament detail when found', async () => {
    sendMock.mockResolvedValue({
      Items: [{ tournamentId: 'spring', status: 'active' }]
    });

    const response = await handler({
      httpMethod: 'GET',
      pathParameters: { id: 'spring' }
    });

    expect(response.statusCode).toBe(200);
    expect(JSON.parse(response.body).tournamentId).toBe('spring');
  });

  it('lists active and upcoming tournaments', async () => {
    sendMock.mockResolvedValue({
      Items: [{ tournamentId: 'spring', status: 'active' }],
      Count: 1
    });

    const response = await handler({
      httpMethod: 'GET',
      pathParameters: undefined
    });

    expect(sendMock).toHaveBeenCalledWith(expect.any(ScanCommand));
    expect(response.statusCode).toBe(200);
    expect(JSON.parse(response.body).items).toHaveLength(1);
  });

  it('lists tournaments with empty default when none returned', async () => {
    sendMock.mockResolvedValue({});

    const response = await handler({
      httpMethod: 'GET',
      pathParameters: undefined
    });

    expect(response.statusCode).toBe(200);
    expect(JSON.parse(response.body).items).toEqual([]);
  });

  it('returns 404 when tournament is missing', async () => {
    sendMock.mockResolvedValue({ Items: [] });

    const response = await handler({
      httpMethod: 'GET',
      pathParameters: { id: 'missing' }
    });

    expect(response.statusCode).toBe(404);
    expect(JSON.parse(response.body).message).toMatch(/not found/i);
  });

  it('rejects unsupported methods', async () => {
    const response = await handler({
      httpMethod: 'POST',
      pathParameters: undefined
    });

    expect(response.statusCode).toBe(405);
  });
});

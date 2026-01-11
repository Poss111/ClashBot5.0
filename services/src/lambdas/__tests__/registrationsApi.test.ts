import { describe, expect, it, jest, beforeEach } from '@jest/globals';
import { PutCommand } from '@aws-sdk/lib-dynamodb';
import { handler } from '../registrationsApi';
import { docClient } from '../../shared/db';

jest.mock('../../shared/db', () => ({
  docClient: { send: jest.fn() }
}));

const sendMock = docClient.send as unknown as jest.MockedFunction<(...args: any[]) => Promise<any>>;

describe('registrationsApi', () => {
  beforeEach(() => {
    jest.resetAllMocks();
    process.env.REGISTRATIONS_TABLE = 'Registrations';
  });

  it('rejects non-POST methods', async () => {
    const resp = await handler({ httpMethod: 'GET' } as any);
    expect(resp.statusCode).toBe(405);
  });

  it('validates required fields', async () => {
    const resp = await handler({
      httpMethod: 'POST',
      pathParameters: {},
      body: JSON.stringify({})
    } as any);
    expect(resp.statusCode).toBe(400);
  });

  it('creates registration', async () => {
    sendMock.mockResolvedValue({});
    const resp = await handler({
      httpMethod: 'POST',
      pathParameters: { id: 't1' },
      body: JSON.stringify({ playerId: 'u1', preferredRoles: ['top'] })
    } as any);

    expect(sendMock).toHaveBeenCalledWith(expect.any(PutCommand));
    expect(resp.statusCode).toBe(201);
    const body = JSON.parse(resp.body);
    expect(body.playerId).toBe('u1');
    expect(body.status).toBe('pending');
  });
});

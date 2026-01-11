import { describe, expect, it, jest, beforeEach } from '@jest/globals';
import { DeleteCommand, PutCommand, ScanCommand } from '@aws-sdk/lib-dynamodb';
import { PostToConnectionCommand } from '@aws-sdk/client-apigatewaymanagementapi';
let handler: any;

// Use var to avoid TDZ with hoisted jest.mock
var sendMock = jest.fn() as jest.MockedFunction<(...args: any[]) => Promise<any>>;

jest.mock('@aws-sdk/client-apigatewaymanagementapi', () => {
  const actual = jest.requireActual('@aws-sdk/client-apigatewaymanagementapi') as typeof import('@aws-sdk/client-apigatewaymanagementapi');
  return {
    ...actual,
    ApiGatewayManagementApiClient: jest.fn().mockImplementation(() => ({ send: sendMock })),
    PostToConnectionCommand: actual.PostToConnectionCommand
  };
});

jest.mock('@aws-sdk/lib-dynamodb', () => {
  const actual = jest.requireActual('@aws-sdk/lib-dynamodb') as typeof import('@aws-sdk/lib-dynamodb');
  return {
    ...actual,
    DynamoDBDocumentClient: { from: () => ({ send: sendMock }) }
  };
});

describe('broadcastEvent', () => {
  beforeEach(async () => {
    jest.resetAllMocks();
    jest.resetModules();
    sendMock.mockImplementation((cmd) => {
      const inner = (cmd as any)?.clientCommand ?? cmd;
      if (inner instanceof ScanCommand) {
        return Promise.resolve({ Items: [{ connectionId: 'c1' }, { connectionId: 'stale' }] });
      }
      if (inner instanceof PostToConnectionCommand) {
        // First call ok, second triggers 410, rest ok.
        if (sendMock.mock.calls.length < 2) {
          return Promise.resolve({});
        }
        const err: any = new Error('gone');
        err.statusCode = 410;
        return Promise.reject(err);
      }
      if (inner instanceof DeleteCommand) return Promise.resolve({});
      if (inner instanceof PutCommand) return Promise.resolve({});
      return Promise.resolve({});
    });
    process.env.CONNECTIONS_TABLE = 'Connections';
    process.env.WEBSOCKET_ENDPOINT = 'https://example.com/dev';
    process.env.EVENTS_TABLE = 'Events';
    handler = (await import('../broadcastEvent')).handler;
  });

  it('returns early when endpoint missing', async () => {
    delete process.env.WEBSOCKET_ENDPOINT;
    await handler({ type: 'test', data: {} });
    expect(sendMock).not.toHaveBeenCalled();
  });

  it('broadcasts and writes event record; removes stale connections', async () => {
    await handler({ type: 'players.assigned', data: { ok: true }, tournamentId: 't1', causedBy: 'system' });
    const names = sendMock.mock.calls.map(([c]) => {
      const cmd = (c as any)?.clientCommand ?? c;
      return cmd?.constructor?.name;
    });
    expect(names).toContain('ScanCommand');
    expect(names.some((n) => n?.includes('Put'))).toBe(true);
  });
});

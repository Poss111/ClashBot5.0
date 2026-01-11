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

describe('websocketHandler', () => {
  const baseEvent = {
    requestContext: {
      connectionId: 'conn-1',
      routeKey: '$connect',
      domainName: 'example.com',
      stage: 'dev'
    }
  };

  beforeEach(async () => {
    jest.resetAllMocks();
    process.env.CONNECTIONS_TABLE = 'Connections';
    jest.resetModules();
    sendMock.mockImplementation((cmd) => Promise.resolve({ clientCommand: cmd }));
    const mod = await import('../websocketHandler');
    handler = mod.handler;
  });

  it('handles connect', async () => {
    const resp = await handler(baseEvent as any);
    expect(resp.statusCode).toBe(200);
    expect(sendMock.mock.calls.length).toBeGreaterThan(0);
  });

  it('handles disconnect', async () => {
    const resp = await handler({ ...baseEvent, requestContext: { ...baseEvent.requestContext, routeKey: '$disconnect' } } as any);
    expect(resp.statusCode).toBe(200);
    expect(sendMock.mock.calls.length).toBeGreaterThan(0);
  });

  it('echoes ping with pong', async () => {
    const resp = await handler({
      ...baseEvent,
      requestContext: { ...baseEvent.requestContext, routeKey: '$default' },
      body: JSON.stringify({ type: 'ping' })
    } as any);
    expect(resp.statusCode).toBe(200);
    expect(sendMock.mock.calls.length).toBeGreaterThan(0);
  });

  it('returns 404 for unknown route', async () => {
    const resp = await handler({ ...baseEvent, requestContext: { ...baseEvent.requestContext, routeKey: 'unknown' } } as any);
    expect(resp.statusCode).toBe(404);
  });
});

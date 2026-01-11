import { describe, expect, it, jest, beforeEach } from '@jest/globals';
import { StartExecutionCommand } from '@aws-sdk/client-sfn';
import { InvokeCommand } from '@aws-sdk/client-lambda';
let handler: any;

// Use var to avoid TDZ with hoisted jest.mock
var sendMock = jest.fn() as jest.MockedFunction<(...args: any[]) => Promise<any>>;

jest.mock('@aws-sdk/client-sfn', () => {
  const actual = jest.requireActual('@aws-sdk/client-sfn') as typeof import('@aws-sdk/client-sfn');
  return {
    ...actual,
    SFNClient: jest.fn().mockImplementation(() => ({ send: sendMock })),
    StartExecutionCommand: actual.StartExecutionCommand
  };
});

jest.mock('@aws-sdk/client-lambda', () => {
  const actual = jest.requireActual('@aws-sdk/client-lambda') as typeof import('@aws-sdk/client-lambda');
  return {
    ...actual,
    LambdaClient: jest.fn().mockImplementation(() => ({ send: sendMock })),
    InvokeCommand: actual.InvokeCommand
  };
});

describe('startAssignmentWorkflow', () => {
  beforeEach(async () => {
    jest.resetAllMocks();
    jest.resetModules();
    sendMock.mockImplementation(() => Promise.resolve({ executionArn: 'exec-123' }));
    process.env.STATE_MACHINE_ARN = 'arn:aws:states:region:acct:stateMachine:Test';
    process.env.BROADCAST_FUNCTION_NAME = 'BroadcastFn';
    handler = (await import('../startAssignmentWorkflow')).handler;
  });

  it('returns 400 when tournamentId missing', async () => {
    const resp = await handler({ body: '{}' } as any);
    expect(resp.statusCode).toBe(400);
  });

  it('starts execution and broadcasts event', async () => {
    const resp = await handler({
      body: JSON.stringify({ tournamentId: 't1' }),
      requestContext: { authorizer: { principalId: 'user-1' } }
    } as any);

    expect(sendMock.mock.calls.length).toBeGreaterThanOrEqual(2);
    expect(resp.statusCode).toBe(202);
  });

  it('handles broadcast failure gracefully', async () => {
    sendMock
      .mockResolvedValueOnce({ executionArn: 'exec-123' }) // StartExecution
      .mockRejectedValueOnce(new Error('broadcast failed')) // Invoke broadcast
      .mockResolvedValue({ executionArn: 'exec-123' }); // Any further calls

    const resp = await handler({
      body: JSON.stringify({ tournamentId: 't1' }),
      requestContext: { authorizer: { principalId: 'user-1' } }
    } as any);

    expect(resp.statusCode).toBe(202);
  });
});

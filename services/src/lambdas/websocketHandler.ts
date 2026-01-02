import { ApiGatewayManagementApiClient, PostToConnectionCommand } from '@aws-sdk/client-apigatewaymanagementapi';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, DeleteCommand, ScanCommand } from '@aws-sdk/lib-dynamodb';
import { logInfo, logError } from '../shared/logger';

const ddbClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const connectionsTable = process.env.CONNECTIONS_TABLE!;

interface WebSocketEvent {
  requestContext: {
    connectionId: string;
    routeKey: string;
    domainName: string;
    stage: string;
  };
  body?: string;
}

export const handler = async (event: WebSocketEvent) => {
  const { connectionId, routeKey } = event.requestContext;
  const endpoint = `https://${event.requestContext.domainName}/${event.requestContext.stage}`;
  const apiGatewayClient = new ApiGatewayManagementApiClient({ endpoint });

  logInfo('websocketHandler.received', { connectionId, routeKey, event });

  try {
    switch (routeKey) {
      case '$connect':
        await handleConnect(connectionId);
        return { statusCode: 200, body: JSON.stringify({ message: 'Connected' }) };

      case '$disconnect':
        await handleDisconnect(connectionId);
        return { statusCode: 200, body: JSON.stringify({ message: 'Disconnected' }) };

      case '$default':
        await handleMessage(connectionId, event.body, apiGatewayClient);
        return { statusCode: 200, body: JSON.stringify({ message: 'Message received' }) };

      default:
        logError('websocketHandler.unknownRoute', { routeKey, connectionId });
        return { statusCode: 404, body: JSON.stringify({ message: 'Unknown route' }) };
    }
  } catch (err) {
    logError('websocketHandler.error', { routeKey, connectionId, error: String(err) });
    return { statusCode: 500, body: JSON.stringify({ message: 'Internal server error' }) };
  }
};

async function handleConnect(connectionId: string) {
  await ddbClient.send(
    new PutCommand({
      TableName: connectionsTable,
      Item: {
        connectionId,
        connectedAt: new Date().toISOString(),
        ttl: Math.floor(Date.now() / 1000) + 3600 // 1 hour TTL
      }
    })
  );
  logInfo('websocketHandler.connected', { connectionId });
}

async function handleDisconnect(connectionId: string) {
  await ddbClient.send(
    new DeleteCommand({
      TableName: connectionsTable,
      Key: { connectionId }
    })
  );
  logInfo('websocketHandler.disconnected', { connectionId });
}

async function handleMessage(
  connectionId: string,
  body: string | undefined,
  apiGatewayClient: ApiGatewayManagementApiClient
) {
  try {
    const message = body ? JSON.parse(body) : {};
    
    // Echo back or handle custom messages
    if (message.type === 'ping') {
      await sendMessage(apiGatewayClient, connectionId, { type: 'pong', timestamp: new Date().toISOString() });
    } else {
      await sendMessage(apiGatewayClient, connectionId, {
        type: 'ack',
        message: 'Message received',
        received: message
      });
    }
  } catch (err) {
    logError('websocketHandler.messageError', { connectionId, error: String(err) });
  }
}

export async function sendMessage(
  client: ApiGatewayManagementApiClient,
  connectionId: string,
  data: any
) {
  try {
    await client.send(
      new PostToConnectionCommand({
        ConnectionId: connectionId,
        Data: JSON.stringify(data)
      })
    );
  } catch (err: any) {
    // Connection may have been closed
    if (err.statusCode === 410) {
      // Remove stale connection
      await ddbClient.send(
        new DeleteCommand({
          TableName: connectionsTable,
          Key: { connectionId }
        })
      );
    } else {
      throw err;
    }
  }
}

// Helper function to broadcast to all connections
export async function broadcastToAll(event: any, connectionsTable: string) {
  const ddbClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));
  const endpoint = `https://${event.requestContext.domainName}/${event.requestContext.stage}`;
  const apiGatewayClient = new ApiGatewayManagementApiClient({ endpoint });

  // Get all connections
  const result = await ddbClient.send(new ScanCommand({ TableName: connectionsTable }));
  const connections = result.Items || [];

  // Broadcast to all
  await Promise.allSettled(
    connections.map((item) =>
      sendMessage(apiGatewayClient, item.connectionId, event)
    )
  );

  logInfo('websocketHandler.broadcast', {
    connectionCount: connections.length,
    eventType: event.type
  });
}


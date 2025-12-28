import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, ScanCommand, DeleteCommand } from '@aws-sdk/lib-dynamodb';
import { ApiGatewayManagementApiClient, PostToConnectionCommand } from '@aws-sdk/client-apigatewaymanagementapi';
import { logInfo, logError } from '../shared/logger';

const ddbClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));

interface BroadcastEvent {
  type: string;
  data: any;
  tournamentId?: string;
}

export const handler = async (event: BroadcastEvent) => {
  const connectionsTable = process.env.CONNECTIONS_TABLE!;
  const websocketEndpoint = process.env.WEBSOCKET_ENDPOINT!;

  if (!websocketEndpoint) {
    logError('broadcastEvent.missingEndpoint', {});
    return;
  }

  const apiGatewayClient = new ApiGatewayManagementApiClient({
    endpoint: websocketEndpoint
  });

  try {
    // Get all active connections
    const result = await ddbClient.send(
      new ScanCommand({ TableName: connectionsTable })
    );
    const connections = result.Items || [];

    // Broadcast event to all connections
    const broadcastPromises = connections.map(async (item) => {
      try {
        await apiGatewayClient.send(
          new PostToConnectionCommand({
            ConnectionId: item.connectionId,
            Data: JSON.stringify({
              type: event.type,
              data: event.data,
              tournamentId: event.tournamentId,
              timestamp: new Date().toISOString()
            })
          })
        );
      } catch (err: any) {
        // Remove stale connections (410 Gone)
        if (err.statusCode === 410) {
          await ddbClient.send(
            new DeleteCommand({
              TableName: connectionsTable,
              Key: { connectionId: item.connectionId }
            })
          );
        }
      }
    });

    await Promise.allSettled(broadcastPromises);

    logInfo('broadcastEvent.completed', {
      eventType: event.type,
      connectionCount: connections.length,
      tournamentId: event.tournamentId
    });
  } catch (err) {
    logError('broadcastEvent.failed', {
      error: String(err),
      eventType: event.type
    });
  }
};


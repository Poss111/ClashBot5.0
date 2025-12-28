class WebSocketConfig {
  // Update this with your WebSocket endpoint after deployment
  // Format: wss://{api-id}.execute-api.{region}.amazonaws.com/{stage}
  static const String baseUrl = 'wss://localhost:3000/prod';
  
  // For local development, you might need to use ws:// instead of wss://
  // For production, use the actual WebSocket API endpoint from CloudFormation outputs
}


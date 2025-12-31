#!/usr/bin/env node
import { WebSocketServer } from 'ws';
import http from 'http';

// Simple WebSocket mock that accepts connections and emits sample events.
// Paths: defaults to /events/dev (align with APP_ENV=dev).
// Usage: PORT=4001 WS_PATH=/events/dev node websocket_server.js

const PORT = process.env.PORT ? Number(process.env.PORT) : 4001;
const WS_PATH = process.env.WS_PATH || '/events/dev';

const server = http.createServer();
const wss = new WebSocketServer({ server, path: WS_PATH });

const broadcast = (data) => {
  const msg = JSON.stringify(data);
  for (const client of wss.clients) {
    if (client.readyState === client.OPEN) {
      client.send(msg);
    }
  }
};

wss.on('connection', (ws, req) => {
  console.log(`WS connected: ${req.url}`);
  ws.send(JSON.stringify({ type: 'welcome', message: 'connected to mock ws' }));

  ws.on('message', (msg) => {
    // Echo back whatever client sends for visibility.
    ws.send(JSON.stringify({ type: 'echo', payload: msg.toString() }));
  });
});

// Emit a mock event every 10 seconds.
setInterval(() => {
  broadcast({
    type: 'tournament.update',
    tournamentId: 'tourn-1',
    status: 'OPEN',
    timestamp: new Date().toISOString()
  });
}, 10_000);

server.listen(PORT, () => {
  console.log(`Mock WS listening on ws://localhost:${PORT}${WS_PATH}`);
});


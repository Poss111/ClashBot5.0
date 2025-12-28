import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/websocket_config.dart';

class WebSocketTestScreen extends StatefulWidget {
  const WebSocketTestScreen({super.key});

  @override
  State<WebSocketTestScreen> createState() => _WebSocketTestScreenState();
}

class _WebSocketTestScreenState extends State<WebSocketTestScreen> {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _urlController = TextEditingController(
    text: WebSocketConfig.baseUrl,
  );
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _disconnect();
    _scrollController.dispose();
    _urlController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _connect() {
    if (_isConnected) {
      _addLog('Already connected', isError: true);
      return;
    }

    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _addLog('Please enter a WebSocket URL', isError: true);
      return;
    }

    try {
      _addLog('Connecting to $url...');
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _channel!.stream.listen(
        (message) {
          try {
            final data = json.decode(message as String);
            _addLog('Received: ${json.encode(data)}', isReceived: true);
            setState(() {
              _messages.add({
                'type': 'received',
                'timestamp': DateTime.now(),
                'data': data,
              });
            });
          } catch (e) {
            _addLog('Received (non-JSON): $message', isReceived: true);
            setState(() {
              _messages.add({
                'type': 'received',
                'timestamp': DateTime.now(),
                'data': {'raw': message},
              });
            });
          }
          _scrollToBottom();
        },
        onError: (error) {
          _addLog('Error: $error', isError: true);
          setState(() {
            _isConnected = false;
          });
        },
        onDone: () {
          _addLog('Connection closed', isError: true);
          setState(() {
            _isConnected = false;
          });
        },
      );

      setState(() {
        _isConnected = true;
      });
      _addLog('Connected successfully');
    } catch (e) {
      _addLog('Connection failed: $e', isError: true);
      setState(() {
        _isConnected = false;
      });
    }
  }

  void _disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
    setState(() {
      _isConnected = false;
    });
    _addLog('Disconnected');
  }

  void _sendMessage() {
    if (!_isConnected || _channel == null) {
      _addLog('Not connected', isError: true);
      return;
    }

    final message = _messageController.text.trim();
    if (message.isEmpty) {
      _addLog('Please enter a message', isError: true);
      return;
    }

    try {
      _channel!.sink.add(message);
      _addLog('Sent: $message', isSent: true);
      setState(() {
        _messages.add({
          'type': 'sent',
          'timestamp': DateTime.now(),
          'data': json.decode(message),
        });
      });
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      _addLog('Send failed: $e', isError: true);
    }
  }

  void _sendPing() {
    if (!_isConnected || _channel == null) {
      _addLog('Not connected', isError: true);
      return;
    }

    try {
      final pingMessage = json.encode({'type': 'ping'});
      _channel!.sink.add(pingMessage);
      _addLog('Sent: $pingMessage', isSent: true);
      setState(() {
        _messages.add({
          'type': 'sent',
          'timestamp': DateTime.now(),
          'data': {'type': 'ping'},
        });
      });
      _scrollToBottom();
    } catch (e) {
      _addLog('Send failed: $e', isError: true);
    }
  }

  void _addLog(String message, {bool isError = false, bool isSent = false, bool isReceived = false}) {
    setState(() {
      _messages.add({
        'type': isError ? 'error' : (isSent ? 'sent' : (isReceived ? 'received' : 'log')),
        'timestamp': DateTime.now(),
        'message': message,
      });
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearMessages() {
    setState(() {
      _messages.clear();
    });
  }

  Color _getMessageColor(String type) {
    switch (type) {
      case 'sent':
        return Colors.blue;
      case 'received':
        return Colors.green;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getMessageIcon(String type) {
    switch (type) {
      case 'sent':
        return Icons.arrow_upward;
      case 'received':
        return Icons.arrow_downward;
      case 'error':
        return Icons.error;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connection Status
          Card(
            color: _isConnected ? Colors.green.shade50 : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.check_circle : Icons.cancel,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isConnected ? 'Connected' : 'Disconnected',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _isConnected ? Colors.green.shade900 : Colors.red.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // URL Input
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: 'WebSocket URL',
              hintText: 'wss://...',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  _urlController.text = WebSocketConfig.baseUrl;
                },
                tooltip: 'Reset to default',
              ),
            ),
            enabled: !_isConnected,
          ),
          const SizedBox(height: 16),

          // Connection Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isConnected ? null : _connect,
                  icon: const Icon(Icons.link),
                  label: const Text('Connect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isConnected ? _disconnect : null,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quick Actions
          if (_isConnected) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _sendPing,
                          icon: const Icon(Icons.send),
                          label: const Text('Send Ping'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _clearMessages,
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Clear Logs'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Message Input
          if (_isConnected) ...[
            TextField(
              controller: _messageController,
              decoration: InputDecoration(
                labelText: 'Message (JSON)',
                hintText: '{"type": "ping"}',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ),
              maxLines: 3,
              onSubmitted: (_) => _sendMessage(),
            ),
            const SizedBox(height: 16),
          ],

          // Messages Log
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Messages (${_messages.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_messages.isNotEmpty)
                        TextButton.icon(
                          onPressed: _clearMessages,
                          icon: const Icon(Icons.clear_all, size: 16),
                          label: const Text('Clear'),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                SizedBox(
                  height: 400,
                  child: _messages.isEmpty
                      ? Center(
                          child: Text(
                            'No messages yet',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final type = message['type'] as String;
                            final timestamp = message['timestamp'] as DateTime;
                            final data = message['data'] ?? message['message'];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: _getMessageColor(type).withOpacity(0.1),
                              child: ListTile(
                                leading: Icon(
                                  _getMessageIcon(type),
                                  color: _getMessageColor(type),
                                ),
                                title: Text(
                                  type.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _getMessageColor(type),
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      data is Map
                                          ? json.encode(data)
                                          : data.toString(),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


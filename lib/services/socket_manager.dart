import 'dart:async';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum SocketState { connecting, connected, disconnected, error }

class WebSocketManager {
  WebSocketChannel? _channel;
  SocketState _state = SocketState.disconnected;
  Timer? _reconnectionTimer;
  final String _url;
  final Function(dynamic) onMessage;
  final Function(SocketState) onStateChange;

  WebSocketManager(this._url,
      {required this.onMessage, required this.onStateChange});

  SocketState get state => _state;

  Future<void> connect() async {
    if (_state == SocketState.connected || _state == SocketState.connecting)
      return;

    _updateState(SocketState.connecting);
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_url));
      _channel!.stream.listen(
        (message) {
          onMessage(message);
        },
        onDone: _handleDisconnection,
        onError: (error) {
          debugPrint("WebSocket error: $error");
          _handleDisconnection();
        },
      );
      _updateState(SocketState.connected);
    } catch (e) {
      debugPrint("Failed to connect to WebSocket: $e");
      _handleDisconnection();
    }
  }

  void _handleDisconnection() {
    _updateState(SocketState.disconnected);
    _scheduleReconnection();
  }

  void _scheduleReconnection() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer(const Duration(seconds: 5), connect);
  }

  void _updateState(SocketState newState) {
    _state = newState;
    onStateChange(_state);
  }

  void send(dynamic data) {
    if (_state == SocketState.connected) {
      _channel?.sink.add(data);
    } else {
      debugPrint("Cannot send data. WebSocket is not connected.");
    }
  }

  void dispose() {
    _reconnectionTimer?.cancel();
    _channel?.sink.close();
  }
}

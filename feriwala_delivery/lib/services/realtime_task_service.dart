import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_service.dart';

class RealtimeTaskService {
  RealtimeTaskService._();
  static final RealtimeTaskService instance = RealtimeTaskService._();

  io.Socket? _socket;

  void connect({required String token, required void Function() onTaskEvent}) {
    _socket?.dispose();

    _socket = io.io(
      DeliveryApiService.baseUrl.replaceAll('/api', ''),
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {});
    _socket!.on('task_assigned', (_) => onTaskEvent());
    _socket!.on('task_updated', (_) => onTaskEvent());
    _socket!.on('delivery_task_update', (_) => onTaskEvent());
    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}

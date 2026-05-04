import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_service.dart';

abstract class RealtimeSocket {
  void onConnect(void Function(dynamic) handler);
  void on(String event, void Function(dynamic) handler);
  void connect();
  void disconnect();
  void dispose();
}

class IoRealtimeSocket implements RealtimeSocket {
  final io.Socket socket;
  IoRealtimeSocket(this.socket);

  @override
  void connect() => socket.connect();

  @override
  void disconnect() => socket.disconnect();

  @override
  void dispose() => socket.dispose();

  @override
  void on(String event, void Function(dynamic p1) handler) => socket.on(event, handler);

  @override
  void onConnect(void Function(dynamic p1) handler) => socket.onConnect(handler);
}

class RealtimeTaskService {
  RealtimeTaskService._();
  static final RealtimeTaskService instance = RealtimeTaskService._();

  RealtimeSocket? _socket;
  RealtimeSocket Function(String url, Map<String, dynamic> options)? socketFactory;

  void connect({required String token, required void Function(int? sequence) onTaskEvent}) {
    _socket?.dispose();

    final url = DeliveryApiService.baseUrl.replaceAll('/api', '');
    final options = io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().setAuth({'token': token}).build();
    _socket = (socketFactory ?? (u, o) => IoRealtimeSocket(io.io(u, o)))(url, options);

    _socket!.onConnect((_) {});
    _socket!.on('task_assigned', (payload) => onTaskEvent(_extractSequence(payload)));
    _socket!.on('task_updated', (payload) => onTaskEvent(_extractSequence(payload)));
    _socket!.on('delivery_task_update', (payload) => onTaskEvent(_extractSequence(payload)));
    _socket!.connect();
  }

  int? _extractSequence(dynamic payload) {
    if (payload is Map && payload['sequence'] is num) {
      return (payload['sequence'] as num).toInt();
    }
    if (payload is Map && payload['version'] is num) {
      return (payload['version'] as num).toInt();
    }
    return null;
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}

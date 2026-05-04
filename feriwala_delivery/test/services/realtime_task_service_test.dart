import 'package:flutter_test/flutter_test.dart';
import 'package:feriwala_delivery/services/realtime_task_service.dart';

class FakeRealtimeSocket implements RealtimeSocket {
  final Map<String, void Function(dynamic)> handlers = {};
  bool connected = false;
  bool disconnected = false;
  bool disposed = false;

  @override
  void connect() => connected = true;

  @override
  void disconnect() => disconnected = true;

  @override
  void dispose() => disposed = true;

  @override
  void on(String event, void Function(dynamic p1) handler) => handlers[event] = handler;

  @override
  void onConnect(void Function(dynamic p1) handler) => handlers['connect'] = handler;

  void emit(String event) => handlers[event]?.call(null);
}

void main() {
  test('connect subscribes and triggers callback on task events', () {
    final service = RealtimeTaskService.instance;
    final socket = FakeRealtimeSocket();
    service.socketFactory = (_, __) => socket;

    var callbackCount = 0;
    service.connect(token: 't', onTaskEvent: () => callbackCount++);

    expect(socket.connected, true);
    socket.emit('task_assigned');
    socket.emit('task_updated');
    expect(callbackCount, 2);

    service.disconnect();
    expect(socket.disconnected, true);
    expect(socket.disposed, true);
  });
}

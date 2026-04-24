import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/app_config.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;

  void connect() {
    if (_socket != null) return;

    _socket = IO.io(AppConfig.socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket!.onConnect((_) => print('Socket connected'));
    _socket!.onDisconnect((_) => print('Socket disconnected'));
  }

  void joinCustomerRoom(String customerId) {
    _socket?.emit('join_customer', customerId);
  }

  void onOrderStatus(Function(dynamic) callback) {
    _socket?.on('order_status', callback);
  }

  void onDeliveryStatus(Function(dynamic) callback) {
    _socket?.on('delivery_status', callback);
  }

  void onAgentLocation(Function(dynamic) callback) {
    _socket?.on('agent_location_update', callback);
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class ShopSocketService {
  static final ShopSocketService _instance = ShopSocketService._internal();
  factory ShopSocketService() => _instance;
  ShopSocketService._internal();

  io.Socket? _socket;
  bool _connected = false;
  final _connectionStateController = StreamController<bool>.broadcast();

  Stream<bool> get connectionStateStream => _connectionStateController.stream;
  bool get isConnected => _connected;

  Future<void> connect({required int shopId}) async {
    if (_socket != null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('shop_access_token');
    final socketBaseUrl = 'https://api.feriwala.in';

    _socket = io.io(
      socketBaseUrl,
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        if (token != null) 'auth': {'token': token},
      },
    );

    _socket!.onConnect((_) {
      _connected = true;
      _connectionStateController.add(true);
      _socket!.emit('join_shop', {'shopId': shopId});
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      _connectionStateController.add(false);
    });
  }

  void onNewOrder(void Function(dynamic) callback) => _socket?.on('shop:new_order', callback);
  void onOrderUpdated(void Function(dynamic) callback) => _socket?.on('shop:order_status_changed', callback);
  void onDeliveryUpdated(void Function(dynamic) callback) => _socket?.on('shop:delivery_task_updated', callback);

  void offAllListeners() {
    _socket?.off('shop:new_order');
    _socket?.off('shop:order_status_changed');
    _socket?.off('shop:delivery_task_updated');
  }

  void dispose() {
    offAllListeners();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
    _connectionStateController.add(false);
  }
}

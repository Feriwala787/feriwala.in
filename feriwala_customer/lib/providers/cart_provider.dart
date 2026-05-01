import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../services/analytics_service.dart';

class CartItem {
  final int productId;
  final String name;
  final double price;
  final String? image;
  final String? size;
  final String? color;
  int quantity;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    this.image,
    this.size,
    this.color,
    this.quantity = 1,
  });

  double get total => price * quantity;

  Map<String, dynamic> toOrderItem() => {
        'productId': productId,
        'quantity': quantity,
        if (size != null) 'size': size,
        if (color != null) 'color': color,
      };
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cart_state');
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _shopId = map['shopId'] as int?;
      _promoCode = map['promoCode'] as String?;
      _discount = (map['discount'] as num?)?.toDouble() ?? 0;
      final items = (map['items'] as List? ?? []);
      _items.clear();
      for (final i in items) {
        _items.add(CartItem(
          productId: i['productId'],
          name: i['name'],
          price: (i['price'] as num).toDouble(),
          image: i['image'],
          size: i['size'],
          color: i['color'],
          quantity: i['quantity'] ?? 1,
        ));
      }
      notifyListeners();
    } catch (_) {
      await prefs.remove('cart_state');
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final map = {
      'shopId': _shopId,
      'promoCode': _promoCode,
      'discount': _discount,
      'items': _items.map((i) => {
        'productId': i.productId,
        'name': i.name,
        'price': i.price,
        'image': i.image,
        'size': i.size,
        'color': i.color,
        'quantity': i.quantity,
      }).toList(),
    };
    await prefs.setString('cart_state', jsonEncode(map));
  }
  int? _shopId;
  String? _promoCode;
  double _discount = 0;

  List<CartItem> get items => List.unmodifiable(_items);
  int? get shopId => _shopId;
  String? get promoCode => _promoCode;
  double get discount => _discount;

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => _items.fold(0, (sum, item) => sum + item.total);

  double get total => subtotal - _discount;

  void addItem(CartItem item, int shopId) {
    if (_shopId != null && _shopId != shopId) {
      _items.clear();
      _promoCode = null;
      _discount = 0;
    }
    _shopId = shopId;

    final existingIndex = _items.indexWhere(
      (i) => i.productId == item.productId && i.size == item.size && i.color == item.color,
    );

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += item.quantity;
    } else {
      _items.add(item);
    }
    AnalyticsService().track('add_to_cart', props: {
      'productId': item.productId,
      'shopId': shopId,
      'quantity': item.quantity,
      'hasSize': item.size != null,
      'hasColor': item.color != null,
    });
    notifyListeners();
    _persist();
  }

  void updateQuantity(int index, int quantity) {
    if (quantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index].quantity = quantity;
    }
    if (_items.isEmpty) {
      _shopId = null;
      _promoCode = null;
      _discount = 0;
    }
    notifyListeners();
    _persist();
  }

  void removeItem(int index) {
    _items.removeAt(index);
    if (_items.isEmpty) {
      _shopId = null;
      _promoCode = null;
      _discount = 0;
    }
    notifyListeners();
    _persist();
  }

  Future<void> applyPromo(String code) async {
    if (_shopId == null) return;
    try {
      final res = await ApiService().post('/promos/validate', body: {
        'code': code,
        'shopId': _shopId,
        'orderAmount': subtotal,
      });
      _promoCode = code;
      _discount = (res['data']['calculatedDiscount'] as num).toDouble();
      notifyListeners();
      _persist();
    } catch (e) {
      _promoCode = null;
      _discount = 0;
      notifyListeners();
      _persist();
      rethrow;
    }
  }

  void clearCart() {
    _items.clear();
    _shopId = null;
    _promoCode = null;
    _discount = 0;
    notifyListeners();
    _persist();
  }
}

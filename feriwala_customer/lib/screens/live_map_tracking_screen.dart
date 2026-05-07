import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:amazon_location_flutter/amazon_location_flutter.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';

class LiveMapTrackingScreen extends StatefulWidget {
  final int orderId;

  const LiveMapTrackingScreen({super.key, required this.orderId});

  @override
  State<LiveMapTrackingScreen> createState() => _LiveMapTrackingScreenState();
}

class _LiveMapTrackingScreenState extends State<LiveMapTrackingScreen> {
  Timer? _timer;
  Map<String, dynamic>? _orderData;
  Position? _userPosition;
  bool _loading = true;
  AmazonLocationClient? _locationClient;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadOrderData();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _loadOrderData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    if (AppConfig.awsLocationApiKey.isEmpty) return;
    try {
      _locationClient = AmazonLocationClient(
        apiKey: AppConfig.awsLocationApiKey,
        region: AppConfig.awsRegion,
      );
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => _userPosition = pos);
      }
    } catch (_) {}
  }

  Future<void> _loadOrderData() async {
    try {
      final res = await ApiService().get('/orders/${widget.orderId}');
      if (mounted) setState(() {
        _orderData = res['data'];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double? _calculateDistance(double? lat1, double? lon1, double? lat2, double? lon2) {
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) return null;
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live Tracking')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final deliveryTasks = (_orderData?['deliveryTasks'] as List?) ?? [];
    final activeTask = deliveryTasks.isNotEmpty ? deliveryTasks.first : null;
    final agentLat = activeTask?['agentLocation']?['latitude'] as double?;
    final agentLng = activeTask?['agentLocation']?['longitude'] as double?;
    final shopLat = _orderData?['shop']?['latitude'] as double?;
    final shopLng = _orderData?['shop']?['longitude'] as double?;
    final userLat = _userPosition?.latitude ?? _orderData?['deliveryAddress']?['latitude'] as double?;
    final userLng = _userPosition?.longitude ?? _orderData?['deliveryAddress']?['longitude'] as double?;

    final distToAgent = _calculateDistance(userLat, userLng, agentLat, agentLng);
    final agentToShop = _calculateDistance(agentLat, agentLng, shopLat, shopLng);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Live Tracking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map placeholder (AWS Location Service integration)
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map, size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'Live Map View',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'AWS Location Service',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (agentLat != null && agentLng != null)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 8),
                            SizedBox(width: 6),
                            Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Distance cards
            if (distToAgent != null || agentToShop != null)
              Row(
                children: [
                  if (distToAgent != null)
                    Expanded(
                      child: _DistanceCard(
                        icon: Icons.delivery_dining,
                        label: 'Agent to You',
                        distance: distToAgent,
                        color: Colors.blue,
                      ),
                    ),
                  if (distToAgent != null && agentToShop != null) const SizedBox(width: 12),
                  if (agentToShop != null)
                    Expanded(
                      child: _DistanceCard(
                        icon: Icons.store,
                        label: 'Agent to Shop',
                        distance: agentToShop,
                        color: Colors.orange,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 16),

            // Order status
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order #${_orderData?['orderNumber'] ?? ''}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(_orderData?['status']).withAlpha(30),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _formatStatus(_orderData?['status']),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(_orderData?['status']),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (activeTask != null) ...[
                      _InfoRow(Icons.person, 'Agent', activeTask['agentName'] ?? 'Assigned'),
                      if (activeTask['agentPhone'] != null)
                        _InfoRow(Icons.phone, 'Contact', activeTask['agentPhone']),
                    ],
                    _InfoRow(Icons.store, 'Shop', _orderData?['shop']?['name'] ?? ''),
                    _InfoRow(Icons.location_on, 'Delivery', _orderData?['deliveryAddress']?['addressLine1'] ?? ''),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ETA card
            if (activeTask != null)
              Card(
                elevation: 1,
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.blue.shade700, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estimated Delivery',
                              style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '25-45 minutes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'delivered':
        return Colors.green;
      case 'out_for_delivery':
      case 'picked_up':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _formatStatus(String? status) {
    return (status ?? '').replaceAll('_', ' ').toUpperCase();
  }
}

class _DistanceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final double distance;
  final Color color;

  const _DistanceCard({
    required this.icon,
    required this.label,
    required this.distance,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              '${distance.toStringAsFixed(1)} km',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

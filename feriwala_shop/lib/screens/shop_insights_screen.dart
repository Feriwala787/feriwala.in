import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shop_auth_provider.dart';
import '../services/api_service.dart';

class ShopInsightsScreen extends StatefulWidget {
  const ShopInsightsScreen({super.key});

  @override
  State<ShopInsightsScreen> createState() => _ShopInsightsScreenState();
}

class _ShopInsightsScreenState extends State<ShopInsightsScreen> {
  bool _loading = true;
  Map<String, dynamic> _insights = {};

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    final shopId = context.read<ShopAuthProvider>().shopId;
    if (shopId == null) return;
    try {
      final stats = await ShopApiService().get('/shops/$shopId/stats');
      final orders = await ShopApiService().get('/orders/shop/$shopId', queryParams: {'limit': '200'});
      final products = await ShopApiService().get('/products', queryParams: {'shopId': '$shopId', 'limit': '200'});
      final data = (orders['data'] ?? []) as List<dynamic>;
      final productsData = (products['data'] ?? []) as List<dynamic>;
      final hourly = <int, int>{};
      final skuCount = <String, int>{};
      int cancelled = 0;
      final cancelReasons = <String, int>{};
      final prepDurations = <int>[];
      double promoDiscountTotal = 0;
      double promoOrderTotal = 0;
      for (final o in data) {
        final dt = DateTime.tryParse((o['createdAt'] ?? '').toString());
        if (dt != null) hourly[dt.hour] = (hourly[dt.hour] ?? 0) + 1;
        if (o['status'] == 'cancelled') {
          cancelled++;
          final reason = (o['cancelReason'] ?? 'unknown').toString();
          cancelReasons[reason] = (cancelReasons[reason] ?? 0) + 1;
        }
        final prep = (o['preparationMinutes'] ?? o['prepMinutes']);
        if (prep is num) prepDurations.add(prep.toInt());
        if ((o['discount'] ?? 0) is num && (o['total'] ?? 0) is num) {
          promoDiscountTotal += (o['discount'] as num).toDouble();
          promoOrderTotal += (o['total'] as num).toDouble();
        }
        final items = (o['items'] as List?) ?? const [];
        for (final i in items) {
          final sku = (i['sku'] ?? i['productName'] ?? 'Unknown').toString();
          skuCount[sku] = (skuCount[sku] ?? 0) + ((i['quantity'] ?? 0) as int);
        }
      }
      final topSkus = skuCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      prepDurations.sort();
      int percentile(List<int> values, double p) => values.isEmpty ? -1 : values[(values.length * p).floor().clamp(0, values.length - 1)];
      final p50 = percentile(prepDurations, 0.50);
      final p90 = percentile(prepDurations, 0.90);

      double lowStockRisk = 0;
      for (final p in productsData) {
        final inv = (p['inventory'] as List?)?.isNotEmpty == true ? p['inventory'][0] : null;
        final qty = (inv?['quantity'] ?? 0) as num;
        final threshold = (inv?['lowStockThreshold'] ?? 5) as num;
        if (qty <= threshold) {
          final price = (p['price'] ?? 0) as num;
          lowStockRisk += price * (threshold - qty + 1);
        }
      }

      if (!mounted) return;
      setState(() {
        _insights = {
          'stats': stats['data'] ?? {},
          'hourly': hourly,
          'cancelled': cancelled,
          'cancelReasons': cancelReasons,
          'p50Prep': p50,
          'p90Prep': p90,
          'promoRoi': promoOrderTotal <= 0 ? 0 : ((promoOrderTotal - promoDiscountTotal) / promoOrderTotal) * 100,
          'lowStockRisk': lowStockRisk,
          'totalOrders': data.length,
          'topSkus': topSkus.take(5).toList(),
        };
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shop Insights')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInsights,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Hourly Order Trend', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...(_insights['hourly'] as Map<int, int>? ?? {}).entries.map((e) => ListTile(
                        dense: true,
                        title: Text('${e.key.toString().padLeft(2, '0')}:00'),
                        trailing: Text('${e.value} orders'),
                      )),
                  const Divider(),
                  ListTile(title: const Text('Cancel/Reject Rate'), trailing: Text('${_insights['cancelled'] ?? 0}/${_insights['totalOrders'] ?? 0}')),
                  ListTile(title: const Text('Avg Prep Time'), trailing: Text('${_insights['stats']?['avgPreparationMinutes'] ?? '-'} min')),
                  ListTile(title: const Text('Prep Time P50'), trailing: Text('${_insights['p50Prep'] ?? '-'} min')),
                  ListTile(title: const Text('Prep Time P90'), trailing: Text('${_insights['p90Prep'] ?? '-'} min')),
                  ListTile(title: const Text('Promo ROI (est.)'), trailing: Text('${((_insights['promoRoi'] ?? 0) as num).toStringAsFixed(1)}%')),
                  ListTile(title: const Text('Low-stock lost-sales risk'), trailing: Text('INR ${((_insights['lowStockRisk'] ?? 0) as num).toStringAsFixed(0)}')),
                  const SizedBox(height: 8),
                  Text('Cancel/Reject Reasons', style: Theme.of(context).textTheme.titleMedium),
                  ...(_insights['cancelReasons'] as Map<String, int>? ?? {}).entries.map((e) => ListTile(
                        dense: true,
                        title: Text(e.key),
                        trailing: Text('${e.value}'),
                      )),
                  const Divider(),
                  Text('Top Selling SKUs', style: Theme.of(context).textTheme.titleMedium),
                  ...(_insights['topSkus'] as List? ?? []).map((e) => ListTile(title: Text('${e.key}'), trailing: Text('Qty ${e.value}'))),
                ],
              ),
            ),
    );
  }
}

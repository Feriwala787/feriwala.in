import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _homeFeed;
  List<dynamic> _browseProducts = [];
  List<dynamic> _nearbyWarehouses = [];
  Position? _currentPosition;
  String _locationLabel = 'Detecting location...';
  bool _locationDenied = false;
  bool _loading = true;
  bool _productLoading = false;
  final _searchController = TextEditingController();
  bool _searchActive = false;
  String? _selectedProductType;
  String _selectedGender = 'men';
  Map<String, dynamic>? _selectedWarehouse;
  List<Map<String, dynamic>> _recentProducts = [];
  int _page = 1;
  bool _hasMore = true;
  Timer? _debounce;

  static const _kOrange = Color(0xFFF47721);
  static const _maxDistKm = 10.0;

  static const _productTypes = [
    'T-Shirt','Shirt','Jeans','Kurta','Dress','Shorts',
    'Jacket','Hoodie','Trousers','Leggings','Saree','Footwear',
  ];

  static const _tagSections = [
    {'title': '🔥 Best Sellers',   'keys': ['party','gown','dress'], 'badge': 'hot'},
    {'title': '💰 50% Off',        'keys': ['casual'],              'badge': 'sale'},
    {'title': '✨ New Arrivals',   'keys': ['gym','active','sports'],'badge': 'new'},
    {'title': '🎉 Party Wear',    'keys': ['summer','cotton','lightweight'], 'badge': null},
    {'title': '🕉️ Ethnic',        'keys': ['ethnic','kurta','saree'], 'badge': null},
    {'title': '👔 Formal',        'keys': ['formal','office','blazer'], 'badge': null},
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await Future.wait([_loadHomeFeed(), _loadRecent(), _loadLocation()]);
    await _loadProducts(reset: true);
  }

  Future<void> _loadHomeFeed() async {
    try {
      final res = await ApiService().get('/customers/home-feed');
      if (mounted) setState(() { _homeFeed = res['data']; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getStringList('recent_products') ?? [];
    final parsed = items.map((e) {
      try { return jsonDecode(e) as Map<String, dynamic>; } catch (_) { return <String, dynamic>{}; }
    }).where((e) => e.isNotEmpty).toList();
    if (mounted) setState(() => _recentProducts = parsed);
  }

  Future<void> _loadLocation() async {
    await Permission.notification.request();
    final svcEnabled = await Geolocator.isLocationServiceEnabled();
    if (!svcEnabled) {
      if (mounted) setState(() { _locationLabel = 'Location off'; _locationDenied = true; });
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      if (mounted) setState(() { _locationLabel = 'Allow location'; _locationDenied = true; });
      return;
    }
    if (mounted) setState(() { _locationLabel = 'Detecting...'; _locationDenied = false; });
    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
    if (!mounted) return;
    setState(() => _currentPosition = pos);
    // Reverse geocode to get readable address
    final geo = await LocationService.geocode('${pos.latitude},${pos.longitude}');
    if (mounted) {
      setState(() {
        if (geo != null) {
          final parts = geo.label.split(',').map((e) => e.trim()).toList();
          _locationLabel = parts.take(2).join(', ');
        } else {
          _locationLabel = '${pos.latitude.toStringAsFixed(3)}, ${pos.longitude.toStringAsFixed(3)}';
        }
      });
    }
    await _loadWarehouses();
  }

  Future<void> _refreshLocation() async {
    setState(() { _locationLabel = 'Detecting...'; _locationDenied = false; });
    await _loadLocation();
  }

  Future<void> _loadWarehouses() async {
    if (_currentPosition == null) return;
    try {
      final res = await ApiService().get('/shops', queryParams: {'limit': '100'});
      final shops = (res['data'] as List? ?? []).cast<dynamic>();
      final nearby = shops.where((s) {
        final d = _dist(s); return d != null && d <= _maxDistKm;
      }).toList()..sort((a, b) => (_dist(a) ?? 9999).compareTo(_dist(b) ?? 9999));
      if (mounted) {
        setState(() {
          _nearbyWarehouses = nearby;
          _selectedWarehouse = nearby.isNotEmpty ? nearby.first as Map<String, dynamic> : null;
        });
      }
    } catch (_) {}
  }

  double? _dist(dynamic shop) {
    if (_currentPosition == null) return null;
    final lat = double.tryParse((shop['latitude'] ?? '').toString());
    final lng = double.tryParse((shop['longitude'] ?? '').toString());
    if (lat == null || lng == null) return null;
    return Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, lat, lng) / 1000;
  }

  Future<void> _loadProducts({bool reset = false}) async {
    if (reset) { _page = 1; _hasMore = true; }
    setState(() => _productLoading = true);
    try {
      final params = <String, String>{'limit': '30', 'page': '$_page', 'gender': _selectedGender};
      if (_selectedProductType != null) params['productType'] = _selectedProductType!;
      if (_selectedWarehouse != null) params['shopId'] = '${_selectedWarehouse!['id']}';
      final q = _searchController.text.trim();
      if (q.isNotEmpty) params['search'] = q;
      final res = await ApiService().get('/products', queryParams: params);
      final list = (res['data'] as List? ?? []).whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList();
      if (mounted) {
        setState(() {
          _browseProducts = reset ? list : [..._browseProducts, ...list];
          _hasMore = list.length >= 30;
        });
      }
    } catch (_) {
      if (mounted) setState(() { if (reset) _browseProducts = []; });
    } finally {
      if (mounted) setState(() => _productLoading = false);
    }
  }

  List<Map<String, dynamic>> _sectionProducts(List<String> keys) {
    return _browseProducts.whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .where((p) {
          final text = '${p['name']} ${p['description']} ${p['category']?['name'] ?? ''} ${(p['tags'] as List? ?? []).join(' ')}'.toLowerCase();
          return keys.any((k) => text.contains(k));
        }).take(10).toList();
  }

  List<Map<String, dynamic>> _personalizedProducts() {
    if (_recentProducts.isEmpty) {
      return _browseProducts.take(10).whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList();
    }
    final recentIds = _recentProducts.map((e) => e['id']).toSet();
    final recentTypes = _recentProducts.map((e) => (e['productType'] ?? '')).toSet();
    return _browseProducts.whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .where((p) => !recentIds.contains(p['id']) && recentTypes.contains(p['attributes']?['productType'] ?? ''))
        .take(10).toList();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _loadProducts(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: _searchActive
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search clothes, shoes...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                ),
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _loadProducts(reset: true),
              )
            : const Text('feriwala', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: _kOrange, letterSpacing: -0.5)),
        actions: [
          IconButton(
            icon: Icon(_searchActive ? Icons.close : Icons.search, color: Colors.black87),
            onPressed: () {
              setState(() {
                _searchActive = !_searchActive;
                if (!_searchActive) { _searchController.clear(); _loadProducts(reset: true); }
              });
            },
          ),
          Stack(children: [
            IconButton(
              icon: const Icon(Icons.shopping_bag_outlined, color: Colors.black87),
              onPressed: () => Navigator.pushNamed(context, '/cart'),
            ),
            if (cart.itemCount > 0) Positioned(
              right: 6, top: 6,
              child: Container(
                width: 16, height: 16,
                decoration: const BoxDecoration(color: _kOrange, shape: BoxShape.circle),
                child: Center(child: Text('${cart.itemCount}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
              ),
            ),
          ]),
          if (!auth.isAuthenticated)
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/login', arguments: '/home'),
              child: const Text('Login', style: TextStyle(color: _kOrange, fontWeight: FontWeight.w600)),
            )
          else
            IconButton(
              icon: const Icon(Icons.person_outline, color: Colors.black87),
              onPressed: () => Navigator.pushNamed(context, '/profile'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _init(),
              child: CustomScrollView(
                slivers: [
                  // Location bar
                  SliverToBoxAdapter(child: _locationBar()),
                  // Location permission banner
                  if (_locationDenied) SliverToBoxAdapter(child: _locationPermissionBanner()),
                  // Gender tabs
                  SliverToBoxAdapter(child: _genderTabs()),
                  // Product type chips
                  SliverToBoxAdapter(child: _productTypeChips()),
                  // Recently viewed
                  if (_recentProducts.isNotEmpty)
                    SliverToBoxAdapter(child: _sectionRow(
                      'Recently Viewed',
                      _recentProducts.map((p) => _toMap(p)).toList(),
                      searchKeys: [],
                    )),
                  // Personalized
                  if (_personalizedProducts().isNotEmpty)
                    SliverToBoxAdapter(child: _sectionRow(
                      'Picked for You',
                      _personalizedProducts(),
                      searchKeys: [],
                    )),
                  // Tag sections
                  ..._tagSections.map((s) {
                    final products = _sectionProducts((s['keys'] as List).cast<String>());
                    if (products.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    return SliverToBoxAdapter(child: _sectionRow(
                      s['title'] as String,
                      products,
                      searchKeys: (s['keys'] as List).cast<String>(),
                    ));
                  }),
                  // Browse grid header
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                    child: Row(children: [
                      Text(
                        _selectedProductType != null ? _selectedProductType! : 'All Products',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (_productLoading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    ]),
                  )),
                  // Product grid
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _ProductCard(product: _browseProducts[i] as Map<String, dynamic>),
                        childCount: _browseProducts.length,
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                    ),
                  ),
                  if (_hasMore) SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutlinedButton(
                      onPressed: _productLoading ? null : () { _page++; _loadProducts(); },
                      child: const Text('Load more'),
                    ),
                  )),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
      floatingActionButton: cart.itemCount > 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(context, '/cart'),
              backgroundColor: _kOrange,
              icon: const Icon(Icons.shopping_bag, color: Colors.white),
              label: Text('₹${cart.total.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) Navigator.pushNamed(context, '/orders');
          if (i == 2) Navigator.pushNamed(context, '/profile');
        },
        selectedItemColor: _kOrange,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _locationBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: _kOrange, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: _nearbyWarehouses.isNotEmpty ? _pickWarehouse : _refreshLocation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Delivering to', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _locationLabel,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_selectedWarehouse != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _kOrange.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.store, size: 12, color: _kOrange),
                  const SizedBox(width: 4),
                  Text(
                    (_selectedWarehouse!['name'] as String? ?? '').split(' ').first,
                    style: const TextStyle(fontSize: 11, color: _kOrange, fontWeight: FontWeight.w600),
                  ),
                  if (_dist(_selectedWarehouse) != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      '${_dist(_selectedWarehouse)!.toStringAsFixed(1)}km',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _refreshLocation,
            child: const Icon(Icons.my_location, size: 18, color: _kOrange),
          ),
        ],
      ),
    );
  }

  Widget _locationPermissionBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Enable location for faster delivery & nearby stores',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
          TextButton(
            onPressed: () async {
              final perm = await Geolocator.checkPermission();
              if (perm == LocationPermission.deniedForever) {
                await openAppSettings();
              } else {
                await _refreshLocation();
              }
            },
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('Enable', style: TextStyle(color: _kOrange, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _toMap(dynamic p) {
    if (p is Map<String, dynamic>) return p;
    if (p is Map) return p.map((k, v) => MapEntry(k.toString(), v));
    return {};
  }

  Widget _genderTabs() {
    final genders = [('Men', 'men'), ('Women', 'women'), ('Kids', 'kids')];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: genders.map((g) {
        final selected = _selectedGender == g.$2;
        return Expanded(child: GestureDetector(
          onTap: () { setState(() => _selectedGender = g.$2); _loadProducts(reset: true); },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? _kOrange : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(g.$1, textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                color: selected ? Colors.white : Colors.black87)),
          ),
        ));
      }).toList()),
    );
  }

  Widget _productTypeChips() {
    return Container(
      color: Colors.white,
      height: 44,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _typeChip('All', null),
          ..._productTypes.map((t) => _typeChip(t, t)),
        ],
      ),
    );
  }

  Widget _typeChip(String label, String? value) {
    final selected = _selectedProductType == value;
    return GestureDetector(
      onTap: () { setState(() => _selectedProductType = value); _loadProducts(reset: true); },
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? _kOrange : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _kOrange : Colors.transparent, width: 1.5),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: selected ? Colors.white : Colors.black87,
        )),
      ),
    );
  }

  Widget _sectionRow(String title, List<Map<String, dynamic>> products, {required List<String> searchKeys}) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/category-products', arguments: {'title': title, 'searchKeys': searchKeys}),
            child: const Row(children: [
              Text('See all', style: TextStyle(fontSize: 12, color: _kOrange, fontWeight: FontWeight.w500)),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, size: 12, color: _kOrange),
            ]),
          ),
        ]),
      ),
      SizedBox(
        height: 210,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: products.length,
          itemBuilder: (_, i) => _ProductCard(product: products[i], compact: true),
        ),
      ),
    ]);
  }

  void _pickWarehouse() {
    if (_nearbyWarehouses.isEmpty) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(padding: EdgeInsets.all(16), child: Text('Select Store', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        ..._nearbyWarehouses.map((w) {
          final d = _dist(w);
          final sel = _selectedWarehouse?['id'] == w['id'];
          return ListTile(
            leading: const Icon(Icons.store, color: _kOrange),
            title: Text(w['name'] ?? ''),
            subtitle: Text(d != null ? '${d.toStringAsFixed(1)} km away' : ''),
            trailing: sel ? const Icon(Icons.check_circle, color: _kOrange) : null,
            onTap: () {
              setState(() => _selectedWarehouse = w as Map<String, dynamic>);
              Navigator.pop(context);
              _loadProducts(reset: true);
            },
          );
        }),
      ])),
    );
  }
}



class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final bool compact;
  const _ProductCard({required this.product, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final images = (product['images'] as List? ?? []);
    final name = product['name'] ?? '';
    final price = product['sellingPrice']?.toString() ?? '';
    final mrp = product['mrp']?.toString() ?? '';
    final discount = double.tryParse((product['discount'] ?? '0').toString()) ?? 0;
    final brand = product['brand'] ?? '';
    final tags = (product['tags'] as List? ?? []).map((e) => e.toString().toLowerCase()).toList();
    
    String? badge;
    Color? badgeColor;
    if (tags.contains('bestseller') || tags.contains('best seller')) {
      badge = 'BEST SELLER';
      badgeColor = Colors.red;
    } else if (discount >= 50) {
      badge = '50% OFF';
      badgeColor = Colors.green;
    } else if (tags.contains('new') || tags.contains('new arrival')) {
      badge = 'NEW';
      badgeColor = Colors.blue;
    }

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/product', arguments: product['id']),
      child: Container(
        width: compact ? 140 : null,
        margin: compact ? const EdgeInsets.only(right: 10) : null,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 0.9,
                  child: images.isNotEmpty
                      ? Image.network(images[0], fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade100, child: const Icon(Icons.checkroom, color: Colors.grey)))
                      : Container(color: Colors.grey.shade100, child: const Icon(Icons.checkroom, color: Colors.grey, size: 40)),
                ),
                if (badge != null)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (brand.isNotEmpty) Text(brand, style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
              Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.2)),
              const SizedBox(height: 4),
              Row(children: [
                Text('₹$price', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFF47721))),
                if (mrp != price && mrp.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text('₹$mrp', style: const TextStyle(decoration: TextDecoration.lineThrough, fontSize: 10, color: Colors.grey)),
                ],
              ]),
              if (discount > 0)
                Text('${discount.toStringAsFixed(0)}% off', style: const TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );
  }
}

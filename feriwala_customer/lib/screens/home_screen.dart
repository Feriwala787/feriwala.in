import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../providers/cart_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _homeFeed;
  List<dynamic> _browseProducts = [];
  List<dynamic> _nearbyWarehouses = [];
  Position? _currentPosition;
  bool _loading = true;
  bool _productLoading = false;
  bool _warehouseLoading = false;
  final _searchController = TextEditingController();
  int? _selectedCategoryId;
  String _selectedCategoryName = 'All';
  Map<String, dynamic>? _selectedWarehouse;
  List<Map<String, dynamic>> _recentProducts = [];
  List<String> _searchSuggestions = [];

  static const double _maxWarehouseDistanceKm = 10;

  static const List<_CategoryTileData> _defaultCategoryTiles = [
    _CategoryTileData('Shirts', Icons.checkroom),
    _CategoryTileData('T-Shirts', Icons.dry_cleaning),
    _CategoryTileData('Jeans', Icons.straighten),
    _CategoryTileData('Casual Pants', Icons.shopping_bag),
    _CategoryTileData('Dresses', Icons.style),
    _CategoryTileData('Western', Icons.nightlife),
    _CategoryTileData('Indian', Icons.auto_awesome),
    _CategoryTileData('Wedding', Icons.diamond),
    _CategoryTileData('Summer', Icons.wb_sunny),
    _CategoryTileData('Winter', Icons.ac_unit),
    _CategoryTileData('Socks', Icons.sports_soccer),
    _CategoryTileData('Ethnic', Icons.emoji_people),
    _CategoryTileData('Sportswear', Icons.fitness_center),
    _CategoryTileData('Kids Wear', Icons.child_care),
    _CategoryTileData('Footwear', Icons.hiking),
  ];

  @override
  void initState() {
    super.initState();
    _initializeHome();
  }

  Future<void> _initializeHome() async {
    await _loadHomeFeed();
    await _loadRecentProducts();
    await _requestPermissionsAndLoadNearbyWarehouses();
    await _loadBrowseProducts();
  }

  Future<void> _requestPermissionsAndLoadNearbyWarehouses() async {
    await Permission.notification.request();

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    if (!mounted) return;

    setState(() => _currentPosition = position);
    await _loadNearbyWarehouses();
  }

  Future<void> _loadNearbyWarehouses() async {
    if (_currentPosition == null) return;

    setState(() => _warehouseLoading = true);
    try {
      final res = await ApiService().get('/shops', queryParams: {'limit': '100'});
      final shops = (res['data'] as List? ?? []).cast<dynamic>();

      final nearby = shops.where((shop) {
        final distance = _distanceKm(shop);
        return distance != null && distance <= _maxWarehouseDistanceKm;
      }).toList();

      nearby.sort((a, b) {
        final da = _distanceKm(a) ?? 9999;
        final db = _distanceKm(b) ?? 9999;
        return da.compareTo(db);
      });

      setState(() {
        _nearbyWarehouses = nearby;
        _selectedWarehouse = nearby.isNotEmpty ? (nearby.first as Map<String, dynamic>) : null;
      });
    } catch (_) {
      setState(() => _nearbyWarehouses = []);
    } finally {
      if (mounted) setState(() => _warehouseLoading = false);
    }
  }

  double? _distanceKm(dynamic shop) {
    if (_currentPosition == null) return null;
    final lat = double.tryParse((shop['latitude'] ?? '').toString());
    final lng = double.tryParse((shop['longitude'] ?? '').toString());
    if (lat == null || lng == null) return null;

    final meters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat,
      lng,
    );
    return meters / 1000;
  }

  void _chooseWarehouse() {
    if (_nearbyWarehouses.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            itemCount: _nearbyWarehouses.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final shop = _nearbyWarehouses[index] as Map<String, dynamic>;
              final distance = _distanceKm(shop);
              final selected = _selectedWarehouse?['id'] == shop['id'];

              return ListTile(
                title: Text(shop['name'] ?? 'Warehouse'),
                subtitle: Text('${shop['city'] ?? ''} • ${(distance ?? 0).toStringAsFixed(1)} km'),
                trailing: selected ? const Icon(Icons.check_circle, color: Color(0xFFF47721)) : null,
                onTap: () {
                  setState(() => _selectedWarehouse = shop);
                  Navigator.pop(context);
                  _loadBrowseProducts();
                },
              );
            },
          ),
        );
      },
    );
  }


  Future<void> _loadRecentProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getStringList('recent_products') ?? [];
    final parsed = items.map((e) {
      try {
        return jsonDecode(e) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((e) => e.isNotEmpty).toList();

    if (!mounted) return;
    setState(() => _recentProducts = parsed);
  }

  void _updateSearchSuggestions(String input) {
    final q = input.toLowerCase().trim();
    if (q.isEmpty) {
      setState(() => _searchSuggestions = []);
      return;
    }

    final synonymMap = {
      'tshirt': ['t-shirt', 'tee', 'tees'],
      'tee': ['t-shirt', 'tshirt'],
      'jean': ['jeans', 'denim'],
      'sock': ['socks'],
    };

    final suggestions = <String>{q};
    synonymMap.forEach((key, values) {
      if (q.contains(key)) suggestions.addAll(values);
    });

    setState(() => _searchSuggestions = suggestions.toList());
  }

  List<_CategoryTileData> _mergedCategories() {
    final apiCategories = (_homeFeed?['categories'] as List? ?? [])
        .map((c) => _CategoryTileData((c['name'] ?? '').toString(), Icons.checkroom, id: c['id']))
        .where((c) => c.name.trim().isNotEmpty)
        .toList();

    final map = <String, _CategoryTileData>{
      for (final item in _defaultCategoryTiles) item.name.toLowerCase(): item,
    };
    for (final item in apiCategories) {
      map[item.name.toLowerCase()] = item;
    }
    return map.values.toList();
  }

  Future<void> _loadHomeFeed() async {
    try {
      final res = await ApiService().get('/customers/home-feed');
      setState(() {
        _homeFeed = res['data'];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadBrowseProducts() async {
    setState(() => _productLoading = true);
    try {
      final params = <String, String>{'limit': '20'};
      if (_selectedCategoryId != null) params['categoryId'] = '$_selectedCategoryId';
      if (_searchController.text.trim().isNotEmpty) {
        final raw = _searchController.text.trim();
        const synonymExpand = {'tshirt': 't-shirt tee', 'tee': 't-shirt', 'jean': 'jeans denim'};
        String expanded = raw;
        synonymExpand.forEach((k, v) { if (raw.toLowerCase().contains(k)) expanded = '$expanded $v'; });
        params['search'] = expanded;
      }
      if (_selectedWarehouse != null) params['shopId'] = '${_selectedWarehouse!['id']}';

      final res = await ApiService().get('/products', queryParams: params);
      setState(() {
        _browseProducts = res['data'] ?? [];
      });
    } catch (_) {
      setState(() => _browseProducts = []);
    } finally {
      if (mounted) setState(() => _productLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final categories = _mergedCategories();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Feriwala', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFF47721))),
            Text('Browse first, login at checkout', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => Navigator.pushNamed(context, '/cart'),
              ),
              if (cart.itemCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Color(0xFFF47721), shape: BoxShape.circle),
                    child: Text('${cart.itemCount}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadHomeFeed();
                await _requestPermissionsAndLoadNearbyWarehouses();
                await _loadBrowseProducts();
              },
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search shirts, jeans, dresses, socks...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: _loadBrowseProducts,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: _updateSearchSuggestions,
                        onSubmitted: (_) => _loadBrowseProducts(),
                      ),
                    ),
                    if (_searchSuggestions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 8,
                          children: _searchSuggestions.map((s) => ActionChip(label: Text(s), onPressed: () { _searchController.text = s; _loadBrowseProducts(); })).toList(),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Color(0xFFF47721)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _warehouseLoading
                                  ? const Text('Fetching nearby warehouses...')
                                  : Text(
                                      _selectedWarehouse == null
                                          ? 'Enable location to find nearest warehouse (within 10 km).'
                                          : '${_selectedWarehouse!['name']} • ${(_distanceKm(_selectedWarehouse) ?? 0).toStringAsFixed(1)} km',
                                      maxLines: 2,
                                    ),
                            ),
                            TextButton(onPressed: _chooseWarehouse, child: const Text('Change')),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Shop by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        childAspectRatio: 0.66,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return _CategoryTile(
                          category: category,
                          selected: _selectedCategoryId == category.id,
                          onTap: () {
                            setState(() {
                              if (_selectedCategoryId == category.id) {
                                _selectedCategoryId = null;
                                _selectedCategoryName = 'All';
                              } else {
                                _selectedCategoryId = category.id;
                                _selectedCategoryName = category.name;
                              }
                            });
                            _loadBrowseProducts();
                          },
                        );
                      },
                    ),
                    if (_recentProducts.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Text('Recently Viewed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _recentProducts.length,
                          itemBuilder: (context, index) {
                            final rp = _recentProducts[index];
                            return GestureDetector(
                              onTap: () => Navigator.pushNamed(context, '/product', arguments: rp['id']),
                              child: Container(
                                width: 110,
                                margin: const EdgeInsets.only(right: 10),
                                child: Column(children: [
                                  Expanded(child: Container(color: Colors.grey.shade200, child: rp['image'] != null ? Image.network(rp['image'], fit: BoxFit.cover) : const Icon(Icons.checkroom))),
                                  Text(rp['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                                ]),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text('Featured', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    if (_homeFeed?['featured'] != null && (_homeFeed!['featured'] as List).isNotEmpty)
                      SizedBox(
                        height: 220,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: (_homeFeed!['featured'] as List).length,
                          itemBuilder: (context, index) {
                            final product = _homeFeed!['featured'][index];
                            return _ProductCard(product: product);
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        _selectedCategoryId == null
                            ? 'Browse Products'
                            : 'Browse Products • $_selectedCategoryName',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (_productLoading)
                      const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                    else if (_browseProducts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(18),
                        child: Center(child: Text('No products found for current filters.')),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _browseProducts.length,
                        itemBuilder: (context, index) => _ProductGridItem(product: _browseProducts[index]),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

      floatingActionButton: cart.itemCount > 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(context, '/cart'),
              backgroundColor: const Color(0xFFF47721),
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              label: Text('${cart.itemCount} items', style: const TextStyle(color: Colors.white)),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          if (i == 1) Navigator.pushNamed(context, '/orders');
          if (i == 2) Navigator.pushNamed(context, '/profile');
        },
        selectedItemColor: const Color(0xFFF47721),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _CategoryTileData {
  final String name;
  final IconData icon;
  final int? id;
  const _CategoryTileData(this.name, this.icon, {this.id});
}

class _CategoryTile extends StatelessWidget {
  final _CategoryTileData category;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryTile({required this.category, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFF47721).withAlpha(45) : const Color(0xFFF47721).withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: selected ? Border.all(color: const Color(0xFFF47721), width: 1.2) : null,
              ),
              child: Icon(category.icon, color: const Color(0xFFF47721), size: 22),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            category.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final images = product['images'] as List? ?? [];
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/product', arguments: product['id']),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey.withAlpha(25), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                height: 140,
                color: Colors.grey[200],
                child: images.isNotEmpty
                    ? Image.network(images[0], fit: BoxFit.cover, width: double.infinity)
                    : const Center(child: Icon(Icons.checkroom, size: 40, color: Colors.grey)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('₹${product['sellingPrice']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF47721))),
                    const SizedBox(width: 4),
                    if (product['mrp'] != product['sellingPrice'])
                      Text('₹${product['mrp']}',
                          style: const TextStyle(decoration: TextDecoration.lineThrough, fontSize: 11, color: Colors.grey)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductGridItem extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductGridItem({required this.product});

  @override
  Widget build(BuildContext context) {
    final images = product['images'] as List? ?? [];
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/product', arguments: product['id']),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey.withAlpha(25), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Container(
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: images.isNotEmpty
                      ? Image.network(images[0], fit: BoxFit.cover)
                      : const Center(child: Icon(Icons.checkroom, size: 40, color: Colors.grey)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product['brand'] != null)
                    Text(product['brand'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(product['name'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('₹${product['sellingPrice']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF47721))),
                    const SizedBox(width: 4),
                    if (product['discount'] != null && double.tryParse(product['discount'].toString()) != null && double.parse(product['discount'].toString()) > 0)
                      Text('${double.parse(product['discount'].toString()).toStringAsFixed(0)}% off',
                          style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w500)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

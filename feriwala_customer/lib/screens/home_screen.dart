import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  bool _loading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHomeFeed();
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

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Feriwala', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFF47721))),
            Text('Delivery in minutes', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
              onRefresh: _loadHomeFeed,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search for clothes...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (q) {
                          // Navigate to search results
                        },
                      ),
                    ),

                    // Categories
                    if (_homeFeed?['categories'] != null) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.all(12),
                          itemCount: (_homeFeed!['categories'] as List).length,
                          itemBuilder: (context, index) {
                            final cat = _homeFeed!['categories'][index];
                            return Container(
                              width: 80,
                              margin: const EdgeInsets.only(right: 12),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: const Color(0xFFF47721).withAlpha(30),
                                    child: const Icon(Icons.checkroom, color: Color(0xFFF47721)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(cat['name'] ?? '', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center, maxLines: 2),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    // Featured Products
                    if (_homeFeed?['featured'] != null && (_homeFeed!['featured'] as List).isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text('Featured', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
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
                    ],

                    // New Arrivals
                    if (_homeFeed?['newArrivals'] != null) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text('New Arrivals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
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
                        itemCount: (_homeFeed!['newArrivals'] as List).length,
                        itemBuilder: (context, index) {
                          final product = _homeFeed!['newArrivals'][index];
                          return _ProductGridItem(product: product);
                        },
                      ),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
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
                  if (product['attributes'] is Map && product['attributes']['productType'] != null)
                    Text(product['attributes']['productType'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
                  if (product['attributes'] is Map && product['attributes']['productType'] != null)
                    Text(product['attributes']['productType'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
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

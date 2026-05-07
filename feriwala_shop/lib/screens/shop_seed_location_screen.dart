import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/shop_auth_provider.dart';

class ShopSeedLocationScreen extends StatefulWidget {
  const ShopSeedLocationScreen({super.key});

  @override
  State<ShopSeedLocationScreen> createState() => _ShopSeedLocationScreenState();
}

class _ShopSeedLocationScreenState extends State<ShopSeedLocationScreen> {
  final _api = ShopApiService();
  bool _locating = false;
  bool _saving = false;
  double? _lat;
  double? _lng;
  String? _error;

  Future<void> _getLocation() async {
    setState(() { _locating = true; _error = null; });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) {
        setState(() { _error = 'Location permission denied. Enable it in Settings.'; _locating = false; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() { _lat = pos.latitude; _lng = pos.longitude; _locating = false; });
    } catch (e) {
      setState(() { _error = 'Could not get location: $e'; _locating = false; });
    }
  }

  Future<void> _save() async {
    if (_lat == null || _lng == null) return;
    setState(() => _saving = true);
    try {
      await _api.put('/shops/my/seed-location', body: {'latitude': _lat, 'longitude': _lng});
      if (!mounted) return;
      // Refresh user profile so shopId is up to date
      await context.read<ShopAuthProvider>().init();
      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.location_on, color: Color(0xFFF47721), size: 72),
            const SizedBox(height: 24),
            const Text('Set Your Shop Location', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text('Please be physically present at your shop and tap the button below to capture your shop\'s GPS location. This is required for customers to find you.', style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            if (_lat != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.green.withAlpha(30), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withAlpha(80))),
                child: Column(children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 32),
                  const SizedBox(height: 8),
                  Text('Location captured!', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Lat: ${_lat!.toStringAsFixed(6)}\nLng: ${_lng!.toStringAsFixed(6)}', style: const TextStyle(color: Colors.white60, fontSize: 12), textAlign: TextAlign.center),
                ]),
              ),
              const SizedBox(height: 16),
            ],
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _locating ? null : _getLocation,
                icon: _locating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF47721))) : const Icon(Icons.my_location, color: Color(0xFFF47721)),
                label: Text(_locating ? 'Getting location...' : (_lat != null ? 'Re-capture Location' : 'Capture My Location'), style: const TextStyle(color: Color(0xFFF47721))),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFF47721)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            if (_lat != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF47721), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save & Activate Shop', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

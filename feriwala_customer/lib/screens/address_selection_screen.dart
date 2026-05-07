import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:amazon_location_flutter/amazon_location_flutter.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class AddressSelectionScreen extends StatefulWidget {
  const AddressSelectionScreen({super.key});

  @override
  State<AddressSelectionScreen> createState() => _AddressSelectionScreenState();
}

class _AddressSelectionScreenState extends State<AddressSelectionScreen> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final addresses = (auth.user?['addresses'] as List?) ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Delivery Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: addresses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('No addresses saved', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _addAddress(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Address'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF47721),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: addresses.length,
                    itemBuilder: (context, index) {
                      final address = addresses[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: RadioListTile<int>(
                          value: index,
                          groupValue: _selectedIndex,
                          onChanged: (v) => setState(() => _selectedIndex = v),
                          activeColor: const Color(0xFFF47721),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF47721).withAlpha(30),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  address['label'] ?? 'Address',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFF47721)),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(address['receiverName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(address['addressLine1'] ?? '', style: const TextStyle(fontSize: 12)),
                                if (address['landmark'] != null && (address['landmark'] as String).isNotEmpty)
                                  Text('Near ${address['landmark']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                Text('${address['city']}, ${address['state']} - ${address['pincode']}', style: const TextStyle(fontSize: 11)),
                                Text('📞 ${address['phone']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.grey.withAlpha(30), blurRadius: 6, offset: const Offset(0, -2))],
                  ),
                  child: Column(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _addAddress(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add New Address', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          side: const BorderSide(color: Color(0xFFF47721)),
                          foregroundColor: const Color(0xFFF47721),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _selectedIndex == null
                            ? null
                            : () => Navigator.pop(context, addresses[_selectedIndex!]),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF47721),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 44),
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                        child: const Text('Deliver Here', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _addAddress() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const _AddAddressScreen()),
    );
    if (result == null) return;

    try {
      await ApiService().post('/auth/addresses', body: result);
      if (!mounted) return;
      await context.read<AuthProvider>().init();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add address: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _AddAddressScreen extends StatefulWidget {
  const _AddAddressScreen();

  @override
  State<_AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<_AddAddressScreen> {
  static const _kOrange = Color(0xFFF47721);

  final _formKey = GlobalKey<FormState>();
  final _searchCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _line1Ctrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  String _label = 'Home';
  bool _isDefault = false;
  double? _lat;
  double? _lng;
  bool _fetchingLocation = false;
  bool _searchLoading = false;
  List<AutocompleteResult> _suggestions = [];
  Timer? _debounce;
  bool _showSuggestions = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _line1Ctrl.dispose();
    _landmarkCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() { _suggestions = []; _showSuggestions = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _searchLoading = true);
      final biasPos = _lat != null && _lng != null
          ? LatLng(latitude: _lat!, longitude: _lng!)
          : null;
      final results = await LocationService.autocomplete(query, biasPosition: biasPos);
      if (mounted) setState(() { _suggestions = results; _showSuggestions = results.isNotEmpty; _searchLoading = false; });
    });
  }

  Future<void> _onSuggestionSelected(AutocompleteResult suggestion) async {
    setState(() { _showSuggestions = false; _searchLoading = true; });
    _searchCtrl.text = suggestion.label;

    final geo = await LocationService.geocode(suggestion.label);
    if (geo != null) {
      _lat = geo.position.latitude;
      _lng = geo.position.longitude;

      // Parse address from label: "Street, City, State, Pincode, Country"
      final parts = geo.label.split(',').map((e) => e.trim()).toList();
      _line1Ctrl.text = parts.isNotEmpty ? parts.first : geo.label;
      _cityCtrl.text = geo.municipality ?? (parts.length > 1 ? parts[parts.length - 3] : '');
      _stateCtrl.text = parts.length > 2 ? parts[parts.length - 2] : '';

      // Extract 6-digit pincode from label
      final pinMatch = RegExp(r'\b\d{6}\b').firstMatch(geo.label);
      if (pinMatch != null) _pinCtrl.text = pinMatch.group(0)!;
    }

    if (mounted) setState(() => _searchLoading = false);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission required')));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _lat = pos.latitude;
      _lng = pos.longitude;

      // Reverse geocode using geocode with coordinates as query
      final geo = await LocationService.geocode('${pos.latitude},${pos.longitude}');
      if (geo != null && mounted) {
        _searchCtrl.text = geo.label;
        final parts = geo.label.split(',').map((e) => e.trim()).toList();
        _line1Ctrl.text = parts.isNotEmpty ? parts.first : geo.label;
        _cityCtrl.text = geo.municipality ?? (parts.length > 2 ? parts[parts.length - 3] : '');
        _stateCtrl.text = parts.length > 2 ? parts[parts.length - 2] : '';
        final pinMatch = RegExp(r'\b\d{6}\b').firstMatch(geo.label);
        if (pinMatch != null) _pinCtrl.text = pinMatch.group(0)!;
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, {
      'label': _label,
      'addressLine1': _line1Ctrl.text.trim(),
      'landmark': _landmarkCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'state': _stateCtrl.text.trim(),
      'pincode': _pinCtrl.text.trim(),
      'receiverName': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'isDefault': _isDefault,
      if (_lat != null) 'latitude': _lat,
      if (_lng != null) 'longitude': _lng,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Add Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(color: _kOrange, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Label selector
            Row(
              children: ['Home', 'Work', 'Other'].map((l) {
                final sel = _label == l;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(l, style: TextStyle(fontSize: 12, color: sel ? Colors.white : Colors.black87)),
                    selected: sel,
                    selectedColor: _kOrange,
                    onSelected: (_) => setState(() => _label = l),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Address search with autocomplete
            const Text('Search Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 6),
            Column(
              children: [
                TextFormField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search area, street, landmark...',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchLoading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                if (_showSuggestions)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      children: _suggestions.map((s) => InkWell(
                        onTap: () => _onSuggestionSelected(s),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(s.label, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Use current location button
            OutlinedButton.icon(
              onPressed: _fetchingLocation ? null : _useCurrentLocation,
              icon: _fetchingLocation
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _kOrange))
                  : const Icon(Icons.my_location, size: 18, color: _kOrange),
              label: Text(
                _lat != null ? '📍 Location captured' : 'Use current location',
                style: const TextStyle(fontSize: 13, color: _kOrange),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 42),
                side: const BorderSide(color: _kOrange),
              ),
            ),
            const SizedBox(height: 20),

            // Form fields
            const Text('Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 10),
            _field(_nameCtrl, 'Receiver Name', validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
            const SizedBox(height: 12),
            _field(_phoneCtrl, 'Phone', keyboardType: TextInputType.phone,
                validator: (v) => (v != null && v.trim().length >= 10) ? null : 'Enter valid phone'),
            const SizedBox(height: 12),
            _field(_line1Ctrl, 'Address Line 1', maxLines: 2,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
            const SizedBox(height: 12),
            _field(_landmarkCtrl, 'Landmark (Optional)'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field(_cityCtrl, 'City',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null)),
              const SizedBox(width: 10),
              Expanded(child: _field(_stateCtrl, 'State',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null)),
            ]),
            const SizedBox(height: 12),
            _field(_pinCtrl, 'Pincode', keyboardType: TextInputType.number,
                validator: (v) => (v != null && v.trim().length == 6) ? null : '6-digit pincode'),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
              activeColor: _kOrange,
              title: const Text('Set as default', style: TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
              ),
              child: const Text('Save Address', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}

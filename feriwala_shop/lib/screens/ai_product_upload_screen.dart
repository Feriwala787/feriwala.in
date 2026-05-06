import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

// ─── Variant model ────────────────────────────────────────────────────────────
class _Variant {
  String color;
  String size;
  int stock;
  _Variant({this.color = '', this.size = 'M', this.stock = 0});
  Map<String, dynamic> toJson() => {'color': color, 'size': size, 'stock': stock};
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class AiProductUploadScreen extends StatefulWidget {
  const AiProductUploadScreen({super.key});

  @override
  State<AiProductUploadScreen> createState() => _AiProductUploadScreenState();
}

class _AiProductUploadScreenState extends State<AiProductUploadScreen> {
  final _picker = ImagePicker();
  final _promptCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _mrpCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  List<XFile> _images = [];
  Map<String, dynamic>? _ai;
  List<_Variant> _variants = [_Variant(color: '', size: 'M', stock: 0)];
  bool _analyzing = false;
  bool _publishing = false;
  String? _error;

  static const _sizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL', '28', '30', 'Free Size'];

  @override
  void dispose() {
    for (final c in [_promptCtrl, _nameCtrl, _brandCtrl, _descCtrl, _mrpCtrl, _priceCtrl]) c.dispose();
    super.dispose();
  }

  // ── Image picking ────────────────────────────────────────────────────────────
  Future<void> _pickGallery() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) setState(() { _images = [..._images, ...picked]; _ai = null; _error = null; });
  }

  Future<void> _pickCamera() async {
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked != null) setState(() { _images = [..._images, picked]; _ai = null; _error = null; });
  }

  // ── AI analyze ───────────────────────────────────────────────────────────────
  Future<void> _analyze() async {
    if (_images.isEmpty) return;
    setState(() { _analyzing = true; _error = null; });
    try {
      final files = _images.map((x) => File(x.path)).toList();
      final res = await ShopApiService().uploadFiles(
        '/ai/analyze-product',
        files: files,
        fields: {'prompt': _promptCtrl.text.trim()},
      );
      final data = res['data'] as Map<String, dynamic>;
      final colors = (data['colors'] as List?)?.map((e) => e.toString()).toList() ?? [''];
      final sizes = (data['sizes'] as List?)?.map((e) => e.toString()).toList() ?? ['M'];

      // Pre-fill variants: one row per color × size combo
      final newVariants = <_Variant>[];
      for (final c in colors) {
        for (final s in sizes) {
          newVariants.add(_Variant(color: c, size: s, stock: 0));
        }
      }

      setState(() {
        _ai = data;
        _nameCtrl.text = data['name'] ?? '';
        _brandCtrl.text = data['brand'] ?? '';
        _descCtrl.text = data['description'] ?? '';
        _mrpCtrl.text = (data['mrp'] ?? '499').toString();
        _priceCtrl.text = (data['sellingPrice'] ?? '399').toString();
        _variants = newVariants.isNotEmpty ? newVariants : [_Variant()];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _analyzing = false);
    }
  }

  // ── Publish ──────────────────────────────────────────────────────────────────
  Future<void> _publish() async {
    if (_images.isEmpty) return;
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Product name is required');
      return;
    }
    setState(() { _publishing = true; _error = null; });
    try {
      final files = _images.map((x) => File(x.path)).toList();
      await ShopApiService().uploadFiles(
        '/ai/create-product',
        files: files,
        fields: {
          'prompt': _promptCtrl.text.trim(),
          'name': _nameCtrl.text.trim(),
          'brand': _brandCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'mrp': _mrpCtrl.text.trim(),
          'sellingPrice': _priceCtrl.text.trim(),
          'variants': _variantsJson(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product published!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  String _variantsJson() {
    final list = _variants.where((v) => v.color.isNotEmpty || v.stock > 0).map((v) => v.toJson()).toList();
    // Simple JSON encode without dart:convert import issues
    return '[${list.map((v) => '{"color":"${v['color']}","size":"${v['size']}","stock":${v['stock']}}').join(',')}]';
  }

  int get _totalStock => _variants.fold(0, (s, v) => s + v.stock);

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('AI Product Upload'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        actions: [
          if (_ai != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: _publishing ? null : _publish,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF47721), foregroundColor: Colors.white),
                icon: _publishing
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.rocket_launch, size: 16),
                label: const Text('Publish'),
              ),
            ),
        ],
      ),
      body: isWide ? _wideLayout() : _narrowLayout(),
    );
  }

  Widget _wideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: _leftPanel())),
        const VerticalDivider(width: 1),
        Expanded(flex: 7, child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: _rightPanel())),
      ],
    );
  }

  Widget _narrowLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [_leftPanel(), const SizedBox(height: 16), _rightPanel()]),
    );
  }

  // Left: photos + prompt + analyze
  Widget _leftPanel() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Label('Product Photos', icon: Icons.photo_library),
        const SizedBox(height: 10),
        _imageGrid(),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: _pickGallery,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Gallery'),
          )),
          const SizedBox(width: 8),
          if (!kIsWeb) Expanded(child: OutlinedButton.icon(
            onPressed: _pickCamera,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Camera'),
          )),
        ]),
      ])),
      const SizedBox(height: 12),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Label('Seller Note (optional)', icon: Icons.edit_note),
        const SizedBox(height: 8),
        TextField(
          controller: _promptCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'e.g. "Cotton t-shirt, red/blue/black, sizes S-XL, MRP ₹499"',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true, fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: (_images.isEmpty || _analyzing) ? null : _analyze,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A1A2E), foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: _analyzing
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.auto_awesome),
          label: Text(_analyzing ? 'Analyzing...' : 'Analyze with Gemini AI'),
        )),
      ])),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
          child: Row(children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
          ]),
        ),
      ],
    ]);
  }

  // Right: AI results + editable fields + variant table
  Widget _rightPanel() {
    if (_ai == null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.auto_awesome, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Add photos and click Analyze', style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Gemini 3.1 Flash-Lite will fill in all product details', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // AI confidence badge
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade200)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 14),
            const SizedBox(width: 4),
            Text('AI Confidence: ${_ai!['confidence'] ?? 'high'}', style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
        ),
        const SizedBox(width: 8),
        Text('${_images.length} photo${_images.length != 1 ? 's' : ''} analyzed', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      ]),
      const SizedBox(height: 12),

      // Basic info
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Label('Product Details', icon: Icons.info_outline),
        const SizedBox(height: 10),
        _field('Product Name *', _nameCtrl),
        _field('Brand', _brandCtrl),
        _field('Description', _descCtrl, maxLines: 3),
        Row(children: [
          Expanded(child: _field('MRP (₹)', _mrpCtrl, keyboardType: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _field('Selling Price (₹)', _priceCtrl, keyboardType: TextInputType.number)),
        ]),
      ])),
      const SizedBox(height: 12),

      // AI detected attributes
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Label('AI Detected Attributes', icon: Icons.auto_awesome),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _aiChip('Type', _ai!['productType']),
          _aiChip('Gender', _ai!['gender']),
          _aiChip('Fit', _ai!['fit']),
          _aiChip('Pattern', _ai!['pattern']),
          _aiChip('Occasion', _ai!['occasion']),
          _aiChip('Sleeve', _ai!['sleeveType']),
          _aiChip('Neck', _ai!['neckType']),
          _aiChip('Material', _ai!['material']),
        ].where((w) => w != null).cast<Widget>().toList()),
        if ((_ai!['tags'] as List?)?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: (_ai!['tags'] as List).map((t) => Chip(
            label: Text(t.toString(), style: const TextStyle(fontSize: 11)),
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: Colors.blue.shade50,
          )).toList()),
        ],
      ])),
      const SizedBox(height: 12),

      // Variant table — user fills stock
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const _Label('Colour × Size × Stock', icon: Icons.table_chart),
          const Spacer(),
          Text('Total: $_totalStock units', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF47721))),
        ]),
        const SizedBox(height: 4),
        const Text('Edit colours/sizes and enter stock count for each variant', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 10),
        _variantTable(),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => setState(() => _variants.add(_Variant())),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add variant row'),
        ),
      ])),
      const SizedBox(height: 16),

      // Publish button
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _publishing ? null : _publish,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF47721), foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: _publishing
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.rocket_launch),
        label: Text(_publishing ? 'Publishing...' : 'Publish Product  ($_totalStock units total)'),
      )),
      const SizedBox(height: 32),
    ]);
  }

  Widget _imageGrid() {
    if (_images.isEmpty) {
      return GestureDetector(
        onTap: _pickGallery,
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300, width: 2),
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey.shade50,
          ),
          child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 6),
            Text('Tap to add photos', style: TextStyle(color: Colors.grey.shade400)),
            Text('Drop t-shirt in red, blue, black — all angles', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
          ])),
        ),
      );
    }
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) => Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(_images[i].path), width: 90, height: 90, fit: BoxFit.cover),
          ),
          Positioned(top: 2, right: 2, child: GestureDetector(
            onTap: () => setState(() => _images.removeAt(i)),
            child: Container(
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          )),
        ]),
      ),
    );
  }

  Widget _variantTable() {
    return Table(
      columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2), 3: FixedColumnWidth(36)},
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
          children: const [
            Padding(padding: EdgeInsets.all(6), child: Text('Colour', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            Padding(padding: EdgeInsets.all(6), child: Text('Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            Padding(padding: EdgeInsets.all(6), child: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            SizedBox(),
          ],
        ),
        ..._variants.asMap().entries.map((e) => _variantRow(e.key, e.value)),
      ],
    );
  }

  TableRow _variantRow(int i, _Variant v) {
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: TextFormField(
          initialValue: v.color,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'e.g. Red',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onChanged: (val) => _variants[i].color = val,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: DropdownButtonFormField<String>(
          value: _sizes.contains(v.size) ? v.size : 'M',
          isDense: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
          items: _sizes.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (val) => setState(() => _variants[i].size = val ?? 'M'),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: TextFormField(
          initialValue: v.stock.toString(),
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: '0',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onChanged: (val) => setState(() => _variants[i].stock = int.tryParse(val) ?? 0),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
        onPressed: _variants.length > 1 ? () => setState(() => _variants.removeAt(i)) : null,
        padding: EdgeInsets.zero,
      ),
    ]);
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true, fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }

  Widget? _aiChip(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
      child: RichText(text: TextSpan(children: [
        TextSpan(text: '$label: ', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        TextSpan(text: value.toString(), style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500)),
      ])),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Label(this.text, {required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: const Color(0xFF1A1A2E)),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    ]);
  }
}

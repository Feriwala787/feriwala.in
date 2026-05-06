import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class AiProductUploadScreen extends StatefulWidget {
  const AiProductUploadScreen({super.key});

  @override
  State<AiProductUploadScreen> createState() => _AiProductUploadScreenState();
}

class _AiProductUploadScreenState extends State<AiProductUploadScreen> {
  final _picker = ImagePicker();
  final _promptCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '10');

  List<XFile> _images = [];
  Map<String, dynamic>? _aiResult;
  bool _analyzing = false;
  bool _publishing = false;
  String? _error;

  // Editable fields after AI fills them
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _mrpCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _materialCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [_promptCtrl, _qtyCtrl, _nameCtrl, _descCtrl, _mrpCtrl, _priceCtrl, _materialCtrl, _brandCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) setState(() { _images = picked; _aiResult = null; _error = null; });
  }

  Future<void> _pickCamera() async {
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked != null) setState(() { _images = [..._images, picked]; _aiResult = null; _error = null; });
  }

  Future<void> _analyzeWithAI() async {
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
      setState(() {
        _aiResult = data;
        _nameCtrl.text = data['name'] ?? '';
        _descCtrl.text = data['description'] ?? '';
        _mrpCtrl.text = (data['mrp'] ?? '').toString();
        _priceCtrl.text = (data['sellingPrice'] ?? '').toString();
        _materialCtrl.text = data['material'] ?? '';
        _brandCtrl.text = data['brand'] ?? '';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _analyzing = false);
    }
  }

  Future<void> _publish() async {
    if (_images.isEmpty || _aiResult == null) return;
    setState(() { _publishing = true; _error = null; });

    try {
      final files = _images.map((x) => File(x.path)).toList();
      await ShopApiService().uploadFiles(
        '/ai/create-product',
        files: files,
        fields: {
          'prompt': _promptCtrl.text.trim(),
          'quantity': _qtyCtrl.text.trim(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product published successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Product Upload'),
        actions: [
          if (_aiResult != null)
            TextButton.icon(
              onPressed: _publishing ? null : _publish,
              icon: _publishing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload, color: Colors.white),
              label: const Text('Publish', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step 1 — Images
            _SectionHeader(step: '1', title: 'Drop Product Photos'),
            const SizedBox(height: 8),
            if (_images.isEmpty)
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 2, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Tap to add photos', style: TextStyle(color: Colors.grey)),
                        Text('T-shirt in different colours, angles', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length + 2,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    if (i == _images.length) {
                      return _AddPhotoButton(icon: Icons.photo_library, onTap: _pickImages);
                    }
                    if (i == _images.length + 1) {
                      return _AddPhotoButton(icon: Icons.camera_alt, onTap: _pickCamera);
                    }
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(_images[i].path), width: 100, height: 100, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 2, right: 2,
                          child: GestureDetector(
                            onTap: () => setState(() => _images.removeAt(i)),
                            child: Container(
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),

            // Step 2 — Prompt
            _SectionHeader(step: '2', title: 'Tell AI about the product (optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _promptCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. "Cotton round-neck t-shirt, available in red/blue/black, sizes S-XL, MRP 499"',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),

            const SizedBox(height: 16),

            // Analyze button
            if (_aiResult == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_images.isEmpty || _analyzing) ? null : _analyzeWithAI,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A2E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _analyzing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome),
                  label: Text(_analyzing ? 'Analyzing with Gemini 2.0...' : 'Analyze with AI'),
                ),
              ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                ]),
              ),
            ],

            // Step 3 — AI Results (editable)
            if (_aiResult != null) ...[
              const SizedBox(height: 20),
              _SectionHeader(step: '3', title: 'Review & Edit AI Results'),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
                const SizedBox(width: 4),
                Text('Confidence: ${_aiResult!['confidence'] ?? 'high'}',
                    style: TextStyle(color: Colors.green.shade700, fontSize: 12)),
              ]),
              const SizedBox(height: 12),

              _EditField(label: 'Product Name *', controller: _nameCtrl),
              _EditField(label: 'Brand', controller: _brandCtrl),
              _EditField(label: 'Description', controller: _descCtrl, maxLines: 3),
              _EditField(label: 'Material', controller: _materialCtrl),

              Row(children: [
                Expanded(child: _EditField(label: 'MRP (₹)', controller: _mrpCtrl, keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _EditField(label: 'Selling Price (₹)', controller: _priceCtrl, keyboardType: TextInputType.number)),
              ]),

              _InfoChips(label: 'Colors', values: (_aiResult!['color'] as List?)?.map((e) => e.toString()).toList() ?? []),
              _InfoChips(label: 'Sizes', values: (_aiResult!['size'] as List?)?.map((e) => e.toString()).toList() ?? []),
              _InfoChips(label: 'Tags', values: (_aiResult!['tags'] as List?)?.map((e) => e.toString()).toList() ?? []),

              _InfoRow('Type', _aiResult!['productType']),
              _InfoRow('Gender', _aiResult!['gender']),
              _InfoRow('Fit', _aiResult!['fit']),
              _InfoRow('Pattern', _aiResult!['pattern']),
              _InfoRow('Occasion', _aiResult!['occasion']),

              const SizedBox(height: 16),
              Row(children: [
                const Text('Initial Stock Quantity:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _publishing ? null : _publish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF47721),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _publishing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.rocket_launch),
                  label: Text(_publishing ? 'Publishing...' : 'Publish Product'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String step, title;
  const _SectionHeader({required this.step, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 24, height: 24,
        decoration: const BoxDecoration(color: Color(0xFF1A1A2E), shape: BoxShape.circle),
        child: Center(child: Text(step, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
      ),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    ]);
  }
}

class _AddPhotoButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AddPhotoButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100, height: 100,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade50,
        ),
        child: Icon(icon, color: Colors.grey, size: 32),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType keyboardType;
  const _EditField({required this.label, required this.controller, this.maxLines = 1, this.keyboardType = TextInputType.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}

class _InfoChips extends StatelessWidget {
  final String label;
  final List<String> values;
  const _InfoChips({required this.label, required this.values});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Wrap(spacing: 6, children: values.map((v) => Chip(
          label: Text(v, style: const TextStyle(fontSize: 12)),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        )).toList()),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final dynamic value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
        Text(value.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

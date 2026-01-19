import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/product_model.dart';
import '../../services/translation_service.dart';
import '../../state/app_state.dart'; // Added for tr()
// import '../../widgets/nv_widgets.dart'; // Unused

class ProductEditorSheet extends StatefulWidget {
  final Product? product; // If null, new product
  
  const ProductEditorSheet({super.key, this.product});

  // Static method to show the sheet easily
  static Future<void> show(BuildContext context, {Product? product}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ProductEditorSheet(product: product),
    );
  }

  @override
  State<ProductEditorSheet> createState() => _ProductEditorSheetState();
}

class _ProductEditorSheetState extends State<ProductEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _category;
  String _imageUrl = '';
  String _videoUrl = '';
  bool _featured = false;
  bool _saving = false;
  final _picker = ImagePicker();
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  
  late DocumentReference<Map<String, dynamic>> _docRef;

  @override
  void initState() {
    super.initState();
    _docRef = widget.product == null
        ? _db.collection('products').doc()
        : _db.collection('products').doc(widget.product!.id);
        
    _name = TextEditingController(text: widget.product?.name ?? '');
    _description = TextEditingController(text: widget.product?.description ?? '');
    _price = TextEditingController(text: widget.product?.price.toStringAsFixed(2) ?? '');
    _category = TextEditingController(text: widget.product?.category ?? '');
    _imageUrl = widget.product?.imageUrl ?? '';
    _videoUrl = widget.product?.videoUrl ?? '';
    _featured = widget.product?.featured ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<String?> _uploadBytes({
    required Uint8List bytes,
    required String path,
    required String contentType,
  }) async {
    final ref = _storage.ref().child(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  Future<String?> _pickAndUpload(bool isVideo) async {
    try {
      final XFile? file = isVideo 
        ? await _picker.pickVideo(source: ImageSource.gallery)
        : await _picker.pickImage(source: ImageSource.gallery);
      
      if (file == null) return null;
      
      final bytes = await file.readAsBytes();
      final ext = isVideo ? 'mp4' : 'jpg';
      final type = isVideo ? 'video/mp4' : 'image/jpeg';
      
      return _uploadBytes(
        bytes: bytes,
        path: 'product_media/${_docRef.id}/${isVideo ? 'video' : 'image'}.$ext',
        contentType: type,
      );
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    final desc = _description.text.trim();
    final price = double.tryParse(_price.text.trim()) ?? 0;
    final category = _category.text.trim();
    
    if (name.isEmpty || category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and Category are required.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // AUTO-TRANSLATE TO ENGLISH FOR STORAGE STANDARD
      final enName = await TranslationService().translate(name, 'en');
      final enDesc = await TranslationService().translate(desc, 'en');
      final enCat = await TranslationService().translate(category, 'en');

      final isNew = widget.product == null;
      final data = <String, dynamic>{
        'name': enName,
        'description': enDesc,
        'price': price,
        'category': enCat,
        'featured': _featured,
        'imageUrl': _imageUrl,
        'videoUrl': _videoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (isNew) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      await _docRef.set(data, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, en: 'Product saved.', es: 'Guardado.')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, en: 'Error saving product.', es: 'Error al guardar.')),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.product == null
        ? tr(context, en: 'New product', es: 'Nuevo producto')
        : tr(context, en: 'Edit product', es: 'Editar producto');

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: tr(context, en: 'Name', es: 'Nombre'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: tr(context, en: 'Description', es: 'Descripcion'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tr(context, en: 'Price (USD)', es: 'Precio'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _category,
                    decoration: InputDecoration(
                      labelText: tr(context, en: 'Category', es: 'Categoria'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _featured,
              onChanged: (v) => setState(() => _featured = v),
              title: Text(tr(context, en: 'Featured', es: 'Destacado')),
            ),
            const SizedBox(height: 8),
            Text(
              tr(context, en: 'Media', es: 'Multimedia'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final url = await _pickAndUpload(false);
                      if (url != null) setState(() => _imageUrl = url);
                    },
                    icon: const Icon(Icons.image),
                    label: Text(tr(context, en: 'Upload image', es: 'Subir imagen')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final url = await _pickAndUpload(true);
                      if (url != null) setState(() => _videoUrl = url);
                    },
                    icon: const Icon(Icons.videocam),
                    label: Text(tr(context, en: 'Upload video', es: 'Subir video')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_imageUrl.isNotEmpty)
              Text(tr(context, en: 'Image ready', es: 'Imagen lista')),
            if (_videoUrl.isNotEmpty)
              Text(tr(context, en: 'Video ready', es: 'Video listo')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(
                  _saving
                      ? tr(context, en: 'Saving...', es: 'Guardando...')
                      : tr(context, en: 'Save product', es: 'Guardar producto'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

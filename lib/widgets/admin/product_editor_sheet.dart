import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/product_model.dart';
import '../../services/translation_service.dart';
import '../../state/app_state.dart';
import '../../config/product_animations_map.dart';

class ProductEditorSheet extends StatefulWidget {
  final Product? product; 

  const ProductEditorSheet({super.key, this.product});

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
  // English Defaults
  late final TextEditingController _nameEn;
  late final TextEditingController _descEn;
  late final TextEditingController _catEn;
  
  // Spanish Defaults
  late final TextEditingController _nameEs;
  late final TextEditingController _descEs;
  late final TextEditingController _catEs;

  late final TextEditingController _price;

  String _imageUrl = '';
  String _videoUrl = '';
  bool _featured = false;
  bool _saving = false;
  final _picker = ImagePicker();
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  
  late DocumentReference<Map<String, dynamic>> _docRef;

  // Category Selection
  String? _selectedCategoryCanonical; 
  // We use the Canonical (Spanish) key from HeroCategoryConfig for the dropdown.

  @override
  void initState() {
    super.initState();
    _docRef = widget.product == null
        ? _db.collection('products').doc()
        : _db.collection('products').doc(widget.product!.id);
        
    // Initialize Controllers with dual-language support
    // If editing existing product, use its fields.
    // If fields are empty, try fallback to main 'name'/'description'
    final p = widget.product;
    
    _nameEn = TextEditingController(text: p?.nameEn.isNotEmpty == true ? p!.nameEn : (p?.name ?? ''));
    _nameEs = TextEditingController(text: p?.nameEs ?? '');
    
    _descEn = TextEditingController(text: p?.descriptionEn.isNotEmpty == true ? p!.descriptionEn : (p?.description ?? ''));
    _descEs = TextEditingController(text: p?.descriptionEs ?? '');
    
    // For Category:
    // If it matches a known canonical category, select it.
    // Otherwise, it might be a custom one.
    final existingCat = p?.category ?? '';
    if (HeroCategoryConfig.order.contains(existingCat)) {
      _selectedCategoryCanonical = existingCat;
    } else {
      _selectedCategoryCanonical = null; // Custom or 'Other'
    }
    
    _catEn = TextEditingController(text: p?.categoryEn.isNotEmpty == true ? p!.categoryEn : '');
    _catEs = TextEditingController(text: p?.categoryEs.isNotEmpty == true ? p!.categoryEs : (p?.category ?? ''));
    
    _price = TextEditingController(text: p?.price.toStringAsFixed(2) ?? '');
    
    _imageUrl = p?.imageUrl ?? '';
    _videoUrl = p?.videoUrl ?? '';
    _featured = p?.featured ?? false;
  }

  @override
  void dispose() {
    _nameEn.dispose();
    _nameEs.dispose();
    _descEn.dispose();
    _descEs.dispose();
    _catEn.dispose();
    _catEs.dispose();
    _price.dispose();
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

  Future<void> _translateField(
      TextEditingController source, 
      TextEditingController target, 
      String targetLang) async {
    if (source.text.isEmpty) return;
    
    setState(() => _saving = true); // blocking ui slightly with spinner effect if needed
    try {
      final result = await TranslationService().translate(source.text, targetLang);
      target.text = result;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Translation failed: $e')),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final nameEn = _nameEn.text.trim();
    final nameEs = _nameEs.text.trim(); // Allow empty? Preferably not.
    final price = double.tryParse(_price.text.trim()) ?? 0;
    
    // Determine Category
    // If dropdown selected, use that.
    // If not, use manual input.
    String catCan = '';
    String catEn = '';
    String catEs = '';

    if (_selectedCategoryCanonical != null) {
      catCan = _selectedCategoryCanonical!;
      // Auto-fill en/es from config if possible
      catEs = catCan; // Canonical is Spanish
      catEn = HeroCategoryConfig.translations[catCan] ?? catCan;
    } else {
      // Custom category logic
      if (_catEs.text.isNotEmpty) {
        catCan = _catEs.text.trim(); // Treat Spanish as Canonical for consistency
        catEs = catCan;
        catEn = _catEn.text.trim();
        if (catEn.isEmpty) catEn = catCan; // Fallback
      } else if (_catEn.text.isNotEmpty) {
         // User entered English only (probably)
         catEn = _catEn.text.trim();
         // We should try to translate or just use it
         catCan = catEn; 
         catEs = catEn; 
      }
    }
    
    if (nameEn.isEmpty && nameEs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required.')),
      );
      return;
    }
    if (catCan.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category is required.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // Ensure we have both languages if possible
      String finalNameEn = nameEn;
      String finalNameEs = nameEs;
      String finalDescEn = _descEn.text.trim();
      String finalDescEs = _descEs.text.trim();

<<<<<<< HEAD
      // Auto-fill missing names SMARTLY
      // New logic: Check language of populated fields
      if (finalNameEn.isNotEmpty && finalNameEs.isEmpty) {
        // Did the user type Spanish in the English field?
        final detected = await TranslationService().detectLanguage(finalNameEn);
        if (detected == 'es') {
          // Swap!
          finalNameEs = finalNameEn;
          // Translate to English
          finalNameEn = await TranslationService().translate(finalNameEs, 'en');
        } else {
          // It's English (or unknown), translate to Spanish
          finalNameEs = await TranslationService().translate(finalNameEn, 'es');
        }
      } else if (finalNameEs.isNotEmpty && finalNameEn.isEmpty) {
        // Standard flow: Spanish filled, English empty
        finalNameEn = await TranslationService().translate(finalNameEs, 'en');
      }

      // Do the same for description if possible, or just standard fill
      if (finalDescEn.isNotEmpty && finalDescEs.isEmpty) {
         final detected = await TranslationService().detectLanguage(finalDescEn);
         if (detected == 'es') {
           finalDescEs = finalDescEn;
           finalDescEn = await TranslationService().translate(finalDescEs, 'en');
         } else {
           finalDescEs = await TranslationService().translate(finalDescEn, 'es');
         }
      } else if (finalDescEs.isNotEmpty && finalDescEn.isEmpty) {
         finalDescEn = await TranslationService().translate(finalDescEs, 'en');
=======
      // Auto-fill missing names
      if (finalNameEn.isEmpty && finalNameEs.isNotEmpty) {
        finalNameEn = await TranslationService().translate(finalNameEs, 'en');
      } else if (finalNameEs.isEmpty && finalNameEn.isNotEmpty) {
        finalNameEs = await TranslationService().translate(finalNameEn, 'es');
>>>>>>> 2364cb6 (feat: On-the-fly Product Translation, Ticker Improvements, Search B… (#87))
      }

      final isNew = widget.product == null;
      final data = <String, dynamic>{
        // Core Standard Fields
        'name': finalNameEn.isNotEmpty ? finalNameEn : finalNameEs, // Valid English or fallback
        'description': finalDescEn.isNotEmpty ? finalDescEn : finalDescEs,
        'price': price,
        'category': catCan, // Canonical (Spanish usually) to match Hero Config
        'featured': _featured,
        'imageUrl': _imageUrl,
        'videoUrl': _videoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
        
        // Localized Fields
        'name_en': finalNameEn,
        'name_es': finalNameEs,
        'description_en': finalDescEn,
        'description_es': finalDescEs,
        'category_en': catEn,
        'category_es': catEs,
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

    final isEs = AppState.of(context).languageCode.value == 'es';

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
            const SizedBox(height: 24),
            
            // --- DUAL LANGUAGE NAMES ---
            _buildDualField(
                context, 
                labelEn: 'Name (English)', 
                labelEs: 'Nombre (Inglés)', 
                controller: _nameEn, 
                otherController: _nameEs,
                langCode: 'en'
            ),
            const SizedBox(height: 12),
            _buildDualField(
                context, 
                labelEn: 'Name (Spanish)', 
                labelEs: 'Nombre (Español)', 
                controller: _nameEs, 
                otherController: _nameEn,
                langCode: 'es'
            ),
            
            const SizedBox(height: 24),
            
             // --- CATEGORY DROPDOWN ---
            DropdownButtonFormField<String>(
<<<<<<< HEAD
              initialValue: _selectedCategoryCanonical,
=======
              value: _selectedCategoryCanonical,
>>>>>>> 2364cb6 (feat: On-the-fly Product Translation, Ticker Improvements, Search B… (#87))
              isExpanded: true,
              decoration: InputDecoration(
                labelText: tr(context, en: 'Category', es: 'Categoría'),
                border: const OutlineInputBorder(),
                filled: true,
              ),
              items: [
                ...HeroCategoryConfig.order.map((cat) {
                  // Display localized name in dropdown
                  final display = isEs ? cat : (HeroCategoryConfig.translations[cat] ?? cat);
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(display),
                  );
                }),
                const DropdownMenuItem(
                  value: null,
                  child: Text('Other / Custom...'),
                ),
              ],
              onChanged: (val) {
                 setState(() {
                   _selectedCategoryCanonical = val;
                   // If custom selected, maybe clear manual fields? 
                   // Or pre-fill if switching back/forth? 
                 });
              },
            ),
            
            // Custom Category Fields (Only if 'Other' is selected)
            if (_selectedCategoryCanonical == null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                       Text(tr(context, en: 'Custom Category', es: 'Categoría Personalizada'), style: const TextStyle(fontWeight: FontWeight.bold)),
                       const SizedBox(height: 8),
                       TextField(
                          controller: _catEn,
                          decoration: const InputDecoration(labelText: 'Category (English)', isDense: true),
                       ),
                       const SizedBox(height: 8),
                       TextField(
                          controller: _catEs,
                          decoration: const InputDecoration(labelText: 'Category (Spanish)', isDense: true),
                       ),
                    ],
                  ),
                ),
            ],

            const SizedBox(height: 24),

            // --- DUAL LANGUAGE DESCRIPTIONS ---
            TextField(
              controller: _descEn,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: tr(context, en: 'Description (English)', es: 'Descripción (Inglés)'),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.translate),
                    onPressed: () => _translateField(_descEn, _descEs, 'es'),
                    tooltip: 'Translate to Spanish',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descEs,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: tr(context, en: 'Description (Spanish)', es: 'Descripción (Español)'),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.translate),
                    onPressed: () => _translateField(_descEs, _descEn, 'en'),
                    tooltip: 'Translate to English',
                ),
              ),
            ),

            const SizedBox(height: 20),
            
            // --- PRICE & EXTRAS ---
            TextField(
                controller: _price,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: tr(context, en: 'Price (USD)', es: 'Precio (USD)'),
                  border: const OutlineInputBorder(),
                  prefixText: '\$ ',
                ),
             ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _featured,
              onChanged: (v) => setState(() => _featured = v),
              title: Text(tr(context, en: 'Featured Product', es: 'Producto Destacado')),
            ),
            
            const SizedBox(height: 12),
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
                // Expanded(
                //   child: OutlinedButton.icon(
                //     onPressed: () async {
                //       final url = await _pickAndUpload(true);
                //       if (url != null) setState(() => _videoUrl = url);
                //     },
                //     icon: const Icon(Icons.videocam),
                //     label: Text(tr(context, en: 'Upload video', es: 'Subir video')),
                //   ),
                // ),
              ],
            ),
            if (_imageUrl.isNotEmpty) ...[
               const SizedBox(height: 8),
               Stack(
                 children: [
                    ClipRRect(
                       borderRadius: BorderRadius.circular(8),
                       child: Image.network(_imageUrl, height: 100, width: double.infinity, fit: BoxFit.cover),
                    ),
                    Positioned(top: 4, right: 4, child: CircleAvatar(backgroundColor: Colors.black54, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() => _imageUrl = '')))),
                 ],
               ),
            ],
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: Text(
                  _saving
                      ? tr(context, en: 'Saving...', es: 'Guardando...')
                      : tr(context, en: 'Save Product', es: 'Guardar Producto'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDualField(BuildContext context, {
      required String labelEn, 
      required String labelEs, 
      required TextEditingController controller,
      required TextEditingController otherController,
      required String langCode // 'en' or 'es' denoting the CONTROLLER'S language
  }) {
      final targetLang = langCode == 'en' ? 'es' : 'en';
      return TextField(
        controller: controller,
        decoration: InputDecoration(
           labelText: tr(context, en: labelEn, es: labelEs),
           border: const OutlineInputBorder(),
           suffixIcon: IconButton(
             icon: const Icon(Icons.translate, size: 20),
             tooltip: 'Translate to ${targetLang.toUpperCase()}',
             onPressed: () => _translateField(controller, otherController, targetLang),
           ),
        ),
      );
  }
}

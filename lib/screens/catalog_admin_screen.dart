import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../models/product_model.dart';

class CatalogAdminScreen extends StatefulWidget {
  const CatalogAdminScreen({super.key});

  @override
  State<CatalogAdminScreen> createState() => _CatalogAdminScreenState();
}

class _CatalogAdminScreenState extends State<CatalogAdminScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();
  late final TabController _tabController;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userDocStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _db.collection('users').doc(user.uid).snapshots();
  }

  bool _isAdmin(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['isAdmin'] == true) return true;
    if ((data['role'] as String?)?.toLowerCase() == 'admin') return true;
    return false;
  }

  Future<String?> _uploadBytes({
    required Uint8List bytes,
    required String path,
    required String contentType,
  }) async {
    final ref = _storage.ref().child(path);
    await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return ref.getDownloadURL();
  }

  Future<String?> _pickAndUploadImage(String productId) async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return _uploadBytes(
      bytes: bytes,
      path: 'product_media/$productId/image.jpg',
      contentType: 'image/jpeg',
    );
  }

  Future<String?> _pickAndUploadVideo(String productId) async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return _uploadBytes(
      bytes: bytes,
      path: 'product_media/$productId/video.mp4',
      contentType: 'video/mp4',
    );
  }

  Future<void> _openEditor({Product? product}) async {
    final docRef = product == null
        ? _db.collection('products').doc()
        : _db.collection('products').doc(product.id);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _ProductEditorSheet(
          docRef: docRef,
          product: product,
          pickImage: () => _pickAndUploadImage(docRef.id),
          pickVideo: () => _pickAndUploadVideo(docRef.id),
        );
      },
    );
  }

  Future<void> _deleteProduct(Product product) async {
    await _db.collection('products').doc(product.id).delete();
  }

  Future<void> _addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _db.collection('categories').doc(trimmed).set({
      'name': trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _deleteCategory(String name) async {
    await _db.collection('categories').doc(name).delete();
  }

  @override
  Widget build(BuildContext context) {
    final title = tr(context, en: 'Catalog Manager', es: 'Catalogo');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userDocStream(),
      builder: (context, snapshot) {
        final admin = _isAdmin(snapshot.data?.data());
        if (!admin) {
          return Scaffold(
            appBar: NvAppBar(title: title, showBack: true),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr(
                    context,
                    en:
                        'Access denied. Set role="admin" or isAdmin=true on your user document in Firestore.',
                    es:
                        'Acceso denegado. Configura role="admin" o isAdmin=true en tu usuario de Firestore.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: NvAppBar(
            title: title,
            showBack: true,
          ),
          body: Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: tr(context, en: 'Products', es: 'Productos')),
                  Tab(text: tr(context, en: 'Categories', es: 'Categorias')),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ProductsPanel(
                      openEditor: _openEditor,
                      deleteProduct: _deleteProduct,
                    ),
                    _CategoriesPanel(
                      addCategory: _addCategory,
                      deleteCategory: _deleteCategory,
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: _tabController.index == 0
              ? FloatingActionButton.extended(
                  onPressed: () => _openEditor(),
                  icon: const Icon(Icons.add),
                  label: Text(tr(context, en: 'Add product', es: 'Agregar')),
                )
              : null,
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class _ProductsPanel extends StatelessWidget {
  final Future<void> Function({Product? product}) openEditor;
  final Future<void> Function(Product product) deleteProduct;

  const _ProductsPanel({
    required this.openEditor,
    required this.deleteProduct,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text(
              tr(context, en: 'No products yet.', es: 'Sin productos.'),
            ),
          );
        }
        final products =
            docs.map((doc) => Product.fromFirestore(doc)).toList();
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final product = products[index];
            return Card(
              child: ListTile(
                leading: product.imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          product.imageUrl,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.image_not_supported_outlined),
                title: Text(product.name),
                subtitle: Text(
                  '${product.category} • ${product.price.toStringAsFixed(2)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: tr(context, en: 'Edit', es: 'Editar'),
                      onPressed: () => openEditor(product: product),
                      icon: const Icon(Icons.edit),
                    ),
                    IconButton(
                      tooltip: tr(context, en: 'Delete', es: 'Eliminar'),
                      onPressed: () => deleteProduct(product),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CategoriesPanel extends StatefulWidget {
  final Future<void> Function(String name) addCategory;
  final Future<void> Function(String name) deleteCategory;

  const _CategoriesPanel({
    required this.addCategory,
    required this.deleteCategory,
  });

  @override
  State<_CategoriesPanel> createState() => _CategoriesPanelState();
}

class _CategoriesPanelState extends State<_CategoriesPanel> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: tr(
                      context,
                      en: 'New category',
                      es: 'Nueva categoria',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  await widget.addCategory(_controller.text);
                  _controller.clear();
                },
                child: Text(tr(context, en: 'Add', es: 'Agregar')),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance.collection('categories').snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    tr(
                      context,
                      en: 'No categories yet.',
                      es: 'Sin categorias.',
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final name = docs[index].id;
                  return Card(
                    child: ListTile(
                      title: Text(name),
                      trailing: IconButton(
                        tooltip: tr(context, en: 'Delete', es: 'Eliminar'),
                        onPressed: () => widget.deleteCategory(name),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductEditorSheet extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> docRef;
  final Product? product;
  final Future<String?> Function() pickImage;
  final Future<String?> Function() pickVideo;

  const _ProductEditorSheet({
    required this.docRef,
    required this.product,
    required this.pickImage,
    required this.pickVideo,
  });

  @override
  State<_ProductEditorSheet> createState() => _ProductEditorSheetState();
}

class _ProductEditorSheetState extends State<_ProductEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _category;
  String _imageUrl = '';
  String _videoUrl = '';
  bool _featured = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.product?.name ?? '');
    _description =
        TextEditingController(text: widget.product?.description ?? '');
    _price = TextEditingController(
        text: widget.product?.price.toStringAsFixed(2) ?? '');
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

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    final desc = _description.text.trim();
    final price = double.tryParse(_price.text.trim()) ?? 0;
    final category = _category.text.trim();
    if (name.isEmpty || category.isEmpty) return;

    setState(() => _saving = true);
    final isNew = widget.product == null;
    final data = <String, dynamic>{
      'name': name,
      'description': desc,
      'price': price,
      'category': category,
      'featured': _featured,
      'imageUrl': _imageUrl,
      'videoUrl': _videoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (isNew) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await widget.docRef.set(data, SetOptions(merge: true));

    if (mounted) {
      Navigator.pop(context);
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
              title: Text(
                tr(context, en: 'Featured', es: 'Destacado'),
              ),
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
                      final url = await widget.pickImage();
                      if (url != null) {
                        setState(() => _imageUrl = url);
                      }
                    },
                    icon: const Icon(Icons.image),
                    label: Text(
                      tr(context, en: 'Upload image', es: 'Subir imagen'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final url = await widget.pickVideo();
                      if (url != null) {
                        setState(() => _videoUrl = url);
                      }
                    },
                    icon: const Icon(Icons.videocam),
                    label: Text(
                      tr(context, en: 'Upload video', es: 'Subir video'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_imageUrl.isNotEmpty)
              Text(
                tr(context, en: 'Image ready', es: 'Imagen lista'),
              ),
            if (_videoUrl.isNotEmpty)
              Text(
                tr(context, en: 'Video ready', es: 'Video listo'),
              ),
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

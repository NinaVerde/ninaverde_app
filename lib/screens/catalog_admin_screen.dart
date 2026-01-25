import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/nv_widgets.dart';
import '../state/app_state.dart';
import '../models/product_model.dart';
import '../widgets/admin/product_editor_sheet.dart';

class CatalogAdminScreen extends StatefulWidget {
  const CatalogAdminScreen({super.key});

  @override
  State<CatalogAdminScreen> createState() => _CatalogAdminScreenState();
}

class _CatalogAdminScreenState extends State<CatalogAdminScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  // final _storage = FirebaseStorage.instance; // Unused
  // final _picker = ImagePicker(); // Unused
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


  Future<void> _openEditor({Product? product}) async {
    await ProductEditorSheet.show(context, product: product);
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
            appBar: NvAppBar(tickerVisible: AppState.of(context).showTicker.value, title: title, showBack: true),
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
            tickerVisible: AppState.of(context).showTicker.value,
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
    return ValueListenableBuilder<String>(
      valueListenable: AppState.of(context).languageCode,
      builder: (context, lang, _) {
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
            final products = docs.map((doc) => Product.fromFirestore(doc)).toList();
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final product = products[index];
                final isEs = AppState.of(context).languageCode.value == 'es';

                // Localized Display Name
                final displayName = (isEs && product.nameEs.isNotEmpty) ? product.nameEs : product.name;

                // Subtitle with Category (localized) + Price
                final displayCategory = isEs
                    ? product.categoryEs.isNotEmpty ? product.categoryEs : product.category
                    : product.categoryEn.isNotEmpty ? product.categoryEn : product.category;

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
                              errorBuilder: (ctx, err, stack) =>
                                  const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                            ),
                          )
                        : const Icon(Icons.image_not_supported_outlined),
                    title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '$displayCategory • \$${product.price.toStringAsFixed(2)}',
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


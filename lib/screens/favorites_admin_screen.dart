import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../models/product_model.dart';
// import '../main.dart'; // Removing to avoid ambiguity
import '../state/app_state.dart';
import '../widgets/nv_widgets.dart';

class FavoritesAdminScreen extends StatelessWidget {
  const FavoritesAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final title = tr(context, en: 'Favorites Insights', es: 'Favoritos');
    final service = FirestoreService();

    return Scaffold(
      appBar: NvAppBar(title: title, showBack: true),
      body: StreamBuilder<List<Product>>(
        stream: service.getProducts(),
        builder: (context, productsSnap) {
          final products = productsSnap.data ?? [];
          final map = {for (final p in products) p.id: p};
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('crm_favorites')
                .orderBy('count', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    tr(
                      context,
                      en: 'No favorites data yet.',
                      es: 'Aun no hay datos de favoritos.',
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data();
                  final productId = data['productId'] as String? ?? doc.id;
                  final count = (data['count'] as num?)?.toInt() ?? 0;
                  final product = map[productId];
                  return Card(
                    child: ListTile(
                      leading: product?.imageUrl.isNotEmpty == true
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                product!.imageUrl,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(Icons.favorite),
                      title: Text(product?.name ?? productId),
                      subtitle: Text(product?.category ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.favorite, color: Colors.redAccent),
                          const SizedBox(width: 6),
                          Text(count.toString()),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

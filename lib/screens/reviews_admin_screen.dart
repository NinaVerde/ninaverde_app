import 'package:flutter/material.dart';

import '../services/review_service.dart';
import '../services/firestore_service.dart';
import '../models/review_model.dart';
import '../models/product_model.dart';
import '../main.dart';
import '../state/app_state.dart';
import '../widgets/nv_widgets.dart';

class ReviewsAdminScreen extends StatefulWidget {
  const ReviewsAdminScreen({super.key});

  @override
  State<ReviewsAdminScreen> createState() => _ReviewsAdminScreenState();
}

class _ReviewsAdminScreenState extends State<ReviewsAdminScreen> {
  final ReviewService _reviewService = ReviewService();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final title = tr(context, en: 'Review Moderation', es: 'Moderacion');
    return Scaffold(
      appBar: NvAppBar(title: title, showBack: true),
      body: StreamBuilder<List<Product>>(
        stream: _firestoreService.getProducts(),
        builder: (context, productsSnap) {
          final products = productsSnap.data ?? [];
          final productsById = {for (final p in products) p.id: p};
          return StreamBuilder<ReviewSettings>(
            stream: _reviewService.settingsStream(),
            builder: (context, settingsSnap) {
              final settings = settingsSnap.data ??
                  const ReviewSettings(
                    autoApproveEnabled: true,
                    autoApproveMinRating: 3,
                  );
              return Column(
                children: [
                  _buildSettings(context, settings),
                  const Divider(height: 1),
                  Expanded(
                    child: StreamBuilder<List<Review>>(
                      stream: _reviewService.moderationQueue(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(
                            child: Text(
                              tr(
                                context,
                                en: 'No reviews awaiting moderation.',
                                es: 'No hay reseñas pendientes.',
                              ),
                            ),
                          );
                        }
                        final reviews = snapshot.data!;
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: reviews.length,
                          itemBuilder: (context, index) {
                            final review = reviews[index];
                            final product = productsById[review.productId];
                            final isFlagged = review.status == 'flagged';
                            return Card(
                              color: isFlagged
                                  ? Theme.of(context)
                                      .colorScheme
                                      .errorContainer
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            product?.name ??
                                                review.productId,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        _statusChip(context, review.status),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: List.generate(5, (i) {
                                        final star = i + 1;
                                        return Icon(
                                          star <= review.rating
                                              ? Icons.star
                                              : Icons.star_border,
                                          size: 16,
                                          color: Colors.amber,
                                        );
                                      }),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(review.comment),
                                    const SizedBox(height: 6),
                                    Text(
                                      review.userName.isEmpty
                                          ? 'Guest'
                                          : review.userName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium,
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () async {
                                              await _reviewService
                                                  .rejectReview(review);
                                            },
                                            child: Text(
                                              tr(
                                                context,
                                                en: 'Reject',
                                                es: 'Rechazar',
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: FilledButton(
                                            onPressed: () async {
                                              await _reviewService
                                                  .approveReview(review);
                                            },
                                            child: Text(
                                              tr(
                                                context,
                                                en: 'Approve',
                                                es: 'Aprobar',
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
            },
          );
        },
      ),
    );
  }

  Widget _buildSettings(BuildContext context, ReviewSettings settings) {
    final label = tr(
      context,
      en: 'Auto-approve rating and above',
      es: 'Auto aprobar calificacion y superior',
    );
    final toggle = tr(context, en: 'Auto-approve enabled', es: 'Auto aprobar');
    final ratingLabel =
        tr(context, en: 'Minimum rating', es: 'Calificacion minima');
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(toggle),
            value: settings.autoApproveEnabled,
            onChanged: (value) async {
              await _reviewService.saveSettings(
                ReviewSettings(
                  autoApproveEnabled: value,
                  autoApproveMinRating: settings.autoApproveMinRating,
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Text(label),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('$ratingLabel: ${settings.autoApproveMinRating}'),
              Expanded(
                child: Slider(
                  value: settings.autoApproveMinRating.toDouble(),
                  min: 3,
                  max: 5,
                  divisions: 2,
                  onChanged: (value) async {
                    await _reviewService.saveSettings(
                      ReviewSettings(
                        autoApproveEnabled: settings.autoApproveEnabled,
                        autoApproveMinRating: value.toInt(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context, String status) {
    Color bg;
    String label;
    switch (status) {
      case 'flagged':
        bg = Theme.of(context).colorScheme.error;
        label = tr(context, en: 'Flagged', es: 'Marcada');
        break;
      case 'pending':
        bg = Theme.of(context).colorScheme.secondary;
        label = tr(context, en: 'Pending', es: 'Pendiente');
        break;
      default:
        bg = Theme.of(context).colorScheme.primary;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

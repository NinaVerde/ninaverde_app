import 'package:flutter/material.dart';

import '../services/review_service.dart';
import '../services/firestore_service.dart';
import '../models/review_model.dart';
import '../models/product_model.dart';
// import '../main.dart'; // Removing to avoid 'tr' conflict
import '../state/app_state.dart';
import '../widgets/nv_widgets.dart';

class ReviewsAdminScreen extends StatefulWidget {
  const ReviewsAdminScreen({super.key});

  @override
  State<ReviewsAdminScreen> createState() => _ReviewsAdminScreenState();
}

class _ReviewsAdminScreenState extends State<ReviewsAdminScreen> with SingleTickerProviderStateMixin {
  final ReviewService _reviewService = ReviewService();
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = tr(context, en: 'Elite Review Hub', es: 'Centro de Reseñas');
    final app = AppState.of(context);
    
    return Scaffold(
      appBar: NvAppBar(
        tickerVisible: app.showTicker.value, 
        title: title, 
        showBack: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: tr(context, en: 'Moderation', es: 'Moderación')),
            Tab(text: tr(context, en: 'History', es: 'Historial')),
            Tab(text: tr(context, en: 'Settings', es: 'Ajustes')),
          ],
        ),
      ),
      body: StreamBuilder<List<Review>>(
        stream: _reviewService.allReviews(),
        builder: (context, allReviewsSnap) {
          final allReviews = allReviewsSnap.data ?? [];
          return StreamBuilder<List<Product>>(
            stream: _firestoreService.getProducts(),
            builder: (context, productsSnap) {
              final products = productsSnap.data ?? [];
              final productsById = {for (final p in products) p.id: p};

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildModerationTab(context, allReviews, productsById),
                  _buildHistoryTab(context, allReviews, productsById),
                  _buildSettingsTab(context),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildModerationTab(BuildContext context, List<Review> allReviews, Map<String, Product> productsById) {
    final pending = allReviews.where((r) => r.status == 'pending' || r.status == 'flagged').toList();
    
    return Column(
      children: [
        _buildStatsHeader(context, allReviews),
        Expanded(
          child: pending.isEmpty 
            ? _buildEmptyState(context, tr(context, en: 'No pending reviews', es: 'Sin reseñas pendientes'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: pending.length,
                itemBuilder: (context, i) => _ReviewCard(
                  review: pending[i],
                  product: productsById[pending[i].productId],
                  onApprove: () => _reviewService.approveReview(pending[i]),
                  onReject: () => _showRejectDialog(context, pending[i]),
                  onResolve: pending[i].status == 'flagged' ? () => _showResolveDialog(context, pending[i]) : null,
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab(BuildContext context, List<Review> allReviews, Map<String, Product> productsById) {
    final resolved = allReviews.where((r) => r.status == 'approved' || r.status == 'rejected' || r.status == 'resolved').toList();
    
    return Column(
      children: [
        Expanded(
          child: resolved.isEmpty
            ? _buildEmptyState(context, tr(context, en: 'No history available', es: 'Sin historial'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: resolved.length,
                itemBuilder: (context, i) => _ReviewCard(
                  review: resolved[i],
                  product: productsById[resolved[i].productId],
                  isReadOnly: true,
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab(BuildContext context) {
    return StreamBuilder<ReviewSettings>(
      stream: _reviewService.settingsStream(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return _buildSettings(context, snap.data!);
      },
    );
  }

  Widget _buildStatsHeader(BuildContext context, List<Review> reviews) {
    final total = reviews.length;
    final flagged = reviews.where((r) => r.status == 'flagged').length;
    final pending = reviews.where((r) => r.status == 'pending').length;
    final avgRating = reviews.isEmpty ? 0.0 : reviews.map((r) => r.rating).reduce((a, b) => a + b) / total;

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 8))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(tr(context, en: 'Total', es: 'Total'), '$total', Icons.forum),
          _buildStatItem(tr(context, en: 'Flagged', es: 'Marcadas'), '$flagged', Icons.warning, color: Colors.red),
          _buildStatItem(tr(context, en: 'Pending', es: 'Espera'), '$pending', Icons.hourglass_empty, color: Colors.orange),
          _buildStatItem(tr(context, en: 'Avg', es: 'Prom'), avgRating.toStringAsFixed(1), Icons.star, color: Colors.amber),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.green, size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, Review review) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, en: 'Reject Review', es: 'Rechazar Reseña')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: tr(context, en: 'Reason (Optional)', es: 'Razón (Opcional)')),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr(context, en: 'Cancel', es: 'Cancelar'))),
          FilledButton(
            onPressed: () {
              _reviewService.rejectReview(review, reason: controller.text);
              Navigator.pop(context);
            },
            child: Text(tr(context, en: 'Confirm Reject', es: 'Confirmar Rechazo')),
          ),
        ],
      ),
    );
  }

  void _showResolveDialog(BuildContext context, Review review) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, en: 'Resolve Flag', es: 'Resolver Alerta')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: tr(context, en: 'Resolution notes...', es: 'Notas de resolución...')),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr(context, en: 'Cancel', es: 'Cancelar'))),
          FilledButton(
            onPressed: () {
              _reviewService.resolveFlaggedReview(review, controller.text);
              Navigator.pop(context);
            },
            child: Text(tr(context, en: 'Mark Resolved', es: 'Marcar Resuelto')),
          ),
        ],
      ),
    );
  }

  Widget _buildSettings(BuildContext context, ReviewSettings settings) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _SectionHeader(
          title: tr(context, en: 'Automation', es: 'Automatización'),
          subtitle: tr(context, en: 'Control how reviews are handled.', es: 'Controla el manejo de reseñas.'),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr(context, en: 'Auto-approve Enabled', es: 'Auto-aprobar Activado')),
          subtitle: Text(tr(context, en: 'High ratings bypass moderation.', es: 'Calificaciones altas saltan moderación.')),
          value: settings.autoApproveEnabled,
          onChanged: (v) => _reviewService.saveSettings(ReviewSettings(autoApproveEnabled: v, autoApproveMinRating: settings.autoApproveMinRating)),
        ),
        const Divider(height: 32),
        Text('${tr(context, en: 'Min Rating for Auto-approve', es: 'Calificación Mínima')}: ${settings.autoApproveMinRating}'),
        Slider(
          value: settings.autoApproveMinRating.toDouble(),
          min: 3, max: 5, divisions: 2,
          onChanged: (v) => _reviewService.saveSettings(ReviewSettings(autoApproveEnabled: settings.autoApproveEnabled, autoApproveMinRating: v.toInt())),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;
  final Product? product;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onResolve;
  final bool isReadOnly;

  const _ReviewCard({
    required this.review,
    this.product,
    this.onApprove,
    this.onReject,
    this.onResolve,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFlagged = review.status == 'flagged';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      shadowColor: isFlagged ? Colors.red.withOpacity(0.2) : Colors.black12,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isFlagged ? Colors.red.withOpacity(0.3) : Colors.transparent,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: theme.colorScheme.primaryContainer, child: const Icon(Icons.person, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(review.userName.isEmpty ? 'Guest' : review.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(product?.name ?? 'Unknown Product', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                _buildStatusChip(context, review.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(5, (i) => Icon(
                i < review.rating ? Icons.star : Icons.star_border,
                size: 16, color: Colors.amber,
              )),
            ),
            const SizedBox(height: 8),
            Text(review.comment, style: theme.textTheme.bodyMedium),
            if (isReadOnly && (review.rejectionReason?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 8),
              Text('${tr(context, en: 'Reason', es: 'Razón')}: ${review.rejectionReason}', style: const TextStyle(color: Colors.red, fontSize: 12, fontStyle: FontStyle.italic)),
            ],
            if (isReadOnly && (review.managerNotes?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 8),
              Text('${tr(context, en: 'Notes', es: 'Notas')}: ${review.managerNotes}', style: const TextStyle(color: Colors.blue, fontSize: 12, fontStyle: FontStyle.italic)),
            ],
            if (!isReadOnly) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                      onPressed: onReject, 
                      child: Text(tr(context, en: 'Reject', es: 'Rechazar'))
                    ),
                  ),
                  if (onResolve != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.blue, side: const BorderSide(color: Colors.blue)),
                        onPressed: onResolve, 
                        child: Text(tr(context, en: 'Resolve', es: 'Resolver'))
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: onApprove, 
                      child: Text(tr(context, en: 'Approve', es: 'Aprobar'))
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    Color color;
    switch(status) {
      case 'approved': color = Colors.green; break;
      case 'rejected': color = Colors.red; break;
      case 'flagged': color = Colors.redAccent; break;
      case 'pending': color = Colors.orange; break;
      case 'resolved': color = Colors.blue; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
      ],
    );
  }
}

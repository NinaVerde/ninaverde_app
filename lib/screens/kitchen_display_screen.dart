// lib/screens/kitchen_display_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order_model.dart';
import '../models/user_profile_model.dart';
import '../services/kitchen_service.dart';
import '../services/user_profile_service.dart';

/// Kitchen Display System (KDS) - Real-time order tracking for kitchen staff
class KitchenDisplayScreen extends StatefulWidget {
  const KitchenDisplayScreen({super.key});

  @override
  State<KitchenDisplayScreen> createState() => _KitchenDisplayScreenState();
}

class _KitchenDisplayScreenState extends State<KitchenDisplayScreen> {
  final KitchenService _kitchenService = KitchenService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserProfileService _profileService = UserProfileService();
  
  UserProfile? _userProfile;
  bool _loading = true;
  
  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }
  
  Future<void> _loadUserProfile() async {
    final profile = await _profileService.getCurrentUserProfile();
    setState(() {
      _userProfile = profile;
      _loading = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    // Check if user has kitchen access
    if (_userProfile == null || !_userProfile!.canAccessKitchen) {
      return Scaffold(
        backgroundColor: Colors.grey[900],
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('Access Denied'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Kitchen Access Required',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(
                'You do not have permission to access the kitchen display.',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          '🔥 Kitchen Display',
          style: TextStyle(
            color: Colors.orangeAccent,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          FutureBuilder<Map<String, int>>(
            future: _kitchenService.getKitchenStats(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final stats = snapshot.data!;
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    'Today: ${stats['total']} | Preparing: ${stats['preparing']} | Ready: ${stats['ready']}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: _kitchenService.getActiveOrdersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent),
            );
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant, size: 80, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  Text(
                    'No Active Orders',
                    style: TextStyle(color: Colors.grey[600], fontSize: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kitchen is all caught up! 👨‍🍳',
                    style: TextStyle(color: Colors.grey[700], fontSize: 16),
                  ),
                ],
              ),
            );
          }
          
          final orders = snapshot.data!;
          final paidOrders = orders.where((o) => o.status == OrderStatus.paid).toList();
          final preparingOrders = orders.where((o) => o.status == OrderStatus.preparing).toList();
          final readyOrders = orders.where((o) => o.status == OrderStatus.ready).toList();
          
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (paidOrders.isNotEmpty) ...[
                    _buildSectionHeader('New Orders', paidOrders.length, Colors.red),
                    _buildOrderGrid(paidOrders, OrderStatus.paid),
                    const SizedBox(height: 24),
                  ],
                  if (preparingOrders.isNotEmpty) ...[
                    _buildSectionHeader('Preparing', preparingOrders.length, Colors.orange),
                    _buildOrderGrid(preparingOrders, OrderStatus.preparing),
                    const SizedBox(height: 24),
                  ],
                  if (readyOrders.isNotEmpty) ...[
                    _buildSectionHeader('Ready for Pickup', readyOrders.length, Colors.green),
                    _buildOrderGrid(readyOrders, OrderStatus.ready),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            color: color,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 1),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildOrderGrid(List<OrderModel> orders, OrderStatus currentStatus) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: orders.map((order) => _buildOrderCard(order, currentStatus)).toList(),
    );
  }
  
  Widget _buildOrderCard(OrderModel order, OrderStatus currentStatus) {
    final timeElapsed = DateTime.now().difference(order.createdAt);
    final isUrgent = timeElapsed.inMinutes > 15;
    
    Color cardColor;
    Color accentColor;
    
    switch (currentStatus) {
      case OrderStatus.paid:
        cardColor = Colors.red[900]!;
        accentColor = Colors.red;
        break;
      case OrderStatus.preparing:
        cardColor = Colors.orange[900]!;
        accentColor = Colors.orange;
        break;
      case OrderStatus.ready:
        cardColor = Colors.green[900]!;
        accentColor = Colors.green;
        break;
      default:
        cardColor = Colors.grey[800]!;
        accentColor = Colors.grey;
    }
    
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUrgent ? Colors.red : accentColor,
          width: isUrgent ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.id.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      _getOrderTypeIcon(order.orderType),
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getOrderTypeLabel(order.orderType),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Timer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: isUrgent ? Colors.red.withOpacity(0.3) : Colors.black.withOpacity(0.2),
            child: Text(
              '⏱️ ${_formatDuration(timeElapsed)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isUrgent ? Colors.red[300] : Colors.white70,
                fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
          
          // Order Items
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${item.quantity}x',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
                if (order.notes != null && order.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.yellow[700]!.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.yellow[700]!, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.note, color: Colors.yellow, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            order.notes!,
                            style: const TextStyle(
                              color: Colors.yellow,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildActionButtons(order, currentStatus),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons(OrderModel order, OrderStatus currentStatus) {
    final currentUser = _auth.currentUser;
    final userId = currentUser?.uid ?? 'unknown';
    
    switch (currentStatus) {
      case OrderStatus.paid:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _startPreparing(order.id, userId),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Preparing'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        );
        
      case OrderStatus.preparing:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _markReady(order.id),
            icon: const Icon(Icons.check_circle),
            label: const Text('Mark Ready'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        );
        
      case OrderStatus.ready:
        return const Text(
          '✅ Waiting for pickup/delivery',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.green, fontSize: 12),
        );
        
      default:
        return const SizedBox();
    }
  }
  
  IconData _getOrderTypeIcon(OrderType type) {
    switch (type) {
      case OrderType.delivery:
        return Icons.delivery_dining;
      case OrderType.pickup:
        return Icons.shopping_bag;
      case OrderType.dineIn:
        return Icons.restaurant;
    }
  }
  
  String _getOrderTypeLabel(OrderType type) {
    switch (type) {
      case OrderType.delivery:
        return 'Delivery';
      case OrderType.pickup:
        return 'Pickup';
      case OrderType.dineIn:
        return 'Dine-In';
    }
  }
  
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
  }
  
  Future<void> _startPreparing(String orderId, String staffId) async {
    try {
      await _kitchenService.startPreparingOrder(orderId, staffId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order started! 👨‍🍳'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  Future<void> _markReady(String orderId) async {
    try {
      await _kitchenService.markOrderReady(orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order ready for pickup! ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

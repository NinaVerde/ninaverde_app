import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math'; // For random ID
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../main.dart';
import '../state/app_state.dart';
import '../providers/cart_provider.dart';
import '../models/order_model.dart';
import '../services/checkout_service.dart';
import '../widgets/nv_widgets.dart';
import 'home_screen.dart'; 
import '../services/analytics_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int _currentStep = 0;
  OrderType _orderType = OrderType.delivery;
  
  // Details
  final _addressCtrl = TextEditingController();
  final _tableCtrl = TextEditingController();
  final _notesCtrl = TextEditingController(); // For "user friendly notes"
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Financials
  double _tipAmount = 0.0;
  int _selectedTipIndex = 1; // Default to 15%?

  // Order Totals State
  OrderTotals? _calculatedTotals;
  bool _calculating = false;

  // Payment
  PaymentMethod _paymentMethod = PaymentMethod.bac;
  final _cardNumCtrl = TextEditingController();
  final _cardExpCtrl = TextEditingController();
  final _cardCvvCtrl = TextEditingController();
  final _cardHolderCtrl = TextEditingController();
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _prefillUser();
    _recalculate();
  }

  void _prefillUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameCtrl.text = user.displayName ?? '';
      _phoneCtrl.text = user.phoneNumber ?? ''; 
      // Ideally fetch address from user profile if saved
    }
  }

  Future<void> _recalculate() async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    setState(() => _calculating = true);
    
    final totals = await CheckoutService.calculateTotals(
      subtotal: cart.totalAmount,
      type: _orderType,
      tipAmount: _tipAmount,
    );

    if (mounted) {
      setState(() {
        _calculatedTotals = totals;
        _calculating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    final isEs = app.languageCode.value == 'es';
    // Helper tr
    String t(String en, String es) => isEs ? es : en;

    return Scaffold(
      appBar: NvAppBar(
        title: t('Checkout', 'Finalizar Pedido'),
        showBack: true,
      ),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepContinue: _nextStep,
        onStepCancel: _prevStep,
        controlsBuilder: (ctx, details) {
          // Custom controls at bottom
          return const SizedBox.shrink(); 
        },
        steps: [
          Step(
            title: Text(t('Mode', 'Modo')),
            content: _buildModeStep(t),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.editing,
          ),
          Step(
            title: Text(t('Review', 'Revisar')),
            content: _buildReviewStep(t),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.editing,
          ),
          Step(
            title: Text(t('Pay', 'Pagar')),
            content: _buildPaymentStep(t),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.editing,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildBottomBar(t),
        ),
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// Step 1: Order Mode & Details
  /// --------------------------------------------------------------------------
  Widget _buildModeStep(String Function(String, String) t) {
    return Column(
      children: [
        // Mode Selector Cards
        Row(
          children: [
            _modeCard(OrderType.delivery, Icons.delivery_dining, t('Delivery', 'Domicilio')),
            const SizedBox(width: 8),
            _modeCard(OrderType.pickup, Icons.shopping_bag, t('Pickup', 'Recoger')),
            const SizedBox(width: 8),
            _modeCard(OrderType.dineIn, Icons.restaurant, t('Dine-In', 'Mesa')),
          ],
        ),
        const SizedBox(height: 20),
        
        // Dynamic Fields
        if (_orderType == OrderType.delivery)
          TextField(
            controller: _addressCtrl,
            decoration: InputDecoration(
              labelText: t('Delivery Address', 'Dirección de Entrega'),
              prefixIcon: const Icon(Icons.location_on),
              border: const OutlineInputBorder(),
            ),
          ),
        if (_orderType == OrderType.dineIn)
          TextField(
            controller: _tableCtrl,
            decoration: InputDecoration(
              labelText: t('Table Number', 'Número de Mesa'),
              prefixIcon: const Icon(Icons.table_restaurant),
              border: const OutlineInputBorder(),
            ),
          ),
        
        const SizedBox(height: 16),
        // Contact Info
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            labelText: t('Your Name', 'Tu Nombre'),
            prefixIcon: const Icon(Icons.person),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: t('Phone Number', 'Teléfono'),
            prefixIcon: const Icon(Icons.phone),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        // Notes
        TextField(
          controller: _notesCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: t('Order Notes (Allergies, etc.)', 'Notas (Alergias, etc.)'),
            hintText: t('Leave a note for the kitchen...', 'Deja una nota para la cocina...'),
            prefixIcon: const Icon(Icons.note_add),
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _modeCard(OrderType type, IconData icon, String label) {
    final selected = _orderType == type;
    final color = selected ? Theme.of(context).primaryColor : Colors.grey.shade200;
    final textCol = selected ? Colors.white : Colors.black87;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _orderType = type);
          _recalculate();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0,4))] : [],
          ),
          child: Column(
            children: [
              Icon(icon, color: textCol, size: 28),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// Step 2: Review & Financials
  /// --------------------------------------------------------------------------
  Widget _buildReviewStep(String Function(String, String) t) {
    final cart = Provider.of<CartProvider>(context);
    final totals = _calculatedTotals;
    
    if (totals == null) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('Order Summary', 'Resumen del Pedido'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cart.items.length,
          itemBuilder: (ctx, i) {
            final item = cart.items.values.elementAt(i);
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(item.product.imageUrl, width: 40, height: 40, fit: BoxFit.cover),
              ),
              title: Text(item.product.name),
              trailing: Text('${item.quantity} x ${formatCurrency(context, item.product.price)}'),
            );
          },
        ),
        const Divider(),
        
        // Smart Upsell Placeholder (Carousel would go here)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(child: Text(t('Forgot a drink? Add a Fresh Juice!', '¿Olvidaste la bebida? ¡Agrega un Jugo Fresco!'))),
              // In real implementation, this button would fetch a random Drink product
              TextButton(onPressed: () {}, child: Text(t('Add', 'Agregar'))),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tipping
        Text(t('Add a Tip', 'Agregar Propina'), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            _tipChip(0, '0%', 0.0),
            const SizedBox(width: 8),
            _tipChip(1, '10%', 0.10),
            const SizedBox(width: 8),
            _tipChip(2, '15%', 0.15),
            const SizedBox(width: 8),
            _tipChip(3, '20%', 0.20),
          ],
        ),
        
        const SizedBox(height: 16),
        _summaryRow(t('Subtotal', 'Subtotal'), totals.subtotal),
        _summaryRow(t('Tax (15%)', 'IVA (15%)'), totals.tax),
        if (totals.serviceFee > 0) _summaryRow(t('Service Fee (10%)', 'Servicio (10%)'), totals.serviceFee),
        _summaryRow(t('Tip', 'Propina'), totals.tip),
        const Divider(),
        _summaryRow(t('Total', 'Total'), totals.total, isTotal: true),
      ],
    );
  }

  Widget _tipChip(int index, String label, double pct) {
    final selected = _selectedTipIndex == index;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) {
        if (val) {
          final cart = Provider.of<CartProvider>(context, listen: false);
          setState(() {
            _selectedTipIndex = index;
            _tipAmount = cart.totalAmount * pct;
          });
          _recalculate();
        }
      },
    );
  }

  Widget _summaryRow(String label, double val, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 18 : 14)),
          Text(formatCurrency(context, val), style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 18 : 14)),
        ],
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// Step 3: Payment
  /// --------------------------------------------------------------------------
  Widget _buildPaymentStep(String Function(String, String) t) {
    return Column(
      children: [
        // Method Selector
        Row(
          children: [
            _paymentCard(PaymentMethod.bac, 'BAC Credomatic', 'assets/images/bac_logo.png'), // Placeholder asset
            const SizedBox(width: 12),
            _paymentCard(PaymentMethod.paypal, 'PayPal', 'assets/images/paypal_logo.png'),
          ],
        ),
        const SizedBox(height: 20),

        if (_paymentMethod == PaymentMethod.bac) ...[
          // Mock Credit Card Form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).cardColor,
            ),
            child: Column(
              children: [
                TextField(
                  controller: _cardNumCtrl,
                  decoration: InputDecoration(
                    labelText: t('Card Number', 'Número de Tarjeta'),
                    prefixIcon: const Icon(Icons.credit_card),
                    hintText: '0000 0000 0000 0000',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cardExpCtrl,
                        decoration: const InputDecoration(
                          labelText: 'MM/YY',
                          hintText: '12/25',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _cardCvvCtrl,
                        decoration: const InputDecoration(
                          labelText: 'CVV',
                          prefixIcon: Icon(Icons.lock),
                        ),
                        obscureText: true,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cardHolderCtrl,
                  decoration: InputDecoration(
                    labelText: t('Cardholder Name', 'Titular'),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.lock, size: 16, color: Colors.green),
              const SizedBox(width: 4),
              Text(t('Secure transaction via BAC Credomatic', 'Transacción segura vía BAC Credomatic'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ] else ...[
          // PayPal Info
          const SizedBox(height: 20),
          const Icon(Icons.paypal, size: 60, color: Colors.blue),
          const SizedBox(height: 10),
          Text(
            t('You will be redirected to PayPal to complete your purchase safely.', 'Serás redirigido a PayPal para completar tu compra de forma segura.'),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _paymentCard(PaymentMethod method, String label, String assetPath) {
    final selected = _paymentMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = method),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: selected ? Colors.red.withValues(alpha: 0.05) : Colors.white, // Red tint for BAC brand?
            border: Border.all(color: selected ? Colors.red : Colors.grey.shade300, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Just text/icon for now if asset missing
              Icon(method == PaymentMethod.bac ? Icons.credit_card : Icons.account_balance_wallet, color: selected ? Colors.red : Colors.grey),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? Colors.red : Colors.grey)),
            ],
          ),
        ).animate(target: selected ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 200.ms),
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// Navigation & Actions
  /// --------------------------------------------------------------------------
  Widget _buildBottomBar(String Function(String, String) t) {
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: _prevStep,
              child: Text(t('Back', 'Atrás')),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton(
             style: FilledButton.styleFrom(
              backgroundColor: _currentStep == 2 ? Colors.green.shade700 : null,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _processing ? null : _nextStep,
            child: _processing 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_currentStep == 2 ? t('PAY NOW', 'PAGAR AHORA') : t('Continue', 'Continuar')),
          ),
        ),
      ],
    );
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _nextStep() async {
    final isEs = AppState.of(context).languageCode.value == 'es';
    String t(String en, String es) => isEs ? es : en;

    if (_currentStep == 0) {
      if (_orderType == OrderType.delivery && _addressCtrl.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Please enter delivery address', 'Ingresa la dirección'))));
        return;
      }
      if (_nameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Name and Phone are required', 'Nombre y Teléfono son requeridos'))));
        return;
      }
      setState(() => _currentStep++);
    } else if (_currentStep == 1) {
      setState(() => _currentStep++);
    } else {
      // PAY
      _submitOrder();
    }
  }

  Future<void> _submitOrder() async {
    setState(() => _processing = true);
    final app = AppState.of(context);
    final cart = Provider.of<CartProvider>(context, listen: false);
    final totals = _calculatedTotals!;

    try {
      // 1. Process Payment
      if (_paymentMethod == PaymentMethod.bac) {
        await CheckoutService.processBacPayment(
          cardNumber: _cardNumCtrl.text,
          expiry: _cardExpCtrl.text,
          cvv: _cardCvvCtrl.text,
          holderName: _cardHolderCtrl.text, 
          amount: totals.total,
        );
      } else {
        await CheckoutService.processPaypalPayment(amount: totals.total);
      }

      // 2. Create Order Object
      final order = OrderModel(
        id: 'ORD-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}',
        userId: FirebaseAuth.instance.currentUser?.uid ?? 'guest',
        userName: _nameCtrl.text,
        userPhone: _phoneCtrl.text,
        orderType: _orderType,
        status: OrderStatus.paid,
        paymentMethod: _paymentMethod,
        items: cart.items.values.map((item) => CartItemSnapshot.fromCartItem(item)).toList(),
        subtotal: totals.subtotal,
        tax: totals.tax,
        serviceFee: totals.serviceFee,
        tip: totals.tip,
        total: totals.total,
        currencyCode: app.currencyCode.value,
        exchangeRate: app.currencyConfigs.value[app.currencyCode.value]?.rateFromUsd ?? 1.0,
        createdAt: DateTime.now(),
        deliveryAddress: _addressCtrl.text,
        tableNumber: _tableCtrl.text,
        notes: _notesCtrl.text,
      );

      // 3. Save to DB
      await CheckoutService.submitOrder(order);

      // Log Purchase
      AnalyticsService.logPurchase(
        orderId: order.id, 
        value: order.total, 
        itemCount: order.items.length
      );

      // 4. Clear Cart
      cart.clear();

      if (!mounted) return;
      
      // Success Celebration Overlay
      if (!mounted) return;
      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.8),
        pageBuilder: (ctx, anim1, anim2) {
           return Scaffold(
             backgroundColor: Colors.transparent,
             body: Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   // Animated Checkmark
                   Container(
                     padding: const EdgeInsets.all(30),
                     decoration: const BoxDecoration(
                       shape: BoxShape.circle,
                       color: Colors.white,
                     ),
                     child: const Icon(Icons.check_rounded, size: 80, color: Colors.green),
                   ).animate().scale(duration: 600.ms, curve: Curves.elasticOut).shimmer(delay: 500.ms),
                   
                   const SizedBox(height: 30),
                   
                   Text(
                     app.languageCode.value == 'es' 
                      ? '¡Pedido Confirmado!' 
                      : 'Order Confirmed!',
                     style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
                   ).animate().fadeIn(delay: 300.ms).moveY(begin: 20, end: 0),
                   
                   const SizedBox(height: 10),
                   
                   Text(
                     app.languageCode.value == 'es' 
                       ? 'Gracias por tu compra en Niña Verde.' 
                       : 'Thank you for shopping at Niña Verde.',
                     textAlign: TextAlign.center,
                     style: const TextStyle(fontSize: 18, color: Colors.white70),
                   ).animate().fadeIn(delay: 500.ms),
                   
                   const SizedBox(height: 50),
                   
                   FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const HomeScreen()), 
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.home),
                      label: Text(app.languageCode.value == 'es' ? 'Volver al Inicio' : 'Back to Home'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                   ).animate().fadeIn(delay: 800.ms).scale(),
                 ],
               ),
             ),
           );
        },
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Payment Failed: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }
}

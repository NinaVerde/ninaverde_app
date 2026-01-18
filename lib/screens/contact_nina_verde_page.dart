import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// import '../main.dart'; // Removing to avoid ambiguity
import '../state/app_state.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
// import '../services/translation_service.dart'; // Unused
import '../widgets/nv_widgets.dart';

class ContactNinaVerdePage extends StatefulWidget {
  const ContactNinaVerdePage({super.key});

  @override
  State<ContactNinaVerdePage> createState() => _ContactNinaVerdePageState();
}

enum _MessageRole { user, assistant }

enum _MessageState { typing, sent }

class _ChatMessage {
  _ChatMessage({
    required this.id,
    required this.text,
    required this.role,
    required this.state,
    required this.timestamp,
  });

  final String id;
  final String text;
  final _MessageRole role;
  final _MessageState state;
  final DateTime timestamp;

  _ChatMessage copyWith({
    String? text,
    _MessageState? state,
  }) {
    return _ChatMessage(
      id: id,
      text: text ?? this.text,
      role: role,
      state: state ?? this.state,
      timestamp: timestamp,
    );
  }
}

class _AiResponse {
  _AiResponse({
    required this.reply,
    required this.actions,
    this.requiresConfirmation = false,
  });

  final String reply;
  final List<_AiAction> actions;
  final bool requiresConfirmation;
}

enum _AiActionType { addToCart, removeFromCart, goToCheckout }

class _AiAction {
  _AiAction({required this.type, this.productId, this.quantity});

  final _AiActionType type;
  final String? productId;
  final int? quantity;

  factory _AiAction.fromMap(Map<String, dynamic> data) {
    final type = (data['type'] as String? ?? '').toLowerCase();
    switch (type) {
      case 'add_to_cart':
        return _AiAction(
          type: _AiActionType.addToCart,
          productId: data['productId'] as String?,
          quantity: (data['quantity'] as num?)?.toInt() ?? 1,
        );
      case 'remove_from_cart':
        return _AiAction(
          type: _AiActionType.removeFromCart,
          productId: data['productId'] as String?,
          quantity: (data['quantity'] as num?)?.toInt() ?? 1,
        );
      case 'go_to_checkout':
        return _AiAction(type: _AiActionType.goToCheckout);
      default:
        return _AiAction(type: _AiActionType.goToCheckout);
    }
  }
}

class _ContactNinaVerdePageState extends State<ContactNinaVerdePage>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final List<_ChatMessage> _messages = [];

  late final AnimationController _pulseCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _waveCtrl;

  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _sttReady = false;
  bool _isListening = false;

  final FlutterTts _tts = FlutterTts();
  bool _voiceEnabled = true;
  bool _isSpeaking = false;

  bool _isTyping = false;
  Timer? _typingTimer;

  _AiRuntimeConfig _config = _AiRuntimeConfig.defaults();
  String? _greetingId;
  String? _avatarUrl;

  List<Product> _menu = [];
  bool _menuLoaded = false;
  bool _awaitingCheckoutConfirm = false;
  bool _handledArgs = false;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 12000),
    )..repeat();

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    // _bootstrapAssistant(); // Moved to didChangeDependencies to access AppState
    _configureTts();
    _loadAiConfig();
    _loadMenu();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Bootstrap with correct language from AppState
    if (!_bootstrapped) {
      _bootstrapAssistant();
      _bootstrapped = true;
    } else {
      // If language changed while on screen, update greeting
      _replaceGreeting();
    }

    if (_handledArgs) return;
    _handledArgs = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['autoListen'] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isListening) {
          _toggleListening();
        }
      });
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _pulseCtrl.dispose();
    _floatCtrl.dispose();
    _waveCtrl.dispose();
    _controller.dispose();
    _inputFocus.dispose();
    _stt.stop();
    _tts.stop();
    super.dispose();
  }

  Future<void> _configureTts() async {
    // Sultry/Sexy settings: slightly slower, slightly lower pitch
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(0.8);
    await _tts.setVolume(1.0);
    _tts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  Future<void> _loadAiConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('ai_hostess')
          .doc('angelina')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _avatarUrl = _extractAvatarUrl(data);
        if (mounted) {
          setState(() {
            _config = _AiRuntimeConfig.fromMap(data);
          });
        }
        _replaceGreeting();
      }
    } catch (_) {
      // fall back to defaults
    }
  }

  String? _extractAvatarUrl(Map<String, dynamic> data) {
    final media = data['media'];
    if (media is! List) return null;
    for (final item in media) {
      if (item is Map && item['type'] == 'image') {
        final url = item['url'];
        if (url is String && url.isNotEmpty) return url;
      }
    }
    return null;
  }

  Future<void> _loadMenu() async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('products').get();
      if (mounted) {
        setState(() {
          _menu = snap.docs.map(Product.fromFirestore).toList();
          _menuLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _menuLoaded = true);
    }
  }

  void _bootstrapAssistant() {
    final isEs = AppState.of(context).languageCode.value == 'es';
    final greeting = _config.greetingFor(isEs);
    final id = _id();
    _greetingId = id;
    _messages.add(
      _ChatMessage(
        id: id,
        text: greeting,
        role: _MessageRole.assistant,
        state: _MessageState.sent,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _replaceGreeting() {
    if (_greetingId == null) return;
    final index = _messages.indexWhere((m) => m.id == _greetingId);
    if (index == -1) return;
    final isEs = AppState.of(context).languageCode.value == 'es';
    if (mounted) {
      setState(() {
        _messages[index] = _messages[index].copyWith(
          text: _config.greetingFor(isEs),
        );
      });
    }
  }

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _handleSend({String? overrideText}) async {
    final text = (overrideText ?? _controller.text).trim();
    if (text.isEmpty) return;

    _controller.clear();
    _inputFocus.unfocus();
    HapticFeedback.lightImpact();

    setState(() {
      _isTyping = false;
      _messages.add(
        _ChatMessage(
          id: _id(),
          text: text,
          role: _MessageRole.user,
          state: _MessageState.sent,
          timestamp: DateTime.now(),
        ),
      );
    });

    await _respondTo(text);
  }
  Future<void> _respondTo(String userText) async {
    final typingId = _id();
    setState(() {
      _messages.add(
        _ChatMessage(
          id: typingId,
          text: 'Thinking...',
          role: _MessageRole.assistant,
          state: _MessageState.typing,
          timestamp: DateTime.now(),
        ),
      );
    });

    final isEs = Provider.of<AppState>(context, listen: false).languageCode.value == 'es';
    _AiResponse response;

    if (_awaitingCheckoutConfirm) {
      final confirmed = _detectCheckoutConfirm(userText);
      if (confirmed) {
        _awaitingCheckoutConfirm = false;
        response = _AiResponse(
          reply: isEs ? 'Dale pues. Te llevo al checkout. ¡Qué alegre!' : 'Alright darling. Taking you to checkout.',
          actions: [
            _AiAction(type: _AiActionType.goToCheckout),
          ],
        );
      } else {
        response = _AiResponse(
          reply: isEs
              ? 'Cuando estés listo, solo dime "confirmar", corazón.'
              : 'Whenever you are ready, just say "confirm", hun.',
          actions: const [],
        );
      }
    } else if (_config.onlineEnabled && _config.endpointUrl.isNotEmpty) {
      response = await _fetchOnlineResponse(userText, isEs) ??
          _offlineResponse(userText, isEs);
    } else {
      response = _offlineResponse(userText, isEs);
    }

    if (response.requiresConfirmation) {
      _awaitingCheckoutConfirm = true;
      response = _AiResponse(
        reply: response.reply,
        actions: response.actions
            .where((a) => a.type != _AiActionType.goToCheckout)
            .toList(),
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;
    setState(() {
      final index = _messages.indexWhere((m) => m.id == typingId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          text: response.reply,
          state: _MessageState.sent,
        );
      }
    });

    if (_voiceEnabled) {
      await _speak(response.reply, isEs);
    }

    if (response.actions.isNotEmpty) {
      await _applyActions(response.actions);
    }
  }

  Future<_AiResponse?> _fetchOnlineResponse(String text, bool isEs) async {
    try {
      final uri = Uri.parse(_config.endpointUrl);
      final cart = Provider.of<CartProvider>(context, listen: false);
      final payload = {
        'message': text,
        'language': isEs ? 'es' : 'en',
        'persona': {
          'name': _config.personaName,
          'bioEn': _config.personaBioEn,
          'bioEs': _config.personaBioEs,
        },
        'knowledge': _config.knowledge.map((k) => k.toMap()).toList(),
        'menu': _menu
            .map((p) => {
                  'id': p.id,
                  'name': p.name,
                  'category': p.category,
                  'price': p.price,
                })
            .toList(),
        'cart': cart.items.values
            .map((item) => {
                  'productId': item.product.id,
                  'name': item.product.name,
                  'quantity': item.quantity,
                  'price': item.product.price,
                })
            .toList(),
      };
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final reply = (data['reply'] as String?)?.trim();
      if (reply == null || reply.isEmpty) return null;
      final actions = (data['actions'] as List? ?? [])
          .whereType<Map>()
          .map((raw) => _AiAction.fromMap(raw.cast<String, dynamic>()))
          .toList();
      final requiresConfirmation = data['requiresConfirmation'] == true;
      return _AiResponse(
        reply: reply,
        actions: actions,
        requiresConfirmation: requiresConfirmation,
      );
    } catch (_) {
      return null;
    }
  }

  _AiResponse _offlineResponse(String text, bool isEs) {
    final matches = _matchKnowledge(text);
    if (matches.isNotEmpty) {
      final snippets = matches.take(2).map((k) => k.contentFor(isEs));
      return _AiResponse(reply: snippets.join('\n'), actions: const []);
    }

    final orderAction = _maybeOrderAction(text);
    if (orderAction != null) {
      final reply = isEs
          ? 'Listo pues. Ya lo agregué. ¿Se te antoja algo más, amor?'
          : 'Done. Added to your cart. Craving anything else, darling?';
      return _AiResponse(reply: reply, actions: [orderAction]);
    }

    final checkout = _detectCheckout(text);
    if (checkout) {
      final summary = _cartSummary(isEs);
      final reply = isEs
          ? 'Antes de cerrar, confirma tu pedido. $summary Di "confirmar" para irnos, mae.'
          : 'Before we wrap up, confirm your order. $summary Say "confirm" to go, darling.';
      return _AiResponse(
        reply: reply,
        actions: [
          _AiAction(type: _AiActionType.goToCheckout),
        ],
        requiresConfirmation: true,
      );
    }

    return _AiResponse(
      reply: _routeIntent(text, isEs),
      actions: const [],
    );
  }

  _AiAction? _maybeOrderAction(String text) {
    if (!_menuLoaded || _menu.isEmpty) return null;
    final lower = text.toLowerCase();
    if (!lower.contains('add') &&
        !lower.contains('order') &&
        !lower.contains('pedido') &&
        !lower.contains('agrega')) {
      return null;
    }

    final match = _matchProduct(text);
    if (match == null) return null;
    final qtyMatch = RegExp(r'(\d+)').firstMatch(text);
    final qty = qtyMatch != null ? int.tryParse(qtyMatch.group(1)!) : null;
    return _AiAction(
      type: _AiActionType.addToCart,
      productId: match.id,
      quantity: qty != null && qty > 0 ? qty : 1,
    );
  }

  bool _detectCheckout(String text) {
    final lower = text.toLowerCase();
    return lower.contains('checkout') ||
        lower.contains('confirm') ||
        lower.contains('pagar') ||
        lower.contains('confirmar');
  }

  bool _detectCheckoutConfirm(String text) {
    final lower = text.toLowerCase();
    return lower.contains('confirm') ||
        lower.contains('confirmar') ||
        lower.contains('yes') ||
        lower.contains('si') ||
        lower.contains('pagar');
  }

  String _cartSummary(bool isEs) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.items.isEmpty) {
      return isEs ? 'Tu carrito esta vacio.' : 'Your cart is empty.';
    }
    final parts = cart.items.values.map((item) {
      return '${item.quantity}x ${item.product.name}';
    }).join(', ');
    return isEs ? 'Tu pedido: $parts.' : 'Your order: $parts.';
  }

  Product? _matchProduct(String text) {
    final normalized = _normalize(text);
    Product? best;
    int bestScore = 0;

    for (final product in _menu) {
      final name = _normalize(product.name);
      if (normalized.contains(name)) {
        return product;
      }
      final words = name.split(' ');
      int score = 0;
      for (final w in words) {
        if (w.length < 3) continue;
        if (normalized.contains(w)) score += 1;
      }
      if (score > bestScore) {
        bestScore = score;
        best = product;
      }
    }

    if (bestScore >= 2) return best;
    return null;
  }

  String _normalize(String text) {
    final lower = text.toLowerCase();
    final buf = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      if (RegExp(r'[a-z0-9 ]').hasMatch(ch)) {
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  List<_AiKnowledgeEntry> _matchKnowledge(String text) {
    final lower = text.toLowerCase();
    return _config.knowledge.where((k) {
      final keywords = k.keywords
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty);
      return keywords.any(lower.contains);
    }).toList();
  }

  String _routeIntent(String text, bool isEs) {
    final lower = text.toLowerCase();

    bool hasAny(List<String> keys) => keys.any((k) => lower.contains(k));

    if (hasAny(['order', 'menu', 'food', 'delivery', 'pickup', 'pedido'])) {
      return isEs
          ? '¡Dale pues! Iniciemos tu pedido. ¿Qué se te antoja? ¿Delivery o pickup?'
          : 'I can start your order. Tell me what you want, darling. Pickup or delivery?';
    }

    if (hasAny(['event', 'party', 'reservation', 'book', 'table', 'reserva'])) {
      return isEs
          ? '¡Qué diacachimba! Organicemos tu evento. ¿Cuántos invitados y para cuándo?'
          : 'How exciting! Let\'s plan it. How many guests and when?';
    }

    if (hasAny(['manager', 'owner', 'complaint', 'issue', 'gerente'])) {
      return isEs
          ? 'Puedo canalizarlo con gerencia. Describe el problema y tu contacto.'
          : 'I can route this to management. Share the issue and contact info.';
    }

    if (hasAny(['hours', 'open', 'close', 'location', 'address', 'horario'])) {
      return isEs
          ? 'Claro amor, te confirmo. ¿Qué día pensás visitarnos?'
          : 'Sure thing. Which day are you coming to see us?';
    }

    if (hasAny(['help', 'support', 'agent', 'live', 'ayuda'])) {
      return isEs
          ? 'Puedo conectarte con un agente. Como prefieres que te contactemos?'
          : 'I can connect you with a live agent. Best way to reach you?';
    }

    return isEs
        ? 'Estoy aquí para lo que querrás: pedidos, reservas o solo platicar. ¡Todo tuani!'
        : 'I\'m here for whatever you need: orders, reservations, or just to chat.';
  }

  Future<void> _speak(String text, bool isEs) async {
    final lang = _voiceLang(isEs);
    await _tts.setLanguage(lang);
    await _tts.speak(text);
  }

  String _voiceLang(bool isEs) {
    final hint = (isEs ? _config.voiceEs : _config.voiceEn).trim();
    if (hint.isEmpty) return isEs ? 'es-ES' : 'en-US';
    final token = hint.split(',').first.trim();
    if (token.contains('-')) return token;
    return isEs ? 'es-MX' : 'en-US';
  }

  String _detectLanguageFromText(String text) {
    const esMarks = ['hola', 'gracias', 'por favor', 'comida', 'pedido', 'que'];
    final lower = text.toLowerCase();
    if (esMarks.any((m) => lower.contains(m))) {
      return 'es';
    }
    return 'en';
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stt.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    if (!_sttReady) {
      _sttReady = await _stt.initialize(
        onStatus: (status) {
          if (status == 'done' && mounted) {
            setState(() => _isListening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
        },
      );
    }

    if (!_sttReady) return;
    setState(() => _isListening = true);

    await _stt.listen(
      onResult: (res) {
        setState(() {
          _controller.text = res.recognizedWords;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
          _isTyping = _controller.text.trim().isNotEmpty;
        });
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
      ),
    );
  }

  void _setTyping(String value) {
    _typingTimer?.cancel();
    setState(() => _isTyping = value.trim().isNotEmpty);
    _typingTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() => _isTyping = _controller.text.trim().isNotEmpty);
      }
    });
  }

  Future<void> _applyActions(List<_AiAction> actions) async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    for (final action in actions) {
      switch (action.type) {
        case _AiActionType.addToCart:
          final product = _menu.firstWhere(
            (p) => p.id == action.productId,
            orElse: () => Product(
              id: '',
              name: '',
              description: '',
              price: 0,
              imageUrl: '',
              category: '',
              featured: false,
              ratingAvg: 0,
              ratingCount: 0,
              favoritesCount: 0,
              videoUrl: '',
            ),
          );
          if (product.id.isNotEmpty) {
            final qty = max(1, action.quantity ?? 1);
            for (var i = 0; i < qty; i += 1) {
              cart.addItem(product);
            }
          }
          break;
        case _AiActionType.removeFromCart:
          if (action.productId != null) {
            cart.removeItem(action.productId!);
          }
          break;
        case _AiActionType.goToCheckout:
          if (cart.itemCount > 0) {
            Navigator.pushNamed(context, '/cart');
          }
          break;
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.of(context).languageCode,
      builder: (context, _) {
        final onlineReady = _config.onlineEnabled && _config.endpointUrl.isNotEmpty;
        final modelUrl = _config.modelUrl.trim();
        final statusLabel = tr(
          context,
          en: onlineReady ? 'Online' : 'Offline',
          es: onlineReady ? 'En linea' : 'Fuera de linea',
        );
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF050505)
              : Theme.of(context).colorScheme.surface,
          body: Stack(
        children: [
          _AmbientBackdrop(controller: _floatCtrl),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                children: [
                  ValueListenableBuilder<String?>(
                    valueListenable: AppState.of(context).selectedProfilePic,
                    builder: (context, selectedPic, _) {
                      return _HeaderBar(
                        pulse: _pulseCtrl,
                        onToggleVoice: () =>
                            setState(() => _voiceEnabled = !_voiceEnabled),
                        voiceEnabled: _voiceEnabled,
                        isSpeaking: _isSpeaking,
                        name: _config.personaName,
                        statusText: statusLabel,
                        avatar: selectedPic != null && selectedPic.isNotEmpty
                            ? NetworkImage(selectedPic)
                            : (_avatarUrl != null
                                ? NetworkImage(_avatarUrl!)
                                : const AssetImage('assets/images/angelina/angelina_bubble_avatar.jpg')),
                      );
                    },
                  ),
                  if (modelUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _AngelinaStage(url: modelUrl),
                  ],
                  const SizedBox(height: 12),
                  _ModeStrip(
                    onSelect: (mode) => _handleSend(overrideText: mode),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _ChatTimeline(
                      messages: _messages,
                      wave: _waveCtrl,
                      isListening: _isListening,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InputBar(
                    controller: _controller,
                    isTyping: _isTyping,
                    isListening: _isListening,
                    onChanged: _setTyping,
                    onMic: _toggleListening,
                    onSend: _handleSend,
                  ),
                  const SizedBox(height: 12),
                  _QuickActions(
                    onSelect: (label) => _handleSend(overrideText: label),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.pulse,
    required this.onToggleVoice,
    required this.voiceEnabled,
    required this.isSpeaking,
    required this.name,
    required this.statusText,
    required this.avatar,
  });

  final AnimationController pulse;
  final VoidCallback onToggleVoice;
  final bool voiceEnabled;
  final bool isSpeaking;
  final String name;
  final String statusText;
  final ImageProvider avatar;

  @override
  Widget build(BuildContext context) {
    final speakingLabel =
        tr(context, en: 'Speaking', es: 'Hablando');
    final voiceLabel =
        tr(context, en: 'Voice on', es: 'Voz activada');
    final voiceOffLabel =
        tr(context, en: 'Voice off', es: 'Voz desactivada');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor =
        isDark ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final subtitleColor = isDark
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    return Row(
      children: [
        AnimatedBuilder(
          animation: pulse,
          builder: (_, __) {
            final glow = 0.6 + (pulse.value * 0.4);
            return Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withValues(alpha: glow * 0.35),
                    blurRadius: 24,
                    spreadRadius: 4,
                  )
                ],
                image: DecorationImage(
                  image: avatar,
                  fit: BoxFit.cover,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isSpeaking ? speakingLabel : statusText,
                style: TextStyle(
                  color: isSpeaking ? Colors.greenAccent : subtitleColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NvLanguageToggle(),
            const NvCurrencyToggle(),
            const NvThemeToggle(),
            IconButton(
              tooltip: voiceEnabled ? voiceLabel : voiceOffLabel,
              onPressed: onToggleVoice,
              icon: Icon(
                voiceEnabled ? Icons.graphic_eq : Icons.volume_off,
                color:
                    voiceEnabled ? Colors.greenAccent : subtitleColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AngelinaStage extends StatelessWidget {
  const _AngelinaStage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ModelViewer(
          src: url,
          alt: 'Angelina',
          ar: false,
          autoRotate: true,
          cameraControls: true,
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}

class _ModeStrip extends StatelessWidget {
  const _ModeStrip({required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _ModeChip(
              label: tr(context, en: 'Start order', es: 'Iniciar pedido'),
              onTap: onSelect),
          _ModeChip(
              label: tr(context, en: 'Plan event', es: 'Planear evento'),
              onTap: onSelect),
          _ModeChip(
              label: tr(context, en: 'Live agent', es: 'Agente en vivo'),
              onTap: onSelect),
          _ModeChip(
              label: tr(context, en: 'Hours and location', es: 'Horario y ubicacion'),
              onTap: onSelect),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.onTap});

  final String label;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ActionChip(
        onPressed: () => onTap(label),
        label: Text(label),
        backgroundColor: scheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: scheme.onSurface),
        side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.12)),
      ),
    );
  }
}

class _ChatTimeline extends StatelessWidget {
  const _ChatTimeline({
    required this.messages,
    required this.wave,
    required this.isListening,
  });

  final List<_ChatMessage> messages;
  final AnimationController wave;
  final bool isListening;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: false,
      itemCount: messages.length + (isListening ? 1 : 0),
      itemBuilder: (context, index) {
        if (isListening && index == messages.length) {
          return _ListeningIndicator(wave: wave);
        }
        final msg = messages[index];
        return _ChatBubble(message: msg, wave: wave);
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.wave});

  final _ChatMessage message;
  final AnimationController wave;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _MessageRole.user;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final scheme = Theme.of(context).colorScheme;
    final color =
        isUser ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final textColor =
        isUser ? scheme.onPrimaryContainer : scheme.onSurface;
    final border = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isUser ? 18 : 4),
      bottomRight: Radius.circular(isUser ? 4 : 18),
    );

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: border,
          border:
              Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: message.state == _MessageState.typing
            ? _TypingIndicator(wave: wave)
            : Text(
                message.text,
                style: TextStyle(color: textColor, height: 1.35),
              ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.wave});

  final AnimationController wave;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: wave,
      builder: (_, __) {
        final t = wave.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final offset = (t + (i * 0.2)) % 1.0;
            final scale = 0.6 + (0.6 * (1 - (offset - 0.5).abs() * 2));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: scale),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ListeningIndicator extends StatelessWidget {
  const _ListeningIndicator({required this.wave});

  final AnimationController wave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.mic, color: Colors.greenAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedBuilder(
              animation: wave,
              builder: (_, __) {
                return LinearProgressIndicator(
                  value: wave.value,
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  color: Colors.greenAccent.withValues(alpha: 0.8),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isTyping,
    required this.isListening,
    required this.onChanged,
    required this.onMic,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isTyping;
  final bool isListening;
  final ValueChanged<String> onChanged;
  final VoidCallback onMic;
  final Future<void> Function({String? overrideText}) onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : scheme.surface;
    final textColor = scheme.onSurface;
    final hintColor = scheme.onSurface.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              isListening ? Icons.stop_circle : Icons.mic,
              color: isListening ? Colors.greenAccent : textColor,
            ),
            onPressed: onMic,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: tr(
                  context,
                  en: 'Type your request or ask a question',
                  es: 'Escribe tu solicitud o pregunta',
                ),
                hintStyle: TextStyle(color: hintColor),
                border: InputBorder.none,
              ),
              onChanged: onChanged,
              onSubmitted: (_) => isTyping ? onSend() : null,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.send,
              color: isTyping ? Colors.greenAccent : hintColor,
            ),
            onPressed: isTyping ? () => onSend() : null,
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final actions = [
      tr(context, en: 'Take my order', es: 'Tomar mi pedido'),
      tr(context, en: 'Management', es: 'Gerencia'),
      tr(context, en: 'Live agent', es: 'Agente en vivo'),
      tr(context, en: 'Reserve a table', es: 'Reservar mesa'),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: actions
          .map(
            (label) => InkWell(
              onTap: () => onSelect(label),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: scheme.onSurface.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value * 2 * pi;
        final orb1 = Offset(0.1 + 0.08 * sin(t), 0.2 + 0.1 * cos(t));
        final orb2 = Offset(0.8 + 0.08 * sin(t + 1.4), 0.7 + 0.1 * cos(t));
        final orb3 = Offset(0.2 + 0.08 * sin(t + 2.4), 0.75 + 0.08 * cos(t));
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final baseA = isDark ? const Color(0xFF0F2B1D) : const Color(0xFFF3F9F3);
        final baseB = isDark ? const Color(0xFF08110D) : const Color(0xFFE8F4E6);
        final baseC = isDark ? const Color(0xFF050505) : const Color(0xFFF7F1D3);
        final orbA = isDark ? const Color(0xFF2AB674) : const Color(0xFF4CAF50);
        final orbB = isDark ? const Color(0xFFF3A70B) : const Color(0xFFF3A70B);
        final orbC = isDark ? const Color(0xFF1C4A2F) : const Color(0xFF1E88E5);

        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.2,
                  colors: [baseA, baseB, baseC],
                ),
              ),
            ),
            _OrbGlow(offset: orb1, color: orbA, size: 220),
            _OrbGlow(offset: orb2, color: orbB, size: 180),
            _OrbGlow(offset: orb3, color: orbC, size: 160),
          ],
        );
      },
    );
  }
}

class _OrbGlow extends StatelessWidget {
  const _OrbGlow({
    required this.offset,
    required this.color,
    required this.size,
  });

  final Offset offset;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: offset.dx * MediaQuery.of(context).size.width - size / 2,
      top: offset.dy * MediaQuery.of(context).size.height - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.32),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiRuntimeConfig {
  _AiRuntimeConfig({
    required this.onlineEnabled,
    required this.endpointUrl,
    required this.modelUrl,
    required this.personaName,
    required this.personaBioEn,
    required this.personaBioEs,
    required this.greetingEn,
    required this.greetingEs,
    required this.voiceEn,
    required this.voiceEs,
    required this.knowledge,
  });

  final bool onlineEnabled;
  final String endpointUrl;
  final String modelUrl;
  final String personaName;
  final String personaBioEn;
  final String personaBioEs;
  final String greetingEn;
  final String greetingEs;
  final String voiceEn;
  final String voiceEs;
  final List<_AiKnowledgeEntry> knowledge;

  factory _AiRuntimeConfig.fromMap(Map<String, dynamic> data) {
    return _AiRuntimeConfig(
      onlineEnabled: data['onlineEnabled'] == true,
      endpointUrl: (data['endpointUrl'] as String?) ?? '',
      modelUrl: (data['modelUrl'] as String?) ?? '',
      personaName: (data['personaName'] as String?) ?? 'Angelina',
      personaBioEn: (data['personaBioEn'] as String?) ?? '',
      personaBioEs: (data['personaBioEs'] as String?) ?? '',
      greetingEn: (data['greetingEn'] as String?) ??
          'Welcome to Niña Verde. I am Angelina, your concierge.',
      greetingEs: (data['greetingEs'] as String?) ??
          'Bienvenido a Niña Verde. Soy Angelina, tu anfitriona.',
      voiceEn: (data['voiceEn'] as String?) ?? 'en-US',
      voiceEs: (data['voiceEs'] as String?) ?? 'es-ES',
      knowledge: (data['knowledge'] as List? ?? [])
          .whereType<Map>()
          .map((raw) =>
              _AiKnowledgeEntry.fromMap(raw.cast<String, dynamic>()))
          .toList(),
    );
  }

  factory _AiRuntimeConfig.defaults() {
    return _AiRuntimeConfig(
      onlineEnabled: false,
      endpointUrl: '',
      modelUrl: '',
      personaName: 'Angelina',
      personaBioEn:
          'Glam, confident Latina host. Warm, playful, lightly flirty, and always classy.',
      personaBioEs:
          'Anfitriona latina, glamorosa y segura. Calida, divertida, con un toque coqueto y siempre con clase.',
      greetingEn:
          'Welcome to Niña Verde. I am Angelina, your concierge. What are you in the mood for?',
      greetingEs:
          'Bienvenido a Niña Verde. Soy Angelina, tu anfitriona. ¿Qué se te antoja hoy?',
      voiceEn: 'en-US, warm, playful, confident',
      voiceEs: 'es-ES, warm, playful, confident',
      knowledge: _AiKnowledgeEntry.defaultEntries(),
    );
  }

  String greetingFor(bool isEs) => isEs ? greetingEs : greetingEn;
}

class _AiKnowledgeEntry {
  _AiKnowledgeEntry({
    required this.title,
    required this.keywords,
    required this.contentEn,
    required this.contentEs,
  });

  final String title;
  final String keywords;
  final String contentEn;
  final String contentEs;

  factory _AiKnowledgeEntry.fromMap(Map<String, dynamic> data) {
    return _AiKnowledgeEntry(
      title: data['title'] as String? ?? '',
      keywords: data['keywords'] as String? ?? '',
      contentEn: data['contentEn'] as String? ?? '',
      contentEs: data['contentEs'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'keywords': keywords,
        'contentEn': contentEn,
        'contentEs': contentEs,
      };

  String contentFor(bool isEs) => isEs ? contentEs : contentEn;

  static List<_AiKnowledgeEntry> defaultEntries() {
    return [
      _AiKnowledgeEntry(
        title: 'About Niña Verde',
        keywords: 'niña verde, restaurant, vibe, host',
        contentEn:
            'Niña Verde is a vibrant spot in Granada known for warm service and bold flavors.',
        contentEs:
            'Niña Verde es un lugar vibrante en Granada con servicio cálido y sabores intensos.',
      ),
      _AiKnowledgeEntry(
        title: 'Granada highlights',
        keywords: 'granada, city, lake, islets, mercado',
        contentEn:
            'Granada is famous for its colonial architecture, lake islets, and colorful markets.',
        contentEs:
            'Granada es famosa por su arquitectura colonial, isletas y mercados coloridos.',
      ),
      _AiKnowledgeEntry(
        title: 'Nicaragua essentials',
        keywords: 'nicaragua, travel, culture, safety',
        contentEn:
            'Nicaragua offers volcano hikes, lakes, and rich culture. Stay hydrated and use sun protection.',
        contentEs:
            'Nicaragua ofrece volcanes, lagos y cultura rica. Mantente hidratado y usa protección solar.',
      ),
    ];
  }
}

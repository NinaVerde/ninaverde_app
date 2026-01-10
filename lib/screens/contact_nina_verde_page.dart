import 'package:flutter/material.dart';

class ContactNinaVerdePage extends StatefulWidget {
  const ContactNinaVerdePage({super.key});

  @override
  State<ContactNinaVerdePage> createState() => _ContactNinaVerdePageState();
}

class _ContactNinaVerdePageState extends State<ContactNinaVerdePage> {
  final TextEditingController _controller = TextEditingController();
  String userMessage = '';
  bool isTyping = false;

  void handleSend() {
    setState(() {
      userMessage = _controller.text.trim();
      _controller.clear();
      isTyping = false;
    });
    // TODO: hook up AI + TTS + animation in Phase 2
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.92),
      body: Stack(
        children: [
          // Background ambience (image placeholder)
          Positioned.fill(
            child: Opacity(
              opacity: 0.22,
              child: Image.asset(
                'assets/images/kitchen_background.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Niña Verde AI Assistant',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const CircleAvatar(
                        radius: 24,
                        backgroundImage:
                            AssetImage('assets/images/nina_verde_avatar.png'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Conversation
                  Expanded(
                    child: ListView(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              '''¡Hola! I'm Niña Verde 🍃
How can I help you today?
Would you like me to:
• Take your order?
• Connect you with our management?
• Transfer you to a live agent? 📞💬''',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  height: 1.3),
                            ),
                          ),
                        ),
                        if (userMessage.isNotEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                userMessage,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 15),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Input bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.mic, color: Colors.white),
                          onPressed: () {
                            // TODO: speech-to-text
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Type your message…',
                              hintStyle: TextStyle(color: Colors.white70),
                              border: InputBorder.none,
                            ),
                            onChanged: (t) =>
                                setState(() => isTyping = t.trim().isNotEmpty),
                            onSubmitted: (_) => isTyping ? handleSend() : null,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: isTyping ? handleSend : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Quick intents
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _glassButton('Take My Order'),
                      _glassButton('Management'),
                      _glassButton('Live Agent'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassButton(String label) {
    return InkWell(
      onTap: () {
        // TODO: intent handling per label
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white30),
        ),
        child: Text(
          label,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

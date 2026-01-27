import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

class JohnCopilotSheet extends StatefulWidget {
  const JohnCopilotSheet({super.key});

  @override
  State<JohnCopilotSheet> createState() => _JohnCopilotSheetState();
}

class _JohnCopilotSheetState extends State<JohnCopilotSheet> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  
  // Mock Chat History
  final List<_ChatMessage> _messages = [
      _ChatMessage(role: 'john', text: 'Good afternoon, boss. Systems are optimal. Revenue is trending +12% vs last week. What\'s on your mind?'),
  ];
  
  bool _isTyping = false;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    border: Border(top: BorderSide(color: Colors.cyanAccent.withOpacity(0.3), width: 1)),
                    boxShadow: [
                        BoxShadow(color: Colors.cyanAccent.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)
                    ]
                ),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        // Handle bar
                        Center(
                            child: Container(
                                margin: const EdgeInsets.only(top: 12, bottom: 8),
                                width: 40, height: 4, 
                                decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(2)),
                            ),
                        ),
                        
                        // Header
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            child: Row(
                                children: [
                                    _buildAnimatedAvatar(),
                                    const SizedBox(width: 16),
                                    const Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                            Text('JOHN AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2)),
                                            Text('Business Copilot • Online', style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                                        ],
                                    ),
                                    const Spacer(),
                                    IconButton(
                                        icon: const Icon(Icons.close, color: Colors.grey),
                                        onPressed: () => Navigator.pop(context),
                                    )
                                ],
                            ),
                        ),
                        
                        const Divider(color: Colors.white10),
                        
                        // Chat Area
                        SizedBox(
                            height: 350, // Fixed height for sheet content
                            child: ListView.builder(
                                controller: _scrollCtrl,
                                padding: const EdgeInsets.all(20),
                                itemCount: _messages.length + (_isTyping ? 1 : 0),
                                itemBuilder: (context, index) {
                                    if (index == _messages.length) {
                                        return _buildTypingIndicator();
                                    }
                                    return _buildMessageBubble(_messages[index]);
                                },
                            ),
                        ),
                        
                        // Quick Actions (Horizontal Scroll)
                        SizedBox(
                            height: 50,
                            child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                children: [
                                    _QuickActionChip(label: 'Labor Analysis', icon: Icons.badge, onTap: () => _sendMessage('Analyze labor costs for today')),
                                    _QuickActionChip(label: 'Inventory Check', icon: Icons.inventory, onTap: () => _sendMessage('Check low stock items')),
                                    _QuickActionChip(label: 'Marketing Idea', icon: Icons.lightbulb, onTap: () => _sendMessage('Give me a promo idea for tonight')),
                                    _QuickActionChip(label: 'Forecast', icon: Icons.trending_up, onTap: () => _sendMessage('What\'s the forecast for tomorrow?')),
                                ],
                            ),
                        ),
                        
                        // Input Area
                        Padding(
                            padding: const EdgeInsets.all(16).copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
                            child: Row(
                                children: [
                                    Expanded(
                                        child: TextField(
                                            controller: _ctrl,
                                            style: const TextStyle(color: Colors.white),
                                            decoration: InputDecoration(
                                                hintText: 'Ask John anything...',
                                                hintStyle: TextStyle(color: Colors.grey[600]),
                                                filled: true,
                                                fillColor: Colors.white.withOpacity(0.05),
                                                border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(24),
                                                    borderSide: BorderSide.none
                                                ),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                            ),
                                            onSubmitted: _sendMessage,
                                        ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                        decoration: const BoxDecoration(
                                            color: Colors.cyanAccent,
                                            shape: BoxShape.circle,
                                            boxShadow: [BoxShadow(color: Colors.cyan, blurRadius: 8)]
                                        ),
                                        child: IconButton(
                                            icon: const Icon(Icons.send_rounded, color: Colors.black),
                                            onPressed: () => _sendMessage(_ctrl.text),
                                        ),
                                    ).animate(target: _ctrl.text.isEmpty ? 0 : 1).scale(begin: const Offset(0.8, 0.8)),
                                ],
                            ),
                        ),
                    ],
                ),
            ),
        ),
    );
  }
  
  void _sendMessage(String text) async {
      if (text.trim().isEmpty) return;
      
      setState(() {
          _messages.add(_ChatMessage(role: 'user', text: text));
          _ctrl.clear();
          _isTyping = true;
      });
      _scrollToBottom();
      
      // Mock AI Delay
      await Future.delayed(const Duration(milliseconds: 1500));
      
      String response = "I'm processing that request. As an MVP simulated AI, I acknowledge your command: \"$text\". In the production version, I will execute this via cloud functions.";
      
      if (text.contains('Labor')) response = "Labor is currently at 18% of sales. Efficient. However, we might be understaffed for the dinner rush at 7 PM based on current reservation trends.";
      if (text.contains('Promo')) response = "How about a 'Flash Hour' on Margaritas? We have excess lime inventory expiring in 2 days.";
      
      if (mounted) {
          setState(() {
              _isTyping = false;
              _messages.add(_ChatMessage(role: 'john', text: response));
          });
          _scrollToBottom();
      }
  }
  
  void _scrollToBottom() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      });
  }
  
  Widget _buildAnimatedAvatar() {
      return Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.cyanAccent, width: 2),
              boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.4), blurRadius: 10)]
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
                const CircleAvatar(
                    backgroundColor: Colors.black,
                    backgroundImage: AssetImage('assets/images/app_icon_foreground.png'), // Placeholder or robust AI icon
                ),
                Container(
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                            colors: [Colors.cyanAccent.withOpacity(0.2), Colors.transparent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight
                        )
                  ),
                )
            ],
          ),
       )
       .animate(onPlay: (c) => c.repeat(reverse: true))
       .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 2.seconds);
  }
  
  Widget _buildMessageBubble(_ChatMessage msg) {
      final isMe = msg.role == 'user';
      return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(maxWidth: 280),
              decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF00FF94).withOpacity(0.2) : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                  ),
                  border: Border.all(color: isMe ? const Color(0xFF00FF94).withOpacity(0.3) : Colors.white10),
              ),
              child: Text(msg.text, style: const TextStyle(color: Colors.white, height: 1.4)),
          ).animate().fadeIn().slideY(begin: 0.2, end: 0),
      );
  }
  
  Widget _buildTypingIndicator() {
      return Align(
          alignment: Alignment.centerLeft,
          child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [0, 1, 2].map((i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 8, height: 8,
                      decoration: const BoxDecoration(color: Colors.cyanAccent, shape: BoxShape.circle),
                  ).animate(onPlay: (c) => c.repeat())
                   .fade(duration: 600.ms, delay: (i*200).ms)
                  ).toList(),
              ),
          ),
      );
  }
}

class _ChatMessage {
    final String role;
    final String text;
    _ChatMessage({required this.role, required this.text});
}

class _QuickActionChip extends StatelessWidget {
    final String label;
    final IconData icon;
    final VoidCallback onTap;
    
    const _QuickActionChip({required this.label, required this.icon, required this.onTap});
    
    @override
    Widget build(BuildContext context) {
        return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
                avatar: Icon(icon, size: 16, color: Colors.cyanAccent),
                label: Text(label),
                backgroundColor: Colors.black,
                side: BorderSide(color: Colors.cyanAccent.withOpacity(0.3)),
                labelStyle: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onPressed: onTap,
            ),
        );
    }
}

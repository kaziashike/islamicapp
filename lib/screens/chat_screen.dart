
import 'package:flutter/material.dart';
import '../services.dart';
import '../widgets.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final OpenRouterService _service = OpenRouterService();
  bool _isTyping = false;

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    final question = _controller.text;
    _controller.clear();

    setState(() {
      _messages.add(ChatMessage(
        text: question,
        isUser: true,
        animation: AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 400),
        ),
      ));
      _messages.last.animation?.forward();
      _messages.add(ChatMessage(
        text: '',
        isUser: false,
        animation: AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 400),
        ),
      ));
      _isTyping = true;
    });

    try {
      String fullResponse = '';
      await for (final chunk in _service.streamChat(question, [])) {
        setState(() {
          fullResponse += chunk;
          _messages.last.text = fullResponse;
        });
      }
      _messages.last.animation?.forward();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(
          text: 'Error: Failed to get response',
          isUser: false,
          animation: AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 400),
          ),
        ));
        _messages.last.animation?.forward();
      });
    } finally {
      setState(() {
        _isTyping = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Islamic AI Chat'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF009688), Color(0xFF80CBC4)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return FadeTransition(
                      opacity: _messages[index].animation?.drive(CurveTween(curve: Curves.easeIn)) ?? const AlwaysStoppedAnimation(1.0),
                      child: ChatBubble(
                        text: _messages[index].text,
                        isUser: _messages[index].isUser,
                      ),
                    );
                  },
                ),
              ),
              if (_isTyping)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: TextField(
                              controller: _controller,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Ask a question...'
                              ),
                              onSubmitted: (value) => _sendMessage(),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: CircleAvatar(
                            backgroundColor: Colors.teal,
                            child: IconButton(
                              icon: const Icon(Icons.send, color: Colors.white),
                              onPressed: _sendMessage,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatMessage {
  String text;
  final bool isUser;
  final AnimationController? animation;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.animation,
  });
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // For JSON encoding/decoding
import '../services.dart'; // Import the Gemini service
import 'package:intl/intl.dart'; // Import the intl package for DateFormat
import 'package:typeset/typeset.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts

class QAScreen extends StatefulWidget {
  const QAScreen({super.key});

  @override
  _QAScreenState createState() => _QAScreenState();
}

class _QAScreenState extends State<QAScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [];
  bool _isLoading = false;
  final ScrollController _scrollController =
      ScrollController(); // For auto-scroll

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  // Helper function to get the current timestamp
  String _getCurrentTimestamp() {
    return DateFormat('HH:mm').format(DateTime.now()); // Format: 14:30
  }

  Future<void> _askQuestion() async {
    final question = _controller.text.trim();
    if (question.isEmpty) return;

    setState(() {
      _messages.add(Message(
        text: question,
        isUser: true,
        timestamp: _getCurrentTimestamp(),
      ));
      _messages.add(Message(
        text: 'loading',
        isUser: false,
        timestamp: _getCurrentTimestamp(),
      ));
      _isLoading = true;
    });

    _controller.clear();
    _saveChatHistory();

    try {
      final answer = await OpenRouterService().askQuestion(question);
      setState(() {
        _messages.removeLast(); // Remove the "loading" message
        _messages.add(Message(
          text: answer,
          isUser: false,
          timestamp: _getCurrentTimestamp(),
        ));
      });
    } catch (e) {
      setState(() {
        _messages.removeLast(); // Remove the "loading" message
        _messages.add(Message(
          text: 'Failed to load answer. Please try again.',
          isUser: false,
          timestamp: _getCurrentTimestamp(),
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }

    _saveChatHistory();

    // Auto-scroll to the latest message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final chatHistory =
        _messages.map((message) => jsonEncode(message.toJson())).toList();
    await prefs.setStringList('chatHistory', chatHistory);
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final chatHistory = prefs.getStringList('chatHistory') ?? [];
    setState(() {
      _messages.addAll(chatHistory
          .map((message) => Message.fromJson(jsonDecode(message)))
          .toList());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Islamic Asks',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 10, // Add elevation for drop shadow
        shadowColor: Colors.black.withOpacity(0.5), // Customize shadow color
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController, // Attach the scroll controller
              padding: EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return AnimatedOpacity(
                  opacity: 1.0,
                  duration: Duration(milliseconds: 500),
                  child: ChatBubble(
                    text: message.text,
                    isUser: message.isUser,
                    timestamp: message.timestamp,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ask a question...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 20,
                      ),
                    ),
                    onSubmitted: (_) => _askQuestion(), // Send on "Enter"
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: _isLoading
                      ? CircularProgressIndicator()
                      : Icon(Icons.send, color: Colors.teal),
                  onPressed: _isLoading ? null : _askQuestion,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final String timestamp;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            const CircleAvatar(
              backgroundColor: Colors.green,
              child: Text('AI'),
            ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width *
                      0.7, // Limit width to 70% of screen
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.teal : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  child: text == 'loading Engine'
                      ? LoadingDots()
                      : TypeSet(
                          text,
                          style: GoogleFonts.poppins(
                            textStyle: TextStyle(
                              color: isUser ? Colors.white : Colors.black,
                              fontSize: 16,
                            ),
                          ),
                          overflow: TextOverflow.visible, // Allow text to wrap
                          softWrap: true, // Enable text wrapping
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timestamp,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser)
            const CircleAvatar(
              backgroundColor: Colors.teal,
              child: Icon(Icons.person, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

class LoadingDots extends StatefulWidget {
  const LoadingDots({super.key});

  @override
  _LoadingDotsState createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _dotsAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
    _dotsAnimation = StepTween(begin: 0, end: 3).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dotsAnimation,
      builder: (context, child) {
        String dots = '.' * _dotsAnimation.value;
        return Text(
          'loading$dots',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
          ),
        );
      },
    );
  }
}

class Message {
  final String text;
  final bool isUser;
  final String timestamp;

  Message({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp,
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        text: json['text'],
        isUser: json['isUser'],
        timestamp: json['timestamp'],
      );
}

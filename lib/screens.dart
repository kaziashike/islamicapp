import 'package:flutter/material.dart';
// For JSON encoding/decoding
import '../services.dart'; // Import the Gemini service
import 'package:intl/intl.dart'; // Import the intl package for DateFormat
import 'package:typeset/typeset.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'package:provider/provider.dart';
import 'models.dart';

class QAScreen extends StatefulWidget {
  const QAScreen({super.key});

  @override
  _QAScreenState createState() => _QAScreenState();
}

class _QAScreenState extends State<QAScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Load chat history when screen initializes
    Provider.of<ChatHistoryProvider>(context, listen: false).loadChatHistory();
  }

  // Helper function to get the current timestamp
  String _getCurrentTimestamp() {
    return DateFormat('HH:mm').format(DateTime.now()); // Format: 14:30
  }

  Future<void> _askQuestion() async {
    final question = _controller.text.trim();
    if (question.isEmpty) return;

    final chatProvider =
        Provider.of<ChatHistoryProvider>(context, listen: false);

    // Add user's question
    chatProvider.addMessage(Message(
      text: question,
      isUser: true,
      timestamp: _getCurrentTimestamp(),
    ));

    // Add loading message
    chatProvider.addMessage(Message(
      text: 'loading',
      isUser: false,
      timestamp: _getCurrentTimestamp(),
    ));

    setState(() => _isLoading = true);
    _controller.clear();

    try {
      String streamedAnswer = '';
      await for (final chunk in OpenRouterService()
          .streamChat(question, chatProvider.getConversationHistory())) {
        streamedAnswer += chunk;
        chatProvider.updateLastMessage(streamedAnswer);
      }
    } catch (e) {
      chatProvider
          .updateLastMessage('Failed to load answer. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }

    // Auto-scroll to the latest message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Islamic Asks'),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatHistoryProvider>(
              builder: (context, chatProvider, child) {
                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(8),
                  itemCount: chatProvider.messages.length,
                  itemBuilder: (context, index) {
                    final message = chatProvider.messages[index];
                    return ChatBubble(
                      text: message.text,
                      isUser: message.isUser,
                      timestamp: message.timestamp,
                    );
                  },
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

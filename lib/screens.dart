import 'package:flutter/material.dart';
// For JSON encoding/decoding
import '../services.dart'; // Import the Gemini service
import 'package:intl/intl.dart'; // Import the intl package for DateFormat
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'models.dart';

/// Main chat screen where users can interact with the AI
/// Handles message display, input, and chat history management
class QAScreen extends StatefulWidget {
  const QAScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _QAScreenState createState() => _QAScreenState();
}

class _QAScreenState extends State<QAScreen> {
  // Controller for the text input field
  final TextEditingController _controller = TextEditingController();
  // Flag to track if a response is being generated
  bool _isLoading = false;
  // Controller for scrolling the chat list
  final ScrollController _scrollController = ScrollController();

  /// Scrolls the chat list to the bottom with a smooth animation
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Add listener to scroll to bottom when text changes
    _controller.addListener(_scrollToBottom);
    // Load chat history when screen initializes
    Provider.of<ChatHistoryProvider>(context, listen: false)
        .loadChatHistory()
        .then((_) {
      // Scroll to bottom after chat history is loaded
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });
  }

  @override
  void dispose() {
    // Clean up controllers and listeners
    _controller.removeListener(_scrollToBottom);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Returns the current time in HH:mm format
  String _getCurrentTimestamp() {
    return DateFormat('HH:mm').format(DateTime.now());
  }

  /// Handles sending a question to the AI and processing the response
  Future<void> _askQuestion() async {
    final question = _controller.text.trim();
    if (question.isEmpty) return;

    // Get chat provider and ensure there's an active chat
    final chatProvider =
        Provider.of<ChatHistoryProvider>(context, listen: false);
    final chatId = chatProvider.activeChatId ?? chatProvider.createNewChat().id;

    // Add user's question to chat
    chatProvider.addMessage(Message(
      text: question,
      isUser: true,
      timestamp: _getCurrentTimestamp(),
      chatId: chatId,
    ));
    _scrollToBottom();

    // Add loading message from AI
    chatProvider.addMessage(Message(
      text: 'loading',
      isUser: false,
      timestamp: _getCurrentTimestamp(),
      chatId: chatId,
    ));
    _scrollToBottom();

    setState(() => _isLoading = true);
    _controller.clear();

    try {
      // Stream the AI response and update the chat
      String streamedAnswer = '';
      await for (final chunk in OpenRouterService()
          .streamChat(question, chatProvider.getConversationHistory())) {
        streamedAnswer += chunk;
        chatProvider.updateLastMessage(streamedAnswer);
        _scrollToBottom();
      }
    } catch (e) {
      // Handle errors by showing an error message
      chatProvider
          .updateLastMessage('Failed to load answer. Please try again.');
      _scrollToBottom();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Islamic Asks'),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      drawer: ChatDrawer(),
      body: Column(
        children: [
          // Chat messages list
          Expanded(
            child: Consumer<ChatHistoryProvider>(
              builder: (context, chatProvider, child) {
                final activeChat = chatProvider.activeChat;
                if (activeChat == null) {
                  return const Center(child: Text('Start a new chat'));
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: activeChat.messages.length,
                  itemBuilder: (context, index) {
                    final message = activeChat.messages[index];
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
          // Input area
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
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 20,
                      ),
                    ),
                    onSubmitted: (_) => _askQuestion(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isLoading
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.send, color: Colors.teal),
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

/// Widget that displays a single chat message bubble
/// Handles different styles for user and AI messages
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // AI avatar for AI messages
          if (!isUser)
            const CircleAvatar(
              backgroundColor: Colors.teal,
              child: Text('AI', style: TextStyle(color: Colors.white)),
            ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Message bubble with markdown support
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Theme.of(context).colorScheme.primary
                        : (isDark ? Colors.grey[800] : Colors.grey[200]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  child: text == 'loading'
                      ? const LoadingDots()
                      : MarkdownBody(
                          data: text,
                          selectable: true,
                          // Custom styling for different markdown elements
                          styleSheet: MarkdownStyleSheet(
                            // Regular paragraph text
                            p: TextStyle(
                              color: isUser
                                  ? Colors.white
                                  : (isDark ? Colors.white : Colors.black),
                              fontSize: 16,
                              fontFamily: GoogleFonts.poppins().fontFamily,
                            ),
                            // Headings
                            h1: TextStyle(
                              color: isUser
                                  ? Colors.white
                                  : (isDark ? Colors.white : Colors.black),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: GoogleFonts.poppins().fontFamily,
                            ),
                            h2: TextStyle(
                              color: isUser
                                  ? Colors.white
                                  : (isDark ? Colors.white : Colors.black),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: GoogleFonts.poppins().fontFamily,
                            ),
                            h3: TextStyle(
                              color: isUser
                                  ? Colors.white
                                  : (isDark ? Colors.white : Colors.black),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: GoogleFonts.poppins().fontFamily,
                            ),
                            // Blockquotes
                            blockquote: TextStyle(
                              color: isUser
                                  ? Colors.white70
                                  : (isDark ? Colors.white70 : Colors.black87),
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              fontFamily: GoogleFonts.poppins().fontFamily,
                            ),
                            // Inline code
                            code: TextStyle(
                              color: isUser
                                  ? Colors.white
                                  : (isDark ? Colors.white : Colors.black),
                              backgroundColor: isUser
                                  ? Colors.white24
                                  : (isDark ? Colors.black26 : Colors.black12),
                              fontSize: 14,
                              fontFamily: 'monospace',
                            ),
                            // Code blocks
                            codeblockDecoration: BoxDecoration(
                              color: isUser
                                  ? Colors.white12
                                  : (isDark
                                      ? Colors.black26
                                      : Colors.black.withValues(alpha: 0.5)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            // List bullets
                            listBullet: TextStyle(
                              color: isUser
                                  ? Colors.white
                                  : (isDark ? Colors.white : Colors.black),
                              fontSize: 16,
                              fontFamily: GoogleFonts.poppins().fontFamily,
                            ),
                          ),
                          // Handle link taps
                          onTapLink: (text, href, title) {
                            if (href != null) {
                              // Handle link taps here
                            }
                          },
                        ),
                ),
              ),
              // Timestamp
              const SizedBox(height: 4),
              Text(
                timestamp,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (isUser) const SizedBox(width: 8),
          // User avatar for user messages
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

/// Widget that displays an animated loading indicator
class LoadingDots extends StatefulWidget {
  const LoadingDots({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LoadingDotsState createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _dotsAnimation;

  @override
  void initState() {
    super.initState();
    // Set up the animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
    // Create the dots animation
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
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
          ),
        );
      },
    );
  }
}

class ChatDrawer extends StatelessWidget {
  const ChatDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.teal,
            ),
            child: Center(
              child: Text(
                'Chat History',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.add),
            title: Text('New Chat'),
            onTap: () {
              final provider =
                  Provider.of<ChatHistoryProvider>(context, listen: false);
              provider.createNewChat();
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (context) => SettingsDialog(),
              );
            },
          ),
          Divider(),
          Expanded(
            child: Consumer<ChatHistoryProvider>(
              builder: (context, chatProvider, child) {
                return ListView.builder(
                  itemCount: chatProvider.sessions.length,
                  itemBuilder: (context, index) {
                    final session = chatProvider
                        .sessions[chatProvider.sessions.length - 1 - index];
                    final isActive = session.id == chatProvider.activeChatId;

                    return ListTile(
                      title: Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(session.timestamp),
                      selected: isActive,
                      // ignore: deprecated_member_use
                      selectedTileColor: Colors.teal.withOpacity(0.1),
                      onTap: () {
                        chatProvider.setActiveChat(session.id);
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            Consumer<SettingsProvider>(
              builder: (context, settings, child) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Language',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 8),
                  DropdownButton<AppLanguage>(
                    value: settings.language,
                    isExpanded: true,
                    items: AppLanguage.values.map((lang) {
                      return DropdownMenuItem(
                        value: lang,
                        child: Text(lang.displayName),
                      );
                    }).toList(),
                    onChanged: (lang) {
                      if (lang != null) {
                        settings.setLanguage(lang);
                      }
                    },
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Theme',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 8),
                  DropdownButton<ThemeMode>(
                    value: settings.themeMode,
                    isExpanded: true,
                    items: ThemeMode.values.map((mode) {
                      return DropdownMenuItem(
                        value: mode,
                        child: Text(mode.displayName),
                      );
                    }).toList(),
                    onChanged: (mode) {
                      if (mode != null) {
                        settings.setThemeMode(mode);
                      }
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

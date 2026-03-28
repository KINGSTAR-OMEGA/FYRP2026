import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/chat_message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/progress_provider.dart';
import '../../services/ai_service.dart';
import '../../utils/theme.dart';

class AiChatPanel extends StatefulWidget {
  final String courseId;
  final String lessonId;
  final String transcription;
  final List<ChatMessageModel> initialMessages;

  const AiChatPanel({
    super.key,
    required this.courseId,
    required this.lessonId,
    required this.transcription,
    required this.initialMessages,
  });

  @override
  State<AiChatPanel> createState() => _AiChatPanelState();
}

class _AiChatPanelState extends State<AiChatPanel> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _ai = AiService();
  final _uuid = const Uuid();
  bool _isThinking = false;

  late List<ChatMessageModel> _messages;

  @override
  void initState() {
    super.initState();
    _messages = List.from(widget.initialMessages);
    if (_messages.isEmpty) {
      _messages.add(ChatMessageModel(
        id: _uuid.v4(),
        role: 'ai',
        content: 'Hi! I\'m your AI Tutor for this lesson. You can ask me to explain concepts, '
            'summarize sections, give examples, or answer any questions about the video content.',
        timestamp: DateTime.now(),
      ));
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isThinking) return;

    final user = context.read<AuthProvider>().currentUser!;
    final userMsg = ChatMessageModel(
      id: _uuid.v4(),
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );

    _inputCtrl.clear();
    setState(() {
      _messages.add(userMsg);
      _isThinking = true;
    });
    _scrollToBottom();

    await context
        .read<ProgressProvider>()
        .addChatMessage(user.id, widget.courseId, widget.lessonId, userMsg);

    final history = _messages
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    final response = await _ai.ask(
      question: text,
      transcription: widget.transcription,
      history: history,
    );

    final aiMsg = ChatMessageModel(
      id: _uuid.v4(),
      role: 'ai',
      content: response,
      timestamp: DateTime.now(),
    );

    if (!mounted) return;
    setState(() {
      _messages.add(aiMsg);
      _isThinking = false;
    });
    _scrollToBottom();

    await context
        .read<ProgressProvider>()
        .addChatMessage(user.id, widget.courseId, widget.lessonId, aiMsg);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  'AI Tutor',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textHigh,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),

          // Body
          Expanded(
            child: _ChatView(
              messages: _messages,
              isThinking: _isThinking,
              scrollCtrl: _scrollCtrl,
            ),
          ),

          // Input
          Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      decoration: InputDecoration(
                        hintText: 'Ask anything about this lesson...',
                        hintStyle: GoogleFonts.outfit(
                            fontSize: 13, color: AppColors.textLow),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                        ),
                      ),
                      style:
                          GoogleFonts.outfit(fontSize: 13, color: AppColors.textHigh),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatView extends StatelessWidget {
  final List<ChatMessageModel> messages;
  final bool isThinking;
  final ScrollController scrollCtrl;

  const _ChatView({
    required this.messages,
    required this.isThinking,
    required this.scrollCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(12),
      itemCount: messages.length + (isThinking ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == messages.length) {
          return const _ThinkingBubble();
        }
        final msg = messages[i];
        return _MessageBubble(message: msg);
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 13),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primaryLight : AppColors.bgSurface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isUser ? 12 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 12),
                ),
                border: Border.all(
                  color: isUser ? AppColors.primaryLight : AppColors.border,
                ),
              ),
              child: Text(
                message.content,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.textHigh,
                  height: 1.5,
                ),
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0),
          ),
        ],
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 13),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .scaleXY(
                      begin: 0.6,
                      end: 1.0,
                      duration: 500.ms,
                      delay: Duration(milliseconds: i * 150),
                    )
                    .then()
                    .scaleXY(begin: 1.0, end: 0.6, duration: 500.ms);
              }),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/conversation.dart';
import '../chat_format.dart';

/// One message: mine on the right (primary), theirs on the left. Long press copies the text.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  // My latest message the other person has read
  final bool showRead;

  const MessageBubble({super.key, required this.message, required this.isMine, this.showRead = false});

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message copied')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // sent_at is null until Firestore sets the server time
    final pending = message.sentAt == null;
    const corner = Radius.circular(18);
    const tail = Radius.circular(4);
    final metaStyle = TextStyle(fontSize: 11, color: colors.outline);

    return AnimatedOpacity(
      opacity: pending ? 0.6 : 1,
      duration: const Duration(milliseconds: 250),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          child: Column(
            crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onLongPress: () => _copy(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMine ? colors.primary : colors.surfaceLow,
                    border: isMine ? null : Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.only(
                      topLeft: corner,
                      topRight: corner,
                      bottomLeft: isMine ? corner : tail,
                      bottomRight: isMine ? tail : corner,
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      color: isMine ? Colors.white : colors.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pending) ...[
                      Icon(Icons.schedule, size: 12, color: colors.outline),
                      const SizedBox(width: 4),
                      Text('Sending', style: metaStyle),
                    ] else
                      Text(messageTime(context, message.sentAt!), style: metaStyle),
                    if (showRead && !pending) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.done_all, size: 14, color: colors.primary),
                      const SizedBox(width: 2),
                      Text('Read', style: metaStyle.copyWith(color: colors.primary)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Today", "Yesterday", "Mon, Nov 24" between the messages of different days.
class DaySeparator extends StatelessWidget {
  final String label;

  const DaySeparator({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: context.colors.surfaceLow,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

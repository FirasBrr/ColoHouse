import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Text field + send button at the bottom of a chat.
class MessageComposer extends StatefulWidget {
  // Same limit as firestore.rules
  static const maxLength = 2000;

  /// Saves the message; returns false when it failed (the text is put back in the field).
  final Future<bool> Function(String text) onSend;
  final bool enabled;

  const MessageComposer({super.key, required this.onSend, this.enabled = true});

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || !widget.enabled) return;

    setState(() => _sending = true);
    _controller.clear();
    final saved = await widget.onSend(text);
    if (!mounted) return;
    // Not saved: give the text back so it can be sent again
    if (!saved && _controller.text.isEmpty) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final roundBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide.none,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: colors.surfaceLowest,
        border: Border(top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                maxLength: MessageComposer.maxLength,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                // The counter only shows up close to the limit
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) =>
                    currentLength > MessageComposer.maxLength - 200
                        ? Text('$currentLength/$maxLength', style: TextStyle(fontSize: 11, color: colors.outline))
                        : null,
                decoration: InputDecoration(
                  hintText: 'Write a message...',
                  hintStyle: TextStyle(color: colors.outline),
                  filled: true,
                  fillColor: colors.surfaceLow,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  border: roundBorder,
                  enabledBorder: roundBorder,
                  focusedBorder: roundBorder.copyWith(
                    borderSide: BorderSide(color: colors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final canSend = widget.enabled && !_sending && value.text.trim().isNotEmpty;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: canSend ? colors.primary : colors.surfaceLow,
                  ),
                  child: _sending
                      ? Padding(
                          padding: const EdgeInsets.all(13),
                          child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                        )
                      : IconButton(
                          tooltip: 'Send',
                          onPressed: canSend ? _send : null,
                          icon: Icon(Icons.send_rounded, size: 20, color: canSend ? Colors.white : colors.outline),
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

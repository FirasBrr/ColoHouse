import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/models/public_user.dart';

/// Same tag in the chat list and the chat app bar: the avatar flies between them.
String chatAvatarHeroTag(int conversationId) => 'chat-avatar-$conversationId';

/// Profile picture, or the initials when there is none (or it fails to load).
class ChatAvatar extends StatelessWidget {
  final PublicUser user;
  final double radius;

  const ChatAvatar({super.key, required this.user, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    final picture = user.profilePicture;
    final hasPicture = picture != null && picture.isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: context.colors.secondaryContainer,
      foregroundImage: hasPicture ? NetworkImage(picture) : null,
      onForegroundImageError: hasPicture ? (_, __) {} : null,
      child: Text(
        user.initials,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
          color: context.colors.primaryDark,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/models/public_user.dart';

/// Profile picture (or initials) that flies between the match card and the detail screen.
class MatchAvatar extends StatelessWidget {
  final PublicUser user;
  final double radius;

  const MatchAvatar({super.key, required this.user, this.radius = 28});

  static String heroTag(int userId) => 'match-avatar-$userId';

  @override
  Widget build(BuildContext context) {
    final picture = user.profilePicture;
    final fallback = Center(
      child: Text(
        user.initials,
        style: TextStyle(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w700,
          color: context.colors.primaryDark,
        ),
      ),
    );

    // Home and Search stay alive offstage and can show the same person:
    // only the visible tab takes part in the flight (duplicate tags would assert)
    return HeroMode(
      enabled: TickerMode.valuesOf(context).enabled,
      child: Hero(
        tag: heroTag(user.id),
        // Material keeps the initials styled while flying over the overlay
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: radius * 2,
            height: radius * 2,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.secondaryContainer,
            ),
            child: picture != null && picture.isNotEmpty
                ? Image.network(
                    picture,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => fallback,
                  )
                : fallback,
          ),
        ),
      ),
    );
  }
}

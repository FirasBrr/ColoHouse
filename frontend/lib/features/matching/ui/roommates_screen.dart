import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'widgets/matches_list.dart';

/// Ranked compatible roommates (/roommates).
class RoommatesScreen extends StatelessWidget {
  const RoommatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Also works when the screen was opened without history
        leading: BackButton(onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        }),
        title: const Text('Compatible roommates'),
      ),
      body: const SafeArea(
        top: false,
        child: MatchesList(padding: EdgeInsets.fromLTRB(20, 12, 20, 24)),
      ),
    );
  }
}

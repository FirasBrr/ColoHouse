import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'requests_tab.dart';
import 'sent_requests_tab.dart';

class ChatTab extends StatelessWidget {
  const ChatTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Changed to 3
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('Inbox'),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.outline,
            tabs: [
              Tab(text: 'Received'),
              Tab(text: 'Sent'),
              Tab(text: 'Messages'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            RequestsTab(),
            SentRequestsTab(),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.outlineVariant), 
                  SizedBox(height: 16),
                  Text('Real-time chat coming soon!', style: TextStyle(color: AppColors.outline)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
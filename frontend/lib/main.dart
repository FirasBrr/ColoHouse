import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/push/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase config comes from android/app/google-services.json
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // One container for the app and the push service (it navigates and refreshes providers)
  final container = ProviderContainer();
  await container.read(pushServiceProvider).init();

  runApp(UncontrolledProviderScope(container: container, child: const ColohouseApp()));
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'src/app.dart';
import 'src/features/shared/providers/auth_provider.dart';
import 'src/features/shared/providers/topics_provider.dart';
import 'src/features/shared/providers/languages_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, TopicsProvider>(
          create: (context) {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            return TopicsProvider(authProvider);
          },
          update: (context, authProvider, previous) {
            // If previous instance exists, just update the auth provider reference
            // Otherwise create a new one
            return previous ?? TopicsProvider(authProvider);
          },
        ),
        ChangeNotifierProvider(create: (_) => LanguagesProvider()),
      ],
      child: const ArchipelagoApp(),
    ),
  );
}


import 'package:flutter/material.dart';
import 'router.dart';
import 'theme.dart';

class QuickServeApp extends StatelessWidget {
  const QuickServeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'QuickServe',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}

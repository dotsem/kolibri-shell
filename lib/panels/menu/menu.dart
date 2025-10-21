import 'package:flutter/material.dart';
import 'package:hypr_flutter/config/theme/theme.dart';
import 'package:hypr_flutter/panels/menu/app_launcher.dart';

class MenuPanel extends StatelessWidget {
  const MenuPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: theme,
      home: Scaffold(backgroundColor: Theme.of(context).colorScheme.onSurface, body: const AppLauncher()),
    );
  }
}

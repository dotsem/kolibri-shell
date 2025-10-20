import 'package:flutter/material.dart';
import 'package:hypr_flutter/config/theme/theme.dart';
import 'package:hypr_flutter/panels/sidebar_left/body/body.dart';

class LeftSidebarWidget extends StatelessWidget {
  const LeftSidebarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          width: 500,
          decoration: BoxDecoration(
            color: Colors.grey[900]!.withOpacity(0.95),
            border: Border(right: BorderSide(color: Colors.grey[700]!, width: 1)),
          ),
          child: Column(children: [LeftSidebarBody()]),
        ),
      ),
    );
  }
}

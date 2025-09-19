import 'package:flutter/material.dart';
import 'package:hypr_flutter/config/theme/theme.dart';
import 'package:hypr_flutter/panels/sidebar_right/body/body.dart';
import 'package:hypr_flutter/panels/sidebar_right/header/header.dart';
import 'package:hypr_flutter/services/system.dart';

class RightSidebarWidget extends StatelessWidget {
  RightSidebarWidget({super.key});
  final SystemInfoService systemInfoService = SystemInfoService();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          width: 400,
          decoration: BoxDecoration(
            color: Colors.grey[900]!.withOpacity(0.95),
            border: Border(left: BorderSide(color: Colors.grey[700]!, width: 1)),
          ),
          child: Column(
            children: [
              SidebarRightHeader(systemInfoService: systemInfoService),
              SidebarRightBody(),
            ],
          ),
        ),
      ),
    );
  }
}

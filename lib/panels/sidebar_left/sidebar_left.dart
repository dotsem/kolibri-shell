import 'package:fl_linux_window_manager/widgets/input_region.dart';
import 'package:flutter/material.dart';
import 'package:hypr_flutter/config/theme/theme.dart';

class LeftSidebarWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          width: 200,
          decoration: BoxDecoration(
            color: Colors.grey[900]!.withOpacity(0.95),
            border: Border(right: BorderSide(color: Colors.grey[700]!, width: 1)),
          ),
          child: Column(children: [_buildHeader(), _buildSidebarItems()]),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 60,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[700]!, width: 1)),
      ),
      child: Center(
        child: Text(
          'Workspace',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSidebarItems() {
    return Expanded(
      child: ListView(
        children: [
          _buildSidebarItem(Icons.folder, 'Files'),
          _buildSidebarItem(Icons.terminal, 'Terminal'),
          _buildSidebarItem(Icons.web, 'Browser'),
          _buildSidebarItem(Icons.code, 'Code Editor'),
          _buildSidebarItem(Icons.settings, 'Settings'),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title) {
    return InputRegion(
      child: ListTile(
        leading: Icon(icon, color: Colors.white70, size: 20),
        title: Text(title, style: TextStyle(color: Colors.white, fontSize: 14)),
        onTap: () {
          print("Sidebar item clicked: $title");
          // Handle sidebar item click
        },
        hoverColor: Colors.grey[700],
        dense: true,
      ),
    );
  }
}

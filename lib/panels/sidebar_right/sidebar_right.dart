import 'package:flutter/material.dart';
import 'package:hypr_flutter/config/theme/theme.dart';
import 'package:hypr_flutter/widgets/widgets.dart';

class RightSidebarWidget extends StatelessWidget {
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
            border: Border(left: BorderSide(color: Colors.grey[700]!, width: 1)),
          ),
          child: Column(children: [_buildHeader(), _buildWidgets()]),
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
          'Widgets',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildWidgets() {
    return Expanded(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(8),
        child: Column(
          children: [
            ClockWidget(),
            SizedBox(height: 16),
            CalendarWidget(),
            SizedBox(height: 16),
            SystemStatsWidget(),
          ],
        ),
      ),
    );
  }
}

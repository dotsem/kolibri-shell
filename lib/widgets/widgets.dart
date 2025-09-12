// widgets/clock/clock_widget.dart
import 'package:flutter/material.dart';

class ClockWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(Icons.access_time, color: Colors.white, size: 24),
            SizedBox(height: 8),
            Text(
              DateTime.now().toString().substring(11, 19),
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(DateTime.now().toString().substring(0, 10), style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// widgets/calendar/calendar_widget.dart
class CalendarWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              'December 2024',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Container(
              height: 80,
              child: Center(
                child: Text(
                  'Calendar\nView',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// widgets/system_stats/system_stats_widget.dart
class SystemStatsWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            _buildStatRow('CPU', 0.45),
            _buildStatRow('RAM', 0.67),
            _buildStatRow('Disk', 0.23),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, double value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(label, style: TextStyle(color: Colors.white70, fontSize: 10)),
          ),
          Expanded(
            child: LinearProgressIndicator(value: value, backgroundColor: Colors.grey[600], valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
          ),
          SizedBox(width: 4),
          Text('${(value * 100).toInt()}%', style: TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}

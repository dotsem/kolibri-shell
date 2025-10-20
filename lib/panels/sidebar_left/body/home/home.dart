import 'package:flutter/material.dart';
import 'package:hypr_flutter/panels/sidebar_left/body/home/notifications.dart';
import 'package:hypr_flutter/services/notification_demo.dart';

class HomeTabWidget extends StatelessWidget {
  const HomeTabWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const NotificationsWidget(),
        // Demo button (can be removed in production)
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(onPressed: () => NotificationDemo.addSampleNotifications(), icon: const Icon(Icons.add_alert), label: const Text('Add Demo Notifications')),
        ),
      ],
    );
  }
}

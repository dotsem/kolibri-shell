import 'package:flutter/material.dart';
import 'package:hypr_flutter/panels/sidebar_left/body/home/home.dart';
import 'package:hypr_flutter/panels/sidebar_left/body/health/health_tab.dart';

class LeftSidebarBody extends StatefulWidget {
  const LeftSidebarBody({super.key});

  @override
  State<LeftSidebarBody> createState() => _LeftSidebarBodyState();
}

class _LeftSidebarBodyState extends State<LeftSidebarBody> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Expanded(
        child: Column(
          children: [
            TabBar(
              tabs: [
                Column(children: [Icon(Icons.home), Text("Home")]),
                Column(children: [Icon(Icons.workspace_premium), Text("Environment")]),
                Column(children: [Icon(Icons.monitor_heart_outlined), Text("Health")]),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  const HomeTabWidget(),
                  const Center(child: Text("Coding Tab Content")),
                  const HealthTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

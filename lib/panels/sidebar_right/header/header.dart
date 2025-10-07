import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hypr_flutter/panels/sidebar_right/header/hypr_flutter_runner.dart';
import 'package:hypr_flutter/services/system.dart';

class SidebarRightHeader extends StatefulWidget {
  final SystemInfoService systemInfoService;
  const SidebarRightHeader({super.key, required this.systemInfoService});

  @override
  State<SidebarRightHeader> createState() => SidebarRightHeaderState();
}

class SidebarRightHeaderState extends State<SidebarRightHeader> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          SvgPicture.asset("assets/icons/arch-symbolic.svg", colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn), height: 40, width: 40),
          Column(
            children: [
              Text(
                widget.systemInfoService.distroName,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              AnimatedBuilder(
                animation: widget.systemInfoService,
                builder: (_, __) {
                  final Duration uptime = widget.systemInfoService.uptime;
                  return Text("Uptime: ${uptime.inDays}d ${uptime.inHours % 24}h ${uptime.inMinutes % 60}m", style: const TextStyle(color: Colors.white70, fontSize: 12));
                },
              ),
            ],
          ),
          const Spacer(),
          HyprFlutterRunner(),
          IconButton(onPressed: () {}, icon: const Icon(Icons.settings)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.power_settings_new_outlined)),
        ],
      ),
    );
  }
}

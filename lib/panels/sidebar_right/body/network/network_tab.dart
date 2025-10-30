import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hypr_flutter/panels/sidebar_right/body/network/available_networks_card.dart';
import 'package:hypr_flutter/panels/sidebar_right/body/network/connection_card.dart';
import 'package:hypr_flutter/panels/sidebar_right/body/network/throughput_card.dart';
import 'package:hypr_flutter/services/network.dart';

class NetworkTab extends StatefulWidget {
  const NetworkTab({super.key, required this.networkService});

  final NetworkService networkService;

  @override
  State<NetworkTab> createState() => _NetworkTabState();
}

class _NetworkTabState extends State<NetworkTab> {
  Timer? _scanTimer;

  @override
  void initState() {
    super.initState();
    widget.networkService.refresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _triggerImmediateScan();
      _startPeriodicScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.networkService,
      builder: (_, __) {
        final service = widget.networkService;
        final children = <Widget>[
          NetworkConnectionCard(networkService: service),
          const SizedBox(height: 12),
          NetworkThroughputCard(networkService: service),
        ];

        if (service.hasWifi) {
          children.add(const SizedBox(height: 12));
          children.add(NetworkAvailableNetworksCard(networkService: service));
        }

        return ListView(padding: const EdgeInsets.all(12), children: children);
      },
    );
  }

  void _startPeriodicScan() {
    _scanTimer?.cancel();
    // Reduce scan frequency from 5s to 10s when already connected
    final scanInterval =
        widget.networkService.wifiConnected || widget.networkService.ethernetConnected
        ? const Duration(seconds: 15)
        : const Duration(seconds: 8);

    _scanTimer = Timer.periodic(scanInterval, (_) {
      _maybeScanForNetworks();
    });
  }

  void _triggerImmediateScan() {
    _maybeScanForNetworks(force: true);
  }

  void _maybeScanForNetworks({bool force = false}) {
    final service = widget.networkService;
    if (!service.hasWifi) return;
    if (service.ethernetConnected) return;
    if (!force && service.scanning) return;
    service.scanForNetworks();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }
}

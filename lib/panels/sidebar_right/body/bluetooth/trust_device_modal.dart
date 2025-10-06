import 'package:bluez/bluez.dart';
import 'package:flutter/material.dart';

typedef TrustDeviceModalCallback = void Function(bool value);

class TrustDeviceModal extends StatelessWidget {
  final BlueZDevice device;
  final TrustDeviceModalCallback onResult;
  const TrustDeviceModal({super.key, required this.device, required this.onResult});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Trust device"),
      content: Text("Do you want to trust \"${device.name}\"?"),
      actions: [
        TextButton(
          onPressed: () {
            onResult(false);
          },
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            onResult(true);
          },
          child: const Text("Trust"),
        ),
      ],
    );
  }
}

Future<bool> showTrustDeviceModal(BuildContext context, BlueZDevice device) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => TrustDeviceModal(
      device: device,
      onResult: (result) {
        Navigator.of(context).pop(result);
      },
    ),
  );
  return result ?? false;
}

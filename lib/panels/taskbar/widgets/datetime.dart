import 'package:flutter/material.dart';

class DatetimeWidget extends StatefulWidget {
  const DatetimeWidget({super.key});

  @override
  State<DatetimeWidget> createState() => _DatetimeWidgetState();
}

class _DatetimeWidgetState extends State<DatetimeWidget> {
  final formattedDate = DateTime.now().toString();
  @override
  Widget build(BuildContext context) {
    return Container(child: Text(formattedDate));
  }
}

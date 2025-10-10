import 'package:flutter/material.dart';

class ColorSelectorTile extends StatelessWidget {
  const ColorSelectorTile({super.key, required this.title, required this.color, required this.onColorPicked});

  final String title;
  final Color color;
  final ValueChanged<Color> onColorPicked;

  Future<void> _openColorPicker(BuildContext context) async {
    Color tempColor = color;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select $title'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ColorPreview(color: tempColor),
              const SizedBox(height: 16),
              ColorPickerSlider(
                label: 'Red',
                value: tempColor.red.toDouble(),
                onChanged: (value) {
                  tempColor = tempColor.withRed(value.toInt());
                },
              ),
              ColorPickerSlider(
                label: 'Green',
                value: tempColor.green.toDouble(),
                onChanged: (value) {
                  tempColor = tempColor.withGreen(value.toInt());
                },
              ),
              ColorPickerSlider(
                label: 'Blue',
                value: tempColor.blue.toDouble(),
                onChanged: (value) {
                  tempColor = tempColor.withBlue(value.toInt());
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                onColorPicked(tempColor);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      title: Text(title),
      trailing: GestureDetector(
        onTap: () => _openColorPicker(context),
        child: ColorPreview(color: color),
      ),
    );
  }
}

class ColorPreview extends StatelessWidget {
  const ColorPreview({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
    );
  }
}

class ColorPickerSlider extends StatefulWidget {
  const ColorPickerSlider({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<ColorPickerSlider> createState() => _ColorPickerSliderState();
}

class _ColorPickerSliderState extends State<ColorPickerSlider> {
  late double sliderValue;

  @override
  void initState() {
    super.initState();
    sliderValue = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${widget.label}: ${sliderValue.toInt()}'),
        Slider(
          value: sliderValue,
          min: 0,
          max: 255,
          divisions: 255,
          onChanged: (value) {
            setState(() => sliderValue = value);
            widget.onChanged(value);
          },
        ),
      ],
    );
  }
}

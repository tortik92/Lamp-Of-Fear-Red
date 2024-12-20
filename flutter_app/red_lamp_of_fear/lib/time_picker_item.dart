import 'package:flutter/material.dart';

class TimePickerItem extends StatelessWidget {
  const TimePickerItem({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Color.fromARGB(115, 120, 120, 120),
            width: 0.0,
          ),
          bottom: BorderSide(
            color:  Color.fromARGB(115, 120, 120, 120),
            width: 0.0,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: children,
        ),
      ),
    );
  }
}
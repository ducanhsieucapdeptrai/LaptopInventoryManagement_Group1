import 'package:flutter/material.dart';

class TempFilterWidget extends StatelessWidget {
  final ValueChanged<String>? onFilterChanged;

  const TempFilterWidget({super.key, this.onFilterChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Lọc nhanh theo tên...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        onChanged: onFilterChanged,
      ),
    );
  }
}

import 'package:flutter/material.dart';

class DateHeader extends StatelessWidget {
  final String dateText;

  const DateHeader({
    super.key,
    required this.dateText,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xE6FFFFFF),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              offset: Offset(0, 1),
              blurRadius: 1,
            )
          ],
        ),
        child: Text(
          dateText.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class CustomLoadingIndicator extends StatelessWidget {
  final double? size;
  final double strokeWidth;

  const CustomLoadingIndicator({
    super.key,
    this.size,
    this.strokeWidth = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    if (size != null) {
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: strokeWidth,
        ),
      );
    }
    
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primary,
      ),
    );
  }
}

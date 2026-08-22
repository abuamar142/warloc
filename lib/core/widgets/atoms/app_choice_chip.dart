import 'package:flutter/material.dart';
import 'package:warloc/core/theme/app_colors.dart';

class AppChoiceChip extends StatelessWidget {
  final Widget label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  const AppChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: label,
      selected: selected,
      selectedColor: AppColors.primaryTransparent,
      checkmarkColor: AppColors.primary,
      onSelected: onSelected,
    );
  }
}

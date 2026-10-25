import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Ô nhập nền vàng nhạt (`#FFF8E1`) dùng trong hộp thoại.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.obscureText = false,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.errorText,
    this.suffixIcon,
    this.maxLines = 1,
  });

  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final bool obscureText;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final Widget? suffixIcon;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      obscureText: obscureText,
      autofocus: autofocus,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      maxLines: obscureText ? 1 : maxLines,
      decoration: InputDecoration(
        filled: true,
        fillColor: dark ? AppColors.inputFillDark : AppColors.inputFill,
        hintText: hintText,
        labelText: labelText,
        errorText: errorText,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}

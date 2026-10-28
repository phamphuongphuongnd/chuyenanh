import 'package:flutter/material.dart';

/// Ô tìm kiếm dùng chung đặt trên thanh tiêu đề (nền = màu theo loại file):
/// trong suốt, chữ/hint trắng. Không ăn nền vàng của `inputDecorationTheme`.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      cursorColor: Colors.white,
      style: const TextStyle(color: Colors.white, fontSize: 18),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white70),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

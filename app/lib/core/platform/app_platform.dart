import 'dart:io';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Nền tảng đang chạy. Chỉ dùng để rẽ nhánh phần dành riêng cho iOS; Android giữ hành vi gốc.
enum AppPlatform { android, ios, other }

AppPlatform detectPlatform() => Platform.isAndroid
    ? AppPlatform.android
    : Platform.isIOS
    ? AppPlatform.ios
    : AppPlatform.other;

/// Test ghi đè để chạy nhánh iOS trên máy dev.
final appPlatformProvider = Provider<AppPlatform>((ref) => detectPlatform());

/// Vị trí neo của bảng chia sẻ. iPad bắt buộc có (popover); Android/khác → `null`
/// (giữ nguyên lời gọi cũ).
Rect? defaultShareOrigin({AppPlatform? platform}) {
  if ((platform ?? detectPlatform()) != AppPlatform.ios) return null;
  final views = PlatformDispatcher.instance.views;
  if (views.isEmpty) return const Rect.fromLTWH(0, 0, 1, 1);
  final view = views.first;
  final size = view.physicalSize / view.devicePixelRatio;
  return Rect.fromLTWH(size.width / 2, size.height / 2, 1, 1);
}

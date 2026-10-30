import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'signature_overlay_model.dart';

/// Lề quanh khung trang trong vùng đặt chữ ký: chỗ cho tay cầm (đổi cỡ) và nút xoá nhô ra ngoài
/// mép trang mà vẫn bấm được (Stack không nhận chạm ngoài kích thước của nó).
const double kSignatureAreaPadding = 18;

const double _kHandle = 28;

/// Các widget `Positioned` của một chữ ký trên trang — kéo thân để dời, kéo tay cầm góc dưới-phải để
/// đổi cỡ (giữ tỷ lệ), nút × góc trên-phải để gỡ.
///
/// Trả về danh sách để đặt thẳng vào cùng một `Stack` (các tay cầm nằm ngoài khung ảnh nên không
/// thể lồng trong Stack con). [pageBox] là kích thước khung trang (pixel), [pageOrigin] là toạ độ góc
/// trên-trái của khung trang trong Stack đó.
List<Widget> signatureOverlayWidgets(
  BuildContext context, {
  required PlacedSignature item,
  required Size pageBox,
  required Offset pageOrigin,
  required bool selected,
  required VoidCallback onSelect,
  required ValueChanged<Offset> onMove,
  required ValueChanged<double> onResize,
  required VoidCallback onRemove,
  String? removeLabel,
}) {
  final scheme = Theme.of(context).colorScheme;
  final rect = Rect.fromLTWH(
    pageOrigin.dx + item.norm.left * pageBox.width,
    pageOrigin.dy + item.norm.top * pageBox.height,
    item.norm.width * pageBox.width,
    item.norm.height * pageBox.height,
  );

  Widget dot(Color fill, Color ring, IconData icon) => Center(
    child: Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 2),
      ),
      child: Icon(icon, size: 10, color: ring),
    ),
  );

  return [
    Positioned.fromRect(
      key: Key('placed_${item.id}'),
      rect: rect,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onSelect(),
        onPanStart: (_) => onSelect(),
        onPanUpdate: (d) => onMove(
          Offset(d.delta.dx / pageBox.width, d.delta.dy / pageBox.height),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: selected
                ? Border.all(color: scheme.primary, width: 1.5)
                : null,
          ),
          child: Image.memory(
            item.pngBytes,
            fit: BoxFit.fill,
            gaplessPlayback: true,
          ),
        ),
      ),
    ),
    if (selected) ...[
      Positioned(
        left: rect.right - _kHandle / 2,
        top: rect.bottom - _kHandle / 2,
        width: _kHandle,
        height: _kHandle,
        child: GestureDetector(
          key: Key('resize_${item.id}'),
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) {
            final deltaPx = resizeWidthDeltaPx(d.delta, rect.size);
            onResize(item.norm.width + deltaPx / pageBox.width);
          },
          child: dot(
            scheme.primary,
            scheme.onPrimary,
            Symbols.open_in_full_rounded,
          ),
        ),
      ),
      Positioned(
        left: rect.right - _kHandle / 2,
        top: rect.top - _kHandle / 2,
        width: _kHandle,
        height: _kHandle,
        child: Semantics(
          button: true,
          label: removeLabel,
          child: GestureDetector(
            key: Key('remove_${item.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: dot(scheme.error, scheme.onError, Symbols.close_rounded),
          ),
        ),
      ),
    ],
  ];
}

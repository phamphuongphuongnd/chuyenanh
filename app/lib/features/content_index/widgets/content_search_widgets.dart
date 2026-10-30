// Phần giao diện của tìm theo nội dung, dùng trong `SearchScreen`.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/db/app_database.dart' show ContentHit;
import '../../documents/document_actions.dart';
import '../../documents/documents_logic.dart';
import '../../documents/widgets/document_tile.dart';
import '../content_index_providers.dart';
import '../logic/search_text.dart';

/// Một file khớp nội dung: dòng [DocumentTile] + đoạn trích có tô đậm từ khoá.
class ContentHitTile extends StatelessWidget {
  const ContentHitTile({super.key, required this.item, required this.excerpt});

  final DocItem item;
  final Excerpt excerpt;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final base = TextStyle(fontSize: 12.5, height: 1.4, color: t.textMuted);
    return Column(
      key: ValueKey('content-hit-${item.path}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DocumentTile(item),
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => openDocumentWithFeedback(context, item.path),
            child: Padding(
              // Thẳng cột với tên file: 14 lề + 40 icon + 12 khoảng cách.
              padding: const EdgeInsets.fromLTRB(66, 0, 14, 10),
              child: Text.rich(
                TextSpan(
                  style: base,
                  children: [
                    TextSpan(text: excerpt.before),
                    if (excerpt.hasMatch)
                      TextSpan(
                        text: excerpt.match,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: t.text,
                        ),
                      ),
                    TextSpan(text: excerpt.after),
                  ],
                ),
                key: const ValueKey('content-hit-excerpt'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tiêu đề nhóm kết quả ("Theo tên", "Trong nội dung").
class SearchGroupHeader extends StatelessWidget {
  const SearchGroupHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: context.tokens.text,
      ),
    ),
  );
}

/// Dòng trạng thái "Đang lập chỉ mục n/m file".
class ContentIndexStatusLine extends StatelessWidget {
  const ContentIndexStatusLine(this.state, {super.key});

  final ContentIndexState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      key: const ValueKey('content-index-status'),
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
      child: Row(
        children: [
          Icon(Symbols.manage_search_rounded, size: 18, color: t.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.cindex_indexing(state.done, state.total),
              style: TextStyle(fontSize: 12.5, color: t.textMuted),
            ),
          ),
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
              value: state.total == 0 ? null : state.done / state.total,
            ),
          ),
        ],
      ),
    );
  }
}

/// Đoạn trích ~80 ký tự cho một [hit].
Excerpt excerptFor(ContentHit hit, String normalizedQuery) => buildExcerpt(
  hit.window,
  normalizedQuery,
  atStart: hit.windowAtStart,
  atEnd: hit.windowAtEnd,
);

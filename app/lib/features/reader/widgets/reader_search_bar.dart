import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/app_search_field.dart';

/// Thanh tìm chữ thay cho AppBar: ô nhập, "2 / 7", ‹ ›, đóng.
class ReaderSearchAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ReaderSearchAppBar({
    super.key,
    required this.textController,
    required this.result,
    required this.onSubmitted,
    required this.onPrevious,
    required this.onNext,
    required this.onClose,
  });

  final TextEditingController textController;

  /// Kết quả tìm hiện tại (null = chưa tìm).
  final PdfTextSearchResult? result;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final searchResult = result;
    return AppBar(
      leading: IconButton(
        tooltip: l.core_close,
        icon: const Icon(Icons.arrow_back),
        onPressed: onClose,
      ),
      title: AppSearchField(
        key: const Key('reader_searchField'),
        controller: textController,
        hintText: l.reader_searchHint,
        onSubmitted: onSubmitted,
      ),
      actions: [
        if (searchResult != null)
          ListenableBuilder(
            listenable: searchResult,
            builder: (context, _) {
              if (!searchResult.isSearchCompleted && !searchResult.hasResult) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              }
              if (!searchResult.hasResult) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      l.reader_searchNoResult,
                      key: const Key('reader_searchNoResult'),
                    ),
                  ),
                );
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.reader_searchCount(
                      searchResult.currentInstanceIndex,
                      searchResult.totalInstanceCount,
                    ),
                  ),
                  IconButton(
                    tooltip: l.reader_previousMatch,
                    icon: const Icon(Icons.keyboard_arrow_up),
                    onPressed: onPrevious,
                  ),
                  IconButton(
                    tooltip: l.reader_nextMatch,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: onNext,
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

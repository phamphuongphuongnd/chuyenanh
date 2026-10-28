import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_search_field.dart';

/// Thanh tìm chữ đặt ngay dưới AppBar (giống Word/Excel/PPT/TXT): ô nhập, "2 / 7", ‹ ›, đóng.
/// Không thay thanh tiêu đề nên các nút phóng to/thu nhỏ vẫn dùng được.
class ReaderSearchBar extends StatelessWidget {
  const ReaderSearchBar({
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
  Widget build(BuildContext context) {
    final l = context.l10n;
    final searchResult = result;
    return Material(
      color: AppColors.pdf,
      elevation: 2,
      child: IconTheme(
        data: const IconThemeData(color: Colors.white),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: AppSearchField(
                  key: const Key('reader_searchField'),
                  controller: textController,
                  hintText: l.reader_searchHint,
                  onSubmitted: onSubmitted,
                ),
              ),
              if (searchResult != null)
                ListenableBuilder(
                  listenable: searchResult,
                  builder: (context, _) {
                    final style = Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: Colors.white);
                    if (!searchResult.isSearchCompleted &&
                        !searchResult.hasResult) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }
                    if (!searchResult.hasResult) {
                      return Text(
                        l.reader_searchNoResult,
                        key: const Key('reader_searchNoResult'),
                        style: style,
                      );
                    }
                    return Text(
                      l.reader_searchCount(
                        searchResult.currentInstanceIndex,
                        searchResult.totalInstanceCount,
                      ),
                      style: style,
                    );
                  },
                ),
              IconButton(
                tooltip: l.reader_previousMatch,
                icon: const Icon(Icons.keyboard_arrow_up),
                color: Colors.white,
                onPressed: onPrevious,
              ),
              IconButton(
                tooltip: l.reader_nextMatch,
                icon: const Icon(Icons.keyboard_arrow_down),
                color: Colors.white,
                onPressed: onNext,
              ),
              IconButton(
                tooltip: l.core_close,
                icon: const Icon(Icons.close),
                color: Colors.white,
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

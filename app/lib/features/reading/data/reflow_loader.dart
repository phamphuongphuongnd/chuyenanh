import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_layout/pdf_layout.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../../core/errors/app_error.dart';
import '../../convert/engine/pdf_extract.dart';
import '../logic/reflow_document.dart';

/// Một lần phát của dàn chữ từng phần: [doc] là tài liệu gom được từ đầu đến trang [pagesDone]
/// (`doc.pageCount` là tổng số trang); các lần phát sau chỉ NỐI THÊM dòng vào cuối [doc.items]
/// (chỉ số dòng / đoạn đã có không đổi). [done] = đã dàn xong mọi trang.
class ReflowProgress {
  const ReflowProgress({
    required this.doc,
    required this.pagesDone,
    required this.done,
  });

  final ReflowDocument doc;
  final int pagesDone;
  final bool done;
}

/// Đọc PDF ở [path] (mật khẩu [password] nếu có) thành các [ReflowProgress] tiến dần theo trang.
/// Phát lỗi [PasswordRequired] / [WrongPassword] / [CorruptFile]; PDF quét → phần cuối là
/// `ReflowDocument.empty` (không có chữ).
typedef ReflowStreamLoader =
    Stream<ReflowProgress> Function(String path, {String? password});

/// Nguồn chữ của màn đọc dàn chữ — test override bằng dữ liệu giả.
final reflowStreamLoaderProvider = Provider<ReflowStreamLoader>(
  (ref) => streamReflowDocument,
);

/// Đổi số khi thuật toán dàn chữ đổi để bỏ bộ nhớ đệm cũ.
const reflowCacheVersion = 2;

/// Số trang mỗi lô: lô đầu 1 trang (hiện sớm nhất), các lô sau gấp đôi dần tới [_maxBatch].
const _firstBatch = 1;
const _maxBatch = 8;
const _cachePrefix = 'reflow_';
const _cacheMaxAge = Duration(days: 14);

/// Thư mục đệm mặc định (thư mục tạm của app); không lấy được (vd. test) → không đệm.
Future<Directory?> _defaultCacheDir() async {
  try {
    final dir = Directory(
      '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}reflow_cache',
    );
    await dir.create(recursive: true);
    return dir;
  } catch (_) {
    return null;
  }
}

/// FNV-1a 32 bit của [s] (tên file đệm, không cần mật mã).
String _hash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16);
}

File _cacheFile(Directory dir, String path, int size, int modifiedMs) => File(
  '${dir.path}${Platform.pathSeparator}$_cachePrefix${_hash(path)}_${size}_${modifiedMs}_v$reflowCacheVersion.json',
);

Map<String, Object?> reflowDocumentToJson(ReflowDocument d) => {
  'pageCount': d.pageCount,
  'items': [
    for (final i in d.items)
      {
        'k': i.kind.index,
        'p': i.page,
        if (i.text.isNotEmpty) 't': i.text,
        if (i.level != 0) 'l': i.level,
        if (i.marker.isNotEmpty) 'm': i.marker,
        if (i.ordered) 'o': true,
        if (i.bold) 'b': true,
        if (i.cells.isNotEmpty) 'c': i.cells,
      },
  ],
};

ReflowDocument reflowDocumentFromJson(Map<String, dynamic> j) {
  final items = <ReflowItem>[
    for (final e in (j['items'] as List).cast<Map<String, dynamic>>())
      ReflowItem(
        kind: ReflowKind.values[e['k'] as int],
        page: e['p'] as int,
        text: (e['t'] as String?) ?? '',
        level: (e['l'] as int?) ?? 0,
        marker: (e['m'] as String?) ?? '',
        ordered: (e['o'] as bool?) ?? false,
        bold: (e['b'] as bool?) ?? false,
        cells: [...?(e['c'] as List?)?.cast<String>()],
      ),
  ];
  final pageCount = j['pageCount'] as int;
  return items.isEmpty
      ? ReflowDocument.empty(pageCount: pageCount)
      : ReflowDocument(items: items, pageCount: pageCount);
}

Future<ReflowDocument?> _readCache(File f) async {
  try {
    if (!await f.exists()) return null;
    final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    return reflowDocumentFromJson(json);
  } catch (_) {
    return null; // đệm hỏng → dàn lại
  }
}

/// Ghi đệm và dọn file đệm quá cũ; mọi lỗi đều bỏ qua (đệm chỉ để nhanh hơn).
Future<void> _writeCache(Directory dir, File f, ReflowDocument doc) async {
  try {
    await f.writeAsString(jsonEncode(reflowDocumentToJson(doc)));
    final now = DateTime.now();
    await for (final e in dir.list()) {
      if (e is File &&
          e.uri.pathSegments.last.startsWith(_cachePrefix) &&
          now.difference(await e.lastModified()) > _cacheMaxAge) {
        await e.delete();
      }
    }
  } catch (_) {}
}

/// Trích chữ + dựng khối trong isolate riêng, phát kết quả từng lô trang (1, 2, 4, 8… trang) để màn
/// hình hiện / đọc trang đầu ngay. File không có mật khẩu được đệm theo (đường dẫn, kích thước,
/// thời điểm sửa): có đệm → phát một lần đủ tài liệu, tức thì. [cacheDir] mặc định là thư mục tạm
/// của app (test truyền thư mục riêng). Huỷ đăng ký thì isolate bị dừng.
///
/// Giới hạn so với dàn một lần: mỗi lô dựng riêng nên cỡ chữ thân bài (để nhận tiêu đề) tính theo lô;
/// đoạn / bảng vắt qua trang không được nối (như trước đây); tiêu đề / chân trang lặp chỉ lọc được
/// từ khi đã đọc ≥ 2 trang, nên trang 1 có thể còn giữ tiêu đề / số trang chạy.
Stream<ReflowProgress> streamReflowDocument(
  String path, {
  String? password,
  Directory? cacheDir,
}) async* {
  final File? cache;
  final dir = (password == null || password.isEmpty)
      ? (cacheDir ?? await _defaultCacheDir())
      : null; // file có mật khẩu: không ghi chữ ra đĩa
  if (dir != null) {
    File? f;
    try {
      final stat = await File(path).stat();
      f = stat.type == FileSystemEntityType.file
          ? _cacheFile(dir, path, stat.size, stat.modified.millisecondsSinceEpoch)
          : null;
    } catch (_) {
      f = null;
    }
    cache = f;
    if (cache != null) {
      final hit = await _readCache(cache);
      if (hit != null) {
        yield ReflowProgress(doc: hit, pagesDone: hit.pageCount, done: true);
        return;
      }
    }
  } else {
    cache = null;
  }

  final Uint8List bytes;
  try {
    bytes = await File(path).readAsBytes();
  } catch (e) {
    final err = AppError.from(e);
    throw err is Unknown ? CorruptFile('$e') : err;
  }

  final port = ReceivePort();
  Isolate? isolate;
  try {
    isolate = await Isolate.spawn(
      _reflowWorker,
      _WorkerArgs(port.sendPort, TransferableTypedData.fromList([bytes]), password),
      onExit: port.sendPort,
    );
    final items = <ReflowItem>[];
    await for (final m in port) {
      if (m is AppError) throw m;
      if (m is! _Batch) throw const CorruptFile('isolate thoát bất thường');
      items.addAll(m.items);
      final done = m.pagesDone >= m.pageCount;
      final doc = done && !items.any((i) => i.hasText)
          ? ReflowDocument.empty(pageCount: m.pageCount)
          : ReflowDocument(items: List.of(items), pageCount: m.pageCount);
      yield ReflowProgress(doc: doc, pagesDone: m.pagesDone, done: done);
      if (done) {
        if (dir != null && cache != null) await _writeCache(dir, cache, doc);
        return;
      }
    }
  } finally {
    port.close();
    isolate?.kill(priority: Isolate.immediate);
  }
}

/// Đọc cả file (đệm hoặc dàn mới) và trả tài liệu cuối cùng.
Future<ReflowDocument> loadReflowDocument(
  String path, {
  String? password,
  Directory? cacheDir,
}) async {
  ReflowDocument? last;
  await for (final p in streamReflowDocument(
    path,
    password: password,
    cacheDir: cacheDir,
  )) {
    last = p.doc;
  }
  return last ?? const ReflowDocument.empty();
}

class _WorkerArgs {
  const _WorkerArgs(this.port, this.bytes, this.password);
  final SendPort port;
  final TransferableTypedData bytes;
  final String? password;
}

/// Các dòng của một lô trang đã dàn; [pagesDone] / [pageCount] = số trang đã xong / tổng.
class _Batch {
  const _Batch(this.items, this.pagesDone, this.pageCount);
  final List<ReflowItem> items;
  final int pagesDone;
  final int pageCount;
}

LayoutPage _extractPage(sf.PdfDocument doc, sf.PdfTextExtractor ex, int i) {
  // Chỉ lỗi từ thư viện Syncfusion (dữ liệu PDF hỏng) mới thành CorruptFile.
  try {
    final size = doc.pages[i].size;
    final lines = ex.extractTextLines(startPageIndex: i, endPageIndex: i);
    return LayoutPage(
      index: i,
      width: size.width,
      height: size.height,
      lines: [
        for (final l in lines)
          if (l.text.trim().isNotEmpty) layoutLineFromTextLine(l),
      ],
    );
  } on AppError {
    rethrow;
  } catch (e) {
    throw CorruptFile(e.toString());
  }
}

void _reflowWorker(_WorkerArgs a) {
  try {
    final bytes = a.bytes.materialize().asUint8List();
    final doc = openPdfDocument(bytes, password: a.password);
    try {
      final extractor = sf.PdfTextExtractor(doc);
      final n = doc.pages.count;
      final read = <LayoutPage>[];
      var next = 0;
      var size = _firstBatch;
      if (n == 0) a.port.send(const _Batch([], 0, 0));
      while (next < n) {
        final end = math.min(n, next + size);
        final batch = [for (var i = next; i < end; i++) _extractPage(doc, extractor, i)];
        final blocks = rebuildDocument(batch, context: read);
        final items = buildReflowItems(blocks, firstPage: next, totalPages: n);
        read.addAll(batch);
        a.port.send(_Batch(items, end, n));
        next = end;
        size = math.min(size * 2, _maxBatch);
      }
    } finally {
      doc.dispose();
    }
  } on AppError catch (e) {
    a.port.send(e);
  } catch (e) {
    a.port.send(CorruptFile('$e'));
  }
}

/// Pure Dart readers for Office Open XML documents (.docx, .xlsx).
///
/// All entry points are synchronous and side-effect free, so they can run in
/// `Isolate.run`. Unreadable input throws [OfficeFormatException].
library;

export 'src/common.dart' show OfficeFormatException;
export 'src/docx/docx_model.dart';
export 'src/docx/docx_reader.dart' show readDocx;
export 'src/xlsx/number_format.dart'
    show formatNumber, formatText, isDateFormat, excelSerialToDate;
export 'src/xlsx/xlsx_model.dart';
export 'src/xlsx/xlsx_reader.dart' show readXlsx, columnIndex, parseCellRef;

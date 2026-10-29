# iOS Simulator CI — Đợt 2: xem file và chuyển đổi (không camera/OCR)

> Mở rộng spec `2026-10-28-ios-simulator-ci-dot1-design.md`. Người dùng yêu cầu (29/10): xem file, chuyển ảnh/file sang PDF và ngược lại, chụp ảnh kết quả; **không** quét camera.

**Goal:** Trên iPhone simulator (CI), mở được PDF/DOCX/XLSX/TXT, chuyển Ảnh→PDF, Word/Excel/Text→PDF, PDF→Text/Word/Excel/Ảnh, và chụp ảnh từng bước.

**Cách làm:** bộ chọn file hệ thống không điều khiển được trên simulator, nhưng mọi route nhận đường dẫn qua `extra`
(`Routes.pdfReader` = `OpenFileArgs`, viewer/convert = `String`, `Routes.imageToPdf` = `List<String>`). Test tự **sinh file mẫu** trong thư mục tạm
(PDF bằng syncfusion_flutter_pdf, XLSX bằng xlsio, DOCX bằng `writeDocx` của `pdf_layout`, ảnh bằng `image`, TXT) rồi `router.push(...)`.

| File | Việc |
|---|---|
| `app/integration_test/support/fixtures.dart` | sinh file mẫu |
| `app/integration_test/support/steps.dart` | thêm `waitFor`, `pumpFor` |
| `app/integration_test/app_features_test.dart` | kịch bản xem + chuyển đổi, ảnh `2x-`/`3x-` |
| `.github/workflows/ios-sim.yml` | chạy cả 2 bộ test, đăng ảnh lên Release `ios-sim-latest` để xem không cần đăng nhập |
| `app/test/core/ios_simulation_test.dart` | test chặn hồi quy cho workflow |

Chờ chuyển đổi xong bằng `Icons.check_circle` (thẻ kết quả của `ConvertScreen`), `result_name` (Ảnh→PDF), `p2i_resultPath` (PDF→ảnh).
Đợt 3 (còn lại): chỉnh sửa PDF, công cụ PDF (gộp/tách/khoá…), PPTX, chia sẻ.

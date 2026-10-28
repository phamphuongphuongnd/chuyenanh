# iOS Simulator CI — Đợt 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trên GitHub CI, chạy app trên iPhone simulator, đi qua 5 tab + các màn Cài đặt, chụp 11 ảnh và đăng thành artifact.

**Architecture:** `integration_test` (Flutter) chạy bằng `flutter drive` trên simulator do runner macOS bật; driver ghi ảnh ra `app/screenshots/`; workflow riêng `ios-sim.yml` upload ảnh. Không sửa `lib/`, không sửa `ios-build.yml`/Android.

**Tech Stack:** Flutter 3.47 (stable), `integration_test` (SDK), Riverpod, drift in-memory, GitHub Actions `macos-latest`, `xcrun simctl`.

Spec: `docs/superpowers/specs/2026-10-28-ios-simulator-ci-dot1-design.md`

## File structure

| File | Tạo/Sửa | Trách nhiệm |
|---|---|---|
| `app/pubspec.yaml` (+`pubspec.lock`) | Sửa | thêm `integration_test` vào `dev_dependencies` |
| `.gitignore` | Sửa | bỏ qua `app/screenshots/` |
| `app/test_driver/integration_test.dart` | Tạo | driver nhận ảnh từ test, ghi `screenshots/<name>.png` |
| `app/integration_test/support/boot.dart` | Tạo | `pumpApp(tester, locale:)` dựng app với DB in-memory, prefs sạch, 3 stream tài liệu rỗng |
| `app/integration_test/support/steps.dart` | Tạo | `settle`, `tapKey`, `shot`: helper dùng chung |
| `app/integration_test/app_test.dart` | Tạo | kịch bản 11 ảnh |
| `.github/workflows/ios-sim.yml` | Tạo | bật simulator, chạy test, upload ảnh |

---

### Task 1: Thêm dependency và driver

**Files:**
- Modify: `app/pubspec.yaml` (mục `dev_dependencies`)
- Modify: `.gitignore`
- Create: `app/test_driver/integration_test.dart`

- [ ] **Step 1: Thêm `integration_test` vào dev_dependencies**

Trong `app/pubspec.yaml`, ngay dưới `flutter_test:`:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
```

- [ ] **Step 2: Bỏ qua thư mục ảnh**

Thêm vào cuối `.gitignore`:

```
# Ảnh chụp từ integration_test trên simulator iOS (CI tạo)
app/screenshots/
```

- [ ] **Step 3: Tạo driver**

`app/test_driver/integration_test.dart`:

```dart
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Nhận ảnh do `binding.takeScreenshot(name)` gửi về và ghi `screenshots/<name>.png`
/// (chạy từ thư mục app/ nên ra app/screenshots/).
Future<void> main() async {
  await integrationDriver(
    onScreenshot:
        (
          String name,
          List<int> image, [
          Map<String, Object?>? args,
        ]) async {
          final file = File('screenshots/$name.png')
            ..createSync(recursive: true);
          file.writeAsBytesSync(image);
          return true;
        },
  );
}
```

- [ ] **Step 4: Cập nhật lock và kiểm tra**

Run (trong `app/`): `flutter pub get`
Expected: `Got dependencies!`, `pubspec.lock` có thêm `integration_test`.

Run: `flutter analyze test_driver`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock .gitignore app/test_driver/integration_test.dart
git commit -m "test(ios-sim): them integration_test va driver ghi anh"
```

---

### Task 2: Helper boot + steps

**Files:**
- Create: `app/integration_test/support/boot.dart`
- Create: `app/integration_test/support/steps.dart`

- [ ] **Step 1: Tạo `boot.dart`** (sao đúng cách dựng của `test/app_smoke_test.dart`)

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/app.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/documents/documents_logic.dart';
import 'package:pdf_office/features/documents/documents_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dựng app với DB trong bộ nhớ, prefs sạch và 3 stream tài liệu rỗng
/// (stream drift để lại timer sau khi cây widget bị huỷ).
Future<void> pumpApp(WidgetTester tester, {String locale = 'en'}) async {
  SharedPreferences.setMockInitialValues({SettingsRepository.kLocale: locale});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        documentsProvider.overrideWith(
          (ref) => Stream.value(const <DocItem>[]),
        ),
        homeRecentItemsProvider.overrideWith(
          (ref) => Stream.value(const <DocItem>[]),
        ),
        homeFavoriteItemsProvider.overrideWith(
          (ref) => Stream.value(const <DocItem>[]),
        ),
      ],
      child: const PdfOfficeApp(),
    ),
  );
}
```

- [ ] **Step 2: Tạo `steps.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Chờ UI yên; quá 20 giây hoặc có exception thì chụp ảnh `FAIL-<label>` rồi báo đỏ.
Future<void> settle(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  String label,
) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );
  } catch (_) {
    await binding.takeScreenshot('FAIL-$label');
    rethrow;
  }
  final error = tester.takeException();
  if (error != null) {
    await binding.takeScreenshot('FAIL-$label');
    throw TestFailure('Exception khi dựng "$label": $error');
  }
}

/// Bấm widget có `ValueKey(key)`; cuộn trong [scrollable] nếu chưa được dựng.
Future<void> tapKey(
  WidgetTester tester,
  String key, {
  Finder? scrollable,
}) async {
  final finder = find.byKey(ValueKey(key));
  if (scrollable != null && finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 200, scrollable: scrollable);
  }
  await tester.ensureVisible(finder);
  await tester.tap(finder);
}

/// Chờ yên rồi chụp ảnh `<name>.png`.
Future<void> shot(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  await settle(tester, binding, name);
  await binding.takeScreenshot(name);
}
```

- [ ] **Step 3: Phân tích**

Run (trong `app/`): `flutter analyze integration_test`
Expected: `No issues found!` (nếu báo `unused_import` ở `boot.dart` cho `documents_logic.dart` thì kiểm lại `DocItem` nằm ở đâu bằng `grep -rn "class DocItem" lib` và sửa import cho đúng — smoke test dùng chính import này nên phải hợp lệ).

- [ ] **Step 4: Commit**

```bash
git add app/integration_test/support
git commit -m "test(ios-sim): helper boot va steps cho integration_test"
```

---

### Task 3: Kịch bản 11 ảnh

**Files:**
- Create: `app/integration_test/app_test.dart`

- [ ] **Step 1: Viết test**

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdf_office/features/documents/main_shell.dart';
import 'package:pdf_office/features/settings/settings_screen.dart';

import 'support/boot.dart';
import 'support/steps.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('đi qua 5 tab và Cài đặt, chụp 11 ảnh', (tester) async {
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();

    Future<void> tab(String key, String label) async {
      await tapKey(tester, key);
      await settle(tester, binding, label);
    }

    final settingsList = find
        .descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(Scrollable),
        )
        .first;

    // Mở mục Cài đặt, chụp, rồi quay lại.
    Future<void> openSetting(String key, String name) async {
      await tapKey(tester, key, scrollable: settingsList);
      await shot(tester, binding, name);
      await tester.pageBack();
      await settle(tester, binding, 'back-$name');
    }

    await pumpApp(tester, locale: 'en');
    await settle(tester, binding, 'boot');
    expect(find.byType(MainShell), findsOneWidget);
    await shot(tester, binding, '01-home');

    await tab('nav-files', 'tab-files');
    await shot(tester, binding, '02-files');

    await tab('nav-tools', 'tab-tools');
    await shot(tester, binding, '03-tools');

    await tab('nav-settings', 'tab-settings');
    expect(find.byType(SettingsScreen), findsOneWidget);
    // iOS không cho chọn thư mục tuỳ ý → mục "Thư mục lưu" phải bị ẩn.
    if (Platform.isIOS) {
      expect(find.byKey(const ValueKey('settings_outputDir')), findsNothing);
    }
    await shot(tester, binding, '04-settings');

    await openSetting('settings_language', '05-language');
    await openSetting('settings_theme', '06-theme');
    await openSetting('settings_pageSize', '07-page-size');
    await openSetting('settings_privacy', '08-privacy');
    await openSetting('settings_about', '09-about');

    // Đổi sang tiếng Việt rồi xem lại Trang chủ.
    await tapKey(tester, 'settings_language', scrollable: settingsList);
    await settle(tester, binding, 'language-open');
    await tapKey(tester, 'lang_vi');
    await settle(tester, binding, 'language-vi');
    await tester.pageBack();
    await settle(tester, binding, 'back-language-vi');
    await tab('nav-home', 'tab-home-vi');
    expect(find.text('Trang chủ'), findsWidgets);
    await shot(tester, binding, '10-home-vi');

    // Chế độ tối.
    await tab('nav-settings', 'tab-settings-dark');
    await tapKey(tester, 'settings_theme', scrollable: settingsList);
    await settle(tester, binding, 'theme-open');
    await tapKey(tester, 'theme_dark');
    await settle(tester, binding, 'theme-dark');
    await tester.pageBack();
    await settle(tester, binding, 'back-theme-dark');
    await tab('nav-home', 'tab-home-dark');
    final brightness = Theme.of(
      tester.element(find.byType(MainShell)),
    ).brightness;
    expect(brightness, Brightness.dark);
    await shot(tester, binding, '11-home-dark');
  });
}
```

- [ ] **Step 2: Phân tích**

Run (trong `app/`): `flutter analyze integration_test test_driver`
Expected: `No issues found!`

- [ ] **Step 3: Chạy thử nếu có thiết bị/emulator** (không bắt buộc; Windows không có iOS)

Run: `flutter devices`
Nếu có thiết bị Android: `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart -d <id>`
Expected: `All tests passed!` và có 11 file `app/screenshots/*.png`. Nếu không có thiết bị → bỏ qua, CI ở Task 4 là lần chạy thật đầu tiên.

- [ ] **Step 4: Đảm bảo test cũ vẫn xanh**

Run: `flutter test`
Expected: toàn bộ test (764) pass; thư mục `integration_test/` không bị `flutter test` chạy.

- [ ] **Step 5: Commit**

```bash
git add app/integration_test/app_test.dart
git commit -m "test(ios-sim): kich ban 11 anh qua 5 tab va Cai dat"
```

---

### Task 4: Workflow `ios-sim.yml`

**Files:**
- Create: `.github/workflows/ios-sim.yml`

- [ ] **Step 1: Viết workflow**

```yaml
name: ios-sim

# Chạy tay hoặc khi đẩy tag ios-sim-*: mỗi lần mất 15–30 phút macOS nên không chạy mỗi lần push.
on:
  workflow_dispatch:
  push:
    tags: ['ios-sim-*']

permissions:
  contents: read

jobs:
  simulator:
    runs-on: macos-latest
    timeout-minutes: 45
    defaults:
      run:
        working-directory: app
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      # lib/l10n/ bị gitignore; flutter pub get tự sinh gói l10n nên cần ARB gộp TRƯỚC.
      - run: dart tool/merge_arb.dart
      - run: flutter pub get
      - run: flutter gen-l10n
      - run: bash tool/fetch_fonts.sh
      - name: Chọn và bật iPhone simulator
        run: |
          UDID=$(xcrun simctl list devices available -j | python3 -c "
          import json,sys
          d=json.load(sys.stdin)['devices']
          for rt in sorted([k for k in d if 'iOS' in k], reverse=True):
              ph=[x for x in d[rt] if x['name'].startswith('iPhone') and x['isAvailable']]
              if ph:
                  print(ph[-1]['udid']); break
          ")
          echo "Simulator: $UDID"
          test -n "$UDID"
          xcrun simctl boot "$UDID" || true
          xcrun simctl bootstatus "$UDID" -b
          echo "UDID=$UDID" >> "$GITHUB_ENV"
      - name: Chạy integration_test và chụp ảnh
        run: >
          flutter drive
          --driver=test_driver/integration_test.dart
          --target=integration_test/app_test.dart
          -d "$UDID"
      - name: Đăng ảnh chụp
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: ios-sim-screenshots
          path: app/screenshots
          if-no-files-found: warn
```

- [ ] **Step 2: Kiểm tra cú pháp YAML**

Run (ở thư mục gốc repo): `python -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ios-sim.yml',encoding='utf-8')); print('YAML OK')"`
Expected: `YAML OK` (nếu thiếu module `yaml` thì đọc lại file bằng mắt, kiểm thụt lề 2 dấu cách).

- [ ] **Step 3: Commit và đẩy**

```bash
git add .github/workflows/ios-sim.yml
git commit -m "ci(ios-sim): workflow iPhone simulator chay integration_test va chup anh"
git push origin feat/pdf-office
```

Chỉ thêm đúng các file của kế hoạch này; **không** `git add` thư mục `lmm-wiki/` (người dùng dặn wiki không đẩy git).

---

### Task 5: Chạy CI và xem ảnh

- [ ] **Step 1: Đẩy tag chạy workflow**

```bash
git tag ios-sim-test1
git push origin ios-sim-test1
```

- [ ] **Step 2: Theo dõi kết quả**

Run: `curl -s "https://api.github.com/repos/phamphuongphuongnd/chuyenanh/actions/runs?per_page=1"` và đọc `status`/`conclusion`; xem từng bước qua `/actions/runs/<id>/jobs`.
Expected: `completed` / `success` (mất 15–30 phút).

- [ ] **Step 3: Nếu đỏ → dùng `systematic-debugging`**

Không đoán: lấy tên bước đỏ (jobs API), tái hiện nguyên nhân, mới sửa; mỗi lần sửa một thay đổi rồi đẩy tag `ios-sim-test2`, `ios-sim-test3`…

- [ ] **Step 4: Xem ảnh**

Artifact `ios-sim-screenshots` cần đăng nhập GitHub để tải; người dùng tải về hoặc gửi ảnh vào chat. Với từng ảnh ghi nhận: chữ cắt, icon vỡ, đè tai thỏ/home indicator, mục "Thư mục lưu" không xuất hiện.

---

## Self-review (đối chiếu spec)

- **Mục 2 (11 màn):** 01-home, 02-files, 03-tools, 04-settings, 05-language, 06-theme, 07-page-size, 08-privacy, 09-about, 10-home-vi, 11-home-dark đều có trong Task 3. Mục "Thư mục lưu" ẩn trên iOS: có `expect(...findsNothing)` khi `Platform.isIOS`.
- **Mục 3 (file):** boot, shots (gộp vào `steps.dart` với `shot`), driver, app_test, workflow đều có task; `pubspec.yaml` chỉ thêm dev dependency; `lib/` không đổi (mọi Key cần dùng đã tồn tại: `nav-*`, `settings_*`, `lang_vi`, `theme_dark`).
- **Mục 4 (workflow):** thứ tự merge_arb → pub get → gen-l10n → fonts; chọn simulator động bằng `simctl`; upload `if: always()`.
- **Mục 5 (lỗi):** `settle` chụp `FAIL-<label>` khi quá 20 giây hoặc có exception.
- **Mục 6 (kiểm chứng):** Task 3 Step 4 (764 test), Task 5.
- **Nhất quán tên:** `pumpApp`, `settle`, `tapKey`, `shot` định nghĩa ở Task 2 và dùng đúng chữ ký ở Task 3.
- **Rủi ro biết trước:** `scrollUntilVisible` cần `Scrollable` duy nhất trong `SettingsScreen`; nếu CI báo nhiều Scrollable thì đã dùng `.first` nên an toàn. Nếu `pageBack()` không tìm được nút Back trên màn đẩy bằng `go_router` (Language, About) thì thay bằng `tester.tap(find.byType(BackButton))` ở bước sửa lỗi.

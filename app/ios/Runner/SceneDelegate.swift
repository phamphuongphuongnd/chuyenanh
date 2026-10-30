import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  /// Khởi động lạnh bằng "Mở trong" / chạm file trong app Tệp: URL nằm ở `connectionOptions`.
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    IncomingFilesBridge.shared.receive(connectionOptions.urlContexts.map { $0.url })
  }

  /// App đang chạy và nhận file mới.
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    let files = URLContexts.filter { $0.url.isFileURL }
    let others = URLContexts.subtracting(files)
    // URL file không phải deep link: không chuyển cho Flutter/plugin khác (tránh GoRouter
    // điều hướng tới đường dẫn file). URL khác vẫn đi tiếp như cũ.
    if !others.isEmpty {
      super.scene(scene, openURLContexts: others)
    }
    IncomingFilesBridge.shared.receive(files.map { $0.url })
  }
}

/// Nhận file từ app khác trên iOS rồi chuyển đường dẫn sang Dart.
///
/// Kênh `com.phuong.pdfoffice/incoming` (giống Android):
///  - `takeInitial` -> `{paths: [String], failed: Int, unsupported: Int}`: file nhận trước khi Dart sẵn sàng
///    (khởi động lạnh). Nếu còn đang chép thì chờ chép xong mới trả.
///  - Native -> Dart `onFiles({paths, failed})`: file nhận khi app đang chạy.
///
/// Mỗi URL: `startAccessingSecurityScopedResource` → chép (NSFileCoordinator) vào
/// `Documents/Imported` (tên trùng + cùng dung lượng thì dùng lại, như `importIntoAppDocuments`
/// ở lib/core/utils/file_import.dart) → `stopAccessing…`. File iOS chép sẵn vào
/// `Documents/Inbox` được xoá sau khi chép để khỏi trùng.
///
/// Mọi biến trạng thái chỉ đụng trên luồng chính; việc chép chạy trên [queue].
final class IncomingFilesBridge: NSObject {
  static let shared = IncomingFilesBridge()

  static let channelName = "com.phuong.pdfoffice/incoming"
  static let maxBytes: Int64 = 200 * 1024 * 1024
  private static let importedFolderName = "Imported"
  private static let maxNameLength = 120

  /// Khớp `documentExtensions` + `imageExtensions` (lib/core/utils/doc_type.dart).
  private static let allowedExtensions: Set<String> = [
    "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt",
    "jpg", "jpeg", "png", "webp", "heic", "heif", "bmp", "gif",
  ]

  private var channel: FlutterMethodChannel?
  private var pendingPaths: [String] = []
  private var pendingFailed = 0
  private var pendingUnsupported = 0
  private var inFlight = 0
  private var waitingResults: [FlutterResult] = []
  private var dartReady = false
  private let queue = DispatchQueue(label: "com.phuong.pdfoffice.incoming", qos: .userInitiated)

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "takeInitial":
        self.takeInitial(result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  /// Gọi trên luồng chính từ SceneDelegate.
  func receive(_ urls: [URL]) {
    let files = urls.filter { $0.isFileURL }
    guard !files.isEmpty else { return }
    inFlight += 1
    queue.async {
      var paths: [String] = []
      var failed = 0
      var unsupported = 0
      for url in files {
        if !Self.allowedExtensions.contains(url.pathExtension.lowercased()) {
          unsupported += 1
        } else if let path = Self.importFile(url) {
          paths.append(path)
        } else {
          failed += 1
        }
      }
      DispatchQueue.main.async {
        self.finish(paths: paths, failed: failed, unsupported: unsupported)
      }
    }
  }

  // MARK: - Trạng thái (luồng chính)

  private func finish(paths: [String], failed: Int, unsupported: Int) {
    inFlight -= 1
    if dartReady, waitingResults.isEmpty, let channel = channel {
      channel.invokeMethod(
        "onFiles", arguments: Self.payload(paths, failed, unsupported))
      return
    }
    pendingPaths.append(contentsOf: paths)
    pendingFailed += failed
    pendingUnsupported += unsupported
    flushWaiting()
  }

  private func takeInitial(_ result: @escaping FlutterResult) {
    dartReady = true
    waitingResults.append(result)
    flushWaiting()
  }

  private func flushWaiting() {
    guard inFlight == 0, !waitingResults.isEmpty else { return }
    let results = waitingResults
    waitingResults = []
    let first = Self.payload(pendingPaths, pendingFailed, pendingUnsupported)
    pendingPaths = []
    pendingFailed = 0
    pendingUnsupported = 0
    for (i, result) in results.enumerated() {
      result(i == 0 ? first : Self.payload([], 0, 0))
    }
  }

  /// `failed` = lỗi đọc / quá dung lượng; `unsupported` = đuôi lạ.
  private static func payload(_ paths: [String], _ failed: Int, _ unsupported: Int)
    -> [String: Any]
  {
    return ["paths": paths, "failed": failed, "unsupported": unsupported]
  }

  // MARK: - Chép file (luồng nền)

  /// Đường dẫn bản sao trong `Documents/Imported`, hoặc nil nếu đuôi lạ / quá lớn / lỗi đọc.
  private static func importFile(_ url: URL) -> String? {
    let ext = url.pathExtension.lowercased()
    guard allowedExtensions.contains(ext) else { return nil }
    let fm = FileManager.default
    guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
      return nil
    }
    let importedDir = docs.appendingPathComponent(importedFolderName, isDirectory: true)
    let source = url.standardizedFileURL

    // Đã nằm trong Documents/Imported (mở từ chính app trong app Tệp): dùng luôn.
    if isWithin(importedDir, source) {
      return source.path
    }

    let scoped = source.startAccessingSecurityScopedResource()
    defer {
      if scoped { source.stopAccessingSecurityScopedResource() }
    }

    var copied: String?
    var coordinatorError: NSError?
    NSFileCoordinator(filePresenter: nil).coordinate(
      readingItemAt: source,
      options: .withoutChanges,
      error: &coordinatorError
    ) { readURL in
      copied = copy(readURL, into: importedDir, ext: ext)
    }
    if copied == nil && coordinatorError != nil {
      // Không phối hợp được (vd. nhà cung cấp file không hỗ trợ): thử chép thẳng.
      copied = copy(source, into: importedDir, ext: ext)
    }

    // iOS chép sẵn file "Mở trong" (bản không in-place) vào Documents/Inbox: dọn đi.
    let inbox = docs.appendingPathComponent("Inbox", isDirectory: true)
    if copied != nil && isWithin(inbox, source) {
      try? fm.removeItem(at: source)
    }
    return copied
  }

  private static func copy(_ source: URL, into dir: URL, ext: String) -> String? {
    let fm = FileManager.default
    guard let attrs = try? fm.attributesOfItem(atPath: source.path),
      (attrs[.type] as? FileAttributeType) == .typeRegular,
      let size = (attrs[.size] as? NSNumber)?.int64Value,
      size <= maxBytes
    else {
      return nil
    }
    do {
      try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    } catch {
      return nil
    }
    let base = safeBaseName(source.deletingPathExtension().lastPathComponent)
    var i = 0
    while i < 10_000 {
      let name = i == 0 ? "\(base).\(ext)" : "\(base) (\(i)).\(ext)"
      let target = dir.appendingPathComponent(name)
      if !fm.fileExists(atPath: target.path) {
        do {
          try fm.copyItem(at: source, to: target)
          return target.path
        } catch {
          return nil
        }
      }
      // Cùng tên và cùng dung lượng: coi như đã nhập trước đó, dùng lại.
      if let existing = (try? fm.attributesOfItem(atPath: target.path))?[.size] as? NSNumber,
        existing.int64Value == size
      {
        return target.path
      }
      i += 1
    }
    return nil
  }

  /// Bỏ ký tự điều khiển / phân cách đường dẫn, cắt độ dài; rỗng thì `file`.
  private static func safeBaseName(_ raw: String) -> String {
    let banned = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters)
    var name = String(raw.unicodeScalars.map { banned.contains($0) ? "_" : Character($0) })
      .trimmingCharacters(in: .whitespacesAndNewlines)
    while name.hasPrefix(".") {
      name.removeFirst()
    }
    if name.count > maxNameLength {
      name = String(name.prefix(maxNameLength))
    }
    return name.isEmpty ? "file" : name
  }

  private static func isWithin(_ dir: URL, _ file: URL) -> Bool {
    let root = dir.standardizedFileURL.resolvingSymlinksInPath().path
    let path = file.standardizedFileURL.resolvingSymlinksInPath().path
    return path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
  }
}

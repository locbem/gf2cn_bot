import 'dart:async';
import 'dart:isolate';

import 'scraper.dart';

/// Chạy [WikiScraper] trong isolate riêng để việc parse/làm sạch ~50MB HTML
/// không làm giật giao diện. Trả về stream tiến độ; phần tử cuối có
/// stage = done hoặc error.
class ScrapeRunner {
  ScrapeRunner._();

  static Stream<ScrapeProgress> run(String outDir) {
    final controller = StreamController<ScrapeProgress>();
    final port = ReceivePort();
    final exitPort = ReceivePort();
    var finished = false;

    void finish([ScrapeProgress? last]) {
      if (finished) return;
      finished = true;
      if (last != null) controller.add(last);
      port.close();
      exitPort.close();
      controller.close();
    }

    port.listen((msg) {
      if (msg is! Map) return;
      final progress = ScrapeProgress.fromMap(msg);
      if (progress.stage == ScrapeStage.done || progress.stage == ScrapeStage.error) {
        finish(progress);
      } else if (!finished) {
        controller.add(progress);
      }
    });
    exitPort.listen((_) {
      // Isolate thoát mà chưa gửi done/error ⇒ coi như lỗi. Chờ một chút để
      // thông điệp done/error (gửi trước khi thoát) kịp được xử lý.
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        finish(const ScrapeProgress(
            ScrapeStage.error, 0, 0, 'Tiến trình tải dữ liệu bị dừng đột ngột'));
      });
    });

    Isolate.spawn<List<Object>>(
      _entry,
      [port.sendPort, outDir],
      onExit: exitPort.sendPort,
      debugName: 'wiki-scraper',
    ).catchError((Object e) {
      finish(ScrapeProgress(ScrapeStage.error, 0, 0, e.toString()));
      return Isolate.current; // giá trị trả về không dùng tới
    });

    return controller.stream;
  }

  static Future<void> _entry(List<Object> args) async {
    final send = args[0] as SendPort;
    final outDir = args[1] as String;
    try {
      final summary = await WikiScraper(outDir: outDir).run(
        onProgress: (p) => send.send(p.toMap()),
      );
      send.send(ScrapeProgress(
        ScrapeStage.done,
        1,
        1,
        summary.failures.isEmpty ? null : '${summary.failures.length} mục tải lỗi (đã bỏ qua)',
      ).toMap());
    } catch (e) {
      send.send(ScrapeProgress(ScrapeStage.error, 0, 0, e.toString()).toMap());
    }
  }
}

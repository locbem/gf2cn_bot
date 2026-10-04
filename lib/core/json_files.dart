import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Encoder dùng chung: JSON thụt lề 2 khoảng trắng, giữ nguyên Unicode
/// (dễ đọc, dễ dịch, diff git rõ ràng).
const JsonEncoder prettyJson = JsonEncoder.withIndent('  ');

List<int> encodeJsonBytes(Object? data) => utf8.encode('${prettyJson.convert(data)}\n');

String md5Hex(List<int> bytes) => md5.convert(bytes).toString();

/// Ghi file JSON an toàn (ghi file tạm rồi đổi tên). Trả về md5 nội dung.
Future<String> writeJsonFile(String path, Object? data) async {
  final bytes = encodeJsonBytes(data);
  await writeBytesAtomic(path, bytes);
  return md5Hex(bytes);
}

Future<void> writeBytesAtomic(String path, List<int> bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  final tmp = File('$path.part');
  await tmp.writeAsBytes(bytes, flush: true);
  if (await file.exists()) await file.delete();
  await tmp.rename(path);
}

/// Đọc JSON từ file; file lớn được parse trong isolate riêng để UI không giật.
Future<dynamic> readJsonFile(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  final length = await file.length();
  try {
    if (length > 300 * 1024) {
      return await Isolate.run(() => jsonDecode(File(path).readAsStringSync()));
    }
    return jsonDecode(await file.readAsString());
  } catch (_) {
    return null;
  }
}

/// Chặn đường dẫn nguy hiểm trong manifest (../, đường dẫn tuyệt đối).
bool isSafeRelativePath(String rel) {
  if (rel.isEmpty || rel.startsWith('/') || rel.startsWith(r'\')) return false;
  if (rel.contains('..') || rel.contains(':')) return false;
  return RegExp(r'^[A-Za-z0-9_\-./]+$').hasMatch(rel);
}

String joinRel(String root, String rel) => p.joinAll([root, ...rel.split('/')]);

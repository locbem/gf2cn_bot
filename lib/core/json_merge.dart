/// Gộp dữ liệu bản dịch (tiếng Việt) lên dữ liệu gốc (tiếng Trung).
///
/// - [base]: dữ liệu nền (tiếng Trung, có thể đã được dịch "xương sống" bằng từ điển).
/// - [tr]: bản dịch trong data/vi.
/// - [orig]: dữ liệu tiếng Trung nguyên bản (cùng cấu trúc với [base]). Giá trị
///   trong [tr] giống hệt [orig] được coi là CHƯA dịch (file chép nguyên từ zh)
///   ⇒ giữ [base] (để bản dịch từ từ điển không bị che mất).
///
/// Quy tắc:
/// - Map: lấy từng khoá của bản gốc, nếu bản dịch có khoá đó thì gộp đệ quy.
/// - List các object có `id` hoặc `key`: ghép theo id (thứ tự theo bản gốc).
/// - List khác: cùng độ dài thì ghép theo vị trí, khác độ dài thì dùng bản dịch
///   (nếu bản dịch không rỗng).
/// - Chuỗi rỗng / null trong bản dịch ⇒ dùng bản gốc (chưa dịch).
dynamic mergeTranslated(dynamic base, dynamic tr, [dynamic orig]) {
  if (tr == null) return base;
  if (base == null) return tr;
  if (base is Map && tr is Map) {
    final o = orig is Map ? orig : null;
    final out = <String, dynamic>{};
    base.forEach((k, v) {
      final key = k.toString();
      out[key] = tr.containsKey(k) ? mergeTranslated(v, tr[k], o?[k]) : v;
    });
    tr.forEach((k, v) {
      final key = k.toString();
      if (!out.containsKey(key)) out[key] = v;
    });
    return out;
  }
  if (base is List && tr is List) {
    if (tr.isEmpty) return base;
    final o = orig is List ? orig : null;
    final idKey = _commonIdKey(base, tr);
    if (idKey != null) {
      final byId = <String, dynamic>{};
      for (final e in tr) {
        byId['${(e as Map)[idKey]}'] = e;
      }
      final origById = <String, dynamic>{};
      if (o != null) {
        for (final e in o) {
          if (e is Map && e[idKey] != null) origById['${e[idKey]}'] = e;
        }
      }
      return [
        for (final e in base)
          mergeTranslated(e, byId['${(e as Map)[idKey]}'], origById['${e[idKey]}']),
      ];
    }
    if (base.length == tr.length) {
      return [
        for (var i = 0; i < base.length; i++)
          mergeTranslated(base[i], tr[i], o != null && i < o.length ? o[i] : null),
      ];
    }
    return tr;
  }
  if (tr is String) {
    if (tr.trim().isEmpty) return base;
    if (orig is String && tr == orig) return base; // chép nguyên từ zh ⇒ chưa dịch
    return tr;
  }
  if (base is Map || base is List) return base; // khác kiểu ⇒ giữ bản gốc
  return tr;
}

/// Khoá định danh ('id' hoặc 'key') có mặt ở MỌI phần tử của cả hai danh sách.
String? _commonIdKey(List a, List b) {
  if (a.isEmpty || b.isEmpty) return null;
  bool allHave(List list, String k) => list.every((e) => e is Map && e[k] != null);
  for (final k in const ['id', 'key']) {
    if (allHave(a, k) && allHave(b, k)) return k;
  }
  return null;
}

// ---- Helpers đọc JSON an toàn ----

String jStr(Object? v) {
  if (v == null) return '';
  if (v is String) return v;
  return v.toString();
}

int jInt(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

List<Map<String, dynamic>> jMapList(Object? v) {
  if (v is! List) return const [];
  return [
    for (final e in v)
      if (e is Map<String, dynamic>)
        e
      else if (e is Map)
        Map<String, dynamic>.from(e),
  ];
}

List<String> jStrList(Object? v) {
  if (v is! List) return const [];
  return [for (final e in v) if (e != null && e.toString().isNotEmpty) e.toString()];
}

Map<String, dynamic> jMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return const <String, dynamic>{};
}

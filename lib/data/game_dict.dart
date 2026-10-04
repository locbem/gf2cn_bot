import '../core/json_merge.dart';

/// Từ điển thuật ngữ game (file `game_dict.json`) dùng để dịch "xương sống"
/// của bản tiếng Việt: tên nhân vật, vũ khí, trang phục, tiêu đề bài, danh mục,
/// bộ lọc, nhãn trong bảng (chỉ số, hình thái...).
///
/// Chỉ dịch khi KHỚP NGUYÊN CỤM (không thay thế chuỗi con giữa câu) để tránh
/// câu lai Trung–Việt. Thứ tự ưu tiên khi hiển thị tiếng Việt:
///   file dịch trong data/vi  >  từ điển này  >  tiếng Trung gốc.
///
/// Cấu trúc file: { "CHAR_NAME": {"中文": "Tiếng Việt", ...}, "ROLE_ID_MAP": {"1": "..."}, ... }
class GameDict {
  GameDict._(this._maps, this._idMaps, this._labels);

  /// Bảng theo tên nhóm (CHAR_NAME, WEAPON_NAME...).
  final Map<String, Map<String, String>> _maps;

  /// Bảng theo id (ROLE_ID_MAP, ATTR_ID_MAP...).
  final Map<String, Map<int, String>> _idMaps;

  /// Hợp nhất mọi bảng nhãn để tra cứu khớp nguyên cụm (bảng đứng trước ưu tiên).
  final Map<String, String> _labels;

  /// Thứ tự ưu tiên khi tra nhãn chung.
  static const List<String> labelPriority = [
    'UI_LABEL_MAP',
    'CATEGORY_VI',
    'ROLE_MAP',
    'ATTR_MAP',
    'TEAM_MAP',
    'WEAPON_TYPE_MAP',
    'RARITY_MAP',
    'STAT_LABELS',
    'REMOULD_HEADERS',
    'REMOULD_FORMS',
    'CHAR_NAME',
    'WEAPON_NAME',
    'COSTUME_NAME',
    'LOCATION_NAME',
    'ITEM_NAME',
    'STORY_TITLE_MAP',
    'WEAPON_SKIN_THEME',
    'TERM_MAP',
    'SKILL_TERM_MAP',
  ];

  /// Bộ lọc trong category.json → bảng id tương ứng trong từ điển.
  static const Map<String, String> filterIdMap = {
    'attr': 'ATTR_ID_MAP',
    'role': 'ROLE_ID_MAP',
    'team': 'TEAM_ID_MAP',
    'type': 'WEAPON_TYPE_ID_MAP',
    'rarity': 'RARITY_ID_MAP',
  };

  int get size => _labels.length;
  bool get isEmpty => _labels.isEmpty && _idMaps.isEmpty;

  static GameDict? tryParse(Object? json) {
    if (json is! Map) return null;
    final maps = <String, Map<String, String>>{};
    final idMaps = <String, Map<int, String>>{};
    json.forEach((k, v) {
      final name = k.toString();
      if (name.startsWith('__') || v is! Map) return;
      if (name.endsWith('_ID_MAP')) {
        idMaps[name] = {
          for (final e in v.entries)
            if (int.tryParse(e.key.toString()) != null && '${e.value}'.trim().isNotEmpty)
              int.parse(e.key.toString()): '${e.value}'.trim(),
        };
      } else {
        maps[name] = {
          for (final e in v.entries)
            if ('${e.key}'.trim().isNotEmpty && '${e.value}'.trim().isNotEmpty)
              '${e.key}'.trim(): '${e.value}'.trim(),
        };
      }
    });
    final labels = <String, String>{};
    final ordered = [
      ...labelPriority.where(maps.containsKey),
      ...maps.keys.where((k) => !labelPriority.contains(k)),
    ];
    for (final name in ordered) {
      for (final e in maps[name]!.entries) {
        labels.putIfAbsent(e.key, () => e.value);
      }
    }
    return GameDict._(maps, idMaps, labels);
  }

  // ------------------------------------------------------------ tra cứu

  String? _inMap(String map, String key) => _maps[map]?[key];

  /// Tra nhãn khớp nguyên cụm (đã trim). Null nếu không có.
  String? label(String zh) {
    final k = zh.trim();
    if (k.isEmpty) return null;
    return _labels[k];
  }

  /// Tra theo bảng ưu tiên trước, rồi tới nhãn chung.
  String? lookup(String zh, [List<String> preferred = const []]) {
    final k = zh.trim();
    if (k.isEmpty) return null;
    for (final m in preferred) {
      final v = _inMap(m, k);
      if (v != null) return v;
    }
    return _labels[k];
  }

  String? byId(String idMap, int id) => _idMaps[idMap]?[id];

  /// Dịch cụm có dấu "·" (vd 寇尔芙·镜刻): khớp nguyên cụm trước,
  /// không có thì dịch từng phần (phần không có trong từ điển giữ nguyên).
  String _compound(String zh, List<String> preferred) {
    final whole = lookup(zh, preferred);
    if (whole != null) return whole;
    if (!zh.contains('·')) return zh;
    final out = <String>[];
    var changed = false;
    for (final part in zh.split('·')) {
      final p = part.trim();
      final v = lookup(p, preferred);
      if (v != null) changed = true;
      out.add(v ?? p);
    }
    return changed ? out.join(' · ') : zh;
  }

  String name(String zh) => _compound(zh, const ['CHAR_NAME']);
  /// Tên vũ khí; "旧式X" chưa có trong từ điển → "<X> Kiểu Cũ" (theo quy ước của từ điển).
  String weapon(String zh) {
    final t = zh.trim();
    final r = _compound(t, const ['WEAPON_NAME']);
    if (r != t || !t.startsWith('旧式')) return r == t ? zh : r;
    final base = _compound(t.substring(2), const ['WEAPON_NAME']);
    return base == t.substring(2) ? zh : '$base Kiểu Cũ';
  }
  String costume(String zh) => _compound(zh, const ['COSTUME_NAME', 'WEAPON_SKIN_THEME']);
  String field(String zh, String map) => lookup(zh, [map]) ?? zh;

  static final RegExp _pvTitle = RegExp(r'^【(.+)】\s*PV$');
  static final RegExp _issue = RegExp(r'^(.*?)第\s*(\d+)\s*期$');
  static final RegExp _charPv = RegExp(r'^(.+?)角色\s*PV$');
  static final RegExp _quoteTitle = RegExp(r'^「(.+)」\s*(.*)$');

  /// Tiêu đề bài / PV / radio.
  String title(String zh) {
    final t = zh.trim();
    if (t.isEmpty) return zh;
    final whole = lookup(t, const ['STORY_TITLE_MAP', 'CATEGORY_VI']);
    if (whole != null) return whole;
    final pv = _pvTitle.firstMatch(t);
    if (pv != null) {
      final inner = title(pv.group(1)!);
      if (inner != pv.group(1)) return 'PV $inner';
    }
    // "莱娅角色PV" → "PV nhân vật Leva"
    final charPv = _charPv.firstMatch(t);
    if (charPv != null) {
      final n = name(charPv.group(1)!.trim());
      if (n != charPv.group(1)!.trim()) return 'PV nhân vật $n';
    }
    // "「女仆的职责」代理人" → "「Bổn phận của hầu gái」Agent"
    final quote = _quoteTitle.firstMatch(t);
    if (quote != null) {
      final q = quote.group(1)!.trim();
      final who = quote.group(2)!.trim();
      final qv = lookup(q, const ['STORY_TITLE_MAP']) ?? q;
      final wv = who.isEmpty ? '' : name(who);
      if (qv != q || wv != who) return '「$qv」${wv.isEmpty ? '' : ' $wv'}';
    }
    final issue = _issue.firstMatch(t);
    if (issue != null) {
      final head = issue.group(1)!.trim();
      final h = head.isEmpty ? '' : title(head);
      return '${h.isEmpty ? '' : '$h - '}Số ${issue.group(2)}';
    }
    return _compound(t, const ['STORY_TITLE_MAP', 'CATEGORY_VI']);
  }

  // ------------------------------------------------------------ HTML

  static final RegExp _textNode = RegExp(r'>([^<>]+)<');
  static final RegExp _edges = RegExp(r'^((?:\s|&nbsp;|\u00a0)*)(.*?)((?:\s|&nbsp;|\u00a0)*)$', dotAll: true);

  /// Dịch các đoạn chữ trong HTML khi CẢ đoạn khớp một mục trong từ điển
  /// (vd ô bảng "攻击：", "显像形态", tên người nói "伊格蕾塔：" trong truyện).
  String html(String html) {
    if (html.isEmpty) return html;
    return html.replaceAllMapped(_textNode, (m) {
      final r = _text(m.group(1)!);
      return r == null ? m.group(0)! : '>$r<';
    });
  }

  String? _text(String raw) {
    final m = _edges.firstMatch(raw);
    if (m == null) return null;
    var core = m.group(2)!;
    if (core.isEmpty || core.length > 40) return null;
    var colon = false;
    if (core.endsWith('：') || core.endsWith(':')) {
      colon = true;
      core = core.substring(0, core.length - 1).trimRight();
    }
    final v = label(core) ?? (core.contains('·') ? _maybeCompound(core) : null);
    if (v == null) return null;
    return '${m.group(1)}$v${colon ? ': ' : ''}${m.group(3)}';
  }

  String? _maybeCompound(String core) {
    final r = _compound(core, const ['CHAR_NAME', 'COSTUME_NAME', 'STORY_TITLE_MAP']);
    return r == core ? null : r;
  }

  // ------------------------------------------------------------ dữ liệu

  /// Áp từ điển lên một file dữ liệu (theo đường dẫn tương đối trong data/zh).
  /// Không sửa [json] gốc – trả về bản sao đã dịch.
  dynamic apply(String rel, dynamic json) {
    if (json is! Map) return json;
    final m = jMap(json);
    if (rel == 'category.json') return _category(m);
    if (rel == 'dolls.json') return _items(m, _doll);
    if (rel.startsWith('dolls/')) return _doll(m);
    if (rel == 'weapons.json') return _items(m, _weapon);
    if (rel == 'world.json') return _items(m, _worldIndex);
    if (rel.startsWith('world/')) return _world(m);
    if (rel == 'media.json') return _items(m, _media);
    return json;
  }

  Map<String, dynamic> _items(Map<String, dynamic> m, Map<String, dynamic> Function(Map<String, dynamic>) f) =>
      {...m, 'items': [for (final e in jMapList(m['items'])) f(e)]};

  Map<String, dynamic> _category(Map<String, dynamic> m) => {
        ...m,
        'sections': [
          for (final s in jMapList(m['sections']))
            {
              ...s,
              'name': field(jStr(s['name']), 'CATEGORY_VI'),
              'tabs': [for (final t in jMapList(s['tabs'])) _tab(t)],
            },
        ],
      };

  Map<String, dynamic> _tab(Map<String, dynamic> t) => {
        ...t,
        'name': field(jStr(t['name']), 'CATEGORY_VI'),
        if (t['filters'] is List) 'filters': [for (final f in jMapList(t['filters'])) _filter(f)],
      };

  Map<String, dynamic> _filter(Map<String, dynamic> f) {
    final idMap = filterIdMap[jStr(f['key'])] ?? '';
    String tr(String zh, int id) => byId(idMap, id) ?? lookup(zh) ?? zh;
    return {
      ...f,
      'name': tr(jStr(f['name']), 0),
      'options': [
        for (final o in jMapList(f['options'])) {...o, 'name': tr(jStr(o['name']), jInt(o['id']))},
      ],
    };
  }

  static const List<String> _htmlDollFields = [
    'cv', 'prop', 'battle_skill', 'remoulding', 'weapon_desc', 'development', 'story', //
  ];

  String _term(String zh, List<String> preferred) => lookup(zh, preferred) ?? zh;

  List<Map<String, dynamic>> _namedList(Object? v) => [
        for (final e in jMapList(v))
          {
            ...e,
            'name': _term(jStr(e['name']), const ['TERM_MAP', 'SKILL_TERM_MAP']),
            'html': html(jStr(e['html'])),
          },
      ];

  Map<String, dynamic> _doll(Map<String, dynamic> d) {
    final out = <String, dynamic>{...d};
    final zhName = jStr(d['name']);
    if (zhName.isNotEmpty) {
      out['name'] = name(zhName);
      out['name_zh'] = zhName;
    }
    if (d.containsKey('weapon')) out['weapon'] = weapon(jStr(d['weapon']));
    if (d.containsKey('team')) out['team'] = field(jStr(d['team']), 'TEAM_MAP');
    if (d.containsKey('role')) out['role'] = field(jStr(d['role']), 'ROLE_MAP');
    if (d.containsKey('attr')) out['attr'] = field(jStr(d['attr']), 'ATTR_MAP');
    if (d.containsKey('rarity')) out['rarity'] = field(jStr(d['rarity']), 'RARITY_MAP');
    if (d.containsKey('ammo_model')) {
      final a = jStr(d['ammo_model']);
      out['ammo_model'] = lookup(a, const ['WEAPON_TYPE_MAP', 'UI_LABEL_MAP']) ?? a;
    }
    if (d['skins'] is List) {
      out['skins'] = [
        for (final s in jMapList(d['skins'])) {...s, 'name': costume(jStr(s['name']))},
      ];
    }
    for (final k in _htmlDollFields) {
      if (d[k] is String) out[k] = html(d[k] as String);
    }
    for (final k in const ['skills', 'talents', 'gifts', 'gallery']) {
      if (d[k] is List) out[k] = _namedList(d[k]);
    }
    return out;
  }

  Map<String, dynamic> _weapon(Map<String, dynamic> w) {
    final zhName = jStr(w['name']);
    return {
      ...w,
      'name': weapon(zhName),
      'name_zh': zhName,
      if (w['base_info'] is String) 'base_info': html(w['base_info'] as String),
      if (w['character'] is String) 'character': html(w['character'] as String),
    };
  }

  String _chapter(String zh) => lookup(zh, const ['STORY_TITLE_MAP', 'SKILL_TERM_MAP']) ?? title(zh);

  Map<String, dynamic> _worldIndex(Map<String, dynamic> w) {
    final zhTitle = jStr(w['title']);
    return {
      ...w,
      'title': title(zhTitle),
      'title_zh': zhTitle,
      'chapters': [for (final c in jStrList(w['chapters'])) _chapter(c)],
    };
  }

  Map<String, dynamic> _world(Map<String, dynamic> w) {
    final zhTitle = jStr(w['title']);
    return {
      ...w,
      'title': title(zhTitle),
      'title_zh': zhTitle,
      'chapters': [
        for (final c in jMapList(w['chapters']))
          {
            ...c,
            'name': _chapter(jStr(c['name'])),
            'parts': [
              for (final p in jMapList(c['parts']))
                {
                  ...p,
                  'name': _term(jStr(p['name']), const ['SKILL_TERM_MAP', 'TERM_MAP']),
                  'html': html(jStr(p['html'])),
                },
            ],
          },
      ],
    };
  }

  Map<String, dynamic> _media(Map<String, dynamic> m) {
    final zhTitle = jStr(m['title']);
    return {
      ...m,
      'title': title(zhTitle),
      'title_zh': zhTitle,
      'html': html(jStr(m['html'])),
    };
  }

  // ------------------------------------------------------------ thống kê

  /// Các giá trị chưa có trong từ điển (dùng cho lệnh `dict-missing`).
  Map<String, Set<String>> missing({
    required Iterable<Map<String, dynamic>> dolls,
    required Iterable<Map<String, dynamic>> weapons,
    required Iterable<Map<String, dynamic>> world,
    required Iterable<Map<String, dynamic>> media,
  }) {
    final out = <String, Set<String>>{
      'CHAR_NAME': {},
      'WEAPON_NAME': {},
      'COSTUME_NAME': {},
      'TEAM_MAP': {},
      'STORY_TITLE_MAP': {},
    };
    for (final d in dolls) {
      final n = jStr(d['name']);
      if (n.isNotEmpty && name(n) == n) out['CHAR_NAME']!.add(n);
      final w = jStr(d['weapon']);
      if (w.isNotEmpty && weapon(w) == w) out['WEAPON_NAME']!.add(w);
      final t = jStr(d['team']);
      if (t.isNotEmpty && field(t, 'TEAM_MAP') == t) out['TEAM_MAP']!.add(t);
      for (final s in jMapList(d['skins'])) {
        final c = jStr(s['name']);
        if (c.isNotEmpty && costume(c) == c) out['COSTUME_NAME']!.add(c);
      }
    }
    for (final w in weapons) {
      final n = jStr(w['name']);
      if (n.isNotEmpty && weapon(n) == n) out['WEAPON_NAME']!.add(n);
    }
    for (final w in [...world, ...media]) {
      final t = jStr(w['title']);
      if (t.isNotEmpty && title(t) == t) out['STORY_TITLE_MAP']!.add(t);
    }
    return out;
  }
}

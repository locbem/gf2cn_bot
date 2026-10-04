import '../core/html_clean.dart';
import '../core/json_merge.dart';

/// Chuyển dữ liệu thô của API wiki sang format JSON gọn, ổn định của app.
/// Format này cũng là format bạn dịch sang tiếng Việt (xem docs/TRANSLATION.md).
class Normalizer {
  Normalizer._();

  static String _h(Object? v) => HtmlCleaner.clean(v);
  static String _url(Object? v) {
    final s = jStr(v).trim();
    return s.isEmpty ? '' : HtmlCleaner.absoluteUrl(s);
  }

  // ---------------------------------------------------------------- category

  static const Map<int, String> _filterKey = {
    2: 'attr',
    3: 'role',
    4: 'team',
    5: 'type',
    6: 'rarity',
  };
  static const Map<int, String> _filterField = {
    2: 'attr_id',
    3: 'role_id',
    4: 'team_id',
    5: 'type',
    6: 'rarity',
  };

  /// Cấu trúc:
  /// ```
  /// {schema, sections: [{key, name, tabs: [{key, name, id?, cid?, filters?}]}]}
  /// ```
  static Map<String, dynamic> category(Map<String, dynamic> raw) {
    final info = jMapList(raw['information']);
    Map<String, dynamic>? byType(int t) {
      for (final e in info) {
        if (jInt(e['type']) == t) return e;
      }
      return null;
    }

    final handbookTabs = <Map<String, dynamic>>[];
    for (final t in jMapList(byType(3)?['title'])) {
      final sub = jInt(t['sub_type'], jInt(t['id']));
      final key = sub == 1 ? 'dolls' : (sub == 2 ? 'weapons' : null);
      if (key == null) continue;
      final filters = <Map<String, dynamic>>[];
      for (final op in jMapList(t['options'])) {
        final opType = jInt(op['op_type']);
        filters.add({
          'key': _filterKey[opType] ?? 'op$opType',
          'field': _filterField[opType] ?? 'op$opType',
          'name': jStr(op['op_name']),
          'options': [
            for (final o in jMapList(op['list']))
              if (jInt(o['id']) != 0) {'id': jInt(o['id']), 'name': jStr(o['name'])},
          ],
        });
      }
      handbookTabs.add({'key': key, 'id': jInt(t['id']), 'name': jStr(t['name']), 'filters': filters});
    }
    if (handbookTabs.isEmpty) {
      handbookTabs.addAll([
        {'key': 'dolls', 'id': 1, 'name': '人形介绍', 'filters': <Object>[]},
        {'key': 'weapons', 'id': 2, 'name': '武器介绍', 'filters': <Object>[]},
      ]);
    }

    List<Map<String, dynamic>> simpleTabs(int type, String prefix, List<String> fallback) {
      final list = jMapList(byType(type)?['title']);
      if (list.isEmpty) {
        return [
          for (var i = 0; i < fallback.length; i++)
            {'key': '${prefix}_${i + 1}', 'cid': i + 1, 'name': fallback[i]},
        ];
      }
      return [
        for (final t in list)
          {'key': '${prefix}_${jInt(t['id'])}', 'cid': jInt(t['id']), 'name': jStr(t['name'])},
      ];
    }

    return {
      'schema': 1,
      'sections': [
        {'key': 'handbook', 'name': '游戏图鉴', 'tabs': handbookTabs},
        {
          'key': 'world',
          'name': '世界设定',
          'tabs': simpleTabs(1, 'world', const ['追放剧情', '其他设定']),
        },
        {
          'key': 'news',
          'name': '其他资讯',
          'tabs': simpleTabs(2, 'news', const ['角色PV合集', '版本PV合集', '北兰岛避难所广播', '壁纸合集']),
        },
      ],
    };
  }

  // ------------------------------------------------------------------ dolls

  static Map<String, String> _pcMobile(Object? v) {
    final m = jMap(v);
    return {'pc': _url(m['pc']), 'mobile': _url(m['mobile'])};
  }

  static List<Map<String, dynamic>> _named(Object? v) => [
        for (final e in jMapList(v))
          {'name': jStr(e['name']).trim(), 'html': _h(e['desc'])},
      ];

  static List<Map<String, dynamic>> _voices(Object? v) => [
        for (final e in jMapList(v))
          if (_url(e['voice_doc']).isNotEmpty || jStr(e['speech']).isNotEmpty)
            {
              'id': jInt(e['id']),
              'title': jStr(e['title']).trim(),
              'text': jStr(e['speech']).trim(),
              'url': _url(e['voice_doc']),
            },
      ];

  static int rarityLevelOf(String rarity) {
    if (rarity.isEmpty) return 0;
    if (rarity.contains('精英') || rarity.contains('5')) return 5;
    return 4;
  }

  /// [l] là phần tử trong /wiki/handbook, [d] là /wiki/hero_detail.info (có thể null nếu lỗi).
  static Map<String, dynamic> doll(Map<String, dynamic> l, Map<String, dynamic>? d) {
    final det = d ?? const <String, dynamic>{};
    final rarity = jStr(det['rarity']).trim();
    final name = jStr(det['name']).trim();
    return {
      'id': jInt(l['hero_id'], jInt(det['hero_id'])),
      'name': name.isNotEmpty ? name : jStr(l['hero_name']).trim(),
      'en_name': jStr(det['en_name']).trim(),
      'pic': _url(l['pic']),
      'icon': jInt(l['icon']),
      'sort': jInt(l['sort']),
      'attr_id': jInt(l['attribute']),
      'role_id': jInt(l['role']),
      'team_id': jInt(l['team']),
      'rarity_level': rarityLevelOf(rarity),
      'rarity': rarity,
      'role': jStr(det['role']).trim(),
      'attr': jStr(det['attr']).trim(),
      'team': jStr(det['team']).trim(),
      'weapon': jStr(det['weapon']).trim(),
      'model': jStr(det['model']).trim(),
      'ammo_model': jStr(det['ammo_model']).trim(),
      'desc': jStr(det['desc']).replaceAll('\r\n', '\n').trim(),
      'portrait': _pcMobile(det['portrait']),
      'modeling': _pcMobile(det['modeling']),
      'skins': [
        for (final s in jMapList(det['skin']))
          {
            'id': jInt(s['id']),
            'name': jStr(s['skin_name']).trim(),
            'pc': _url(s['portrait_pc']),
            'mobile': _url(s['portrait_mobile']),
          },
      ],
      'gifs': [for (final g in jStrList(det['gif_pic'])) _url(g)],
      'cv': _h(det['cv']),
      'prop': _h(det['prop']),
      'skills': _named(det['skill']),
      'battle_skill': _h(det['battle_skill']),
      'talents': _named(det['talent']),
      'remoulding': _h(det['remoulding']),
      'weapon_desc': _h(det['weapon_desc']),
      'development': _h(det['hero_development']),
      'story': _h(det['story']),
      'gifts': _named(det['gift']),
      'gallery': _named(det['hero_profile']),
      'voices': _voices(det['voice']),
      'battle_voices': _voices(det['voice_battle']),
    };
  }

  static const List<String> dollIndexKeys = [
    'id', 'name', 'en_name', 'pic', 'icon', 'sort', 'attr_id', 'role_id', 'team_id', //
    'rarity_level', 'rarity', 'role', 'attr', 'team', 'weapon',
  ];

  static Map<String, dynamic> dollIndexEntry(Map<String, dynamic> doll) => {
        for (final k in dollIndexKeys)
          if (doll.containsKey(k)) k: doll[k],
      };

  // ---------------------------------------------------------------- weapons

  static Map<String, dynamic> weapon(Map<String, dynamic> l, Map<String, dynamic>? d) {
    final det = d ?? const <String, dynamic>{};
    final name = jStr(det['name']).trim();
    return {
      'id': jInt(l['weapon_id']),
      'name': name.isNotEmpty ? name : jStr(l['weapon_name']).trim(),
      'pic': _url(l['pic']),
      'icon': jInt(l['icon']),
      'type': jInt(l['weapon_type']),
      'rarity': jInt(l['weapon_rarity']),
      'belong_hero': jInt(l['belong_hero']),
      'base_info': _h(det['base_info']),
      'character': _h(det['character']),
    };
  }

  // ----------------------------------------------------------- world (世界设定)

  static Map<String, dynamic> world(Map<String, dynamic> l, Map<String, dynamic>? d, int cid) {
    final det = d ?? const <String, dynamic>{};
    final title = jStr(det['title']).trim().isNotEmpty ? jStr(det['title']).trim() : jStr(l['title']).trim();
    final catalog = jStrList(det['catalog']);
    final desc = det['catalog_desc'] is List ? det['catalog_desc'] as List : const [];
    final chapters = <Map<String, dynamic>>[];
    for (var i = 0; i < catalog.length; i++) {
      final raw = i < desc.length ? desc[i] : null;
      final parts = <Map<String, dynamic>>[];
      final partList = raw is List ? jMapList(raw) : (raw is Map ? [jMap(raw)] : const <Map<String, dynamic>>[]);
      for (final pt in partList) {
        final html = _h(pt['desc']);
        if (html.isEmpty) continue;
        parts.add({'name': jStr(pt['name']).trim(), 'html': html});
      }
      if (parts.isEmpty) continue;
      chapters.add({'name': catalog[i].trim(), 'parts': parts});
    }
    if (chapters.isEmpty) {
      final content = jStr(det['content']).trim();
      if (content.isNotEmpty && content != title) {
        final html = _h(content);
        if (html.isNotEmpty) {
          chapters.add({
            'name': title,
            'parts': [
              {'name': '', 'html': html},
            ],
          });
        }
      }
    }
    return {
      'id': jInt(l['id'], jInt(det['id'])),
      'cid': cid,
      'title': title,
      'cover': _url(det['cover'] ?? l['cover']),
      'sort': jInt(l['sort']),
      'chapters': chapters,
    };
  }

  static Map<String, dynamic> worldIndexEntry(Map<String, dynamic> w) => {
        'id': w['id'],
        'cid': w['cid'],
        'title': w['title'],
        'cover': w['cover'],
        'sort': w['sort'],
        'chapters': [for (final c in jMapList(w['chapters'])) jStr(c['name'])],
      };

  // --------------------------------------------------------- media (其他资讯)

  static Map<String, dynamic> media(Map<String, dynamic> l, int cid) => {
        'id': jInt(l['id']),
        'cid': cid,
        'title': jStr(l['title']).trim(),
        'cover': _url(l['cover']),
        'sort': jInt(l['sort']),
        'html': _h(l['content']),
      };
}

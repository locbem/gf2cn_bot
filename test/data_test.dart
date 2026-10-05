import 'package:flutter_test/flutter_test.dart';
import 'package:gf2_wiki/core/html_clean.dart';
import 'package:gf2_wiki/core/json_merge.dart';
import 'package:gf2_wiki/data/game_dict.dart';
import 'package:gf2_wiki/data/normalize.dart';
import 'package:gf2_wiki/data/translation_sync.dart';

void main() {
  group('HtmlCleaner', () {
    test('bỏ style rác, giữ màu nổi bật', () {
      const raw = '<p class="MsoNormal" style="padding-left: 40px; font-size: 14pt; mso-bidi-font-weight: bold;">'
          '<span lang="EN-US" style="color: #ffffff;">Xin chào</span> '
          '<span style="color: #ff9900;">80%</span></p><p>&nbsp;</p><!--[endif]-->';
      final out = HtmlCleaner.clean(raw);
      expect(out, '<p>Xin chào <span style="color: #ff9900">80%</span></p>');
    });

    test('ảnh lớn bỏ kích thước, icon nhỏ giữ kích thước', () {
      final out = HtmlCleaner.clean(
          '<p><img src="//cdn.x/a.png" width="592" height="333"><sub><img src="http://cdn.x/i.png" width="20" height="20"></sub>攻击</p>');
      expect(out, contains('<img src="https://cdn.x/a.png">'));
      expect(out, contains('<img src="https://cdn.x/i.png" width="20" height="20">'));
    });

    test('bảng giữ border và rowspan', () {
      final out = HtmlCleaner.clean(
          '<table style="width: 99%;" border="1"><colgroup><col width="72"></colgroup><tbody>'
          '<tr><td rowspan="2" style="text-align: center; height: 20px;">A</td><td colspan="1">B</td></tr></tbody></table>');
      expect(out, contains('<table border="1">'));
      expect(out, contains('<td rowspan="2" style="text-align: center">A</td>'));
      expect(out, contains('<td>B</td>'));
      expect(out, isNot(contains('colgroup')));
    });

    test('văn bản thuần → đoạn văn', () {
      expect(HtmlCleaner.clean('dòng 1\r\ndòng 2'), '<p>dòng 1</p>\n<p>dòng 2</p>');
    });

    test('nội dung rỗng', () {
      expect(HtmlCleaner.clean('<p>&nbsp;</p><p><br></p>'), '');
      expect(HtmlCleaner.clean(null), '');
    });
  });

  group('mergeTranslated', () {
    test('ghép theo id, chuỗi rỗng dùng bản gốc', () {
      final zh = {
        'items': [
          {'id': 1, 'name': '物理', 'pic': 'a.png'},
          {'id': 2, 'name': '燃烧', 'pic': 'b.png'},
        ],
      };
      final vi = {
        'items': [
          {'id': 2, 'name': 'Thiêu đốt'},
          {'id': 1, 'name': ''},
        ],
      };
      final m = mergeTranslated(zh, vi) as Map;
      final items = m['items'] as List;
      expect(items[0], {'id': 1, 'name': '物理', 'pic': 'a.png'});
      expect(items[1], {'id': 2, 'name': 'Thiêu đốt', 'pic': 'b.png'});
    });

    test('danh sách không id cùng độ dài ghép theo vị trí', () {
      final zh = [
        {'name': '技能1', 'html': '<p>中文</p>'},
        {'name': '技能2', 'html': '<p>中文2</p>'},
      ];
      final vi = [
        {'name': 'Kỹ năng 1'},
        {'name': '', 'html': '<p>Tiếng Việt 2</p>'},
      ];
      final m = mergeTranslated(zh, vi) as List;
      expect(m[0], {'name': 'Kỹ năng 1', 'html': '<p>中文</p>'});
      expect(m[1], {'name': '技能2', 'html': '<p>Tiếng Việt 2</p>'});
    });

    test('không có bản dịch', () {
      expect(mergeTranslated({'a': 1}, null), {'a': 1});
    });
  });

  group('Normalizer', () {
    test('category: tab & bộ lọc', () {
      final cat = Normalizer.category({
        'information': [
          {
            'type': 1,
            'title': [
              {'id': 1, 'name': '追放剧情'},
            ],
          },
          {
            'type': 3,
            'title': [
              {
                'id': 1,
                'name': '人形介绍',
                'sub_type': 1,
                'options': [
                  {
                    'op_type': 2,
                    'op_name': '异位属性',
                    'list': [
                      {'id': 0, 'name': '异位属性'},
                      {'id': 1, 'name': '物理'},
                    ],
                  },
                ],
              },
            ],
          },
        ],
      });
      final sections = cat['sections'] as List;
      expect(sections.length, 3);
      final handbook = sections[0] as Map;
      final dolls = (handbook['tabs'] as List)[0] as Map;
      expect(dolls['key'], 'dolls');
      final filter = (dolls['filters'] as List)[0] as Map;
      expect(filter['key'], 'attr');
      expect(filter['field'], 'attr_id');
      expect((filter['options'] as List).length, 1);
      final world = sections[1] as Map;
      expect(((world['tabs'] as List)[0] as Map)['cid'], 1);
    });

    test('world: catalog → chapters', () {
      final w = Normalizer.world(
        {'id': '85', 'title': 'T', 'cover': '', 'sort': '0'},
        {
          'title': 'T',
          'catalog': ['剧情点1', '1-1'],
          'catalog_desc': [
            [
              {'name': '剧情点1', 'desc': '<p>A</p>'},
            ],
            [
              {'name': '关卡前', 'desc': '<p>B</p>'},
              {'name': '关卡后', 'desc': '<p>C</p>'},
            ],
          ],
        },
        1,
      );
      expect(w['id'], 85);
      final chapters = w['chapters'] as List;
      expect(chapters.length, 2);
      expect(((chapters[1] as Map)['parts'] as List).length, 2);
    });
  });

  group('GameDict', () {
    final dict = GameDict.tryParse({
      'CHAR_NAME': {'寇尔芙': 'Colphne', '伊格蕾塔': 'Eagletta', '寇尔芙·镜刻': 'Colphne Doppelganger'},
      'WEAPON_NAME': {'黑棘': 'Black Thorn'},
      'ROLE_MAP': {'支援': 'Support', '职业': 'Nghề nghiệp'},
      'TERM_MAP': {'支援': 'chi viện', '心智螺旋': 'Neural Helix'},
      'STAT_LABELS': {'攻击': 'Tấn công'},
      'STORY_TITLE_MAP': {
        '静默突触': 'Tiếp hợp vô thanh',
        '伊利昂之围': 'Trận Chiến Thành Troy',
        '女仆的职责': 'Bổn phận của hầu gái',
      },
      'CATEGORY_VI': {'北兰岛避难所广播': 'Đài phát thanh khu trú ẩn Bắc Lan Đảo', '人形介绍': 'Giới thiệu T-Doll'},
      'SKILL_TERM_MAP': {'下篇': 'Hạ'},
      'ROLE_ID_MAP': {'0': 'Nghề nghiệp', '3': 'Support'},
      '__scope__': {'ROLE_MAP': 'label'},
    })!;

    test('tên ghép và ưu tiên bảng', () {
      expect(dict.name('寇尔芙·镜刻'), 'Colphne Doppelganger');
      expect(dict.name('寇尔芙·未知'), 'Colphne · 未知');
      expect(dict.name('不存在'), '不存在');
      expect(dict.lookup('支援', const ['ROLE_MAP']), 'Support');
      expect(dict.label('支援'), 'Support'); // ROLE_MAP đứng trước TERM_MAP
    });

    test('tiêu đề PV / radio / phần', () {
      expect(dict.title('【静默突触】PV'), 'PV Tiếp hợp vô thanh');
      expect(dict.title('伊格蕾塔角色PV'), 'PV nhân vật Eagletta');
      expect(dict.title('「女仆的职责」 伊格蕾塔'), '「Bổn phận của hầu gái」 Eagletta');
      expect(dict.title('北兰岛避难所广播第35期'), 'Đài phát thanh khu trú ẩn Bắc Lan Đảo - Số 35');
      expect(dict.title('伊利昂之围·下篇'), 'Trận Chiến Thành Troy · Hạ');
    });

    test('HTML: chỉ dịch đoạn khớp nguyên cụm', () {
      final out = dict.html('<td><strong>攻击：</strong>690</td><p><strong>伊格蕾塔：</strong>晚上好，托卡列夫。</p>');
      expect(out, '<td><strong>Tấn công: </strong>690</td><p><strong>Eagletta: </strong>晚上好，托卡列夫。</p>');
    });

    test('áp lên file dữ liệu + gộp bản dịch chép nguyên', () {
      final zh = {
        'id': 1084,
        'name': '寇尔芙·镜刻',
        'role': '支援',
        'weapon': '黑棘',
        'talents': [
          {'name': '心智螺旋', 'html': '<p>x</p>'},
        ],
      };
      final base = dict.apply('dolls/1084.json', zh) as Map;
      expect(base['name'], 'Colphne Doppelganger');
      expect(base['name_zh'], '寇尔芙·镜刻');
      expect(base['role'], 'Support');
      expect(base['weapon'], 'Black Thorn');
      expect(zh['name'], '寇尔芙·镜刻'); // bản gốc không bị sửa
      // file vi chép nguyên từ zh (chưa dịch) không che bản dịch từ từ điển
      final vi = {...zh, 'role': 'Hỗ trợ'};
      final merged = mergeTranslated(base, vi, zh) as Map;
      expect(merged['name'], 'Colphne Doppelganger');
      expect(merged['role'], 'Hỗ trợ');
    });

    test('mẫu: nhãn + số, cụm A/B, mẫu câu, chi phí nghề, thẻ bị tách', () {
      final d = GameDict.tryParse({
        'STAT_LABELS': {'生命': 'HP', '攻击': 'Tấn công'},
        'UI_LABEL_MAP': {'稳态伤害': 'Sát thương ổn định', '手枪': 'HG', '日常': 'Thường ngày'},
        'ITEM_NAME': {'轻型弹': 'Light Ammo'},
        'ROLE_MAP': {'防卫': 'Bulwark', '支援': 'Support'},
        'TERM_MAP': {'主动': 'Chủ động', '好感度': 'Affinity'},
        'SKILL_TERM_MAP': {'范围': 'diện rộng'},
        'TEMPLATE_MAP': {'造成伤害提高{n}%。': 'Sát thương gây ra tăng {n}%.'},
      })!;
      expect(d.html('<td><strong>生</strong><strong>命：</strong>1965</td>'), '<td><strong>HP: </strong>1965</td>');
      expect(d.short('稳态伤害：3'), 'Sát thương ổn định: 3');
      expect(d.short('主动 / 范围'), 'Chủ động / Diện rộng');
      expect(d.short('手枪/轻型弹'), 'HG / Light Ammo');
      expect(d.short('造成伤害提高 5% 。'), 'Sát thương gây ra tăng 5%.');
      expect(d.short('防卫x3，支援x18'), 'Bulwark ×3, Support ×18');
      expect(d.short('攻击174【60级】'), 'Tấn công 174 (Lv.60)');
      expect(d.short('日常-01'), 'Thường ngày - 01');
      expect(d.short('+75%好感度'), '+75% Affinity');
      expect(d.short('晚上好，托卡列夫。'), isNull);
    });

    test('category: bộ lọc theo bảng id', () {
      final cat = dict.apply('category.json', {
        'sections': [
          {
            'key': 'handbook',
            'name': '游戏图鉴',
            'tabs': [
              {
                'key': 'dolls',
                'name': '人形介绍',
                'filters': [
                  {
                    'key': 'role',
                    'field': 'role_id',
                    'name': '职业',
                    'options': [
                      {'id': 3, 'name': '支援'},
                    ],
                  },
                ],
              },
            ],
          },
        ],
      }) as Map;
      final tab = ((cat['sections'] as List)[0]['tabs'] as List)[0] as Map;
      expect(tab['name'], 'Giới thiệu T-Doll');
      final f = (tab['filters'] as List)[0] as Map;
      expect(f['name'], 'Nghề nghiệp');
      expect(((f['options'] as List)[0] as Map)['name'], 'Support');
    });
  });

  test('GithubSource.normalizeRepo', () {
    expect(GithubSource.normalizeRepo('https://github.com/locbem/gf2cn_bot.git'), 'locbem/gf2cn_bot');
    expect(GithubSource.normalizeRepo('locbem/gf2cn_bot/'), 'locbem/gf2cn_bot');
    const src = GithubSource(repo: 'locbem/gf2cn_bot', branch: 'main', path: '/data/vi/');
    expect(src.baseUrls.first, 'https://raw.githubusercontent.com/locbem/gf2cn_bot/main/data/vi/');
  });
}

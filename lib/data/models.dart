import '../core/json_merge.dart';

class FilterOption {
  const FilterOption(this.id, this.name);
  final int id;
  final String name;
}

class FilterDef {
  FilterDef({required this.key, required this.field, required this.name, required this.options});

  final String key;
  final String field;
  final String name;
  final List<FilterOption> options;

  String? optionName(int id) {
    for (final o in options) {
      if (o.id == id) return o.name;
    }
    return null;
  }

  factory FilterDef.fromJson(Map<String, dynamic> j) => FilterDef(
        key: jStr(j['key']),
        field: jStr(j['field']),
        name: jStr(j['name']),
        options: [for (final o in jMapList(j['options'])) FilterOption(jInt(o['id']), jStr(o['name']))],
      );
}

class CatTab {
  CatTab({required this.key, required this.name, required this.id, required this.cid, required this.filters});

  final String key;
  final String name;
  final int id;
  final int cid;
  final List<FilterDef> filters;

  FilterDef? filter(String key) {
    for (final f in filters) {
      if (f.key == key) return f;
    }
    return null;
  }

  factory CatTab.fromJson(Map<String, dynamic> j) => CatTab(
        key: jStr(j['key']),
        name: jStr(j['name']),
        id: jInt(j['id']),
        cid: jInt(j['cid']),
        filters: [for (final f in jMapList(j['filters'])) FilterDef.fromJson(f)],
      );
}

class CatSection {
  CatSection({required this.key, required this.name, required this.tabs});

  final String key;
  final String name;
  final List<CatTab> tabs;

  factory CatSection.fromJson(Map<String, dynamic> j) => CatSection(
        key: jStr(j['key']),
        name: jStr(j['name']),
        tabs: [for (final t in jMapList(j['tabs'])) CatTab.fromJson(t)],
      );
}

class CategoryData {
  CategoryData(this.sections);

  final List<CatSection> sections;

  CatSection? section(String key) {
    for (final s in sections) {
      if (s.key == key) return s;
    }
    return null;
  }

  CatTab? tab(String key) {
    for (final s in sections) {
      for (final t in s.tabs) {
        if (t.key == key) return t;
      }
    }
    return null;
  }

  factory CategoryData.fromJson(Map<String, dynamic> j) =>
      CategoryData([for (final s in jMapList(j['sections'])) CatSection.fromJson(s)]);
}

class DollSummary {
  DollSummary({
    required this.id,
    required this.name,
    required this.enName,
    required this.pic,
    required this.icon,
    required this.attrId,
    required this.roleId,
    required this.teamId,
    required this.rarityLevel,
    required this.rarity,
    required this.role,
    required this.attr,
    required this.team,
    required this.weapon,
    this.nameZh = '',
  });

  final int id;
  final String name;

  /// Tên tiếng Trung gốc (khi đang xem tiếng Việt) – dùng cho tìm kiếm.
  final String nameZh;
  final String enName;
  final String pic;
  final int icon;
  final int attrId;
  final int roleId;
  final int teamId;
  final int rarityLevel;
  final String rarity;
  final String role;
  final String attr;
  final String team;
  final String weapon;

  int field(String f) => switch (f) {
        'attr_id' => attrId,
        'role_id' => roleId,
        'team_id' => teamId,
        'rarity_level' => rarityLevel,
        _ => -1,
      };

  factory DollSummary.fromJson(Map<String, dynamic> j) => DollSummary(
        id: jInt(j['id']),
        name: jStr(j['name']),
        enName: jStr(j['en_name']),
        pic: jStr(j['pic']),
        icon: jInt(j['icon']),
        attrId: jInt(j['attr_id']),
        roleId: jInt(j['role_id']),
        teamId: jInt(j['team_id']),
        rarityLevel: jInt(j['rarity_level']),
        rarity: jStr(j['rarity']),
        role: jStr(j['role']),
        attr: jStr(j['attr']),
        team: jStr(j['team']),
        weapon: jStr(j['weapon']),
        nameZh: jStr(j['name_zh']),
      );
}

class NamedHtml {
  const NamedHtml(this.name, this.html);
  final String name;
  final String html;

  static List<NamedHtml> listFrom(Object? v) => [
        for (final e in jMapList(v)) NamedHtml(jStr(e['name']), jStr(e['html'])),
      ];
}

class Voice {
  const Voice({required this.id, required this.title, required this.text, required this.url});
  final int id;
  final String title;
  final String text;
  final String url;

  static List<Voice> listFrom(Object? v) => [
        for (final e in jMapList(v))
          Voice(id: jInt(e['id']), title: jStr(e['title']), text: jStr(e['text']), url: jStr(e['url'])),
      ];
}

class Skin {
  const Skin({required this.id, required this.name, required this.pc, required this.mobile});
  final int id;
  final String name;
  final String pc;
  final String mobile;
}

class PcMobile {
  const PcMobile(this.pc, this.mobile);
  final String pc;
  final String mobile;

  bool get isEmpty => pc.isEmpty && mobile.isEmpty;
  String get any => mobile.isNotEmpty ? mobile : pc;

  static PcMobile from(Object? v) {
    final m = jMap(v);
    return PcMobile(jStr(m['pc']), jStr(m['mobile']));
  }
}

class DollDetail {
  DollDetail({
    required this.summary,
    required this.model,
    required this.ammoModel,
    required this.desc,
    required this.portrait,
    required this.modeling,
    required this.skins,
    required this.gifs,
    required this.cv,
    required this.prop,
    required this.skills,
    required this.battleSkill,
    required this.talents,
    required this.remoulding,
    required this.weaponDesc,
    required this.development,
    required this.story,
    required this.gifts,
    required this.gallery,
    required this.voices,
    required this.battleVoices,
  });

  final DollSummary summary;
  final String model;
  final String ammoModel;
  final String desc;
  final PcMobile portrait;
  final PcMobile modeling;
  final List<Skin> skins;
  final List<String> gifs;
  final String cv;
  final String prop;
  final List<NamedHtml> skills;
  final String battleSkill;
  final List<NamedHtml> talents;
  final String remoulding;
  final String weaponDesc;
  final String development;
  final String story;
  final List<NamedHtml> gifts;
  final List<NamedHtml> gallery;
  final List<Voice> voices;
  final List<Voice> battleVoices;

  factory DollDetail.fromJson(Map<String, dynamic> j) => DollDetail(
        summary: DollSummary.fromJson(j),
        model: jStr(j['model']),
        ammoModel: jStr(j['ammo_model']),
        desc: jStr(j['desc']),
        portrait: PcMobile.from(j['portrait']),
        modeling: PcMobile.from(j['modeling']),
        skins: [
          for (final s in jMapList(j['skins']))
            Skin(id: jInt(s['id']), name: jStr(s['name']), pc: jStr(s['pc']), mobile: jStr(s['mobile'])),
        ],
        gifs: jStrList(j['gifs']),
        cv: jStr(j['cv']),
        prop: jStr(j['prop']),
        skills: NamedHtml.listFrom(j['skills']),
        battleSkill: jStr(j['battle_skill']),
        talents: NamedHtml.listFrom(j['talents']),
        remoulding: jStr(j['remoulding']),
        weaponDesc: jStr(j['weapon_desc']),
        development: jStr(j['development']),
        story: jStr(j['story']),
        gifts: NamedHtml.listFrom(j['gifts']),
        gallery: NamedHtml.listFrom(j['gallery']),
        voices: Voice.listFrom(j['voices']),
        battleVoices: Voice.listFrom(j['battle_voices']),
      );
}

class Weapon {
  Weapon({
    required this.id,
    required this.name,
    required this.pic,
    required this.icon,
    required this.type,
    required this.rarity,
    required this.belongHero,
    required this.baseInfo,
    required this.character,
    this.nameZh = '',
  });

  final int id;
  final String name;
  final String nameZh;
  final String pic;
  final int icon;
  final int type;
  final int rarity;
  final int belongHero;
  final String baseInfo;
  final String character;

  int field(String f) => switch (f) {
        'type' => type,
        'rarity' => rarity,
        _ => -1,
      };

  factory Weapon.fromJson(Map<String, dynamic> j) => Weapon(
        id: jInt(j['id']),
        name: jStr(j['name']),
        pic: jStr(j['pic']),
        icon: jInt(j['icon']),
        type: jInt(j['type']),
        rarity: jInt(j['rarity']),
        belongHero: jInt(j['belong_hero']),
        baseInfo: jStr(j['base_info']),
        character: jStr(j['character']),
        nameZh: jStr(j['name_zh']),
      );
}

class WorldSummary {
  WorldSummary({
    required this.id,
    required this.cid,
    required this.title,
    required this.cover,
    required this.chapters,
    this.titleZh = '',
  });

  final int id;
  final int cid;
  final String title;
  final String titleZh;
  final String cover;
  final List<String> chapters;

  factory WorldSummary.fromJson(Map<String, dynamic> j) => WorldSummary(
        id: jInt(j['id']),
        cid: jInt(j['cid']),
        title: jStr(j['title']),
        cover: jStr(j['cover']),
        chapters: jStrList(j['chapters']),
        titleZh: jStr(j['title_zh']),
      );
}

class WorldChapter {
  WorldChapter(this.name, this.parts);
  final String name;
  final List<NamedHtml> parts;
}

class WorldDetail {
  WorldDetail({required this.id, required this.cid, required this.title, required this.cover, required this.chapters});

  final int id;
  final int cid;
  final String title;
  final String cover;
  final List<WorldChapter> chapters;

  factory WorldDetail.fromJson(Map<String, dynamic> j) => WorldDetail(
        id: jInt(j['id']),
        cid: jInt(j['cid']),
        title: jStr(j['title']),
        cover: jStr(j['cover']),
        chapters: [
          for (final c in jMapList(j['chapters'])) WorldChapter(jStr(c['name']), NamedHtml.listFrom(c['parts'])),
        ],
      );
}

class MediaItem {
  MediaItem({
    required this.id,
    required this.cid,
    required this.title,
    required this.cover,
    required this.html,
    this.titleZh = '',
  });

  final int id;
  final int cid;
  final String title;
  final String titleZh;
  final String cover;
  final String html;

  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
        id: jInt(j['id']),
        cid: jInt(j['cid']),
        title: jStr(j['title']),
        cover: jStr(j['cover']),
        html: jStr(j['html']),
        titleZh: jStr(j['title_zh']),
      );
}

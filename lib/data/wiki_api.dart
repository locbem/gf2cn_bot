import '../core/json_merge.dart';
import '../core/net.dart';

/// Các endpoint của wiki chính thức (khảo sát từ app.js của trang wiki).
///
/// Tất cả đều là POST JSON tới https://gf2-bbs-api.exiliumgf.com
/// - /wiki/category                      → cây danh mục + bộ lọc
/// - /wiki/handbook {type:1|2}            → danh sách nhân vật / vũ khí
/// - /wiki/hero_detail {id}               → chi tiết nhân vật
/// - /wiki/weapon_detail {id}             → chi tiết vũ khí
/// - /wiki/information {type, cid}        → danh sách bài (1: thiết lập thế giới, 2: tư liệu khác)
/// - /wiki/info_detail {id, type}         → chi tiết bài
class WikiApi {
  WikiApi(this.net);

  final Net net;

  Future<Map<String, dynamic>> category() => net.postWiki('/wiki/category');

  Future<List<Map<String, dynamic>>> handbook(int type) async {
    final data = await net.postWiki('/wiki/handbook', {
      'type': type,
      'hero_param': {'attr': 0, 'role': 0, 'team': 0},
      'weapon_param': {'type': 0, 'rarity': 0},
    });
    return jMapList(data['list']);
  }

  Future<Map<String, dynamic>> heroDetail(int id) async =>
      jMap((await net.postWiki('/wiki/hero_detail', {'id': id}))['info']);

  Future<Map<String, dynamic>> weaponDetail(int id) async =>
      jMap((await net.postWiki('/wiki/weapon_detail', {'id': id}))['info']);

  Future<List<Map<String, dynamic>>> information(int type, int cid) async {
    final data = await net.postWiki('/wiki/information', {'type': type, 'cid': cid});
    return jMapList(data['list']);
  }

  Future<Map<String, dynamic>> infoDetail(int id, int type) async =>
      jMap((await net.postWiki('/wiki/info_detail', {'id': id, 'type': type}))['info']);
}

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import 'html_content.dart';

/// Khối nội dung có tiêu đề, thu gọn/mở rộng được.
/// Nội dung chỉ được dựng khi mở → trang chi tiết dài vẫn mượt.
class SectionCard extends StatefulWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.builder,
    this.initiallyExpanded = true,
    this.trailing,
    this.isEmpty = false,
  });

  final String title;
  final WidgetBuilder builder;
  final bool initiallyExpanded;
  final Widget? trailing;

  /// Không có dữ liệu → hiện "Đang cập nhật" và không cho mở.
  final bool isEmpty;

  @override
  State<SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<SectionCard> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final empty = widget.isEmpty;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: empty ? null : () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 16,
                    decoration: BoxDecoration(
                      color: empty ? AppColors.textFaint : AppColors.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (empty)
                    Text(s.t('in_progress'), style: const TextStyle(fontSize: 12.5, color: AppColors.textFaint))
                  else ...[
                    if (widget.trailing != null) widget.trailing!,
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.expand_more_rounded, color: AppColors.textDim),
                    ),
                  ],
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: (_open && !empty)
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: widget.builder(context),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
        ),
      ),
    );
  }
}

/// Khối HTML đơn giản trong SectionCard.
class HtmlSection extends StatelessWidget {
  const HtmlSection({super.key, required this.title, required this.html, this.initiallyExpanded = true});

  final String title;
  final String html;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: title,
        isEmpty: html.trim().isEmpty,
        initiallyExpanded: initiallyExpanded,
        builder: (_) => HtmlContent(html),
      );
}

/// Danh sách mục có tên (kỹ năng, quà tặng...) – chọn bằng chip, hiển thị 1 mục.
class NamedHtmlSwitcher extends StatefulWidget {
  const NamedHtmlSwitcher({super.key, required this.items, this.iconCells = false});

  final List<NamedHtml> items;

  /// Bảng kỹ năng / Neural Helix: ô ảnh đầu hàng là icon (cỡ đều nhau).
  final bool iconCells;

  @override
  State<NamedHtmlSwitcher> createState() => _NamedHtmlSwitcherState();
}

class _NamedHtmlSwitcherState extends State<NamedHtmlSwitcher> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final index = _index.clamp(0, items.length - 1).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (items.length > 1)
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => ChoiceChip(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                label: Text(items[i].name.isEmpty ? '#${i + 1}' : items[i].name),
                selected: i == index,
                onSelected: (_) => setState(() => _index = i),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                  color: i == index ? AppColors.accent : AppColors.text,
                ),
                side: BorderSide(color: i == index ? AppColors.accent : AppColors.line),
              ),
            ),
          )
        else if (items.first.name.isNotEmpty)
          Text(items.first.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accentSoft)),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topLeft,
            children: [...previous, if (current != null) current],
          ),
          child: KeyedSubtree(
            key: ValueKey(index),
            child: HtmlContent(items[index].html, iconCells: widget.iconCells),
          ),
        ),
      ],
    );
  }
}

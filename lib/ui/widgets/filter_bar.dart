import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../state/app_controller.dart';
import '../theme.dart';

/// Ô tìm kiếm + các bộ lọc dạng chip (mỗi chip mở menu chọn giá trị).
class FilterBar extends StatefulWidget {
  const FilterBar({
    super.key,
    required this.filters,
    required this.selected,
    required this.onFilterChanged,
    required this.onQueryChanged,
    required this.hint,
    this.colorOf,
    this.resultCount,
  });

  final List<FilterDef> filters;
  final Map<String, int> selected;
  final void Function(String key, int? id) onFilterChanged;
  final ValueChanged<String> onQueryChanged;
  final String hint;

  /// Màu riêng cho từng giá trị của một bộ lọc (vd: thuộc tính).
  final Color? Function(String filterKey, int id)? colorOf;
  final int? resultCount;

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  final TextEditingController _text = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _onText(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () => widget.onQueryChanged(v.trim()));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final hasFilter = widget.selected.values.any((v) => v != 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _text,
          onChanged: _onText,
          textInputAction: TextInputAction.search,
          decoration: searchDecoration(
            widget.hint,
            suffix: _text.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _text.clear();
                      _onText('');
                    },
                  ),
          ),
        ),
        if (widget.filters.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final f in widget.filters) ...[
                  _FilterChipMenu(
                    filter: f,
                    value: widget.selected[f.key] ?? 0,
                    allLabel: s.t('all'),
                    colorOf: widget.colorOf,
                    onSelected: (id) => widget.onFilterChanged(f.key, id == 0 ? null : id),
                  ),
                  const SizedBox(width: 8),
                ],
                if (hasFilter)
                  ActionChip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.filter_alt_off_outlined, size: 16, color: AppColors.textDim),
                    label: Text(s.t('clear_filters')),
                    onPressed: () {
                      for (final f in widget.filters) {
                        widget.onFilterChanged(f.key, null);
                      }
                    },
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _FilterChipMenu extends StatelessWidget {
  const _FilterChipMenu({
    required this.filter,
    required this.value,
    required this.allLabel,
    required this.onSelected,
    this.colorOf,
  });

  final FilterDef filter;
  final int value;
  final String allLabel;
  final ValueChanged<int> onSelected;
  final Color? Function(String filterKey, int id)? colorOf;

  @override
  Widget build(BuildContext context) {
    final active = value != 0;
    final name = active ? (filter.optionName(value) ?? filter.name) : filter.name;
    final color = active ? (colorOf?.call(filter.key, value) ?? AppColors.accent) : AppColors.textDim;
    return PopupMenuButton<int>(
      tooltip: filter.name,
      initialValue: value,
      position: PopupMenuPosition.under,
      color: AppColors.cardHigh,
      constraints: const BoxConstraints(minWidth: 160, maxHeight: 420),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem<int>(value: 0, child: Text(allLabel)),
        for (final o in filter.options)
          PopupMenuItem<int>(
            value: o.id,
            child: Row(
              children: [
                if (colorOf?.call(filter.key, o.id) != null) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: colorOf!.call(filter.key, o.id), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    o.name,
                    style: TextStyle(
                      fontWeight: o.id == value ? FontWeight.w700 : FontWeight.w400,
                      color: o.id == value ? AppColors.accent : AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.only(left: 12, right: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.14) : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? color.withValues(alpha: 0.7) : AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? color : AppColors.text,
              ),
            ),
            Icon(Icons.arrow_drop_down_rounded, color: active ? color : AppColors.textDim),
          ],
        ),
      ),
    );
  }
}

/// Giữ trạng thái tab (cuộn, bộ lọc) khi chuyển qua lại trong TabBarView.
class KeepAliveTab extends StatefulWidget {
  const KeepAliveTab({super.key, required this.child});

  final Widget child;

  @override
  State<KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<KeepAliveTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

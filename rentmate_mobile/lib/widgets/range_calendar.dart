import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import 'ui.dart';

/// Chọn ngày nhận – ngày trả (mẫu "Reserve Date"): bảng trượt có lịch tháng,
/// ngày đầu và ngày cuối là chấm tròn màu chính, các ngày ở giữa tô nhạt.
Future<DateTimeRange?> showRangeCalendar(
  BuildContext context, {
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initial,
}) {
  return showModalBottomSheet<DateTimeRange>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: _RangeCalendar(firstDate: firstDate, lastDate: lastDate, initial: initial),
    ),
  );
}

class _RangeCalendar extends StatefulWidget {
  final DateTime firstDate, lastDate;
  final DateTimeRange? initial;
  const _RangeCalendar({required this.firstDate, required this.lastDate, this.initial});

  @override
  State<_RangeCalendar> createState() => _RangeCalendarState();
}

class _RangeCalendarState extends State<_RangeCalendar> {
  late DateTime? _start = widget.initial?.start;
  late DateTime? _end = widget.initial?.end;
  late DateTime _month = DateTime((_start ?? widget.firstDate).year, (_start ?? widget.firstDate).month);

  bool get _canPrev => _month.isAfter(DateTime(widget.firstDate.year, widget.firstDate.month));
  bool get _canNext => _month.isBefore(DateTime(widget.lastDate.year, widget.lastDate.month));

  void _tap(DateTime day) {
    setState(() {
      // Chưa chọn, hoặc đã chọn đủ 2 ngày, hoặc bấm ngày trước ngày đầu: chọn lại ngày đầu
      if (_start == null || _end != null || day.isBefore(_start!)) {
        _start = day;
        _end = null;
      } else {
        _end = day;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final firstWeekday = loc.firstDayOfWeekIndex; // 0 = Chủ nhật
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final offset = (DateTime(_month.year, _month.month).weekday % 7 - firstWeekday) % 7;
    final cells = <DateTime?>[
      for (var i = 0; i < offset; i++) null,
      for (var d = 1; d <= daysInMonth; d++) DateTime(_month.year, _month.month, d),
    ];
    final days = _start == null ? 0 : (_end ?? _start!).difference(_start!).inDays + 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(pagePadding, 0, pagePadding, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tr('Chọn ngày thuê'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          Row(
            children: [
              const IconCircle(Icons.calendar_month_outlined, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _start == null
                          ? tr('Chọn ngày nhận')
                          : _end == null
                          ? tr('Chọn ngày trả')
                          : '${fmtDate(_start!)} → ${fmtDate(_end!)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      days == 0 ? tr('Bấm ngày nhận rồi bấm ngày trả') : tr('{0} ngày', [days]),
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
          Row(
            children: [
              Expanded(
                child: Text(
                  loc.formatMonthYear(_month),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
              _arrow(Icons.chevron_left_rounded, _canPrev, -1),
              const SizedBox(width: 12),
              _arrow(Icons.chevron_right_rounded, _canNext, 1),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      loc.narrowWeekdays[(i + firstWeekday) % 7],
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
            ],
          ),
          const Padding(padding: EdgeInsets.only(top: 12, bottom: 8), child: Divider()),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [for (final d in cells) d == null ? const SizedBox() : _day(d)],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _start == null
                  ? null
                  : () => Navigator.pop(context, DateTimeRange(start: _start!, end: _end ?? _start!)),
              child: Text(tr('Lưu')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrow(IconData icon, bool enabled, int delta) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: enabled ? () => setState(() => _month = DateTime(_month.year, _month.month + delta)) : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: enabled ? AppColors.ink : AppColors.border, width: 1.5),
        ),
        child: Icon(icon, size: 20, color: enabled ? AppColors.ink : AppColors.border),
      ),
    );
  }

  Widget _day(DateTime d) {
    final disabled = d.isBefore(widget.firstDate) || d.isAfter(widget.lastDate);
    final isEdge = (_start != null && DateUtils.isSameDay(d, _start)) || (_end != null && DateUtils.isSameDay(d, _end));
    final inside = _start != null && _end != null && d.isAfter(_start!) && d.isBefore(_end!);
    return GestureDetector(
      onTap: disabled ? null : () => _tap(d),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isEdge ? AppColors.primary : (inside ? const Color(0xFFE6E6E6) : null),
        ),
        alignment: Alignment.center,
        child: Text(
          '${d.day}',
          style: TextStyle(
            fontSize: 16,
            color: isEdge ? Colors.white : (disabled ? const Color(0xFFBFC3C9) : AppColors.ink),
            fontWeight: isEdge ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

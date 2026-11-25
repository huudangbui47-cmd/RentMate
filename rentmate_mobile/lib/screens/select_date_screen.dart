import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/config_service.dart';
import '../services/item_service.dart';
import '../theme.dart';
import '../widgets/kit.dart';

/// Chọn ngày nhận – ngày trả, theo khung "Select Date" (Figma 1:8246).
/// RentMate thuê theo ngày nên bỏ 2 thanh kéo giờ của mẫu, thay bằng dòng tóm tắt số ngày và tiền thuê.
class SelectDateScreen extends StatefulWidget {
  final DateTimeRange? initial;
  final num Function(int days)? rentFor; // có thì hiện tạm tính tiền thuê (đã trừ ưu đãi)
  const SelectDateScreen({super.key, this.initial, this.rentFor});

  /// Mở màn hình, trả về khoảng ngày đã chọn (null nếu quay lại).
  static Future<DateTimeRange?> open(BuildContext context, {DateTimeRange? initial, num Function(int)? rentFor}) =>
      Navigator.of(context).push<DateTimeRange>(
        MaterialPageRoute(
          builder: (_) => SelectDateScreen(initial: initial, rentFor: rentFor),
        ),
      );

  @override
  State<SelectDateScreen> createState() => _SelectDateScreenState();
}

class _SelectDateScreenState extends State<SelectDateScreen> {
  final _today = DateUtils.dateOnly(DateTime.now());
  late DateTime? _start = widget.initial?.start;
  late DateTime? _end = widget.initial?.end;
  late DateTime _month = DateTime((_start ?? _today).year, (_start ?? _today).month);

  // Khớp giới hạn của Api: bắt đầu trong N ngày tới, mỗi đơn tối đa M ngày
  DateTime get _lastStart => _today.add(Duration(days: AppConfig.maxDaysAhead));
  DateTime get _lastDay => _today.add(Duration(days: AppConfig.maxDaysAhead + AppConfig.maxRentalDays - 1));

  bool get _canPrev => _month.isAfter(DateTime(_today.year, _today.month));
  bool get _canNext => _month.isBefore(DateTime(_lastDay.year, _lastDay.month));

  int get _days => _start == null ? 0 : (_end ?? _start!).difference(_start!).inDays + 1;

  bool _disabled(DateTime d) {
    if (d.isBefore(_today) || d.isAfter(_lastDay)) return true;
    // Đang chọn ngày trả: không quá số ngày tối đa của một đơn
    if (_start != null && _end == null && !d.isBefore(_start!)) {
      return d.difference(_start!).inDays + 1 > AppConfig.maxRentalDays;
    }
    return d.isAfter(_lastStart) && (_start == null || _end != null);
  }

  void _tap(DateTime d) {
    setState(() {
      if (_start == null || _end != null || d.isBefore(_start!)) {
        _start = d;
        _end = null;
      } else {
        _end = d;
      }
    });
  }

  String _dayLabel(DateTime d) {
    final loc = MaterialLocalizations.of(context);
    // "10 thg 8, T5" / "10 Aug, Thu" theo ngôn ngữ đang dùng
    return '${loc.formatShortMonthDay(d)}, ${loc.narrowWeekdays[d.weekday % 7]}';
  }

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final first = loc.firstDayOfWeekIndex;
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final offset = (DateTime(_month.year, _month.month).weekday % 7 - first) % 7;
    // Đủ 6 hàng như mẫu: ngày tháng trước/sau mờ 10%
    final firstCell = DateTime(_month.year, _month.month, 1 - offset);
    final rows = ((offset + daysInMonth) / 7).ceil();
    final cells = [for (var i = 0; i < rows * 7; i++) DateTime(firstCell.year, firstCell.month, firstCell.day + i)];

    return Scaffold(
      appBar: RcAppBar(title: Text(tr('Chọn ngày thuê'))),
      body: Column(
        children: [
          // Ngày nhận / ngày trả như "Pickup / Return" của mẫu: nhãn xám, khung viền bo tròn chứa viên xám có icon lịch
          RcCard(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(tr('Ngày nhận'), style: kText(15, FontWeight.w300, color: AppColors.muted)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(tr('Ngày trả'), style: kText(15, FontWeight.w300, color: AppColors.muted)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _edge(_start, active: _start == null || _end != null)),
                    const SizedBox(width: 12),
                    Expanded(child: _edge(_end, active: _start != null && _end == null)),
                  ],
                ),
                if (_start != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() {
                        _start = null;
                        _end = null;
                      }),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        padding: const EdgeInsets.only(top: 6),
                      ),
                      child: Text(
                        tr('Chọn lại'),
                        style: kText(14, FontWeight.w400, decoration: TextDecoration.underline),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: RcCard(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: EdgeInsets.zero,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                children: [
                  // Ô tháng: mũi tên hai bên, tên tháng xanh ở giữa
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(24)),
                    child: Row(
                      children: [
                        _arrow('cal_prev', _canPrev, -1),
                        Expanded(
                          child: Text(
                            _capitalize(loc.formatMonthYear(_month)),
                            textAlign: TextAlign.center,
                            style: kText(15, FontWeight.w500, lh: 23, tracking: -0.01),
                          ),
                        ),
                        _arrow('cal_next', _canNext, 1),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: Center(
                              child: Text(
                                loc.narrowWeekdays[(i + first) % 7],
                                style: kText(14, FontWeight.w300, lh: 24, color: AppColors.muted),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  for (var r = 0; r < rows; r++)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(children: [for (var c = 0; c < 7; c++) Expanded(child: _cell(cells[r * 7 + c], c))]),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Thanh đáy trắng bo góc trên: tóm tắt + nút Lưu
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            padding: EdgeInsets.fromLTRB(18, 16, 18, 12 + MediaQuery.of(context).padding.bottom),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(tr('Số ngày thuê'), style: kText(13, FontWeight.w300, lh: 20, color: AppColors.muted)),
                    const Spacer(),
                    Text(_days == 0 ? '-' : tr('{0} ngày', [_days]), style: kText(14, FontWeight.w500, lh: 20)),
                  ],
                ),
                if (widget.rentFor != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(tr('Tạm tính tiền thuê'), style: kText(13, FontWeight.w300, lh: 20, color: AppColors.muted)),
                      const Spacer(),
                      Text(
                        _days == 0 ? '-' : formatVnd(widget.rentFor!(_days)),
                        style: kText(17, FontWeight.w600, lh: 22),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: KitButton(
                    tr('Lưu'),
                    onPressed: _start == null
                        ? null
                        : () => Navigator.pop(context, DateTimeRange(start: _start!, end: _end ?? _start!)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // Khung viền bo tròn chứa viên xám: icon lịch + ngày. Khung đang chờ chọn có viền đen.
  Widget _edge(DateTime? d, {required bool active}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: active ? AppColors.ink : AppColors.border, width: active ? 1.4 : 1),
      ),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(24)),
        child: Row(
          children: [
            const Icon(Icons.event_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                d == null ? tr('Chọn ngày') : _dayLabel(d),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kText(14, FontWeight.w400, color: d == null ? AppColors.muted : AppColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _band(bool on, {bool left = false, bool right = false}) {
    if (!on) return const SizedBox();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.horizontal(
          left: left ? const Radius.circular(24) : Radius.zero,
          right: right ? const Radius.circular(24) : Radius.zero,
        ),
      ),
    );
  }

  Widget _arrow(String icon, bool enabled, int delta) {
    return GestureDetector(
      onTap: enabled
          ? () => setState(() {
              _month = DateTime(_month.year, _month.month + delta);
            })
          : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.3,
        child: Icon(delta < 0 ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, size: 26),
      ),
    );
  }

  Widget _cell(DateTime d, int col) {
    final inMonth = d.month == _month.month;
    final disabled = !inMonth || _disabled(d);
    final isStart = _start != null && DateUtils.isSameDay(d, _start);
    final isEnd = _end != null && DateUtils.isSameDay(d, _end);
    final edge = isStart || isEnd;
    final inside = _start != null && _end != null && d.isAfter(_start!) && d.isBefore(_end!);
    final hasRange = _start != null && _end != null && !DateUtils.isSameDay(_start, _end);
    return GestureDetector(
      onTap: disabled ? null : () => _tap(d),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Dải xám nối ngày đầu – ngày cuối (mẫu: #F8F8F8)
            if (inMonth && (inside || (hasRange && edge)))
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Nửa trái / nửa phải ô; đầu và cuối hàng bo tròn như mẫu
                    Expanded(child: _band(inside || isEnd, left: col == 0 || d.day == 1)),
                    Expanded(
                      child: _band(
                        inside || isStart,
                        right: col == 6 || d.day == DateUtils.getDaysInMonth(d.year, d.month),
                      ),
                    ),
                  ],
                ),
              ),
            if (edge && inMonth)
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              ),
            Text(
              '${d.day}',
              style: kText(
                15,
                edge || inside ? FontWeight.w500 : FontWeight.w300,
                lh: 24,
                color: edge && inMonth
                    ? Colors.white
                    : disabled
                    ? AppColors.ink.withValues(alpha: 0.1)
                    : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

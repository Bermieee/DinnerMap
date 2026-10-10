import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/planner_repository.dart';
import '../../layout/adaptive_layout.dart';
import '../../layout/adaptive_page.dart';
import 'models.dart';
import 'planner_calendar.dart';
import 'planner_day_detail.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  final PlannerSnapshot snapshot;
  const PlannerScreen({super.key, required this.snapshot});
  @override
  ConsumerState<PlannerScreen> createState() => _PlannerState();
}

class _PlannerState extends ConsumerState<PlannerScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selected = dateOnly(DateTime.now());
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final policy = AdaptiveLayout.resolve(
        size: constraints.biggest,
        padding: EdgeInsets.zero,
        displayFeatures: media.displayFeatures,
        textScale: media.textScaler.scale(1),
      );
      final calendar = PlannerCalendar(
        key: const ValueKey('planner-calendar'),
        snapshot: widget.snapshot,
        month: month,
        selected: selected,
        onSelected: (date) => setState(() => selected = date),
        onMonthChanged: (date) => setState(() => month = date),
      );
      final detail = PlannerDayDetail(
        key: const ValueKey('planner-day-detail'),
        snapshot: widget.snapshot,
        selected: selected,
        month: month,
      );
      final scale = math.max(1.0, media.textScaler.scale(1));
      final secondRegion = policy.secondaryRegion;
      final canSplit =
          policy.canSplitCalendar &&
          (secondRegion == null
              ? math.min(constraints.maxWidth, 1440.0) - 24 >= 880 * scale + 24
              : policy.primaryRegion.width - 16 >= 560 * scale &&
                    secondRegion.width - 16 >= 320 * scale);
      if (canSplit) {
        final second = policy.secondaryRegion;
        if (second != null) {
          return Stack(
            children: [
              Positioned.fromRect(
                rect: policy.primaryRegion,
                child: ListView(
                  key: const PageStorageKey('calendar-pane'),
                  padding: const EdgeInsets.all(8),
                  children: [calendar],
                ),
              ),
              Positioned.fromRect(
                rect: second,
                child: ListView(
                  key: const PageStorageKey('detail-pane'),
                  padding: const EdgeInsets.all(8),
                  children: [detail],
                ),
              ),
            ],
          );
        }
        final width = math.min(constraints.maxWidth, 1440.0);
        return Center(
          child: SizedBox(
            width: width,
            child: ListView(
              key: const PageStorageKey('planner-scroll'),
              padding: const EdgeInsets.all(12),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: calendar),
                    const SizedBox(width: 24),
                    Expanded(flex: 4, child: detail),
                  ],
                ),
              ],
            ),
          ),
        );
      }
      return AdaptivePage(
        child: ListView(
          key: const PageStorageKey('planner-scroll'),
          padding: const EdgeInsets.all(12),
          children: [calendar, const SizedBox(height: 16), detail],
        ),
      );
    },
  );
}

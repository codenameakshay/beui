import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiAvailabilityScheduler] — toggle days, add/remove time
/// ranges, and copy a day's hours to others.
Widget availabilitySchedulerDemo(BuildContext context) =>
    const _AvailabilitySchedulerDemo();

class _AvailabilitySchedulerDemo extends StatefulWidget {
  const _AvailabilitySchedulerDemo();

  @override
  State<_AvailabilitySchedulerDemo> createState() =>
      _AvailabilitySchedulerDemoState();
}

class _AvailabilitySchedulerDemoState
    extends State<_AvailabilitySchedulerDemo> {
  BeuiWeekAvailability _week = beuiDefaultWeek();

  int get _enabledDays => _week.values.where((d) => d.enabled).length;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 576),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Weekly availability',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$_enabledDays of 7 days available',
                style: TextStyle(fontSize: 13, color: colors.mutedForeground),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colors.card,
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: BeuiAvailabilityScheduler(
                  value: _week,
                  onChanged: (next) => setState(() => _week = next),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

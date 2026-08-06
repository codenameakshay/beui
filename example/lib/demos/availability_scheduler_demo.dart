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

  // Mirrors `availability-scheduler.preview.tsx`: a full-width centering row
  // holding a bare `<AvailabilityScheduler />` — no heading, no card chrome.
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: BeuiAvailabilityScheduler(
        value: _week,
        onChanged: (next) => setState(() => _week = next),
      ),
    ),
  );
}

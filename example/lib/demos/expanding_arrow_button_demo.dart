import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for the expanding-arrow CTA suite — expanding, hold, and
/// slide variants, matching the source previews.
Widget expandingArrowButtonDemo(BuildContext context) =>
    const _ExpandingArrowButtonDemo();

class _ExpandingArrowButtonDemo extends StatefulWidget {
  const _ExpandingArrowButtonDemo();

  @override
  State<_ExpandingArrowButtonDemo> createState() =>
      _ExpandingArrowButtonDemoState();
}

class _ExpandingArrowButtonDemoState extends State<_ExpandingArrowButtonDemo> {
  String _status = '';

  void _flash(String message) {
    setState(() => _status = message);
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _status == message) setState(() => _status = '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Expanding arrow',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              BeuiExpandingArrowButton(
                onPressed: () => _flash('Demo booked'),
                child: const Text('Book a demo'),
              ),
              const SizedBox(height: 36),
              Text(
                'Hold action',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              BeuiHoldActionButton(
                onHoldComplete: () => _flash('Vertical hold confirmed'),
                child: const Text('Hold for vertical fill'),
              ),
              const SizedBox(height: 12),
              BeuiHoldActionButton(
                direction: BeuiHoldActionDirection.horizontal,
                onHoldComplete: () => _flash('Horizontal hold confirmed'),
                child: const Text('Hold for horizontal fill'),
              ),
              const SizedBox(height: 36),
              Text(
                'Slide action',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              BeuiSlideActionButton(
                completeLabel: const Text('Ready'),
                onComplete: () => _flash('Slide completed'),
                child: const Text('Slide to continue'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 16,
                child: Text(
                  _status.isEmpty ? ' ' : _status,
                  style: TextStyle(fontSize: 12, color: colors.mutedForeground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

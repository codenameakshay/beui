import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiAnimatedToastStack] — mirrors the source demo:
/// buttons that push status toasts, a loading→success flow, an action toast,
/// with the stack anchored bottom-right.
Widget animatedToastStackDemo(BuildContext context) =>
    const _AnimatedToastStackDemo();

class _AnimatedToastStackDemo extends StatefulWidget {
  const _AnimatedToastStackDemo();

  @override
  State<_AnimatedToastStackDemo> createState() =>
      _AnimatedToastStackDemoState();
}

class _AnimatedToastStackDemoState extends State<_AnimatedToastStackDemo> {
  final BeuiToastController _toasts = BeuiToastController(limit: 6);
  int _n = 0;

  @override
  void dispose() {
    _toasts.dispose();
    super.dispose();
  }

  void _basic() => _toasts.show(
    title: 'Event #${++_n} logged',
    description: 'Nothing to do — just letting you know.',
  );

  void _success() => _toasts.show(
    title: 'Payment sent',
    description: 'Your transfer is on its way.',
    status: BeuiToastStatus.success,
  );

  void _error() => _toasts.show(
    title: 'Upload failed',
    description: 'The connection dropped mid-flight.',
    status: BeuiToastStatus.error,
    action: BeuiToastAction(
      label: 'Retry',
      onPressed: (toast) => _toasts.update(
        toast.id,
        title: 'Retrying…',
        status: BeuiToastStatus.loading,
        duration: const Duration(seconds: 2),
      ),
    ),
  );

  Future<void> _flow() async {
    final id = _toasts.show(
      title: 'Deploying…',
      description: 'Building and shipping to production.',
      status: BeuiToastStatus.loading,
      duration: Duration.zero, // sticky while loading
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    _toasts.update(
      id,
      title: 'Deployed',
      description: 'Live in 2.1s.',
      status: BeuiToastStatus.success,
      duration: const Duration(milliseconds: 3200),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              BeuiButton(onPressed: _basic, child: const Text('Neutral')),
              BeuiButton(onPressed: _success, child: const Text('Success')),
              BeuiButton(
                onPressed: _error,
                child: const Text('Error + action'),
              ),
              BeuiButton(
                onPressed: _flow,
                child: const Text('Loading → success'),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 24,
          left: 16,
          child: Align(
            alignment: Alignment.bottomRight,
            child: ListenableBuilder(
              listenable: _toasts,
              builder: (context, _) => BeuiAnimatedToastStack(
                toasts: _toasts.toasts,
                onDismiss: _toasts.dismiss,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

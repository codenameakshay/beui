import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiCard].
Widget cardDemo(BuildContext context) => const _CardDemo();

class _CardDemo extends StatefulWidget {
  const _CardDemo();

  @override
  State<_CardDemo> createState() => _CardDemoState();
}

class _CardDemoState extends State<_CardDemo> {
  bool _contract = true;
  bool _invoice = false;
  bool _notifications = true;
  bool _weeklyDigest = false;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 768),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 600;
          final columnWidth = wide
              ? (constraints.maxWidth - 12) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: columnWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BeuiCard(
                      size: BeuiCardSize.compact,
                      interactive: true,
                      selected: _contract,
                      child: BeuiCardHeader(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BeuiCardTitle(child: Text('Signed contract')),
                                  SizedBox(height: 4),
                                  BeuiCardDescription(
                                    child: Text(
                                      'The final PDF with every signature and the audit trail.',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            MergeSemantics(
                              child: Semantics(
                                label: 'Signed contract',
                                child: BeuiCheckbox(
                                  value: _contract,
                                  onChanged: (value) =>
                                      setState(() => _contract = value),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    BeuiCard(
                      size: BeuiCardSize.compact,
                      interactive: true,
                      selected: _invoice,
                      child: BeuiCardHeader(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BeuiCardTitle(child: Text('Invoice')),
                                  SizedBox(height: 4),
                                  BeuiCardDescription(
                                    child: Text(
                                      'Itemised billing, ready for accounting.',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            MergeSemantics(
                              child: Semantics(
                                label: 'Invoice',
                                child: BeuiCheckbox(
                                  value: _invoice,
                                  onChanged: (value) =>
                                      setState(() => _invoice = value),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    BeuiCard(
                      variant: BeuiCardVariant.muted,
                      size: BeuiCardSize.compact,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const BeuiCardHeader(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                BeuiCardTitle(
                                  headingLevel: 3,
                                  child: Text('Notifications'),
                                ),
                                SizedBox(height: 4),
                                BeuiCardDescription(
                                  child: Text(
                                    'Choose what reaches your inbox.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          BeuiCardContent(
                            child: Column(
                              children: [
                                _SwitchRow(
                                  label: 'Mentions and replies',
                                  value: _notifications,
                                  onChanged: (value) =>
                                      setState(() => _notifications = value),
                                ),
                                const SizedBox(height: 8),
                                _SwitchRow(
                                  label: 'Weekly digest',
                                  value: _weeklyDigest,
                                  onChanged: (value) =>
                                      setState(() => _weeklyDigest = value),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: columnWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BeuiCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          BeuiCardHeader(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      BeuiCardTitle(
                                        headingLevel: 3,
                                        child: Text('Review order'),
                                      ),
                                      SizedBox(height: 4),
                                      BeuiCardDescription(
                                        child: Text(
                                          'Check the details before you confirm.',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                BeuiCardAction(
                                  child: BeuiButton(
                                    variant: BeuiButtonVariant.ghost,
                                    onPressed: () {},
                                    child: const Text('Edit'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          BeuiCardContent(
                            child: const Column(
                              children: [
                                _SummaryRow(
                                  label: 'Plan',
                                  value: 'Team, yearly',
                                ),
                                _SummaryRow(label: 'Seats', value: '12'),
                                _SummaryRow(
                                  label: 'Billing email',
                                  value: 'billing@acme.co',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          BeuiCardFooter(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                BeuiButton(
                                  variant: BeuiButtonVariant.secondary,
                                  onPressed: () {},
                                  child: const Text('Back'),
                                ),
                                const SizedBox(width: 8),
                                BeuiButton(
                                  onPressed: () {},
                                  child: const Text('Confirm order'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _StudioCard(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _StudioCard extends StatelessWidget {
  const _StudioCard();

  @override
  Widget build(BuildContext context) => BeuiCard(
    interactive: true,
    child: SizedBox(
      height: 200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              'https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=1200&q=85',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const ColoredBox(
                color: Color(0xFFB8C6D1),
                child: Center(child: Icon(Icons.image_outlined, size: 40)),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Studio, Lisbon',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                ),
              ),
            ),
          ),
          BeuiCardTarget(
            child: Semantics(
              button: true,
              label: 'Studio, Lisbon',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label), Text(value)],
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: colors.foreground)),
        ),
        MergeSemantics(
          child: Semantics(
            label: label,
            child: BeuiSwitch(value: value, onChanged: onChanged),
          ),
        ),
      ],
    );
  }
}

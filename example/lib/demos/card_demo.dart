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
              ? (constraints.maxWidth - 16) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: columnWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTap: () => setState(() => _contract = !_contract),
                      child: BeuiCard(
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
                                    BeuiCardTitle(
                                      child: Text('Signed contract'),
                                    ),
                                    SizedBox(height: 6),
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
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTap: () => setState(() => _invoice = !_invoice),
                      child: BeuiCard(
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
                                    SizedBox(height: 6),
                                    BeuiCardDescription(
                                      child: Text(
                                        'Itemised billing for the period, ready for accounting.',
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
                                SizedBox(height: 6),
                                BeuiCardDescription(
                                  child: Text(
                                    'Choose what reaches your inbox.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          BeuiCardContent(
                            child: Column(
                              children: [
                                _SwitchRow(
                                  label: 'Mentions and replies',
                                  value: _notifications,
                                  onChanged: (value) =>
                                      setState(() => _notifications = value),
                                ),
                                const SizedBox(height: 12),
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
                                      SizedBox(height: 6),
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
                                    size: BeuiButtonSize.sm,
                                    onPressed: () {},
                                    child: const Text('Edit'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
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
                          const SizedBox(height: 24),
                          BeuiCardFooter(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                BeuiButton(
                                  variant: BeuiButtonVariant.secondary,
                                  size: BeuiButtonSize.sm,
                                  onPressed: () {},
                                  child: const Text('Back'),
                                ),
                                const SizedBox(width: 8),
                                BeuiButton(
                                  size: BeuiButtonSize.sm,
                                  onPressed: () {},
                                  child: const Text('Confirm order'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
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
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              'https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=720&q=80',
              semanticLabel:
                  'Bright open-plan studio with long desks and plants',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const ColoredBox(
                color: Color(0xFFB8C6D1),
                child: Center(child: Icon(Icons.image_outlined, size: 40)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const BeuiCardHeader(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BeuiCardTitle(headingLevel: 3, child: Text('Studio, Lisbon')),
              SizedBox(height: 6),
              BeuiCardDescription(
                child: Text(
                  'Desks for 12 people, booked for the March offsite.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        BeuiCardFooter(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '€1,840',
                        style: TextStyle(
                          color: BeuiColors.resolve(context).foreground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const TextSpan(text: ' · 3 days'),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: BeuiColors.resolve(context).mutedForeground,
                  ),
                ),
              ),
              BeuiButton(
                size: BeuiButtonSize.sm,
                variant: BeuiButtonVariant.secondary,
                onPressed: () {},
                child: const Text('View booking'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: label == 'Billing email'
          ? null
          : Border(
              bottom: BorderSide(color: BeuiColors.resolve(context).border),
            ),
    ),
    padding: EdgeInsets.only(
      top: label == 'Plan' ? 0 : 10,
      bottom: label == 'Billing email' ? 0 : 10,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: BeuiColors.resolve(context).mutedForeground,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              color: BeuiColors.resolve(context).foreground,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
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

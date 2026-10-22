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

  @override
  Widget build(BuildContext context) => Column(
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    BeuiCardTitle(child: Text('Signed contract')),
                    SizedBox(height: 4),
                    BeuiCardDescription(
                      child: Text('The final PDF with every signature.'),
                    ),
                  ],
                ),
              ),
              BeuiCheckbox(
                value: _contract,
                onChanged: (value) => setState(() => _contract = value),
                label: 'Signed contract',
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
                      child: Text('Itemised billing, ready for accounting.'),
                    ),
                  ],
                ),
              ),
              BeuiCheckbox(
                value: _invoice,
                onChanged: (value) => setState(() => _invoice = value),
                label: 'Invoice',
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
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
                  BeuiCardTitle(headingLevel: 3, child: Text('Notifications')),
                  SizedBox(height: 4),
                  BeuiCardDescription(
                    child: Text('Choose what reaches your inbox.'),
                  ),
                ],
              ),
            ),
            BeuiCardContent(
              child: BeuiSwitch(
                value: _notifications,
                label: 'Mentions and replies',
                onChanged: (value) => setState(() => _notifications = value),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      BeuiCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BeuiCardHeader(
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BeuiCardTitle(
                          headingLevel: 3,
                          child: Text('Review order'),
                        ),
                        SizedBox(height: 4),
                        BeuiCardDescription(
                          child: Text('Check the details before you confirm.'),
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
                  _SummaryRow(label: 'Plan', value: 'Team, yearly'),
                  _SummaryRow(label: 'Seats', value: '12'),
                  _SummaryRow(label: 'Billing email', value: 'billing@acme.co'),
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
    ],
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

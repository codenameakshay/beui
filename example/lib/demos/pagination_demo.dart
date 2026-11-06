import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiPagination].
Widget paginationDemo(BuildContext context) => const _PaginationDemo();

class _PaginationDemo extends StatefulWidget {
  const _PaginationDemo();

  @override
  State<_PaginationDemo> createState() => _PaginationDemoState();
}

class _PaginationDemoState extends State<_PaginationDemo> {
  int _page = 6;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        BeuiPagination(
          totalPages: 20,
          page: _page,
          onPageChange: (page) => setState(() => _page = page),
        ),
        const SizedBox(height: 16),
        Text(
          'Page $_page of 20',
          style: TextStyle(
            color: colors.mutedForeground,
            fontSize: 12,
            height: 16 / 12,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

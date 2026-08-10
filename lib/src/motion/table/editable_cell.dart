part of 'table.dart';

/// An inline cell text editor — the Flutter port of `editable-cell.tsx`.
///
/// A borderless field that reads as plain text at rest and, on focus, fills
/// with the `muted` surface and shows a `ring`-coloured focus ring (the source's
/// `focus:bg-muted focus:ring-1 focus:ring-ring`). The placeholder ("Empty")
/// uses muted-foreground at 40% alpha, matching the source.
class _EditableCell extends StatefulWidget {
  const _EditableCell({
    required this.value,
    required this.colors,
    required this.align,
    required this.onChanged,
  });

  final String value;
  final BeuiColors colors;
  final BeuiTableAlign align;
  final ValueChanged<String> onChanged;

  @override
  State<_EditableCell> createState() => _EditableCellState();
}

class _EditableCellState extends State<_EditableCell> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void didUpdateWidget(_EditableCell old) {
    super.didUpdateWidget(old);
    // Keep external edits in sync without clobbering the caret while typing.
    if (widget.value != _controller.text && !_focused) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        textAlign: _textAlign(widget.align),
        cursorColor: colors.ring,
        style: TextStyle(color: colors.foreground, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          filled: _focused,
          fillColor: colors.muted,
          hintText: 'Empty',
          hintStyle: TextStyle(
            color: colors.mutedForeground.withValues(alpha: 0.4),
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: colors.ring),
          ),
        ),
      ),
    );
  }
}

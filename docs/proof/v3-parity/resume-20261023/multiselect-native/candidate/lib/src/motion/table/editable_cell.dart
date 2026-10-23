part of 'table.dart';

/// An inline text editor shared by a table cell (`editable-cell.tsx`) and a
/// renameable column header (`table-header.tsx`'s header-becomes-input case).
///
/// Both are a borderless field that fills with the `muted` surface on focus;
/// they differ only in outer padding, text style, placeholder and whether
/// focus draws a `ring`-coloured border, which the two named constructors
/// below set — the controller/focus-node/didUpdateWidget-sync plumbing is
/// written once.
class _InlineTextField extends StatefulWidget {
  /// A table cell's inline editor: fixed style, an "Empty" placeholder, and a
  /// ring-coloured cursor and focus border.
  const _InlineTextField.cell({
    required this.value,
    required this.colors,
    required this.align,
    required this.onChanged,
  }) : header = false;

  /// A renameable column header's inline editor: row-padded, bolded and
  /// full-strength only while focused, no placeholder, no focus border (the
  /// filled background alone signals editability).
  const _InlineTextField.header({
    required this.value,
    required this.colors,
    required this.align,
    required this.onChanged,
    super.key,
  }) : header = true;

  final String value;
  final BeuiColors colors;
  final BeuiTableAlign align;
  final ValueChanged<String> onChanged;

  /// True for [_InlineTextField.header], false for [_InlineTextField.cell].
  final bool header;

  @override
  State<_InlineTextField> createState() => _InlineTextFieldState();
}

class _InlineTextFieldState extends State<_InlineTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void didUpdateWidget(_InlineTextField old) {
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
    final header = widget.header;

    final style = header
        ? TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _focused ? colors.foreground : colors.mutedForeground,
          )
        : TextStyle(color: colors.foreground, fontSize: 14);

    Widget field = TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      textAlign: _textAlign(widget.align),
      cursorColor: header ? null : colors.ring,
      style: style,
      decoration: InputDecoration(
        isDense: true,
        filled: _focused,
        fillColor: colors.muted,
        hintText: header ? null : 'Empty',
        hintStyle: header
            ? null
            : TextStyle(
                color: colors.mutedForeground.withValues(alpha: 0.4),
                fontSize: 14,
              ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: header ? 6 : 8,
          vertical: 6,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        focusedBorder: header
            ? null
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: colors.ring),
              ),
      ),
    );

    field = Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: field,
    );

    if (!header) return field;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: field,
    );
  }
}

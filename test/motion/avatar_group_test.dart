import 'package:beui/src/motion/avatar_group.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _members = [
  BeuiAvatarGroupMember(id: 'maya', name: 'Maya Chen'),
  BeuiAvatarGroupMember(id: 'leo', name: 'Leo Hart'),
  BeuiAvatarGroupMember(id: 'ines', name: 'Ines Duarte'),
  BeuiAvatarGroupMember(id: 'sam', name: 'Sam Okafor'),
  BeuiAvatarGroupMember(id: 'noah', name: 'Noah Berg'),
  BeuiAvatarGroupMember(id: 'aria', name: 'Aria Patel'),
  BeuiAvatarGroupMember(id: 'zoe', name: 'Zoe Laurent'),
  BeuiAvatarGroupMember(id: 'kai', name: 'Kai Moreno'),
];

Widget _app(Widget child, {bool reduce = true}) => beuiTestApp(
  MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: child,
  ),
);

Future<TestGesture> _mouseOver(WidgetTester tester, Finder finder) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: const Offset(-100, -100));
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(finder));
  await tester.pump();
  return gesture;
}

Finder _avatar(String id) => find.descendant(
  of: find.byKey(ValueKey<String>(id)),
  matching: find.byType(BeuiAvatar),
);

bool _accessibleLabel(WidgetTester tester, String label) {
  final root = tester.getSemantics(find.bySemanticsLabel('Members'));
  bool contains(SemanticsNode node) {
    if (node.label == label) return true;
    var found = false;
    node.visitChildren((child) {
      found = contains(child);
      return !found;
    });
    return found;
  }

  return contains(root);
}

void main() {
  test('initials trim, split, and uppercase names', () {
    expect(BeuiAvatar.initialsFor('  maya chen  '), 'MC');
    expect(BeuiAvatar.initialsFor('Maya'), 'MA');
    expect(BeuiAvatar.initialsFor('   '), '?');
    expect(BeuiAvatar.initialsFor('Jean Luc Picard'), 'JP');
  });

  for (final size in BeuiAvatarSize.values) {
    testWidgets('${size.name} avatar uses literal size and text size', (
      tester,
    ) async {
      await tester.pumpWidget(_app(BeuiAvatar(name: 'Maya Chen', size: size)));
      final box = tester.getSize(find.byType(BeuiAvatar));
      expect(box, Size.square(size.pixels));
      final text = tester.widget<Text>(find.text('MC'));
      expect(text.style?.fontSize, size.fontSize);
    });
  }

  testWidgets('collapsed geometry, source order, and overflow label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const BeuiAvatarGroup(
          members: _members,
          max: 4,
          size: BeuiAvatarSize.lg,
        ),
      ),
    );
    expect(find.byType(BeuiAvatar), findsNWidgets(4));
    expect(find.byType(InkWell), findsOneWidget);
    expect(find.text('+4'), findsOneWidget);
    final group = tester.getRect(find.byType(BeuiAvatarGroup));
    expect(group.width, 160); // 5 * 44 - 4 * 15
    expect(
      tester.getTopLeft(find.byType(BeuiAvatar).at(1)).dx -
          tester.getTopLeft(find.byType(BeuiAvatar).first).dx,
      29,
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Members')).label,
      'Members',
    );
    expect(find.bySemanticsLabel('Maya Chen'), findsOneWidget);
  });

  testWidgets('overflow label starts settled without an entrance animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const BeuiAvatarGroup(members: _members, max: 4)),
    );
    final label = find.text('+4');
    final switcher = find.ancestor(
      of: label,
      matching: find.byType(AnimatedSwitcher),
    );
    final fade = find.descendant(
      of: switcher,
      matching: find.byType(FadeTransition),
    );
    expect(fade, findsOneWidget);
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
    final slide = find.descendant(
      of: switcher,
      matching: find.byType(SlideTransition),
    );
    expect(slide, findsOneWidget);
    expect(tester.widget<SlideTransition>(slide).position.value, Offset.zero);
  });

  testWidgets('overflow label swaps on the source 160ms clock', (tester) async {
    await tester.pumpWidget(
      _app(const BeuiAvatarGroup(members: _members, max: 4), reduce: false),
    );
    await tester.tap(find.bySemanticsLabel('Show 4 more members'));
    await tester.pump();
    final label = find.text('−');
    final fade = find.ancestor(
      of: label,
      matching: find.byType(FadeTransition),
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      tester.widget<FadeTransition>(fade.first).opacity.value,
      greaterThan(0),
    );
    expect(
      tester.widget<FadeTransition>(fade.first).opacity.value,
      lessThan(1),
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.widget<FadeTransition>(fade.first).opacity.value, 1);
    final slide = find.ancestor(
      of: label,
      matching: find.byType(SlideTransition),
    );
    expect(
      tester.widget<SlideTransition>(slide.first).position.value,
      Offset.zero,
    );
  });

  testWidgets('overflow remains while expanded; its button toggles back', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const BeuiAvatarGroup(members: _members, max: 4)),
    );
    final more = find.bySemanticsLabel('Show 4 more members');
    expect(
      tester.getSemantics(more),
      matchesSemantics(
        label: 'Show 4 more members',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasExpandedState: true,
        isExpanded: false,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.byType(BeuiAvatar), findsNWidgets(8));
    expect(find.text('−'), findsOneWidget);
    expect(find.bySemanticsLabel('Show fewer members'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Show fewer members'));
    await tester.pumpAndSettle();
    expect(find.byType(BeuiAvatar), findsNWidgets(4));
  });

  testWidgets(
    'controlled state reports toggles without changing until parent updates',
    (tester) async {
      final changes = <bool>[];
      late StateSetter update;
      var expanded = false;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return BeuiAvatarGroup(
                members: _members,
                max: 4,
                expanded: expanded,
                onExpandedChange: changes.add,
              );
            },
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Show 4 more members'));
      await tester.pump();
      expect(changes, [true]);
      expect(find.byType(BeuiAvatar), findsNWidgets(4));
      update(() => expanded = true);
      await tester.pumpAndSettle();
      expect(find.byType(BeuiAvatar), findsNWidgets(8));
    },
  );

  testWidgets('uncontrolled state seeds once and notifies after update', (
    tester,
  ) async {
    final changes = <bool>[];
    await tester.pumpWidget(
      _app(
        BeuiAvatarGroup(
          members: _members,
          max: 4,
          defaultExpanded: true,
          onExpandedChange: changes.add,
        ),
      ),
    );
    expect(find.byType(BeuiAvatar), findsNWidgets(8));
    await tester.tap(find.bySemanticsLabel('Show fewer members'));
    await tester.pumpAndSettle();
    expect(changes, [false]);
    expect(find.byType(BeuiAvatar), findsNWidgets(4));
  });

  testWidgets('max floors at one and no overflow means no toggle control', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(BeuiAvatarGroup(members: [_members.first], max: 0)),
    );
    expect(find.byType(BeuiAvatar), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
    await tester.pumpWidget(_app(const BeuiAvatarGroup(members: [], max: 0)));
    expect(tester.getSize(find.byType(BeuiAvatarGroup)), Size.zero);
  });

  testWidgets('mouse hover parts the row; touch does not fan it out', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const BeuiAvatarGroup(
          members: _members,
          max: 4,
          size: BeuiAvatarSize.md,
        ),
        reduce: false,
      ),
    );
    final avatar = _avatar('leo');
    final before = tester.getCenter(avatar).dx;
    final firstBefore = tester.getTopLeft(find.byType(BeuiAvatar).first).dx;
    final mouse = await _mouseOver(tester, avatar);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getCenter(avatar).dx, closeTo(before, 0.01));
    expect(
      tester.getTopLeft(_avatar('maya')).dx,
      closeTo(firstBefore - 9, 0.2),
    );
    final scales = tester.widgetList<Transform>(
      find.ancestor(of: avatar, matching: find.byType(Transform)),
    );
    expect(
      scales.any((scale) => scale.transform.entry(0, 0).abs() > 1),
      isTrue,
    );

    await mouse.moveTo(const Offset(10000, 10000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(
      _app(
        const BeuiAvatarGroup(
          key: ValueKey('touch-only'),
          members: _members,
          max: 4,
          size: BeuiAvatarSize.md,
        ),
        reduce: false,
      ),
    );
    Iterable<Transform> touchTransforms() => tester.widgetList<Transform>(
      find.ancestor(of: avatar, matching: find.byType(Transform)),
    );
    expect(
      touchTransforms().every(
        (transform) => transform.transform.entry(0, 0).abs() == 1,
      ),
      isTrue,
    );
    final touch = await tester.createGesture(kind: PointerDeviceKind.touch);
    await touch.addPointer(location: tester.getCenter(avatar));
    await touch.moveTo(tester.getCenter(avatar));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      touchTransforms().every(
        (transform) => transform.transform.entry(0, 0).abs() == 1,
      ),
      isTrue,
    );
  });

  testWidgets('hovering overflow only parts it horizontally', (tester) async {
    await tester.pumpWidget(
      _app(const BeuiAvatarGroup(members: _members, max: 4), reduce: false),
    );
    final overflow = find.byType(InkWell);
    final initialTop = tester.getTopLeft(overflow).dy;
    await _mouseOver(tester, overflow);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getTopLeft(overflow).dy, initialTop);
    final transforms = tester.widgetList<Transform>(
      find.ancestor(of: overflow, matching: find.byType(Transform)),
    );
    expect(
      transforms.every(
        (transform) => transform.transform.entry(0, 0).abs() == 1,
      ),
      isTrue,
    );
  });

  testWidgets(
    'removed member becomes inert immediately and is cleaned after exit',
    (tester) async {
      var members = _members;
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return BeuiAvatarGroup(members: members, max: 8);
            },
          ),
        ),
      );
      update(() => members = _members.skip(1).toList());
      await tester.pump();
      expect(_accessibleLabel(tester, 'Maya Chen'), isFalse);
      expect(find.byType(BeuiAvatar), findsNWidgets(8));
      await tester.pump(const Duration(milliseconds: 141));
      expect(find.byType(BeuiAvatar), findsNWidgets(7));
    },
  );

  testWidgets('initially present member exits on the source 140ms clock', (
    tester,
  ) async {
    var members = _members;
    late StateSetter update;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeuiAvatarGroup(members: members, max: 8);
          },
        ),
      ),
    );
    update(() => members = _members.skip(1).toList());
    await tester.pump();
    final exiting = find.byKey(const ValueKey<String>('maya'));
    final opacity = find.descendant(
      of: exiting,
      matching: find.byType(Opacity),
    );
    await tester.pump(const Duration(milliseconds: 70));
    expect(tester.widget<Opacity>(opacity.first).opacity, greaterThan(0));
    expect(tester.widget<Opacity>(opacity.first).opacity, lessThan(1));
    await tester.pump(const Duration(milliseconds: 69));
    expect(find.byType(BeuiAvatar), findsNWidgets(8));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byType(BeuiAvatar), findsNWidgets(7));
  });

  testWidgets('reinserted member cancels its retained exit cleanup', (
    tester,
  ) async {
    var members = _members;
    late StateSetter update;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeuiAvatarGroup(members: members, max: 8);
          },
        ),
      ),
    );
    update(() => members = _members.skip(1).toList());
    await tester.pump();
    update(() => members = _members);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    expect(find.byType(BeuiAvatar), findsNWidgets(8));
    expect(find.bySemanticsLabel('Maya Chen'), findsOneWidget);
  });

  testWidgets(
    'overflow activates from keyboard and updates expanded semantics',
    (tester) async {
      await tester.pumpWidget(
        _app(const BeuiAvatarGroup(members: _members, max: 4)),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Show fewer members')),
        matchesSemantics(
          label: 'Show fewer members',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasExpandedState: true,
          isExpanded: true,
          isFocused: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.byType(BeuiAvatar), findsNWidgets(4));
    },
  );

  testWidgets('reduced-motion insertion fades in on source duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const BeuiAvatarGroup(members: _members, max: 4)),
    );
    await tester.tap(find.bySemanticsLabel('Show 4 more members'));
    await tester.pump();
    final inserted = find.byKey(const ValueKey<String>('noah'));
    final opacity = find.descendant(
      of: inserted,
      matching: find.byType(Opacity),
    );
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.widget<Opacity>(opacity.first).opacity, greaterThan(0));
    expect(tester.widget<Opacity>(opacity.first).opacity, lessThan(1));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.widget<Opacity>(opacity.first).opacity, 1);
    final insertedAvatar = find.descendant(
      of: inserted,
      matching: find.byType(BeuiAvatar),
    );
    final transforms = tester.widgetList<Transform>(
      find.ancestor(of: insertedAvatar, matching: find.byType(Transform)),
    );
    expect(
      transforms.every(
        (transform) => transform.transform.entry(0, 0).abs() == 1,
      ),
      isTrue,
    );
  });

  testWidgets('normal-motion insertion scales from source size', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const BeuiAvatarGroup(members: _members, max: 4), reduce: false),
    );
    await tester.tap(find.bySemanticsLabel('Show 4 more members'));
    await tester.pump();
    final inserted = find.byKey(const ValueKey<String>('noah'));
    final insertedAvatar = find.descendant(
      of: inserted,
      matching: find.byType(BeuiAvatar),
    );
    await tester.pump(const Duration(milliseconds: 60));
    final transforms = tester.widgetList<Transform>(
      find.ancestor(of: insertedAvatar, matching: find.byType(Transform)),
    );
    expect(
      transforms.any((transform) {
        final scale = transform.transform.entry(0, 0).abs();
        return scale > 0.6 && scale < 1;
      }),
      isTrue,
    );
  });

  testWidgets('rapid expand-collapse retains members and cancels exits', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const BeuiAvatarGroup(members: _members, max: 4)),
    );
    await tester.tap(find.bySemanticsLabel('Show 4 more members'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Show fewer members'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.byType(BeuiAvatar), findsNWidgets(4));
    expect(find.text('+4'), findsOneWidget);
    expect(find.bySemanticsLabel('Noah Berg'), findsNothing);
  });

  testWidgets('dispose cancels pending exit cleanup', (tester) async {
    var members = _members;
    var show = true;
    late StateSetter update;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return show
                ? BeuiAvatarGroup(members: members, max: 8)
                : const SizedBox.shrink();
          },
        ),
      ),
    );
    update(() => members = _members.skip(1).toList());
    await tester.pump();
    update(() => show = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hover exit resets and forwards the caller callback', (
    tester,
  ) async {
    var left = 0;
    await tester.pumpWidget(
      _app(
        BeuiAvatarGroup(
          members: _members,
          max: 4,
          onPointerLeave: (_) => left++,
        ),
        reduce: false,
      ),
    );
    final mouse = await _mouseOver(tester, find.byType(BeuiAvatar).first);
    await mouse.moveTo(const Offset(500, 500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(left, 1);
    final transforms = tester.widgetList<Transform>(
      find.ancestor(of: _avatar('maya'), matching: find.byType(Transform)),
    );
    expect(
      transforms.every(
        (transform) => transform.transform.entry(0, 0).abs() == 1,
      ),
      isTrue,
    );
  });

  testWidgets('member tooltip opens at the source delay above its avatar', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const BeuiAvatarGroup(members: _members, max: 4)),
    );
    final avatar = find.byType(BeuiAvatar).first;
    await _mouseOver(tester, avatar);
    await tester.pump(const Duration(milliseconds: 119));
    expect(find.text('Maya Chen'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    final tooltip = find.text('Maya Chen');
    expect(tooltip, findsOneWidget);
    expect(
      tester.getTopLeft(tooltip).dy,
      lessThan(tester.getTopLeft(avatar).dy),
    );
  });

  testWidgets('all sizes use source overlaps and pushes', (tester) async {
    for (final size in BeuiAvatarSize.values) {
      await tester.pumpWidget(
        _app(
          BeuiAvatarGroup(
            key: ValueKey(size),
            members: _members,
            max: 4,
            size: size,
          ),
          reduce: false,
        ),
      );
      final first = tester.getTopLeft(_avatar('maya')).dx;
      final second = tester.getTopLeft(_avatar('leo')).dx;
      final overlap = (size.pixels / 3).round();
      final push = (overlap * 0.75).round();
      expect(second - first, size.pixels - overlap);
      final mouse = await _mouseOver(tester, _avatar('leo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        tester.getTopLeft(_avatar('maya')).dx,
        closeTo(first - push, 0.25),
      );
      await mouse.removePointer();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }
  });

  testWidgets(
    'reduced motion preserves member geometry and suppresses hover scale',
    (tester) async {
      await tester.pumpWidget(
        _app(const BeuiAvatarGroup(members: _members, max: 4), reduce: true),
      );
      final first = find.byType(BeuiAvatar).first;
      await _mouseOver(tester, first);
      await tester.pump(const Duration(milliseconds: 200));
      final transforms = tester.widgetList<Transform>(
        find.ancestor(of: first, matching: find.byType(Transform)),
      );
      expect(
        transforms.every(
          (transform) => transform.transform.entry(0, 0).abs() == 1,
        ),
        isTrue,
      );
    },
  );

  testWidgets('overflow focus visibility follows keyboard and pointer input', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const BeuiAvatarGroup(members: _members, max: 4)),
    );
    final material = find.ancestor(
      of: find.byType(InkWell),
      matching: find.byType(Material),
    );
    BorderSide side() =>
        (tester.widget<Material>(material.first).shape! as CircleBorder).side;

    final idleSide = side();
    await tester.tap(find.bySemanticsLabel('Show 4 more members'));
    await tester.pump();
    expect(side().color, idleSide.color);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(side().color, isNot(idleSide.color));

    final mouse = await _mouseOver(tester, find.byType(InkWell));
    await mouse.down(tester.getCenter(find.byType(InkWell)));
    await mouse.up();
    await tester.pump();
    expect(side().color, idleSide.color);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(side().color, isNot(idleSide.color));
  });

  testWidgets('first Tab from outside shows the overflow focus ring', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const BeuiAvatarGroup(members: _members, max: 4)),
    );
    final material = find.ancestor(
      of: find.byType(InkWell),
      matching: find.byType(Material),
    );
    BorderSide side() =>
        (tester.widget<Material>(material.first).shape! as CircleBorder).side;
    final idle = side().color;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester.getSemantics(find.bySemanticsLabel('Show 4 more members')),
      matchesSemantics(
        label: 'Show 4 more members',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasExpandedState: true,
        isFocusable: true,
        isFocused: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(side().color, isNot(idle));
  });

  testWidgets('a changed image URL replaces the keyed network image', (
    tester,
  ) async {
    var source = 'https://example.invalid/first.png';
    late StateSetter update;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeuiAvatar(name: 'Maya Chen', src: source);
          },
        ),
      ),
    );
    final firstImage = tester.widget<Image>(find.byType(Image));
    expect(firstImage.image, isA<NetworkImage>());
    update(() => source = 'https://example.invalid/second.png');
    await tester.pump();
    expect(tester.widget<Image>(find.byType(Image)).image, isA<NetworkImage>());
    expect(
      (tester.widget<Image>(find.byType(Image)).image as NetworkImage).url,
      source,
    );
  });

  testWidgets('failed network image falls back to initials', (tester) async {
    await tester.pumpWidget(
      _app(
        const BeuiAvatar(
          name: 'Maya Chen',
          src: 'https://example.invalid/not-an-image.png',
        ),
      ),
    );
    // flutter_test rejects network requests locally; verify its error fallback.
    await tester.pumpAndSettle();
    expect(find.text('MC'), findsOneWidget);
    expect(find.bySemanticsLabel('Maya Chen'), findsOneWidget);
  });
}

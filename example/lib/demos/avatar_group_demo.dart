import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

const _members = <BeuiAvatarGroupMember>[
  BeuiAvatarGroupMember(
    id: 'maya',
    name: 'Maya Chen',
    src:
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=96&h=96&q=80',
  ),
  BeuiAvatarGroupMember(
    id: 'leo',
    name: 'Leo Hart',
    src:
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=96&h=96&q=80',
  ),
  BeuiAvatarGroupMember(
    id: 'ines',
    name: 'Ines Duarte',
    src:
        'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=96&h=96&q=80',
  ),
  BeuiAvatarGroupMember(
    id: 'sam',
    name: 'Sam Okafor',
    src:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=96&h=96&q=80',
  ),
  BeuiAvatarGroupMember(
    id: 'noah',
    name: 'Noah Berg',
    src:
        'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=96&h=96&q=80',
  ),
  BeuiAvatarGroupMember(id: 'aria', name: 'Aria Patel'),
  BeuiAvatarGroupMember(
    id: 'zoe',
    name: 'Zoe Laurent',
    src:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=96&h=96&q=80',
  ),
  BeuiAvatarGroupMember(id: 'kai', name: 'Kai Moreno'),
];

/// Gallery demo matching the pinned Avatar Group preview (eight members).
Widget avatarGroupDemo(BuildContext context) => const BeuiAvatarGroup(
  members: _members,
  max: 4,
  size: BeuiAvatarSize.lg,
  label: 'Project members',
);

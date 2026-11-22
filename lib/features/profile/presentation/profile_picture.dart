import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_adapter.dart';
import '../application/cloud_profile.dart';

class ProfilePicture extends ConsumerWidget {
  const ProfilePicture({super.key, required this.size, required this.fallback});

  final double size;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(sessionProvider).asData?.value?.uid;
    if (uid == null) return fallback;
    final profile = ref.watch(cloudProfileProvider);
    final photo = profile.uid == uid ? profile.photo : null;
    if (photo == null) return fallback;
    return Semantics(
      image: true,
      label: 'Profile photo',
      child: ClipOval(
        child: Image.memory(
          photo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/design_system/design_system.dart';
import '../../../app/developer/developer_tools.dart';
import '../../../app/preferences.dart';
import '../../../app/shell/layout.dart';
import '../../../core/capabilities.dart';
import '../../../core/config.dart';
import '../../../core/operation.dart';
import '../../../core/platform.dart';
import '../../auth/auth_adapter.dart';
import '../../../data/repositories/entitlement_repository.dart';
import '../../../domain/models/plan.dart';
import '../../../ui/notifications/widgets/notifications_screen.dart';
import '../../../ui/plans/widgets/plans_screen.dart';
import '../application/cloud_profile.dart';
import 'profile_picture.dart';

enum ProfileSection {
  account('Account', 'Sign-in and verification', BimbiIcons.profile),
  appearance('Appearance', 'Name, theme and buddy', BimbiIcons.palette),
  permissions('Permissions', 'Alarms and device access', BimbiIcons.lock),
  notifications('Notifications', 'Tips and updates', BimbiIcons.bell),
  plans('Plans', 'Free, Plus and Premium', BimbiIcons.card),
  privacy('Privacy', 'Location and account data', BimbiIcons.shield);

  const ProfileSection(this.label, this.subtitle, this.icon);
  final String label;
  final String subtitle;
  final BimbiIcons icon;
}

class ProfileSectionController extends Notifier<ProfileSection> {
  @override
  ProfileSection build() => ProfileSection.account;
  void select(ProfileSection s) => state = s;
}

final profileSectionProvider =
    NotifierProvider<ProfileSectionController, ProfileSection>(
      ProfileSectionController.new,
    );

Widget _sectionBody(ProfileSection s) => switch (s) {
  ProfileSection.account => const AccountSection(),
  ProfileSection.appearance => const AppearanceSection(),
  ProfileSection.permissions => const PermissionsSection(),
  // Plans and Notifications are their own screens; the pane never shows them.
  ProfileSection.plans ||
  ProfileSection.notifications => const SizedBox.shrink(),
  ProfileSection.privacy => const PrivacySection(),
};

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = WindowScope.of(context);
    const header = PageHeader(title: 'Profile');
    if (window.isExpanded) {
      final selected = ref.watch(profileSectionProvider);
      return TwoPane(
        primaryFlex: 2,
        secondaryFlex: 3,
        primary: [
          header,
          const _ProfileSummary(),
          _ProfileMenu(
            selected: selected,
            onSelect: (section) => switch (section) {
              ProfileSection.plans => openPlans(context),
              ProfileSection.notifications => openNotifications(context),
              _ => ref.read(profileSectionProvider.notifier).select(section),
            },
          ),
          if (AppConfig.harness) const DeveloperTools(),
        ],
        secondary: [_sectionBody(selected)],
      );
    }
    return PageBody(
      children: [
        header,
        const _ProfileSummary(),
        _ProfileMenu(
          onSelect: (section) => section == ProfileSection.plans
              ? openPlans(context)
              : section == ProfileSection.notifications
              ? openNotifications(context)
              : Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Profile')),
                      body: SafeArea(
                        top: false,
                        child: PageBody(
                          maxWidth: 640,
                          children: [_sectionBody(section)],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        if (AppConfig.harness) const DeveloperTools(),
      ],
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({required this.onSelect, this.selected});

  final ValueChanged<ProfileSection> onSelect;
  final ProfileSection? selected;

  @override
  Widget build(BuildContext context) {
    final c = context.bimbi;
    return BimbiCard(
      padding: const EdgeInsets.all(BimbiSpace.xs),
      child: Column(
        children: [
          for (final section in ProfileSection.values) ...[
            if (section != ProfileSection.values.first)
              Divider(
                height: 1,
                indent: 64,
                endIndent: 12,
                color: c.cardBorder,
              ),
            ListTile(
              minTileHeight: 68,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: BimbiSpace.sm,
              ),
              leading: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.accentTint,
                  borderRadius: BimbiRadius.chipBorder,
                ),
                child: BimbiIcon(section.icon, size: 20),
              ),
              title: Text(section.label),
              subtitle: Text(section.subtitle),
              selected: section == selected,
              trailing: BimbiIcon(BimbiIcons.chevronRight, size: 18),
              onTap: () => onSelect(section),
            ),
          ],
          TextButton(
            onPressed: () async {
              final opened = await launchUrl(
                Uri.https('icons8.com', '/icons/claude-hand-drawn'),
                mode: LaunchMode.externalApplication,
              );
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open icons8.com.')),
                );
              }
            },
            child: const Text('Icons by Icons8'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.children});
  final ProfileSection section;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => BimbiCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            BimbiIcon(section.icon),
            const SizedBox(width: BimbiSpace.sm),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(section.label, style: context.text.headlineSmall),
              ),
            ),
          ],
        ),
        const SizedBox(height: BimbiSpace.md),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: BimbiSpace.sm),
          children[i],
        ],
      ],
    ),
  );
}

class _ProfileSummary extends ConsumerWidget {
  const _ProfileSummary();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).asData?.value;
    final name = ref.watch(visibleProfileNameProvider);
    final shown = name.isEmpty ? 'Hello there' : name;
    final c = context.bimbi;
    return BimbiCard(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Row(
        children: [
          ProfilePicture(
            size: 80,
            fallback: DecoratedBox(
              decoration: BoxDecoration(color: c.card, shape: BoxShape.circle),
              child: const BimbiBuddy(size: 80, glow: false),
            ),
          ),
          const SizedBox(width: BimbiSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shown, style: context.text.headlineSmall),
                const SizedBox(height: 4),
                if (user == null)
                  const StatusPill('Not signed in')
                else
                  StatusPill(
                    user.emailVerified
                        ? 'Email verified'
                        : 'Email not verified',
                    tone: user.emailVerified
                        ? PillTone.success
                        : PillTone.danger,
                    icon: user.emailVerified
                        ? BimbiIcons.check
                        : BimbiIcons.mail,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AccountSection extends ConsumerStatefulWidget {
  const AccountSection({super.key});
  @override
  ConsumerState<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<AccountSection> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authAdapterProvider);
    final session = ref.watch(sessionProvider);
    final user = session.asData?.value;
    final ready = ref.watch(firebaseReadyProvider);
    final busy = ref.watch(operationProvider).busy;
    final op = ref.read(operationProvider.notifier);
    VoidCallback? run(Future<String> Function() action, {bool when = true}) =>
        ready && when && !busy ? () => op.run(action) : null;

    if (ready && session.isLoading) {
      return const _SectionCard(
        section: ProfileSection.account,
        children: [Text('Restoring your account…'), LinearProgressIndicator()],
      );
    }

    if (user != null) {
      final providers = user.providerData.map((p) => p.providerId).toList();
      return _SectionCard(
        section: ProfileSection.account,
        children: [
          Text(
            user.email ?? 'Signed-in account',
            style: context.text.titleMedium,
          ),
          Wrap(
            spacing: BimbiSpace.xs,
            runSpacing: BimbiSpace.xs,
            children: [
              StatusPill(
                user.emailVerified ? 'Email verified' : 'Email not verified',
                tone: user.emailVerified ? PillTone.success : PillTone.danger,
              ),
              for (final p in providers) StatusPill('Provider: $p'),
            ],
          ),
          if (!user.emailVerified)
            FilledButton(
              onPressed: run(() async {
                await auth!.verify();
                return 'Verification email sent.';
              }),
              child: const Text('Resend verification'),
            ),
          OutlinedButton(
            onPressed: run(() async {
              await auth!.reload();
              if (mounted) {
                await ref.read(cloudProfileProvider.notifier).refreshPhoto();
              }
              return 'Session refreshed.';
            }),
            child: const Text('Refresh status'),
          ),
          if (user.emailVerified) const _PhotoActions(),
          TextButton.icon(
            onPressed: run(() async {
              await auth!.signOut();
              return 'Signed out.';
            }),
            icon: BimbiIcon(BimbiIcons.signOut),
            label: const Text('Sign out'),
          ),
        ],
      );
    }

    return _SectionCard(
      section: ProfileSection.account,
      children: [
        if (!ready)
          const InlineBanner(
            icon: BimbiIcons.info,
            title: 'Sign-in unavailable in this build',
            message:
                'Firebase configuration required. Alarms, sleep and focus '
                'still work offline.',
          ),
        if (session.hasError)
          const InlineBanner(
            icon: BimbiIcons.info,
            title: 'Could not restore your account',
            message: 'Check your connection and try signing in again.',
          ),
        TextField(
          controller: _email,
          enabled: ready,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        TextField(
          controller: _password,
          enabled: ready,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        FilledButton(
          onPressed: run(() async {
            await auth!.email(_email.text, _password.text);
            _password.clear();
            return 'Signed in.';
          }),
          child: const Text('Sign in'),
        ),
        OutlinedButton(
          onPressed: run(() async {
            await auth!.email(_email.text, _password.text, register: true);
            _password.clear();
            await auth.verify();
            return 'Account created. Check your verification email.';
          }),
          child: const Text('Create account'),
        ),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BimbiSpace.sm),
              child: Text('or', style: context.text.bodySmall),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        OutlinedButton.icon(
          onPressed: run(() async {
            await auth!.google();
            return 'Google sign-in completed.';
          }),
          icon: const BimbiIcon(BimbiIcons.google),
          label: const Text('Continue with Google'),
        ),
        OutlinedButton.icon(
          onPressed: run(() async {
            await auth!.github();
            return 'GitHub sign-in completed.';
          }),
          icon: const BimbiIcon(BimbiIcons.github),
          label: const Text('Continue with GitHub'),
        ),
        TextButton(
          onPressed: run(() async {
            await auth!.reset(_email.text);
            return 'Password reset requested. Check your email.';
          }),
          child: const Text('Forgot password?'),
        ),
      ],
    );
  }
}

class _PhotoActions extends ConsumerWidget {
  const _PhotoActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(cloudProfileProvider);
    final controller = ref.read(cloudProfileProvider.notifier);
    final busy = profile.savingPhoto;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profile.canEditAvatar)
          Wrap(
            spacing: BimbiSpace.xs,
            children: [
              OutlinedButton(
                onPressed: busy ? null : () => controller.editPhoto(),
                child: const Text('Choose photo'),
              ),
              if (profile.photo != null)
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Remove profile photo?'),
                              content: const Text(
                                'Your other devices will show the buddy after they refresh.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Keep photo'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Remove photo'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true &&
                              context.mounted &&
                              ref.read(cloudProfileProvider).uid ==
                                  profile.uid) {
                            await controller.editPhoto(remove: true);
                          }
                        },
                  child: const Text('Remove photo'),
                ),
            ],
          )
        else
          const Text(
            'Custom photos are available for verified email accounts created with a password.',
          ),
        if (busy) const LinearProgressIndicator(),
        if (profile.photoStatus.isNotEmpty)
          Semantics(liveRegion: true, child: Text(profile.photoStatus)),
      ],
    );
  }
}

class _SyncedNameEditor extends ConsumerStatefulWidget {
  const _SyncedNameEditor({super.key});

  @override
  ConsumerState<_SyncedNameEditor> createState() => _SyncedNameEditorState();
}

class _SyncedNameEditorState extends ConsumerState<_SyncedNameEditor> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: ref.read(visibleProfileNameProvider));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(visibleProfileNameProvider, (previous, next) {
      if (_text.text == previous) _text.text = next;
    });
    final profile = ref.watch(cloudProfileProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _text,
          maxLength: 40,
          enabled: profile.verified && !profile.savingName,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Profile name',
            helperText: profile.verified
                ? 'Syncs to devices signed into this account.'
                : 'Verify your email to sync your profile.',
            counterText: '',
          ),
        ),
        const SizedBox(height: BimbiSpace.xs),
        OutlinedButton(
          onPressed: profile.verified && !profile.savingName
              ? () =>
                    ref.read(cloudProfileProvider.notifier).saveName(_text.text)
              : null,
          child: const Text('Save name'),
        ),
        if (profile.savingName)
          Semantics(
            liveRegion: true,
            child: Text(
              profile.online ? 'Saving name…' : 'Waiting for connection…',
            ),
          )
        else if (profile.nameStatus.isNotEmpty ||
            (profile.verified && !profile.online))
          Semantics(
            liveRegion: true,
            child: Text(
              profile.nameStatus.isNotEmpty
                  ? profile.nameStatus
                  : 'Waiting for the profile database to connect.',
            ),
          ),
      ],
    );
  }
}

class AppearanceSection extends ConsumerStatefulWidget {
  const AppearanceSection({super.key});
  @override
  ConsumerState<AppearanceSection> createState() => _AppearanceSectionState();
}

class _AppearanceSectionState extends ConsumerState<AppearanceSection> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: ref.read(displayNameProvider));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).asData?.value;
    final mode = ref.watch(themeModeProvider);
    final buddy = ref.watch(buddyColorProvider);
    final tier = ref.watch(planTierProvider);
    final appTheme = ref.watch(appThemeProvider);
    return _SectionCard(
      section: ProfileSection.appearance,
      children: [
        if (user != null)
          _SyncedNameEditor(key: ValueKey(user.uid))
        else
          TextField(
            controller: _name,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Your name',
              helperText: 'What Bimbi calls you. Stays on this device.',
              counterText: '',
            ),
            onChanged: ref.read(displayNameProvider.notifier).set,
          ),
        const SizedBox(height: BimbiSpace.xs),
        const SectionLabel('Theme'),
        SegmentedButton<ThemeMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: ThemeMode.system, label: Text('System')),
            ButtonSegment(value: ThemeMode.light, label: Text('Light')),
            ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
          ],
          selected: {mode},
          onSelectionChanged: (s) =>
              ref.read(themeModeProvider.notifier).set(s.first),
        ),
        const SizedBox(height: BimbiSpace.xs),
        const SectionLabel('Colours'),
        Wrap(
          spacing: BimbiSpace.xs,
          runSpacing: BimbiSpace.xs,
          children: [
            for (final t in AppTheme.values)
              ChoiceChip(
                label: Text(
                  t == AppTheme.sunrise && !tier.includes(PlanTier.premium)
                      ? '${t.label} · Premium'
                      : t.label,
                ),
                selected: appTheme == t,
                onSelected: (_) =>
                    t == AppTheme.sunrise && !tier.includes(PlanTier.premium)
                    ? openPlans(context)
                    : ref.read(appThemeProvider.notifier).set(t),
              ),
          ],
        ),
        const SizedBox(height: BimbiSpace.xs),
        const SectionLabel('Buddy colour'),
        Row(
          children: [
            const BimbiBuddy(size: 72, glow: false, mood: BuddyMood.excited),
            const SizedBox(width: BimbiSpace.sm),
            Expanded(
              child: BuddyColorPicker(
                value: buddy,
                onChanged: ref.read(buddyColorProvider.notifier).set,
                plusUnlocked: tier.includes(PlanTier.plus),
                onLocked: () => openPlans(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class PermissionsSection extends ConsumerWidget {
  const PermissionsSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref
        .watch(capabilitiesProvider)
        .whenData(DeviceCapabilities.new)
        .asData
        ?.value;
    final platform = ref.read(platformProvider);
    final op = ref.read(operationProvider.notifier);
    Widget row(
      String label,
      String detail,
      bool? on,
      String kind, {
      bool optional = false,
    }) => MergeSemantics(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: Text(detail),
        trailing: on == null
            ? null
            : StatusPill(
                on ? 'Allowed' : 'Off',
                tone: on
                    ? PillTone.success
                    : (optional ? PillTone.neutral : PillTone.danger),
              ),
        onTap: () => op.run(() async {
          await platform.settings(kind);
          return 'Return to Bimbi after reviewing Android settings.';
        }),
      ),
    );
    return _SectionCard(
      section: ProfileSection.permissions,
      children: [
        Text(
          'Tap one to open its Android setting.',
          style: context.text.bodySmall,
        ),
        row('Exact alarms', 'Rings exactly on time', caps?.exactAlarm, 'exact'),
        row(
          'Notifications',
          'Alarm alerts and opt-in news',
          caps?.notifications,
          'notification',
        ),
        row(
          'Lock-screen alerts',
          'Full-screen wake screen',
          caps?.fullScreen,
          'fullScreen',
        ),
        row(
          'Usage Access',
          'Optional phone-use awareness',
          caps?.usageAccess,
          'usage',
          optional: true,
        ),
      ],
    );
  }
}

class PrivacySection extends StatelessWidget {
  const PrivacySection({super.key});
  @override
  Widget build(BuildContext context) {
    Widget line(BimbiIcons icon, String text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BimbiIcon(icon, size: 22),
        const SizedBox(width: BimbiSpace.sm),
        Expanded(child: Text(text, style: context.text.bodyMedium)),
      ],
    );
    return _SectionCard(
      section: ProfileSection.privacy,
      children: [
        line(
          BimbiIcons.alarm,
          'Alarms are scheduled on this device and ring without internet.',
        ),
        line(
          BimbiIcons.gps,
          'Location is used only while you walk, and stays on this device.',
        ),
        line(
          BimbiIcons.bedtime,
          'Sleep entries are self-reported, never measured or diagnosed.',
        ),
        line(
          BimbiIcons.bell,
          'Bimbi asks for each permission only when you use the feature.',
        ),
        line(
          BimbiIcons.profile,
          'Verified accounts sync their profile name and photo. A cached photo '
          'can be used on this device for up to seven days. Signing out clears '
          'your local profile data.',
        ),
      ],
    );
  }
}

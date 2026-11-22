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
import '../../payments/payment_adapter.dart';

enum ProfileSection {
  account('Account', 'Sign-in and verification', BimbiIcons.profile),
  appearance('Appearance', 'Name, theme and buddy', BimbiIcons.palette),
  permissions('Permissions', 'Alarms and device access', BimbiIcons.lock),
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
  ProfileSection.plans => const PlansSection(),
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
            onSelect: ref.read(profileSectionProvider.notifier).select,
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
          onSelect: (section) => Navigator.of(context).push(
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
    final name = ref.watch(displayNameProvider);
    final shown = name.isNotEmpty
        ? name
        : (user?.displayName?.isNotEmpty == true
              ? user!.displayName!
              : 'Hello there');
    final photo = user?.photoURL;
    final c = context.bimbi;
    return BimbiCard(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Row(
        children: [
          if (photo != null)
            Semantics(
              image: true,
              label: 'Profile photo',
              child: CircleAvatar(
                radius: 36,
                backgroundImage: NetworkImage(photo),
                backgroundColor: c.accentTint,
              ),
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(color: c.card, shape: BoxShape.circle),
              child: const BimbiBuddy(size: 80, glow: false),
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
    final user = ref.watch(sessionProvider).asData?.value;
    final ready = ref.watch(firebaseReadyProvider);
    final busy = ref.watch(operationProvider).busy;
    final op = ref.read(operationProvider.notifier);
    VoidCallback? run(Future<String> Function() action, {bool when = true}) =>
        ready && when && !busy ? () => op.run(action) : null;

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
              return 'Session refreshed.';
            }),
            child: const Text('Refresh status'),
          ),
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

class AppearanceSection extends ConsumerStatefulWidget {
  const AppearanceSection({super.key});
  @override
  ConsumerState<AppearanceSection> createState() => _AppearanceSectionState();
}

class _AppearanceSectionState extends ConsumerState<AppearanceSection> {
  late final TextEditingController _name = TextEditingController(
    text: ref.read(displayNameProvider),
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final buddy = ref.watch(buddyColorProvider);
    return _SectionCard(
      section: ProfileSection.appearance,
      children: [
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
        const SectionLabel('Buddy colour'),
        Row(
          children: [
            const BimbiBuddy(size: 72, glow: false, mood: BuddyMood.excited),
            const SizedBox(width: BimbiSpace.sm),
            Expanded(
              child: BuddyColorPicker(
                value: buddy,
                onChanged: ref.read(buddyColorProvider.notifier).set,
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

class PlansSection extends ConsumerWidget {
  const PlansSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(firebaseReadyProvider);
    final user = ref.watch(sessionProvider).asData?.value;
    final busy = ref.watch(operationProvider).busy;
    final canPay = ready && user?.emailVerified == true && !busy;
    VoidCallback? checkout(String plan) => canPay
        ? () => ref
              .read(operationProvider.notifier)
              .run(() => ref.read(paymentAdapterProvider).checkout(plan))
        : null;
    final window = WindowScope.of(context);
    final cards = [
      const PlanCard(
        name: 'Free',
        price: r'MX$0',
        period: 'forever',
        current: true,
        features: ['Alarms with safe dismissal', 'Sleep diary', 'Focus timer'],
      ),
      PlanCard(
        name: 'Plus',
        price: r'MX$10',
        period: 'test payment',
        featured: true,
        features: const ['Everything in Free', 'Wake-up missions'],
        actionLabel: 'Try Plus',
        onPressed: checkout('plus'),
      ),
      PlanCard(
        name: 'Premium',
        price: r'MX$20',
        period: 'test payment',
        features: const ['Everything in Plus', 'All buddy colours'],
        actionLabel: 'Try Premium',
        onPressed: checkout('premium'),
      ),
    ];
    return _SectionCard(
      section: ProfileSection.plans,
      children: [
        const InlineBanner(
          icon: BimbiIcons.card,
          title: 'Test mode',
          message: 'Stripe sandbox only. No real charges and no paid access.',
        ),
        if (!canPay && !busy)
          Text(
            'Sign in with a verified email to try a test checkout.',
            style: context.text.bodySmall,
          ),
        if (window.isCompact)
          ...cards
        else
          LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth >= 640 ? 3 : 2;
              final width =
                  (box.maxWidth - BimbiSpace.sm * (columns - 1)) / columns;
              return Wrap(
                spacing: BimbiSpace.sm,
                runSpacing: BimbiSpace.sm,
                children: [
                  for (final card in cards) SizedBox(width: width, child: card),
                ],
              );
            },
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
      ],
    );
  }
}

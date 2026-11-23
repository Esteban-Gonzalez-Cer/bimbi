import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_system/design_system.dart';
import '../../../app/shell/layout.dart';
import '../../../core/clock.dart';
import '../../../core/operation.dart';
import '../../../data/repositories/collection_sync.dart';
import '../../../data/repositories/entitlement_repository.dart';
import '../../../domain/models/plan.dart';
import '../../../features/auth/auth_adapter.dart';
import '../../../features/payments/payment_adapter.dart';

Future<void> openPlans(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const PlansScreen()));

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
String _date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// What each plan offers. Core features stay free; paid passes add extras.
const _perks = {
  PlanTier.free: [
    'Alarms with wake-up challenges',
    'Sleep diary and Focus',
    'Focus shield and Running',
  ],
  PlanTier.plus: [
    'Everything in Free',
    '3 extra buddy colours',
    '2 extra alarm tones',
  ],
  PlanTier.premium: [
    'Everything in Plus',
    'Sunrise colour theme',
    'Premium badge',
  ],
};
const _price = {PlanTier.plus: r'MX$10', PlanTier.premium: r'MX$20'};

/// Plans: the current pass, the three plans, restore and test receipts.
/// Stripe's own PaymentSheet collects card details; Bimbi never sees them,
/// and only the server can turn on a plan.
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  static const _pad = EdgeInsets.fromLTRB(20, 8, 20, 32);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final left = <Widget>[
      const _CurrentPlan(),
      const InlineBanner(
        icon: BimbiIcons.card,
        title: 'Test mode',
        message:
            'Stripe sandbox only: use Stripe test cards. No real charges, '
            'and plans are 30-day test passes.',
      ),
      const _Receipts(),
    ];
    const right = <Widget>[
      _PlanCard(tier: PlanTier.free),
      _PlanCard(tier: PlanTier.plus),
      _PlanCard(tier: PlanTier.premium),
    ];
    Widget column(List<Widget> children, {EdgeInsets pad = _pad}) =>
        ListView.separated(
          padding: pad,
          itemCount: children.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (_, i) => children[i],
        );
    final expanded = WindowScope.of(context).isExpanded;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const BimbiIcon(BimbiIcons.chevronLeft),
        ),
        title: Text(
          'Plans',
          key: PageHeader.titleKey,
          style: context.text.headlineSmall,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: expanded ? 1100 : 560),
            child: expanded
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: column(left)),
                      Expanded(child: column(right)),
                    ],
                  )
                : column([...left.take(2), ...right, left.last]),
          ),
        ),
      ),
    );
  }
}

class _CurrentPlan extends ConsumerWidget {
  const _CurrentPlan();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final tier = ref.watch(planTierProvider);
    final entitlement = ref.watch(entitlementProvider).value;
    final now = ref.watch(clockProvider)();
    final signedIn = ref.watch(syncAccountProvider) != null;
    final busy = ref.watch(operationProvider).busy;
    final night = Theme.of(context).brightness == Brightness.dark;
    final fg = night ? c.onNight : c.onAccentTint;
    final muted = night ? c.onNightMuted : c.textMuted;
    final expired = entitlement != null && !entitlement.activeAt(now);
    final detail = switch (tier) {
      PlanTier.free when expired =>
        'Your ${entitlement.tier.label} pass ended on ${_date(entitlement.expiresAt)}.',
      PlanTier.free => 'Every core feature is free.',
      _ => 'Active until ${_date(entitlement!.expiresAt)}',
    };
    return BimbiCard(
      color: night ? c.night : c.accentTint,
      borderColor: night ? c.cardBorder : c.accentTint,
      padding: const EdgeInsets.all(BimbiSpace.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel('Your plan', color: muted),
                const SizedBox(height: 2),
                Text(
                  tier.label,
                  style: context.text.headlineLarge?.copyWith(
                    fontSize: 36,
                    height: 1.08,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: context.text.bodyMedium?.copyWith(color: muted),
                ),
                const SizedBox(height: BimbiSpace.sm),
                if (!signedIn)
                  Text(
                    'Sign in with a verified email (Profile › Account) to '
                    'try a test pass.',
                    style: context.text.bodyMedium?.copyWith(color: fg),
                  )
                else
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: c.link,
                    ),
                    onPressed: busy
                        ? null
                        : () => ref
                              .read(operationProvider.notifier)
                              .run(
                                () =>
                                    ref.read(paymentAdapterProvider).restore(),
                              ),
                    child: const Text('Restore purchases'),
                  ),
              ],
            ),
          ),
          const SizedBox(width: BimbiSpace.sm),
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: night
                  ? BimbiPalette.lavender.withValues(alpha: .12)
                  : BimbiPalette.lightBackground.withValues(alpha: .68),
            ),
            child: BimbiBuddy(
              size: 84,
              mood: tier == PlanTier.free ? BuddyMood.happy : BuddyMood.excited,
              glow: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.tier});
  final PlanTier tier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final current = ref.watch(planTierProvider);
    final user = ref.watch(sessionProvider).asData?.value;
    final ready = ref.watch(firebaseReadyProvider);
    final busy = ref.watch(operationProvider).busy;
    final canPay = ready && user?.emailVerified == true && !busy;
    final isCurrent = current == tier;
    final covered = current.includes(tier) && !isCurrent;
    final recommended = tier == PlanTier.plus && current == PlanTier.free;

    final String? action = switch (tier) {
      PlanTier.free => null,
      _ when isCurrent => 'Renew 30 days',
      _ when covered => null,
      PlanTier.premium when current == PlanTier.plus => 'Upgrade to Premium',
      _ => 'Get ${tier.label}',
    };
    void buy() => ref
        .read(operationProvider.notifier)
        .run(() => ref.read(paymentAdapterProvider).checkout(tier.name));

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BimbiRadius.cardBorder,
        border: Border.all(
          color: isCurrent || recommended
              ? Theme.of(context).colorScheme.primary
              : c.card,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: BimbiSpace.sm,
            runSpacing: 6,
            children: [
              Semantics(
                header: true,
                child: Text(
                  tier.label,
                  style: context.text.titleLarge?.copyWith(fontSize: 24),
                ),
              ),
              if (isCurrent)
                const StatusPill('Current plan', tone: PillTone.success)
              else if (covered)
                const StatusPill('Included')
              else if (recommended)
                const StatusPill('Recommended', tone: PillTone.accent),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            tier == PlanTier.free
                ? 'Free forever'
                : '${_price[tier]} · 30 days · test',
            style: context.text.labelLarge?.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: BimbiSpace.sm),
          for (final perk in _perks[tier]!)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: BimbiIcon(BimbiIcons.check, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(perk, style: context.text.bodyMedium)),
                ],
              ),
            ),
          if (action != null) ...[
            const SizedBox(height: BimbiSpace.xs),
            isCurrent
                ? OutlinedButton(
                    onPressed: canPay ? buy : null,
                    child: Text(action),
                  )
                : FilledButton(
                    onPressed: canPay ? buy : null,
                    child: Text(action),
                  ),
          ],
        ],
      ),
    );
  }
}

class _Receipts extends ConsumerWidget {
  const _Receipts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.bimbi;
    final receipts = ref.watch(receiptsProvider).value ?? const [];
    if (receipts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 10),
          child: Semantics(
            header: true,
            child: Text('Test receipts', style: context.text.headlineSmall),
          ),
        ),
        for (final r in receipts.take(10)) ...[
          MergeSemantics(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: const BorderRadius.all(Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r.plan.label} · 30 days',
                          style: context.text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${_date(r.verifiedAt)} · test payment',
                          style: context.text.bodyMedium?.copyWith(
                            color: c.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${r.currency == 'MXN' ? r'MX$' : '${r.currency} '}'
                    '${(r.amountMinor / 100).toStringAsFixed(2)}',
                    style: context.text.titleLarge?.copyWith(fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

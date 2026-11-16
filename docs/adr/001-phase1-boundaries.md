# ADR-001: Phase 1 feasibility boundaries
Date: 2026-11-16. Status: accepted by implementation plan; device results recorded separately.

## Context
A default Flutter starter must establish Android feasibility in a short university deadline. Services are initially unconfigured. The available physical device is a Galaxy Tab A9.

## Decision
Native Kotlin owns one persisted experimental AlarmManager schedule and alert/dismissal. Choose SCHEDULE_EXACT_ALARM with explicit user grant rather than USE_EXACT_ALARM. Use feature-based Riverpod adapters and an offline-capable debug shell. Use SDK-resolved dependency versions in committed lockfiles, with Flutter 3.47.5 pinned. Defer generator use and product-wide persistence choice to Phase 3; native alarm preferences and local payment attempt IDs suffice for these bounded experiments.

Use standard Material 3 navigation at <600 / 600–839 / >=840 logical pixels. Wider content is constrained, with the same routes. Defer two-pane product editors and final art/font to Phase 2.

Use Stripe test-only HTTPS Functions, explicit verified authentication, fixed synthetic MXN prices and server-side retrieval. Keep all cloud data locked except the scoped probe. Usage Access remains optional. No game module is created.

## Alternatives
A Flutter timer cannot survive a stopped process. Cloud-triggered alarms depend on delivery/network. Client-only paid flags cannot prove a payment. A broad unlocked Firebase development database would invalidate security evidence.

## Consequences and review
Manifest adds alarm, boot, foreground audio, notifications, usage and foreground location permissions. Native service and receiver are unexported. Full-screen access is checked separately. Test audio is capped at two minutes. Review these declarations before release.

Revisit if target SDK/plugin compatibility changes, recurrence evolves to local-wall-clock/DST semantics, background GPS is requested, or real billing/store distribution enters scope. Record physical evidence before broadening reliability claims.

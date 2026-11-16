# Observed toolchain — 2026-11-16

- Flutter stable 3.47.5, revision 6a19cca564; Dart 3.13.4. `.fvmrc` pins Flutter. Global SDK used for this run; FVM itself was not installed during validation.
- Android Gradle Plugin 9.1.0, Gradle wrapper 9.3.1, Kotlin plugin declaration 2.4.0; Java 21.0.10 from installed Android Studio. Java/Kotlin target 17.
- compileSdk/targetSdk 36, minSdk 26. Installed API 34/35/36/36.1 SDKs.
- App ID/namespace com.bimbi.app. Debug APK signing only.
- Backend target Node 22; initial backend tests used Node 26.4.0; final 11 backend tests also passed on Node 22.23.5. Firebase emulators ran with bundled Node 24.22.1 and JDK 21. CI pins Node 22; hosted CI has not run.
- `pubspec.lock` and both npm package-lock files record exact resolved dependencies. Dependencies were resolved from their registries and a combined Android APK built successfully.

## Compatibility observations

Flutter reports that several FlutterFire plugins still apply the Kotlin Gradle Plugin and a future Flutter version will require migration to built-in Kotlin. Current pinned build passes; do not upgrade Flutter mid-phase without rerunning native/cloud tests. Some Android dependencies print Java 8/deprecated API warnings. The build also reports an SDK XML parser/version warning; no compile failure occurred.

Firebase emulator tools initially pulled a vulnerable gRPC version. A patched compatible override was added and rule tests rerun. Remaining development-tool advisories are recorded in the Phase 1 report. Payment backend dependencies audited with zero reported vulnerabilities at installation.

# Bimbi · Alarm sounds and snoozes

## Set a sound for an alarm

1. In **Alarms**, edit an existing alarm or tap **Add alarm**. Under **Alarm sound**, choose Android's default alarm sound or one of Bimbi's four bundled tones. **Dawn Chime**, **Soft Bells**, **Morning Pulse**, and **Bright Signal** work offline.
2. Set **Alarm volume** from 20% to 100%, then choose a **Sound intensity**. The five levels are **Softest**, **Normal**, **Noisy**, **Heavy**, and **Jackhammer**. **Normal** is the default. **Noisy** matches the boost from the first sound update.
3. Tap **Preview sound** to listen for up to three seconds with the selected settings. Tap **Save alarm** to keep them.

The Flutter editor sends the settings through the platform adapter. The Android store saves the tone, volume, and intensity for each alarm and each occurrence. Older alarms without sound settings use Android's default tone at 100% with **Normal** intensity. Alarms saved with the earlier boost switch enabled use **Noisy**. All four WAV files can be regenerated from the synthesis script. [Flutter editor](../../../lib/features/alarm/presentation/alarm_editor.dart) · [Platform adapter](../../../lib/core/platform.dart) · [Android store](../../../android/app/src/main/kotlin/com/bimbi/app/AlarmStore.kt) · [Sound generator](../../../scripts/generate_alarm_sounds.py)

The preview and ringing alarm share the same playback code. **Softest** lowers the player's volume. **Noisy**, **Heavy**, and **Jackhammer** use progressively stronger settings on Android's loudness effect. Android's alarm volume and the output device govern the final loudness. When an output cannot apply the effect, the preview reports it and the alarm can ring at the selected volume. [Android playback code](../../../android/app/src/main/kotlin/com/bimbi/app/AlarmAudio.kt) · [Android volume control](https://developer.android.com/media/platform/output) · [Android LoudnessEnhancer](https://developer.android.com/reference/android/media/audiofx/LoudnessEnhancer)

## Two snoozes per scheduled occurrence

The alarm model creates a new occurrence with two snoozes at each scheduled time. When the user taps **Snooze 5 min**, the engine schedules that same occurrence for five minutes later. When it returns, it keeps its tone, volume, intensity, and remaining snoozes. The challenge reopens at round one. [Alarm model](../../../android/app/src/main/kotlin/com/bimbi/app/LocalAlarm.kt) · [Alarm engine](../../../android/app/src/main/kotlin/com/bimbi/app/AlarmEngine.kt)

A 7:00 a.m. alarm that repeats on Monday and Tuesday starts with two snoozes each morning. Using both snoozes and completing Monday's challenge leaves Tuesday's counter ready at two. Any other alarm that rings while Monday's alarm is snoozed has two of its own.

## Verification

- `./scripts/check.sh` passed formatting, analysis, 71 Flutter tests, 12 Android JVM tests, 13 test-server checks, 11 Firebase emulator checks, and the debug build. The editor test exercises preview, save, and reopen at 360 dp and 200% text, with **Jackhammer** selected. The Android test covers the Monday and Tuesday schedule at 7:00, the two-snooze limit, and a second alarm's independent count.
- In a 412 dp Android emulator in airplane mode, a Monday alarm used both five-minute snoozes. A second alarm rang with two of its own while Monday's alarm was snoozed. Installing the final APK during the second snooze kept its deadline and migrated its saved boost to **Noisy**. When it rang again, the remaining count was zero and the third snooze stayed unavailable. After completing the challenge, advancing the emulator clock to Tuesday produced a new 7:00 a.m. ring with two snoozes.
- The Galaxy Tab A9 owner confirmed that **Soft Bells** sounded louder at 100% than at 25%. After installing the final APK, the owner previewed the five named levels at a fixed volume and confirmed they sounded in order from **Softest** to **Jackhammer**.
- `apksigner verify --verbose` verified the debug signature. APK SHA-256 `8e9cb63ac75d8a7bc35c10efcf919ca83dda103c97c3c911758662b96cec9d56`. [Installable APK](../../../build/review/bimbi-phase4-sounds-debug.apk)

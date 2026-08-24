/// Settings-gate test (D8): device preferences persist through
/// SharedPreferences, and the audio/haptics services consult those flags
/// before ever touching a platform channel. Ends with the asset-integrity
/// check that every sfx listed in AudioService.init() ships as a valid WAV.
library;

import 'dart:io';

import 'package:flame_audio/bgm.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:starcade/core/services/audio_service.dart';
import 'package:starcade/core/services/haptics_service.dart';
import 'package:starcade/core/services/settings_service.dart';

/// Minimal Bgm stub installed via `FlameAudio.bgmFactory` — flame_audio's own
/// documented testing hook. Records whether AudioService actually told the
/// background-music player to play/stop, without ever constructing the real
/// AudioPlayer (which would need a plugin channel).
class _StubBgm implements Bgm {
  bool playCalled = false;
  bool stopCalled = false;

  @override
  Future<void> play(String fileName, {double volume = 1, String? package}) async {
    playCalled = true;
  }

  @override
  Future<void> stop() async {
    stopCalled = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final bgm = _StubBgm();
  setUpAll(() {
    // One stub, installed before any test touches FlameAudio.bgm (which is a
    // `static final`, cached on first access) so every music test spies the
    // same instance instead of a per-test factory being ignored.
    FlameAudio.bgmFactory = ({required AudioCache audioCache}) => bgm;
  });

  group('SettingsService', () {
    test('defaults: sound/music/haptics on, reduceMotion off', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final s = SettingsService(prefs);

      expect(s.state.soundEnabled, isTrue);
      expect(s.state.musicEnabled, isTrue);
      expect(s.state.hapticsEnabled, isTrue);
      expect(s.state.reduceMotion, isFalse);

      s.load(); // empty prefs fall back to the same defaults
      expect(s.state.soundEnabled, isTrue);
      expect(s.state.musicEnabled, isTrue);
      expect(s.state.hapticsEnabled, isTrue);
      expect(s.state.reduceMotion, isFalse);
    });

    test('setSoundEnabled updates state, persists, and notifies', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final s = SettingsService(prefs)..load();
      var notified = 0;
      s.addListener(() => notified++);

      await s.setSoundEnabled(false);

      expect(s.state.soundEnabled, isFalse);
      expect(notified, 1);
      // Value lives in the prefs store, not just in memory.
      final readBack = await SharedPreferences.getInstance();
      expect(readBack.getBool('settings.sound'), isFalse);
    });

    test('setMusicEnabled updates state, persists, and notifies', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final s = SettingsService(prefs)..load();
      var notified = 0;
      s.addListener(() => notified++);

      await s.setMusicEnabled(false);

      expect(s.state.musicEnabled, isFalse);
      expect(notified, 1);
      final readBack = await SharedPreferences.getInstance();
      expect(readBack.getBool('settings.music'), isFalse);
    });

    test('setHapticsEnabled updates state, persists, and notifies', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final s = SettingsService(prefs)..load();
      var notified = 0;
      s.addListener(() => notified++);

      await s.setHapticsEnabled(false);

      expect(s.state.hapticsEnabled, isFalse);
      expect(notified, 1);
      final readBack = await SharedPreferences.getInstance();
      expect(readBack.getBool('settings.haptics'), isFalse);
    });

    test('setReduceMotion updates state, persists, and notifies', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final s = SettingsService(prefs)..load();
      var notified = 0;
      s.addListener(() => notified++);

      await s.setReduceMotion(true);

      expect(s.state.reduceMotion, isTrue);
      expect(notified, 1);
      final readBack = await SharedPreferences.getInstance();
      expect(readBack.getBool('settings.reduce_motion'), isTrue);
    });

    test('roundtrip: a fresh instance load() reads the persisted values back',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final a = SettingsService(prefs)..load();
      await a.setSoundEnabled(false);
      await a.setMusicEnabled(false);
      await a.setHapticsEnabled(false);
      await a.setReduceMotion(true);

      final b = SettingsService(prefs)..load();
      expect(b.state.soundEnabled, isFalse);
      expect(b.state.musicEnabled, isFalse);
      expect(b.state.hapticsEnabled, isFalse);
      expect(b.state.reduceMotion, isTrue);
    });
  });

  group('AudioService settings gate', () {
    test('sound disabled: playSfx returns before any platform call', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs)..load();
      await settings.setSoundEnabled(false);
      final audio = AudioService(settings);

      expect(() => audio.playSfx('ui_click.wav'), returnsNormally);
    });

    test('music disabled: playMusic never touches the bgm player', () async {
      bgm.playCalled = false;
      bgm.stopCalled = false;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs)..load();
      await settings.setMusicEnabled(false);
      final audio = AudioService(settings);

      audio.playMusic('bgm_hub.wav');

      // The gate held: the (spied) bgm player was never asked to play.
      expect(bgm.playCalled, isFalse);
    });

    test('music enabled: playMusic does reach the bgm player', () async {
      bgm.playCalled = false;
      bgm.stopCalled = false;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs)..load(); // music enabled default
      final audio = AudioService(settings);

      audio.playMusic('bgm_hub.wav');

      expect(bgm.playCalled, isTrue);
    });

    test('disabling music after construction does not throw (listener wiring)',
        () async {
      bgm.playCalled = false;
      bgm.stopCalled = false;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs)..load(); // music starts enabled
      // Constructing registers the settings listener — the wiring under test.
      AudioService(settings);

      await settings.setMusicEnabled(false);

      expect(settings.state.musicEnabled, isFalse);
      // The listener forwarded the disable to the (stubbed) background music.
      expect(bgm.stopCalled, isTrue);
    });
  });

  group('HapticsService settings gate', () {
    test('haptics disabled: trigger sends nothing on the platform channel',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs)..load();
      await settings.setHapticsEnabled(false);
      final haptics = HapticsService(settings);

      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform,
              (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      haptics.trigger(HapticType.light);
      haptics.trigger(HapticType.warning);

      expect(calls, isEmpty, reason: 'the gate must block every channel call');
    });

    test('haptics enabled: trigger does reach the platform channel',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService(prefs)..load(); // haptics enabled default
      final haptics = HapticsService(settings);

      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform,
              (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance
          .defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      haptics.trigger(HapticType.light);

      expect(calls, isNotEmpty,
          reason: 'with haptics on, HapticFeedback must reach the channel');
    });
  });

  group('asset integrity (sfx listed in AudioService)', () {
    test('every sfxAssets filename exists and is a valid non-empty WAV', () {
      // Derived from AudioService.sfxAssets — the same list init() loads — so
      // a divergence between the init list and shipped assets fails here.
      final sfx = AudioService.sfxAssets;

      for (final name in sfx) {
        final file = File('assets/audio/$name');
        expect(file.existsSync(), isTrue,
            reason: '$name is referenced by AudioService.init()');
        final bytes = file.readAsBytesSync();
        expect(bytes.length, greaterThanOrEqualTo(12),
            reason: '$name is empty/truncated — a WAV needs at least the '
                '12-byte RIFF/WAVE header');
        expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF',
            reason: '$name is not a RIFF container');
        expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE',
            reason: '$name is not a WAVE file');
      }
    });
  });
}

# Claw Phone — Project Guide

## What This Is
Native iOS Swift voice assistant app. User speaks, app transcribes via on-device SFSpeechRecognizer, streams to an OpenAI-compatible LLM (OpenClaw gateway), synthesizes response via ElevenLabs TTS, plays audio, and loops back to listening. Supports barge-in (interrupt assistant mid-speech).

## Tech Stack
- **iOS 17+**, **SwiftUI**, **Swift 5**
- Zero third-party dependencies — all Apple frameworks (AVFoundation, Speech, Security, Foundation)
- Xcode 16 with `PBXFileSystemSynchronizedRootGroup` (auto-discovers .swift files from disk)

## Project Structure
```
ClawPhone/ClawPhone/
├── ClawPhoneApp.swift              — App entry point
├── Models/
│   ├── VoiceLoopState.swift        — State enum: idle/listening/processing/speaking/error
│   └── Message.swift               — Chat message struct
├── Services/
│   ├── AudioManager.swift          — Single AVAudioSession/AVAudioEngine, playback, VAD
│   ├── SpeechRecognizer.swift      — SFSpeechRecognizer wrapper with silence detection
│   ├── ChatService.swift           — LLM SSE streaming via URLSession.bytes
│   ├── TTSService.swift            — ElevenLabs REST API
│   └── KeychainHelper.swift        — Raw Security framework CRUD
├── ViewModels/
│   ├── VoiceLoopManager.swift      — State machine orchestrator (the brain)
│   └── SettingsManager.swift       — @Observable, credentials via Keychain
└── Views/
    ├── HomeView.swift              — Main conversation UI
    ├── SettingsView.swift          — Credential entry form
    └── MessageBubbleView.swift     — Chat bubble component
```

## Architecture Decisions
- **One AVAudioSession, configured once** — never reconfigure mid-conversation (Bug #1 from Flutter)
- **One AVAudioEngine** — shared between STT input tap, VAD monitoring, and playback
- **VAD for barge-in, not STT** — RMS level monitoring during playback, STT only after playback stops (Bug #7)
- **Sentence pipelining** — TTS fires per-sentence as LLM streams, played in order (Bug #4)
- **URLSession.bytes.lines** — handles SSE TCP chunk buffering automatically (Bug #3)
- **Keychain for credentials** — no UserDefaults for secrets

## Key Constants
- Silence timeout: 4 seconds
- VAD threshold: -40 dB, sustained 200ms
- STT stale callback grace period: 1.5 seconds
- LLM history window: last 10 messages
- LLM model: "main", max_tokens: 500, temperature: 0.7
- TTS model: eleven_turbo_v2_5
- Default voice ID: cgSgspJ2msm6clMCkdW9 (Jessica)

## Building
Open `ClawPhone/ClawPhone.xcodeproj` in Xcode. Must run on a **physical iOS 17+ device** (mic + speaker required). Simulator won't work for voice features.

## Known Bug Mitigations
See `SWIFT_REWRITE_GUIDE.md` Section 12 for full details on bugs #1-#7 from the Flutter version and where each is handled in the Swift code.

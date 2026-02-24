# Claw Phone

A voice-first conversational assistant for iOS. Tap a button, speak naturally, and get spoken responses from an LLM — with support for interrupting the assistant mid-speech.

## How It Works

1. **You speak** — on-device speech recognition transcribes your voice
2. **LLM thinks** — your message streams to an OpenAI-compatible API (OpenClaw gateway)
3. **Assistant speaks** — the response is synthesized via ElevenLabs and played back
4. **Loop** — automatically returns to listening after the response finishes
5. **Barge-in** — start talking while the assistant speaks and it stops to listen

## Requirements

- iOS 17.0+
- Physical device (mic + speaker required)
- Xcode 16+
- An OpenAI-compatible LLM API endpoint (gateway URL + token)
- An ElevenLabs API key

## Setup

1. Clone the repo
2. Open `ClawPhone/ClawPhone.xcodeproj` in Xcode
3. Select your physical device as the build target
4. Build and run
5. On first launch, the Settings screen opens — enter your credentials:
   - **Gateway URL** — your OpenAI-compatible API base URL (e.g. `https://your-gateway.example.com`)
   - **Gateway Token** — your API bearer token
   - **ElevenLabs API Key** — from your ElevenLabs account
   - **ElevenLabs Voice ID** — defaults to Jessica (`cgSgspJ2msm6clMCkdW9`)

## Architecture

```
┌─────────────────────────────────────────────┐
│              VoiceLoopManager               │
│         (state machine orchestrator)        │
├─────────┬───────────┬───────────┬───────────┤
│  Speech │   Chat    │    TTS    │   Audio   │
│Recognizer│  Service  │  Service  │  Manager  │
│  (STT)  │  (LLM)   │(ElevenLabs)│(Engine)  │
└─────────┴───────────┴───────────┴───────────┘
```

**State machine:** `idle` → `listening` → `processing` → `speaking` → `listening` → ...

**Sentence pipelining:** TTS requests fire per-sentence as the LLM streams tokens, so audio playback starts before the full response is generated.

**Barge-in:** During playback, RMS-based voice activity detection monitors the mic (with echo cancellation filtering out speaker output). When speech is detected, playback stops and the app returns to listening.

## Tech Stack

- **SwiftUI** for UI
- **AVFoundation** — `AVAudioEngine`, `AVAudioSession`, `AVAudioPlayer`
- **Speech** — `SFSpeechRecognizer` with on-device recognition
- **Security** — Keychain for credential storage
- **Foundation** — `URLSession` for HTTP/SSE streaming

Zero third-party dependencies.

## License

Private project.

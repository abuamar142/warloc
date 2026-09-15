<div align="center">

# Warloc

**Your chats survived the ban. Your memories didn't disappear.**

A local WhatsApp & Telegram chat backup and viewer for Android.

---

</div>

## The Problem

WhatsApp bans accounts. Sometimes unjustly. Sometimes without warning.

When it happens, your chat history — years of conversations, memories, important information — vanishes. WhatsApp's built-in export gives you an unreadable `.txt` file that nobody actually opens.

**Warloc exists because your data should be yours.**

## What It Does

Warloc turns those forgotten export files into something actually useful — a clean, searchable, browsable archive of your conversations. Everything stays on your device. No cloud. No accounts. No tracking.

<div align="center">

| | |
|---|---|
| 📱 **Import** | WhatsApp `.txt` (Android & iOS) and Telegram JSON exports |
| 💬 **Read** | Clean message bubbles with timestamps and date grouping |
| 🔍 **Search** | Find any message across all your conversations |
| 🖼️ **Media** | Browse images, play videos and audio from your chats |
| 🔒 **Lock** | PIN, fingerprint, or face unlock to protect your archive |
| 💾 **Backup** | Export and restore your archive in compact WAL format |
| ⚡ **Quick Share** | Send chats directly from WhatsApp to Warloc via share menu |

</div>

## How It Works

```
WhatsApp  →  Export Chat  →  Open in Warloc  →  Browse & Search
```

1. Open WhatsApp → select a chat → ⋮ → More → Export chat
2. Share the `.txt` file to Warloc, or open it directly
3. Your conversation is parsed, indexed, and ready to read

That's it. No setup wizard. No login. No servers.

## Getting Started

```bash
git clone git@github.com:abuamar142/warloc.git
cd warloc
flutter pub get
flutter run
```

> Requires Flutter `^3.11.0` · Android API 21+

<div align="center">

---

### Built with

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)

---

*Your data. Your device. Your control.*

</div>

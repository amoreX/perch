# Perch — Project Documentation

> Reference doc for rebuilding the marketing site. Covers product, design, copy, features, audience, and tech.

---

## What Is Perch

Perch is a macOS app that lives in the physical notch on a MacBook. When you hover near the notch, it drops down into a compact interface — part ambient dashboard, part AI assistant, part system monitor.

It started as a way to watch delegated AI agent tasks run without switching windows. It's evolved into something broader: a place where everything ambient about your machine sits one hover away.

**Tagline:** *The notch is now a command center.*

**One-liner:** AI agents, Claude chat, scheduled tasks, system stats, music, calendar — all from your MacBook notch.

---

## Brand

- **Name:** Perch
- **Old name (internal/codebase):** Danotch — do not use in any user-facing copy
- **Aesthetic:** Dark, Nothing-inspired. OLED-black. Monospaced type. Minimal. No decoration that doesn't carry meaning.
- **Accent color:** `#8B7CF6` — soft muted purple. This is the real app accent, drive the site from this.
- **Active accent (glass tint):** `#3D3270` — dim purple used on active glass buttons
- **Note:** The old site used `#E53935` red — that was the pre-rebrand design, do not use it.
- **Tone:** Technical but not jargon-heavy. Direct. Confident. Low hype. No exclamation points. Writes like a developer who built something they actually use.

---

## Target Audience

- macOS power users, primarily developers
- People running AI coding agents (Claude Code, Cursor, Codex, Windsurf)
- People who want ambient system awareness without context-switching
- MacBook Pro / MacBook Air users with the physical notch (M-series)
- Technically comfortable; will appreciate specificity and accuracy over marketing fluff

---

## Core Features (in priority order)

### 1. AI Agent Monitor
Watch every Claude Code session running on your Mac in real time. Perch reads the session JSONL directly, so it knows the project name, the last thing you asked, the current tool being used (reading a file, running a command, searching, thinking), and the exact file or command involved. Click a session row to bring that terminal to the front.

- **Live states:** Thinking (yellow), Tool Use (orange + tool name/detail), Responding (green), Waiting for user (silent), Idle
- **Detection:** Scans `ps` every 3s, enriches with `~/.claude/sessions/{pid}.json` and JSONL conversation files
- **Grouped display** with collapsible sections when multiple sessions exist
- Currently Claude Code only (Cursor/Windsurf/Codex don't expose prompt data in a readable way)

### 2. Chat That Does Things
The notch has a chat bar. Type into it and it hits a backend running a real tool-use loop. It can:
- Execute shell commands on your machine (`bash_execute`)
- Search the web (DuckDuckGo, no API key needed) (`web_search`)
- Fetch and parse URLs (`web_fetch`)
- Manage scheduled tasks via natural language
- If you've connected Gmail, Calendar, Docs, or GitHub: read and act on those

When Claude needs access to an app it doesn't have, it asks right in the chat — a CONNECT / DENY button appears as a chat bubble.

**Keyboard shortcut:** `⌘⇧Space` drops the notch and focuses the chat input from anywhere.

### 3. Scheduled Tasks
Ask Claude to do something on a schedule using natural language. The scheduler:
- Runs on the backend, ticks every 30 seconds
- Supports cron expressions and interval-based scheduling
- Has two notification modes:
  - **Silent:** Saves output to the task row. You see it by expanding on HOME tab.
  - **Notify:** Pushes a notification. Conditional tasks ("tell me when AAPL drops below $200") only fire when the condition is true — Claude evaluates it each run.
- Supports: `bash_execute`, `web_search`, `web_fetch`
- Does NOT have full tool-use loop (no Composio in scheduled runs, by design)

### 4. Peek Notifications
When a scheduled task has something worth saying, the notch expands slightly — not a full drop-down, just a peek. It shows the headline. Hover to read the body. Ignore it and it auto-dismisses in 4 seconds.

Notifications are grouped by source task in the notifications panel.

### 5. System Stats
A bento-style dashboard of system metrics:
- CPU: Arc gauge (tick-mark ring, 36 ticks, 270° sweep) + sparkline history
- RAM: Same format as CPU
- Network: Stepped oscilloscope-style graph for up and down
- Disk: Ring gauge showing used/total
- Process count, uptime
- Full sortable process table (CPU, MEM, name) with app icons and kill actions

Stats update every 2 seconds via Mach APIs.

### 6. Pinnable Widgets
Pin up to 3 widgets to the home view left column. Options:
- Calendar (compact strip or full grid)
- Apple Music (mini or big, derived from widget count)
- RAM mini-view
- Disk mini-view
- Network (up/down)
- Uptime
- Process count

### 7. Apple Music
Polls Apple Music every 2 seconds via osascript. Shows track name, artist, album art, progress bar, playback controls. Two display modes (mini / big) derived from how many other widgets are pinned.

### 8. Bring Your Own Key (BYOK)
Users can use the server's default model or supply their own API key for:
- Anthropic (Claude)
- OpenAI (GPT)
- OpenRouter (any model on their catalog)

Keys are encrypted at rest with AES-256-GCM.

### 9. App Connections (Composio)
OAuth connections to third-party apps, managed via Composio:
- **Gmail**: Send, fetch, search emails
- **Google Calendar**: Create, read, update, delete events
- **Google Docs**: Read, create, update documents
- **GitHub**: Issues, PRs, repos, commits

---

## The Notch UI — View Structure

```
[collapsed]   Two wings: time (left) | count (right)

[expanded]    Black pill drops down. Top tabs: HOME · AGENTS · STATS · 🔔 · ⚙

HOME tab
├── Left column:  "Hi, {name}" / time / date / pinned widgets (up to 3)
└── Right column: Claude Code sessions, chat input bar, recent tasks, scheduled tasks

AGENTS tab
├── Claude Code session rows (grouped, collapsible)
├── Recent chat tasks (collapsible)
└── Thread history (past conversations from DB)

STATS tab
└── Bento grid: CPU, RAM, network, disk, process count, uptime, process list

NOTIFICATIONS tab
└── Grouped by source task, expandable rows, mark-read on expand

SETTINGS tab
└── Chat, Display, Agents, Providers, App Connections
```

**Collapse behavior:**
- 400ms grace period after mouse leaves
- Will NOT collapse if chat input is focused
- Will NOT collapse while in `agentChat` view if `keepOpenInChat` is enabled
- `Escape` collapses immediately

---

## Design System (App)

All tokens in `Theme.swift` under `enum DN`:

| Token | Value | Use |
|-------|-------|-----|
| `black` | `#000000` | OLED background |
| `surface` | `#111111` | Elevated surfaces |
| `surfaceRaised` | `#1A1A1A` | Cards, rows |
| `border` | `#222222` | Subtle borders |
| `borderVisible` | `#333333` | Visible dividers |
| `textDisabled` | `#666666` | Placeholder, disabled |
| `textSecondary` | `#999999` | Secondary labels |
| `textPrimary` | `#E8E8E8` | Body text |
| `textDisplay` | `#FFFFFF` | Headlines |
| `accent` | `#8B7CF6` | Soft purple, CTAs, active states |
| `activeAccent` | `#3D3270` | Dim purple, glass button tint |
| `success` | `#4A9E5C` | Completed, responding |
| `warning` | `#D4A843` | Running, thinking |
| `claudeOrange` | `#D97757` | Claude agent brand color |

**Typography:** Monospaced light for display, monospaced ALL CAPS with tracking for labels, system default for body.

**Spacing:** 8px base grid (`spaceSM=8`, `spaceMD=16`, `spaceLG=24`).

**Motion:** `easeOut` only, 0.2s micro / 0.35s transitions. No spring, no bounce.

---

## Design System (Site — current)

The current landing page (`V7Split.tsx`) mirrors the app design system in CSS:

- **Layout:** Fixed black left panel (~45vw, max 580px) + scrollable white right panel
- **Accent:** `#E53935` (red) — OLD, pre-rebrand. The real accent is `#8B7CF6` purple.
- **Typeface:** System sans for body; font-mono for the wordmark `DANOTCH`
- **Left panel behaviors:**
  - Initial: full headline + CTA buttons
  - After scrolling past the hero notch demo: switches to cycling feature card + embedded NotchDemo
- **Right panel sections:** Hero NotchDemo (autoplay), Features (horizontal list rows), How It Works (3 steps), Download CTA, Footer
- **Mobile:** Stacked layout, black hero, compact NotchDemo

**Current issues / why it's being remade:**
- The brand name is `DANOTCH` throughout but the app is now called **Perch**
- Generic split-layout treatment doesn't differentiate from other dev tool landing pages
- The interactive NotchDemo is heavy and doesn't communicate the product at first glance
- Features section is a plain horizontal list — doesn't show depth
- No real visual identity beyond the red accent and black/white split

---

## Copy (Current Site — For Reference)

**Headline:** The notch is now a command center.

**Subhead:** AI agents, Claude chat, scheduled tasks, system stats, music, calendar — all from your MacBook notch.

**Features:**
1. AI Agent Monitor — See every Claude Code, Cursor, and Codex session running on your Mac. Live state, current tool, project name.
2. Local Code Execution — Run bash commands, check files, execute scripts — all from the notch. Claude runs code directly on your machine.
3. Web Search — Search the web and fetch pages in real-time. Get current prices, news, weather — anything that needs fresh data.
4. Scheduled Tasks — Tell Claude to check your emails every morning or alert you when a stock hits a price. Natural language scheduling.
5. Smart Notifications — Conditional alerts that peek from the notch. Claude decides when to notify you — no spam, only signal.
6. Pinnable Utils — Pin any 2 widgets to your notch: CPU, RAM, network, calendar, music, uptime. Your command center, your layout.

**How it Works:**
1. Install — Download and launch. Lives in the menu bar, no dock icon.
2. Hover — Move your cursor to the notch. It smoothly expands.
3. Command — Chat, monitor, schedule, browse stats. All right there.

**CTA:** Ready to make your notch useful? / Free, open source, macOS 14 or later. / Download for Mac

**Footer:** Built for the notch.

---

## README Description (Raw / Honest Voice)

From the README — this is how the builder describes it, and it's the tone to match:

> "Perch lives in your MacBook notch. Hover near it and it drops down into a little assistant — your time and date, what's playing, system stats, the AI sessions running in your terminal, and a chat box that can actually do things on your machine."

> "It started as a status viewer for delegated agent tasks. It's now closer to a place where everything ambient about your machine perches above the keyboard, one hover away, instead of buried in a tab you forgot to switch to."

> "watches your agents. If you've got Claude Code running in a terminal, Perch sees it. Project name, the last thing you asked it, what tool it's reaching for right now."

> "is a chat box that does things... and when it needs access it doesn't have, it asks, right there in the chat, with a connect/deny button."

> "runs things on a schedule... The conditional ones ("tell me when X drops below Y") only fire when they mean it."

> "peeks at you. When a scheduled task has something worth saying, the notch grows a little and shows the headline without taking over your screen."

---

## Technical Stack

| Layer | Stack |
|-------|-------|
| macOS app | Swift 6, SwiftUI, MVVM, macOS 14+ |
| Backend | Node.js / TypeScript ESM, Express, tsx |
| Database | Supabase (PostgreSQL) |
| LLM | Anthropic (default), OpenAI, OpenRouter (BYOK) |
| App integrations | Composio (OAuth) |
| Site | React 19, Vite 8, TypeScript 6, Tailwind v4, Framer Motion |
| WebSocket | App runs `ws://localhost:7778/ws`, backend connects as client |
| Auth | Supabase auth + JWT, tokens in `~/.danotch/auth.json` |
| Settings | JSON at `~/.danotch/settings.json` |

---

## Distribution

- **Free, open source**
- macOS 14 (Sonoma) or later
- ARM64 (Apple Silicon) and x86_64
- No App Store — direct download (`.app` bundle, ad-hoc signed)
- No dock icon, no menu bar clutter — runs as an accessory

---

## Key Differentiators

1. **Notch-native.** Not a menu bar app. Not a floating window. It lives specifically in the MacBook notch — a space every MacBook with a notch wastes.

2. **Agent awareness.** The only ambient UI that reads Claude Code's live session state from JSONL — showing what it's actually doing right now, not just that it's running.

3. **Real tool use.** The chat isn't a wrapper around a chat API. It runs a full tool-use loop: bash, web, scheduled tasks, OAuth-connected apps.

4. **Conditional scheduling.** Most schedulers just run prompts. Perch's scheduler evaluates conditions — "only notify me when X" — using the LLM to decide if the condition is met before surfacing anything.

5. **Peek, not push.** Notifications grow the notch slightly instead of interrupting. Hover for details. Ignore and they vanish. No notification center required.

6. **Ambient, not attention-grabbing.** Collapses automatically. Never takes over your screen. Always one hover away.

---

## Site Sections to Rebuild

These are the sections the new site needs to cover, derived from the current site + README:

1. **Hero** — Product name, tagline, primary CTA (Download), secondary CTA (GitHub / Source)
2. **What is Perch** — Brief product description, the "one hover away" concept
3. **Agent Monitor** — The flagship feature. Show live state indicators, session data, what the detail looks like
4. **Chat** — Show tool use in action: bash exec, web search, connect flow
5. **Scheduled Tasks + Notifications** — The peek mechanic, conditional logic
6. **Stats / Widgets** — Ambient system info, bento grid, pinnable widgets
7. **How it Works** — Install → Hover → Command (keep this simple)
8. **BYOK / Providers** — Anthropic, OpenAI, OpenRouter. Your key, encrypted.
9. **Download CTA** — Free, open source, macOS 14+
10. **Footer** — Minimal

---

## Assets Available

- `public/favicon.svg` — App icon / favicon
- `public/icons.svg` — Icon sprites
- The `NotchDemo` component (`src/components/NotchDemo.tsx`, ~1172 lines) — a fully interactive mock of the notch UI. Supports views: `overview`, `agents`, `stats`, `chat`, `notifications`, `settings`. Also supports forced sequences: `code-exec`, `web-search`, `scheduled`, `notif-peek`, `pin-utils`.
- The demo matches the app's design tokens exactly and can be embedded in the new site.

---

## What to Avoid in the New Site

- The name "Danotch" — it's Perch now, everywhere
- Generic dev tool aesthetic (dark background + code snippet + feature grid)
- The "command center" framing is good but overused — lead with the notch concept
- Heavy above-the-fold animations that block the message
- Feature list without depth — show what each feature actually looks like in use
- Any claim about Cursor/Codex/Windsurf support — they're filtered out in the current build
- Markdown/bullet-heavy copy — write prose, keep it lean

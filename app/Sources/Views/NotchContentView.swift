import SwiftUI

struct NotchContentView: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        Group {
            switch viewModel.viewState {
            case .overview, .taskList:
                TodayPage(viewModel: viewModel)
            case .agentChat(let taskId):
                AgentChatView(viewModel: viewModel, taskId: taskId)
            case .stats, .processList, .settings, .notifications:
                EmptyView()
            }
        }
    }
}

// MARK: - Today Page (single, non-scrolling)
//
// Three stacked pieces sized to fit the expanded notch height exactly:
//   1. Clock card
//   2. Music card (album art + scrub bar + transport, or "Nothing playing" empty state)
//   3. Composer pill (chat input)

private struct TodayPage: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var composerText: String = ""
    @FocusState private var composerFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            TodayClockCard(viewModel: viewModel)
                .frame(maxHeight: .infinity)

            TodayMusicCard(monitor: viewModel.nowPlaying)
                .frame(maxHeight: .infinity)

            TodayStatsRow(stats: viewModel.statsMonitor)
                .frame(maxHeight: .infinity)

            composer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: viewModel.shouldFocusChatInput) { _, shouldFocus in
            if shouldFocus {
                composerFocused = true
                viewModel.shouldFocusChatInput = false
            }
        }
        .onChange(of: composerFocused) { _, focused in
            viewModel.isChatInputActive = focused
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Ask Perch anything…", text: $composerText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .focused($composerFocused)
                .onSubmit { submit() }

            sendButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .glassEffect(.regular, in: .capsule)
        .contentShape(.capsule)
        .onTapGesture { composerFocused = true }
    }

    private var sendButton: some View {
        let enabled = !composerText.trimmingCharacters(in: .whitespaces).isEmpty
        return Image(systemName: "arrow.up")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .glassEffect(
                enabled ? Glass.regular.tint(DN.activeAccent) : Glass.regular,
                in: .circle
            )
            .opacity(enabled ? 1 : 0.55)
            .contentShape(.circle)
            .onTapGesture { if enabled { submit() } }
    }

    private func submit() {
        let trimmed = composerText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        composerText = ""
        composerFocused = false
        viewModel.sendChat(message: trimmed)
    }
}

// MARK: - Today modules

private struct TodayClockCard: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(viewModel.timeString)
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .tracking(-1.2)
            Text(viewModel.periodString)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(viewModel.dateString)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .glassCell(cornerRadius: 18)
    }
}

private struct TodayMusicCard: View {
    @ObservedObject var monitor: NowPlayingMonitor

    var body: some View {
        Group {
            if let track = monitor.track {
                activeBody(track: track)
            } else {
                emptyBody
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .glassCell(cornerRadius: 18)
        .animation(.easeOut(duration: 0.22), value: monitor.track)
    }

    @ViewBuilder
    private func activeBody(track: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            artwork(size: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text(track)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let artist = monitor.artist {
                    Text(artist)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: max(2, geo.size.width * monitor.progress))
                    }
                }
                .frame(height: 3)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            transportControls
        }
    }

    private var transportControls: some View {
        HStack(spacing: 10) {
            mediaButton("backward.fill", size: 12) { monitor.runCommand("previous track") }
            mediaButton(monitor.isPlaying ? "pause.fill" : "play.fill", size: 16) { monitor.runCommand("playpause") }
            mediaButton("forward.fill", size: 12) { monitor.runCommand("next track") }
        }
    }

    private var emptyBody: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                Image(systemName: "music.note")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text("Nothing playing")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Start a track in Apple Music or Spotify")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private func artwork(size: CGFloat) -> some View {
        ZStack {
            if let img = monitor.artworkImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.35, weight: .light))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func mediaButton(_ icon: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size + 12, height: size + 12)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Today stats row

private struct TodayStatsRow: View {
    @ObservedObject var stats: SystemStatsMonitor

    var body: some View {
        HStack(spacing: 10) {
            TodayStatTile(
                icon: "cpu",
                label: "CPU",
                value: "\(Int(stats.cpuUsage))%",
                progress: stats.cpuUsage / 100,
                tint: tint(for: stats.cpuUsage)
            )
            .frame(width: 96)

            TodayStatTile(
                icon: "memorychip",
                label: "RAM",
                value: "\(Int(stats.ramPercent))%",
                progress: stats.ramPercent / 100,
                tint: tint(for: stats.ramPercent)
            )
            .frame(width: 96)

            TodayInlineCalendarTile()
                .frame(maxWidth: .infinity)
        }
    }

    private func tint(for pct: Double) -> Color {
        if pct > 85 { return .red }
        if pct > 65 { return .yellow }
        return .green
    }
}

private struct TodayStatTile: View {
    let icon: String
    let label: String
    let value: String
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            Spacer(minLength: 0)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(tint.opacity(0.9))
                        .frame(width: max(2, geo.size.width * max(0, min(1, progress))))
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .glassCell(cornerRadius: 16)
    }
}

/// Calendar tile sized to occupy two slots in the stats row. Shows the
/// month/year header on top and a horizontal day strip that auto-scrolls
/// today into view.
private struct TodayInlineCalendarTile: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("CALENDAR")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }
            MiniCalendarView(compact: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassCell(cornerRadius: 16)
    }
}

// MARK: - Icon Action Button (icon only, label on hover)

struct IconActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.glass)
        .controlSize(.small)
        .tint(.clear)
        .help(label)
    }
}

// MARK: - Agent Group View

struct AgentGroupView: View {
    let group: AgentGroup
    let isCompact: Bool
    @Binding var collapsedGroups: Set<String>
    var showLiveState: Bool = true
    let onTapAgent: (DetectedAgent) -> Void

    private var isGroupExpanded: Bool { !collapsedGroups.contains(group.id) }
    private var canCollapse: Bool { group.agents.count > 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header — tappable to toggle if multiple agents
            Button(action: {
                guard canCollapse else { return }
                withAnimation(DN.transition) {
                    collapsedGroups.toggle(group.id)
                }
            }) {
                HStack(spacing: DN.spaceSM) {
                    Image(systemName: group.type.icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(group.type.brandColor)
                        .frame(width: 14)

                    Text(group.type.rawValue)
                        .font(DN.body(11, weight: .semibold))
                        .foregroundColor(group.type.brandColor)

                    if group.agents.count > 1 {
                        Text("\(group.agents.count)")
                            .font(DN.mono(10, weight: .medium))
                            .foregroundColor(group.type.brandColor.opacity(0.7))
                    }

                    Spacer()

                    ActiveBadge(count: group.runningCount)

                    if canCollapse {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(DN.textDisabled)
                            .rotationEffect(.degrees(isGroupExpanded ? 90 : 0))
                    }
                }
                .padding(.horizontal, DN.spaceMD)
                .padding(.vertical, DN.spaceSM)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Agent rows — collapsible
            if isGroupExpanded {
                VStack(spacing: 1) {
                    ForEach(group.agents) { agent in
                        AgentSessionRow(agent: agent, showLiveState: showLiveState, isCompact: isCompact) {
                            onTapAgent(agent)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentCard(cornerRadius: DN.radiusMD)
    }
}

// MARK: - Agent Session Row (individual session within a group)

struct AgentSessionRow: View {
    let agent: DetectedAgent
    var showLiveState: Bool = true
    let isCompact: Bool
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DN.spaceSM) {
                    // Project name — primary identifier
                    Text(agent.displayName)
                        .font(DN.body(12, weight: .semibold))
                        .foregroundColor(DN.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    // Elapsed
                    Text(agent.elapsed)
                        .font(DN.mono(10))
                        .foregroundColor(DN.textDisabled)
                }

                // Live state indicator
                if showLiveState && agent.liveState != .idle && agent.liveState != .waitingForUser {
                    LiveStateView(state: agent.liveState, detail: agent.liveDetail)
                        .padding(.top, 1)
                }

                // Last prompt
                if let prompt = agent.lastPrompt, !prompt.isEmpty {
                    Text(prompt)
                        .font(DN.body(10))
                        .foregroundColor(agent.liveState == .waitingForUser || agent.liveState == .idle ? DN.textDisabled : DN.textSecondary)
                        .lineLimit(isCompact ? 1 : 2)
                }

                // Resource usage on hover or expanded
                if isHovering || !isCompact {
                    HStack(spacing: DN.spaceSM) {
                        HStack(spacing: 3) {
                            Text("CPU")
                                .font(DN.label(9))
                                .tracking(0.5)
                                .foregroundColor(DN.textDisabled)
                            Text(String(format: "%.1f%%", agent.cpu))
                                .font(DN.mono(10))
                                .foregroundColor(agent.cpu > 1.0 ? DN.warning : DN.textSecondary)
                        }

                        HStack(spacing: 3) {
                            Text("MEM")
                                .font(DN.label(9))
                                .tracking(0.5)
                                .foregroundColor(DN.textDisabled)
                            Text(String(format: "%.0fMB", agent.memMB))
                                .font(DN.mono(10))
                                .foregroundColor(DN.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(.top, 2)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, DN.spaceSM)
            .padding(.vertical, DN.spaceXS + 2)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: DN.radiusSM, style: .continuous)
                    .fill(isHovering ? Color.white.opacity(0.06) : Color.clear)
            )
            .animation(DN.transition, value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Live State View

struct LiveStateView: View {
    let state: AgentLiveState
    let detail: String?
    @State private var pulse = false

    init(state: AgentLiveState, detail: String? = nil) {
        self.state = state
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: DN.spaceXS) {
                Circle()
                    .fill(state.color)
                    .frame(width: 4, height: 4)
                    .opacity(pulse ? 1.0 : 0.4)

                Image(systemName: state.icon)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(state.color)

                Text(state.label)
                    .font(DN.label(8))
                    .tracking(0.6)
                    .foregroundColor(state.color)
            }

            if let detail = detail, !detail.isEmpty {
                Text(detail)
                    .font(DN.mono(9))
                    .foregroundColor(state.color.opacity(0.6))
                    .lineLimit(1)
                    .padding(.leading, 12)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Agent Row (for WebSocket tasks)

struct AgentRow: View {
    let task: SubagentTask
    let isCompact: Bool
    let activityText: String
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: DN.spaceSM) {
                    Circle()
                        .fill(DN.statusColor(task.status))
                        .frame(width: 6, height: 6)

                    Text(task.description ?? task.task)
                        .font(DN.body(12, weight: .medium))
                        .foregroundColor(DN.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(task.durationString)
                        .font(DN.mono(10))
                        .foregroundColor(DN.textDisabled)
                }

                if task.status == .running && (!isCompact || isHovering) {
                    ActivityText(text: activityText, color: DN.warning)
                        .padding(.leading, 14)
                        .padding(.top, 3)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, DN.spaceSM)
            .padding(.vertical, isCompact ? 6 : 8)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: DN.radiusSM, style: .continuous)
                    .fill(isHovering ? Color.white.opacity(0.06) : Color.clear)
            )
            .animation(DN.transition, value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Activity Text

struct ActivityText: View {
    let text: String
    let color: Color
    @State private var phase: Bool = false

    var body: some View {
        HStack(spacing: DN.spaceXS) {
            HStack(spacing: 2) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(color.opacity(dotOpacity(i)))
                        .frame(width: 3, height: 3)
                }
            }

            Text(text)
                .font(DN.mono(10))
                .foregroundColor(color.opacity(0.7))
                .lineLimit(1)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                phase.toggle()
            }
        }
        .id(text)
    }

    private func dotOpacity(_ index: Int) -> Double {
        let base = phase ? 1.0 : 0.3
        switch index {
        case 0: return phase ? 1.0 : 0.3
        case 1: return 0.6
        case 2: return phase ? 0.3 : 1.0
        default: return base
        }
    }
}

// MARK: - Now Playing

enum MusicSource: String {
    case appleMusic
    case spotify

    var appName: String {
        switch self {
        case .appleMusic: return "Music"
        case .spotify:    return "Spotify"
        }
    }

    var displayName: String {
        switch self {
        case .appleMusic: return "Apple Music"
        case .spotify:    return "Spotify"
        }
    }
}

class NowPlayingMonitor: ObservableObject {
    @Published var track: String?
    @Published var artist: String?
    @Published var isPlaying = false
    @Published var artworkImage: NSImage?
    @Published var position: Double = 0
    @Published var duration: Double = 0
    @Published var source: MusicSource?

    private var timer: Timer?
    private var lastTrackKey: String?
    private static let artPath = "/tmp/perch_art.png"

    var progress: Double { duration > 0 ? position / duration : 0 }

    func timeString(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    init() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    deinit { timer?.invalidate() }

    /// Send a transport command to the currently-active source. We resolve the
    /// app at call time rather than at construction so switching from Apple
    /// Music to Spotify (or vice versa) works without re-instantiating.
    func runCommand(_ cmd: String) {
        guard let src = source else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let script = """
            try
                if application "\(src.appName)" is running then
                    tell application "\(src.appName)" to \(cmd)
                end if
            end try
            """
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            proc.arguments = ["-e", script]
            proc.standardOutput = FileHandle.nullDevice
            proc.standardError = FileHandle.nullDevice
            try? proc.run()
            proc.waitUntilExit()
            Thread.sleep(forTimeInterval: 0.3)
            self?.poll()
        }
    }

    func poll() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Query both apps; pick whichever is actively playing. If neither
            // is playing we fall back to whichever has a track loaded (paused).
            let music = Self.fetch(.appleMusic)
            let spotify = Self.fetch(.spotify)
            let chosen = Self.pick(music: music, spotify: spotify)

            let trackKey = chosen.result.track.map { "\(chosen.source?.rawValue ?? "_")|\($0)" }
            let trackChanged = trackKey != self?.lastTrackKey
            var artwork: NSImage? = self?.artworkImage

            if trackChanged, let src = chosen.source, chosen.result.track != nil {
                artwork = Self.fetchArtwork(for: src, artworkURL: chosen.result.artworkURL)
            }
            if chosen.result.track == nil { artwork = nil }

            DispatchQueue.main.async {
                self?.source = chosen.source
                self?.track = chosen.result.track
                self?.artist = chosen.result.artist
                self?.isPlaying = chosen.result.playing
                self?.position = chosen.result.position
                self?.duration = chosen.result.duration
                self?.lastTrackKey = trackKey
                if trackChanged { self?.artworkImage = artwork }
            }
        }
    }

    // MARK: - Source resolution

    private static func pick(
        music: FetchResult,
        spotify: FetchResult
    ) -> (source: MusicSource?, result: FetchResult) {
        // Prefer whichever app is currently playing.
        if music.playing { return (.appleMusic, music) }
        if spotify.playing { return (.spotify, spotify) }
        // Neither is playing — surface whichever has a paused track.
        if music.track != nil { return (.appleMusic, music) }
        if spotify.track != nil { return (.spotify, spotify) }
        return (nil, FetchResult.empty)
    }

    // MARK: - Per-app fetch

    private struct FetchResult {
        let track: String?
        let artist: String?
        let playing: Bool
        let position: Double
        let duration: Double
        let artworkURL: String?

        static let empty = FetchResult(track: nil, artist: nil, playing: false, position: 0, duration: 0, artworkURL: nil)
    }

    private static func fetch(_ source: MusicSource) -> FetchResult {
        switch source {
        case .appleMusic: return fetchAppleMusic()
        case .spotify:    return fetchSpotify()
        }
    }

    private static func fetchAppleMusic() -> FetchResult {
        let script = """
        try
            if application "Music" is running then
                tell application "Music"
                    if player state is playing or player state is paused then
                        set t to name of current track
                        set a to artist of current track
                        set p to player position
                        set d to duration of current track
                        set s to "paused"
                        if player state is playing then set s to "playing"
                        return t & "|||" & a & "|||" & s & "|||" & (round p) & "|||" & (round d)
                    end if
                end tell
            end if
        end try
        return ""
        """
        return parseTriplePipe(runOsa(script))
    }

    /// Spotify exposes the same dictionary verbs as iTunes/Music, plus an
    /// `artwork url` of the album artwork on Spotify's CDN — much faster to
    /// fetch via HTTP than to round-trip `raw data of artwork` through
    /// osascript. Spotify reports `duration` in MILLISECONDS, so we
    /// normalise to seconds here.
    private static func fetchSpotify() -> FetchResult {
        let script = """
        try
            if application "Spotify" is running then
                tell application "Spotify"
                    if player state is playing or player state is paused then
                        set t to name of current track
                        set a to artist of current track
                        set p to player position
                        set d to duration of current track
                        set u to ""
                        try
                            set u to artwork url of current track
                        end try
                        set s to "paused"
                        if player state is playing then set s to "playing"
                        return t & "|||" & a & "|||" & s & "|||" & (round p) & "|||" & d & "|||" & u
                    end if
                end tell
            end if
        end try
        return ""
        """
        let out = runOsa(script)
        let parts = out.components(separatedBy: "|||")
        guard parts.count >= 5, !parts[0].isEmpty else { return .empty }
        let durationMs = Double(parts[4]) ?? 0
        return FetchResult(
            track: parts[0],
            artist: parts[1],
            playing: parts[2] == "playing",
            position: Double(parts[3]) ?? 0,
            duration: durationMs / 1000.0,
            artworkURL: parts.count > 5 ? parts[5] : nil
        )
    }

    private static func parseTriplePipe(_ raw: String) -> FetchResult {
        let parts = raw.components(separatedBy: "|||")
        guard parts.count >= 5, !parts[0].isEmpty else { return .empty }
        return FetchResult(
            track: parts[0],
            artist: parts[1],
            playing: parts[2] == "playing",
            position: Double(parts[3]) ?? 0,
            duration: Double(parts[4]) ?? 0,
            artworkURL: parts.count > 5 ? parts[5] : nil
        )
    }

    private static func runOsa(_ script: String) -> String {
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do { try proc.run() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // MARK: - Artwork

    private static func fetchArtwork(for source: MusicSource, artworkURL: String?) -> NSImage? {
        switch source {
        case .appleMusic:
            // Apple Music: export `raw data of artwork 1` to a tmp file, then load it.
            let script = """
            try
                if application "Music" is running then
                    tell application "Music"
                        set artData to raw data of artwork 1 of current track
                        set f to open for access POSIX file "\(artPath)" with write permission
                        set eof of f to 0
                        write artData to f
                        close access f
                    end tell
                end if
            end try
            """
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            proc.arguments = ["-e", script]
            proc.standardOutput = FileHandle.nullDevice
            proc.standardError = FileHandle.nullDevice
            try? proc.run()
            proc.waitUntilExit()
            return NSImage(contentsOfFile: artPath)
        case .spotify:
            // Spotify: artwork is hosted on i.scdn.co — fetch over HTTP.
            guard let urlStr = artworkURL,
                  !urlStr.isEmpty,
                  let url = URL(string: urlStr),
                  let data = try? Data(contentsOf: url) else { return nil }
            return NSImage(data: data)
        }
    }
}

struct NowPlayingView: View {
    @ObservedObject var monitor: NowPlayingMonitor
    var isBig: Bool = false
    var accentColor: Color = DN.textPrimary
    @State private var isHovering = false

    private var artSize: CGFloat { isBig ? 52 : 30 }
    private var titleSize: CGFloat { isBig ? 12 : 10 }
    private var artistSize: CGFloat { isBig ? 9 : 8 }
    private var controlSize: CGFloat { isBig ? 12 : 9 }

    var body: some View {
        if let track = monitor.track {
            VStack(spacing: DN.spaceXS) {
                if isBig {
                    bigLayout(track: track)
                } else {
                    miniLayout(track: track)
                }

                // Progress bar + times
                VStack(spacing: 2) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.06)).frame(height: isBig ? 3 : 2)
                            Capsule().fill(accentColor.opacity(0.6)).frame(width: max(geo.size.width * monitor.progress, 2), height: isBig ? 3 : 2)
                        }
                    }
                    .frame(height: isBig ? 3 : 2)

                    HStack {
                        Text(monitor.timeString(monitor.position))
                            .font(DN.mono(7))
                            .foregroundColor(DN.textDisabled)
                        Spacer()
                        Text(monitor.timeString(monitor.duration))
                            .font(DN.mono(7))
                            .foregroundColor(DN.textDisabled)
                    }
                }

                // Big: controls row, always reserved, opacity toggle
                if isBig {
                    HStack(spacing: DN.spaceLG) {
                        mediaButton("backward.fill") { monitor.runCommand("previous track") }
                        mediaButton(monitor.isPlaying ? "pause.fill" : "play.fill", size: 16) { monitor.runCommand("playpause") }
                        mediaButton("forward.fill") { monitor.runCommand("next track") }
                    }
                    .padding(.top, DN.space2xs)
                    .opacity(isHovering ? 1 : 0)
                }
            }
            .padding(.top, DN.spaceXS)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: DN.microDuration), value: isHovering)
        }
    }

    // Big: art on left, info on right, stacked
    private func bigLayout(track: String) -> some View {
        HStack(spacing: DN.spaceSM + 2) {
            albumArt(size: 56, radius: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(track)
                    .font(DN.body(13, weight: .semibold))
                    .foregroundColor(DN.textDisplay)
                    .lineLimit(2)

                if let artist = monitor.artist {
                    Text(artist)
                        .font(DN.mono(9))
                        .foregroundColor(DN.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
    }

    // Mini: compact single row
    private func miniLayout(track: String) -> some View {
        HStack(spacing: DN.spaceSM) {
            albumArt(size: 30, radius: 5)

            VStack(alignment: .leading, spacing: 1) {
                Text(track)
                    .font(DN.body(10, weight: .medium))
                    .foregroundColor(DN.textPrimary)
                    .lineLimit(1)

                if let artist = monitor.artist {
                    Text(artist)
                        .font(DN.mono(8))
                        .foregroundColor(DN.textDisabled)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            // Inline controls on hover
            HStack(spacing: DN.spaceSM) {
                mediaButton("backward.fill") { monitor.runCommand("previous track") }
                mediaButton(monitor.isPlaying ? "pause.fill" : "play.fill", size: 11) { monitor.runCommand("playpause") }
                mediaButton("forward.fill") { monitor.runCommand("next track") }
            }
            .opacity(isHovering ? 1 : 0)
        }
    }

    private func albumArt(size: CGFloat, radius: CGFloat) -> some View {
        ZStack {
            if let img = monitor.artworkImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(DN.surface)
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.35, weight: .light))
                    .foregroundColor(DN.textDisabled)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private func mediaButton(_ icon: String, size: CGFloat? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size ?? controlSize, weight: .medium))
                .foregroundColor(accentColor)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scheduled Tasks Section

struct ScheduledTasksSection: View {
    @ObservedObject var viewModel: NotchViewModel

    private var isExpanded: Bool { !viewModel.settings.collapsedGroups.contains("scheduled") }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: {
                withAnimation(DN.transition) {
                    viewModel.settings.collapsedGroups.toggle("scheduled")
                }
            }) {
                HStack(spacing: DN.spaceSM) {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DN.warning)
                        .frame(width: 14)

                    Text("Scheduled")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DN.textSecondary)

                    Text("\(viewModel.scheduledTasks.filter { $0.enabled }.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DN.textDisabled)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(DN.textDisabled)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, DN.spaceMD)
                .padding(.vertical, DN.spaceSM)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(viewModel.scheduledTasks) { task in
                        ScheduledTaskRow(task: task, viewModel: viewModel)
                    }
                }
            }
        }
        .contentCard(cornerRadius: DN.radiusMD)
    }
}

struct ScheduledTaskRow: View {
    let task: ScheduledTask
    @ObservedObject var viewModel: NotchViewModel
    @State private var isHovering = false
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: DN.spaceSM) {
                Circle()
                    .fill(task.enabled ? DN.warning : DN.textDisabled)
                    .frame(width: 5, height: 5)

                VStack(alignment: .leading, spacing: 1) {
                    Text(task.name)
                        .font(DN.body(10, weight: .medium))
                        .foregroundColor(task.enabled ? DN.textPrimary : DN.textDisabled)
                        .lineLimit(1)

                    HStack(spacing: DN.spaceXS) {
                        if task.notifyUser {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 7))
                                .foregroundColor(DN.accent.opacity(0.7))
                        }

                        Text(task.scheduleHuman)
                            .font(DN.mono(8))
                            .foregroundColor(DN.textDisabled)

                        if let lastStatus = task.lastStatus {
                            Text("·")
                                .foregroundColor(DN.textDisabled)
                            Text(lastStatus == "completed" ? "✓" : "✗")
                                .font(DN.mono(8))
                                .foregroundColor(lastStatus == "completed" ? DN.success : DN.accent)
                        }

                        if task.runCount > 0 {
                            Text("·")
                                .foregroundColor(DN.textDisabled)
                            Text("\(task.runCount)×")
                                .font(DN.mono(8))
                                .foregroundColor(DN.textDisabled)
                        }
                    }
                }

                Spacer()

                if isHovering {
                    Button(action: {
                        viewModel.toggleScheduledTask(task.id, enabled: !task.enabled)
                    }) {
                        Image(systemName: task.enabled ? "pause.circle" : "play.circle")
                            .font(.system(size: 12))
                            .foregroundColor(task.enabled ? DN.warning : DN.success)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        withAnimation(DN.transition) {
                            viewModel.deleteScheduledTask(task.id)
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(DN.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DN.spaceSM)
            .padding(.vertical, DN.spaceXS + 1)
            .contentShape(Rectangle())
            .onTapGesture {
                if task.lastResultSummary != nil {
                    withAnimation(DN.transition) {
                        isExpanded.toggle()
                    }
                }
            }

            // Expanded: show last result
            if isExpanded, let summary = task.lastResultSummary {
                VStack(alignment: .leading, spacing: 6) {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 0.5)

                    Text("LAST OUTPUT")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.6)
                        .foregroundColor(DN.textDisabled)

                    MarkdownView(text: summary, isFinal: true)
                        .lineLimit(10)
                }
                .padding(.horizontal, DN.spaceMD)
                .padding(.vertical, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            Rectangle()
                .fill(Color.white.opacity(isHovering || isExpanded ? 0.05 : 0.0))
        )
        .animation(DN.transition, value: isHovering)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Mini Calendar

struct MiniCalendarView: View {
    let compact: Bool

    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]
    private var cal: Calendar { Calendar.current }
    private var today: Date { Date() }
    private var currentDay: Int { cal.component(.day, from: today) }

    private var monthName: String {
        let f = DateFormatter()
        f.dateFormat = compact ? "MMM" : "MMMM"
        return f.string(from: today).uppercased()
    }

    private var yearString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f.string(from: today)
    }

    private var daysInMonth: Int {
        cal.range(of: .day, in: .month, for: today)?.count ?? 30
    }

    private var firstWeekday: Int {
        let comps = cal.dateComponents([.year, .month], from: today)
        guard let first = cal.date(from: comps) else { return 0 }
        return (cal.component(.weekday, from: first) - 1) % 7
    }

    var body: some View {
        if compact {
            compactCalendar
        } else {
            fullCalendar
        }
    }

    private var compactCalendar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(monthName.capitalized)
                .font(DN.body(10, weight: .medium))
                .foregroundColor(DN.textDisabled)

            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { proxy in
                    HStack(spacing: 2) {
                        ForEach(1...daysInMonth, id: \.self) { day in
                            VStack(spacing: 2) {
                                Text(dayOfWeekLabel(day))
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundColor(day == currentDay ? DN.textPrimary : DN.textDisabled.opacity(0.6))
                                Text("\(day)")
                                    .font(.system(size: 10, weight: day == currentDay ? .semibold : .regular, design: .rounded))
                                    .foregroundColor(dayColor(day))
                                    .monospacedDigit()
                            }
                            .frame(width: 20, height: 26)
                            .background {
                                if day == currentDay {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.white.opacity(0.10))
                                }
                            }
                            .id(day)
                        }
                    }
                    .onAppear {
                        proxy.scrollTo(max(currentDay - 2, 1), anchor: .leading)
                    }
                }
            }
        }
    }

    private var fullCalendar: some View {
        VStack(spacing: 0) {
            HStack {
                Text(monthName)
                    .font(DN.label(8))
                    .tracking(1.5)
                    .foregroundColor(DN.textSecondary)
                Spacer()
                Text(yearString)
                    .font(DN.mono(8))
                    .foregroundColor(DN.textDisabled)
            }
            .padding(.bottom, 6)

            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(DN.label(6))
                        .tracking(0.5)
                        .foregroundColor(DN.textDisabled)
                        .frame(maxWidth: .infinity)
                        .frame(height: 12)
                }
            }

            Rectangle()
                .fill(DN.border)
                .frame(height: 1)
                .padding(.vertical, 3)

            let rows = buildCalendarDays()
            VStack(spacing: 2) {
                ForEach(0..<rows.count, id: \.self) { rowIdx in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let day = rows[rowIdx][col]
                            if day > 0 {
                                Text("\(day)")
                                    .font(DN.mono(8, weight: day == currentDay ? .bold : .regular))
                                    .foregroundColor(dayColor(day))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 16)
                                    .background {
                                        if day == currentDay {
                                            Circle()
                                                .fill(DN.textDisplay)
                                                .frame(width: 15, height: 15)
                                        }
                                    }
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 16)
                            }
                        }
                    }
                }
            }
        }
        .padding(DN.spaceSM)
        .contentCard(cornerRadius: DN.radiusMD)
    }

    private func dayColor(_ day: Int) -> Color {
        if day == currentDay { return DN.textDisplay }
        if day < currentDay { return DN.textDisabled }
        return DN.textPrimary
    }

    private func dayOfWeekLabel(_ day: Int) -> String {
        let comps = cal.dateComponents([.year, .month], from: today)
        var dc = comps
        dc.day = day
        guard let date = cal.date(from: dc) else { return "" }
        let weekday = cal.component(.weekday, from: date)
        return ["S","M","T","W","T","F","S"][weekday - 1]
    }

    private func buildCalendarDays() -> [[Int]] {
        var rows: [[Int]] = []
        var row: [Int] = Array(repeating: 0, count: firstWeekday)
        for day in 1...daysInMonth {
            row.append(day)
            if row.count == 7 {
                rows.append(row)
                row = []
            }
        }
        if !row.isEmpty {
            while row.count < 7 { row.append(0) }
            rows.append(row)
        }
        return rows
    }
}

// MARK: - Pinned Widget Views

struct PinnedRAMView: View {
    @ObservedObject var monitor: SystemStatsMonitor
    private var pct: Double { monitor.ramTotal > 0 ? monitor.ramUsed / monitor.ramTotal : 0 }
    private var color: Color {
        if pct > 0.85 { return DN.accent }
        if pct > 0.6 { return DN.warning }
        return DN.success
    }
    var body: some View {
        HStack(spacing: DN.spaceSM) {
            ZStack {
                ForEach(0..<20, id: \.self) { i in
                    let angle = Angle.degrees(135 + Double(i) * (270.0 / 20.0))
                    let filled = Double(i) / 20.0 < pct
                    Capsule()
                        .fill(filled ? color : Color.white.opacity(0.06))
                        .frame(width: 1.5, height: 4)
                        .offset(y: -16)
                        .rotationEffect(angle)
                }
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("RAM")
                    .font(DN.label(7))
                    .tracking(1.2)
                    .foregroundColor(DN.textDisabled)
                Text("\(Int(pct * 100))%")
                    .font(DN.mono(14, weight: .light))
                    .foregroundColor(DN.textDisplay)
                Text(String(format: "%.1f / %.0f GB", monitor.ramUsed / (1024 * 1024 * 1024), monitor.ramTotal / (1024 * 1024 * 1024)))
                    .font(DN.mono(7))
                    .foregroundColor(DN.textDisabled)
            }
        }
    }
}

struct PinnedDiskView: View {
    @ObservedObject var monitor: SystemStatsMonitor
    private var pct: Double { monitor.diskTotal > 0 ? monitor.diskUsed / monitor.diskTotal : 0 }
    private var color: Color {
        if pct > 0.9 { return DN.accent }
        if pct > 0.75 { return DN.warning }
        return DN.textSecondary
    }
    var body: some View {
        HStack(spacing: DN.spaceSM) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.06), lineWidth: 3).frame(width: 36, height: 36)
                Circle().trim(from: 0, to: pct)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("DISK")
                    .font(DN.label(7))
                    .tracking(1.2)
                    .foregroundColor(DN.textDisabled)
                Text("\(Int(pct * 100))%")
                    .font(DN.mono(14, weight: .light))
                    .foregroundColor(DN.textDisplay)
                Text(String(format: "%.0f / %.0f GB", monitor.diskUsed / (1024 * 1024 * 1024), monitor.diskTotal / (1024 * 1024 * 1024)))
                    .font(DN.mono(7))
                    .foregroundColor(DN.textDisabled)
            }
        }
    }
}

struct PinnedNetworkView: View {
    @ObservedObject var monitor: SystemStatsMonitor
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(DN.success)
                Text("DOWN")
                    .font(DN.label(6))
                    .tracking(0.8)
                    .foregroundColor(DN.textDisabled)
                Spacer()
                Text(fmtBytes(monitor.netDown))
                    .font(DN.mono(9, weight: .medium))
                    .foregroundColor(DN.success)
            }
            HStack(spacing: 4) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(DN.warning)
                Text("UP")
                    .font(DN.label(6))
                    .tracking(0.8)
                    .foregroundColor(DN.textDisabled)
                Spacer()
                Text(fmtBytes(monitor.netUp))
                    .font(DN.mono(9, weight: .medium))
                    .foregroundColor(DN.warning)
            }
        }
    }
}

struct PinnedUptimeView: View {
    @ObservedObject var monitor: SystemStatsMonitor
    var body: some View {
        HStack(spacing: DN.spaceSM) {
            Image(systemName: "clock")
                .font(.system(size: 12))
                .foregroundColor(DN.textDisabled)
            VStack(alignment: .leading, spacing: 2) {
                Text("UPTIME")
                    .font(DN.label(7))
                    .tracking(1.2)
                    .foregroundColor(DN.textDisabled)
                Text(monitor.uptimeString)
                    .font(DN.mono(12, weight: .medium))
                    .foregroundColor(DN.textPrimary)
            }
        }
    }
}

struct PinnedProcessView: View {
    @ObservedObject var monitor: SystemStatsMonitor
    var body: some View {
        HStack(spacing: DN.spaceSM) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PROCESSES")
                    .font(DN.label(7))
                    .tracking(1.2)
                    .foregroundColor(DN.textDisabled)
                Text("\(monitor.processes.count)")
                    .font(DN.mono(16, weight: .light))
                    .foregroundColor(DN.textDisplay)
            }
            Spacer()
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(monitor.processes.prefix(5).enumerated()), id: \.offset) { _, proc in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(proc.cpu > 10 ? DN.warning : DN.textSecondary.opacity(0.5))
                        .frame(width: 4, height: max(4, CGFloat(proc.cpu / 2)))
                }
            }
            .frame(height: 24)
        }
    }
}

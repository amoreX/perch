import SwiftUI
import AppKit
import IOKit.ps

struct NotchShellView: View {
    @ObservedObject var viewModel: NotchViewModel

    private var screen: NSScreen { NSScreen.main ?? NSScreen.screens[0] }
    private var notchW: CGFloat { screen.notchWidth }
    private var notchH: CGFloat { screen.notchHeight }
    private var expanded: Bool { viewModel.isExpanded }

    // Single canonical expanded size — no per-view dimension change so view-switching
    // never resizes the notch frame. Inner ScrollViews handle overflow.
    static let expandedW: CGFloat = 540
    static let expandedH: CGFloat = 320

    private var shapeWidth: CGFloat {
        if viewModel.isPeeking {
            return viewModel.peekHovering ? notchW + 200 : notchW + 140
        }
        if !expanded { return notchW }
        return Self.expandedW
    }

    private var shapeHeight: CGFloat {
        if viewModel.isPeeking {
            return viewModel.peekHovering ? notchH + 80 : notchH + 28
        }
        if !expanded { return notchH }
        return notchH + Self.expandedH
    }

    private var bottomRadius: CGFloat {
        if viewModel.isPeeking { return 12 }
        return expanded ? 16 : 8
    }

    var body: some View {
        ZStack(alignment: .top) {
            notchShape

            // Peek state — soft grow, just title + optional body on hover
            if viewModel.isPeeking {
                peekContent
                    .padding(.top, notchH)
                    .padding(.horizontal, DN.spaceSM)
                    .frame(width: shapeWidth, alignment: .top)
                    .transition(.opacity)
            }

            if expanded && !viewModel.isPeeking {
                // Interactive dot grid behind content — toned down so the glass breathes
                if viewModel.settings.showDotGrid {
                    DotGridView(dotColor: viewModel.settings.dotGridSwiftColor)
                        .padding(.top, notchH)
                        .opacity(viewModel.settings.dotGridOpacity * 0.6)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                expandedTopBar
                    .transition(.opacity)

                // Cross-fade between views; the surrounding shape never changes size,
                // so no layout reflow needed.
                expandedContent
                    .padding(.top, notchH + 1)
                    .padding(.horizontal, DN.spaceMD)
                    .padding(.bottom, DN.spaceMD)
                    .frame(width: shapeWidth, alignment: .top)
                    .id(viewModel.viewState.transitionKey)
                    .transition(.opacity)
            }
        }
        .frame(width: shapeWidth, height: shapeHeight)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: bottomRadius,
                bottomTrailingRadius: bottomRadius,
                topTrailingRadius: 0,
                style: .continuous
            )
        )
        .onHover { hovering in
            viewModel.mouseInContent = hovering
            if viewModel.isPeeking {
                withAnimation(.easeOut(duration: 0.2)) {
                    viewModel.peekHovering = hovering
                }
                // If user stops hovering peek, dismiss after 2s
                if !hovering {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak viewModel] in
                        guard let vm = viewModel, vm.isPeeking, !vm.peekHovering else { return }
                        vm.dismissPeek()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(DN.expandSpring, value: expanded)
        .animation(DN.peekSpring, value: viewModel.isPeeking)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: viewModel.peekHovering)
        .animation(DN.viewStateSpring, value: viewModel.viewState)
    }

    private var notchShape: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: bottomRadius,
            bottomTrailingRadius: bottomRadius,
            topTrailingRadius: 0,
            style: .continuous
        )

        return ZStack {
            // Tahoe-style base: liquid glass material
            shape.fill(.ultraThinMaterial)

            // Subtle dark tint — much lighter than before so glass blur is visible.
            // Collapsed: fully opaque so the physical notch reads as solid black.
            shape.fill(DN.black.opacity(expanded ? 0.32 : 0.95))

            // Top sheen
            shape.fill(
                LinearGradient(
                    colors: [Color.white.opacity(expanded ? 0.10 : 0.02), Color.white.opacity(0.0)],
                    startPoint: .top, endPoint: .center
                )
            )

            // Bottom rim shadow for depth
            shape.fill(
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(expanded ? 0.30 : 0.0)],
                    startPoint: .center, endPoint: .bottom
                )
            )
        }
        .overlay(
            // Rim light stroke — only when expanded so the collapsed bar still reads as the physical notch
            shape.stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(expanded ? 0.16 : 0.0),
                        Color.white.opacity(expanded ? 0.04 : 0.0),
                        Color.white.opacity(expanded ? 0.10 : 0.0),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: 0.8
            )
        )
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private var expandedContent: some View {
        switch viewModel.viewState {
        case .overview, .taskList, .agentChat:
            NotchContentView(viewModel: viewModel)
        case .stats:
            StatsPanel(viewModel: viewModel)
        case .processList:
            ProcessListPanel(viewModel: viewModel)
        case .settings:
            SettingsPanel(viewModel: viewModel)
        case .notifications:
            NotificationsPanel(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var peekContent: some View {
        VStack(alignment: .leading, spacing: DN.spaceXS) {
            // Compact title line — always visible
            HStack(spacing: DN.spaceXS) {
                Text("❗")
                    .font(.system(size: 9))

                Text(viewModel.peekTitle)
                    .font(DN.body(10, weight: .semibold))
                    .foregroundColor(DN.textDisplay)
                    .lineLimit(1)
            }
            .padding(.horizontal, DN.spaceXS)
            .padding(.top, 4)

            // Body — only on hover
            if viewModel.peekHovering {
                MarkdownView(text: viewModel.peekBody, isFinal: true)
                    .padding(.horizontal, DN.spaceXS)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.dismissPeek()
                        withAnimation(DN.transition) {
                            viewModel.isExpanded = true
                            viewModel.viewState = .notifications
                        }
                    }) {
                        Text("VIEW ALL")
                            .font(DN.label(7))
                            .tracking(0.8)
                            .foregroundColor(DN.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DN.spaceXS)
            }
        }
    }

    // MARK: - Top Bar
    //
    // Layout grid: [LEFT TABS] [physical notch gap] [RIGHT TABS]
    // Both side groups sit on the same baseline (vertically centered to notchH)
    // and all controls are pill-shaped with a single height to share a baseline.

    // Top bar: identical inset on both sides of the notch gap, no battery.
    // Layout: [pad] [LEFT CLUSTER] [grow] [physical notch] [grow] [RIGHT CLUSTER] [pad]
    private var expandedTopBar: some View {
        let sideInset: CGFloat = DN.spaceMD

        return HStack(alignment: .center, spacing: 0) {
            // Left edge inset
            Color.clear.frame(width: sideInset)

            // Left cluster — flush to the left edge inset
            HStack(spacing: DN.spaceXS) {
                pillTab(label: "Home", isActive: viewModel.viewState == .overview) {
                    withAnimation(DN.transition) {
                        viewModel.viewState = .overview
                    }
                }
                pillTab(label: "Agents", isActive: viewModel.isInTaskOrChat) {
                    withAnimation(DN.transition) {
                        viewModel.viewState = .taskList
                    }
                }
            }

            // Flexible spacer up to notch
            Spacer(minLength: DN.spaceSM)

            // Physical notch
            Color.clear.frame(width: notchW)

            // Flexible spacer after notch
            Spacer(minLength: DN.spaceSM)

            // Right cluster — flush to the right edge inset
            HStack(spacing: DN.spaceXS) {
                pillTab(label: "Stats", isActive: viewModel.viewState == .stats || viewModel.viewState == .processList) {
                    withAnimation(DN.transition) {
                        viewModel.viewState = .stats
                    }
                }

                let notifsActive = viewModel.viewState == .notifications
                pillIcon(
                    icon: notifsActive ? "bell.fill" : "bell",
                    isActive: notifsActive,
                    badge: viewModel.unreadCount > 0
                ) {
                    withAnimation(DN.transition) {
                        viewModel.viewState = .notifications
                    }
                }

                let settingsActive = viewModel.viewState == .settings
                pillIcon(
                    icon: settingsActive ? "gearshape.fill" : "gearshape",
                    isActive: settingsActive
                ) {
                    withAnimation(DN.transition) {
                        viewModel.viewState = .settings
                    }
                }
            }

            // Right edge inset
            Color.clear.frame(width: sideInset)
        }
        .frame(width: shapeWidth, height: notchH)
    }

    // Unified pill — fixed metrics. Weight stays constant (so glyph never reflows),
    // only color and background opacity change between states.
    private func pillTab(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isActive ? DN.textDisplay : DN.textSecondary)
                .padding(.horizontal, 12)
                .frame(height: 24)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(isActive ? 0.14 : 0.0))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(isActive ? 0.16 : 0.0), lineWidth: 0.6)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func pillIcon(icon: String, isActive: Bool, badge: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isActive ? DN.textDisplay : DN.textSecondary)
                    .frame(width: 24, height: 24)

                if badge {
                    Circle()
                        .fill(DN.accent)
                        .frame(width: 5, height: 5)
                        .offset(x: 2, y: -2)
                }
            }
            .frame(width: 24, height: 24)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(isActive ? 0.14 : 0.0))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(isActive ? 0.16 : 0.0), lineWidth: 0.6)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // Legacy tabButton kept for compatibility with any remaining call sites
    private func tabButton(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(DN.label(10))
                .tracking(1.2)
                .foregroundColor(isActive ? DN.textDisplay : DN.textDisabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(isActive ? Color.white.opacity(0.12) : Color.clear)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isActive ? DN.glassStrokeHi : Color.clear, lineWidth: 0.6)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Battery

struct BatteryView: View {
    @State private var level: Int = 0
    @State private var isCharging: Bool = false
    @State private var timer: Timer?

    private var batteryIcon: String {
        if isCharging { return "battery.100.bolt" }
        switch level {
        case 90...:  return "battery.100"
        case 70..<90: return "battery.75"
        case 40..<70: return "battery.50"
        case 15..<40: return "battery.25"
        default:      return "battery.0"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: batteryIcon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(batteryColor)
                .symbolRenderingMode(.hierarchical)

            Text("\(level)%")
                .font(DN.body(10, weight: .medium))
                .foregroundColor(DN.textSecondary)
                .monospacedDigit()
                .fixedSize()
        }
        .onAppear {
            updateBattery()
            timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                DispatchQueue.main.async { updateBattery() }
            }
        }
        .onDisappear { timer?.invalidate() }
    }

    private var batteryColor: Color {
        if isCharging { return DN.success }
        if level <= 20 { return DN.accent }
        return DN.textPrimary
    }

    private func updateBattery() {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] else { continue }
            if let capacity = desc[kIOPSCurrentCapacityKey] as? Int { level = capacity }
            if let charging = desc[kIOPSIsChargingKey] as? Bool { isCharging = charging }
        }
    }
}

// MARK: - Settings

// MARK: - Notifications Panel

struct NotificationsPanel: View {
    @ObservedObject var viewModel: NotchViewModel

    // Group notifications by sourceId (or by id if no sourceId)
    private var grouped: [(key: String, title: String, items: [NotificationItem])] {
        var dict: [(key: String, title: String, items: [NotificationItem])] = []
        var seen: [String: Int] = [:]

        for notif in viewModel.notifications {
            let groupKey = notif.sourceId ?? notif.id
            if let idx = seen[groupKey] {
                dict[idx].items.append(notif)
            } else {
                seen[groupKey] = dict.count
                dict.append((key: groupKey, title: notif.title, items: [notif]))
            }
        }
        return dict
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DN.spaceSM) {
            HStack {
                Text("Notifications")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DN.textDisplay)

                Spacer()

                if viewModel.unreadCount > 0 {
                    SecondaryActionButton(label: "Mark all read") {
                        viewModel.markAllRead()
                    }
                }
            }
            .padding(.bottom, DN.spaceXS)

            if viewModel.notifications.isEmpty {
                VStack(spacing: 6) {
                    Spacer().frame(height: 28)
                    Text("No notifications")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DN.textSecondary)
                    Text("Scheduled task results will appear here")
                        .font(.system(size: 11))
                        .foregroundColor(DN.textDisabled.opacity(0.8))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: DN.spaceXS) {
                        ForEach(grouped, id: \.key) { group in
                            NotificationGroupRow(
                                title: group.title,
                                items: group.items,
                                viewModel: viewModel
                            )
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadNotifications()
        }
    }
}

struct NotificationGroupRow: View {
    let title: String
    let items: [NotificationItem]
    @ObservedObject var viewModel: NotchViewModel
    @State private var isExpanded = false

    private var unreadCount: Int { items.filter { !$0.read }.count }
    private var latest: NotificationItem { items.first! }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header
            HStack(spacing: DN.spaceSM) {
                Circle()
                    .fill(unreadCount > 0 ? DN.accent : .clear)
                    .frame(width: 5, height: 5)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DN.spaceXS) {
                        Text(title)
                            .font(DN.body(11, weight: unreadCount > 0 ? .medium : .regular))
                            .foregroundColor(unreadCount > 0 ? DN.textPrimary : DN.textSecondary)
                            .lineLimit(1)

                        if items.count > 1 {
                            Text("\(items.count)")
                                .font(DN.mono(8))
                                .foregroundColor(DN.textDisabled)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(DN.border)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }

                    HStack(spacing: DN.spaceXS) {
                        Text("Scheduled")
                            .font(DN.mono(8))
                            .foregroundColor(DN.textDisabled)
                        Text("·")
                            .foregroundColor(DN.textDisabled)
                        Text(notifDate(latest.createdAt))
                            .font(DN.mono(8))
                            .foregroundColor(DN.textDisabled)
                    }
                }

                Spacer()

                if isExpanded {
                    // Pause/resume the source task
                    if let sourceId = latest.sourceId {
                        Button(action: {
                            let task = viewModel.scheduledTasks.first { $0.id == sourceId }
                            viewModel.toggleScheduledTask(sourceId, enabled: !(task?.enabled ?? true))
                        }) {
                            let task = viewModel.scheduledTasks.first { $0.id == latest.sourceId }
                            Image(systemName: task?.enabled != false ? "pause.circle" : "play.circle")
                                .font(.system(size: 12))
                                .foregroundColor(task?.enabled != false ? DN.warning : DN.success)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            withAnimation(.easeOut(duration: DN.microDuration)) {
                                viewModel.deleteScheduledTask(sourceId)
                            }
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundColor(DN.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(DN.textDisabled)
            }
            .padding(.horizontal, DN.spaceSM)
            .padding(.vertical, DN.spaceXS + 2)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeOut(duration: DN.microDuration)) {
                    isExpanded.toggle()
                }
            }

            // Expanded: show each run
            if isExpanded {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(items) { notif in
                        NotificationRunRow(notif: notif, viewModel: viewModel)
                    }
                }
                .padding(.leading, DN.spaceMD + DN.spaceSM)
                .padding(.trailing, DN.spaceSM)
                .padding(.bottom, DN.spaceXS)
                .transition(.opacity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(isExpanded ? 0.08 : (unreadCount > 0 ? 0.05 : 0.0)))
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct NotificationRunRow: View {
    let notif: NotificationItem
    @ObservedObject var viewModel: NotchViewModel
    @State private var showBody = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DN.spaceXS) {
                Circle()
                    .fill(notif.read ? DN.textDisabled : DN.accent)
                    .frame(width: 3, height: 3)

                Text(notifDate(notif.createdAt))
                    .font(DN.mono(8))
                    .foregroundColor(notif.read ? DN.textDisabled : DN.textSecondary)

                Spacer()

                if notif.body != nil {
                    Image(systemName: showBody ? "chevron.down" : "chevron.right")
                        .font(.system(size: 7))
                        .foregroundColor(DN.textDisabled)
                }
            }
            .padding(.vertical, DN.spaceXS)
            .contentShape(Rectangle())
            .onTapGesture {
                if notif.body != nil {
                    withAnimation(.easeOut(duration: DN.microDuration)) {
                        showBody.toggle()
                    }
                    if !notif.read {
                        viewModel.markNotificationRead(notif.id)
                    }
                }
            }

            if showBody, let body = notif.body, !body.isEmpty {
                MarkdownView(text: body, isFinal: true)
                    .padding(.bottom, DN.spaceXS)
                    .transition(.opacity)
            }
        }
    }
}

private func notifDate(_ iso: String) -> String {
    formatRelativeDate(iso, fallbackFormat: "MMM d, h:mm a")
}

// MARK: - Settings (Apple System Settings-style grouped lists)

struct SettingsPanel: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Page title — System Settings style
            HStack(spacing: 0) {
                Text("Settings")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(DN.textDisplay)
                Spacer()
            }
            .padding(.horizontal, 2)
            .padding(.bottom, DN.spaceMD)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: DN.spaceMD) {
                    SettingsSection(title: "Chat") {
                        SettingsToggleRow(
                            icon: "bubble.left.and.text.bubble.right",
                            title: "Open chat on send",
                            subtitle: "Sending a message opens the conversation instantly",
                            isOn: $viewModel.settings.openChatOnSend
                        )
                        SettingsToggleRow(
                            icon: "arrow.counterclockwise",
                            title: "Restore last view",
                            subtitle: "Re-hover opens the last page instead of home",
                            isOn: $viewModel.settings.restoreLastView
                        )
                        SettingsToggleRow(
                            icon: "lock.open",
                            title: "Keep open in chat",
                            subtitle: "Don't auto-close when viewing a conversation",
                            isOn: $viewModel.settings.keepOpenInChat
                        )
                    }

                    SettingsSection(title: "Provider") {
                        DefaultProviderRow(viewModel: viewModel)
                        ProviderRow(viewModel: viewModel, providerType: "anthropic")
                        ProviderRow(viewModel: viewModel, providerType: "openai")
                        ProviderRow(viewModel: viewModel, providerType: "openrouter")
                    }

                    SettingsSection(title: "Widgets", footer: "Pin up to 3 widgets to your overview.") {
                        ForEach(PinnedWidget.allCases, id: \.rawValue) { widget in
                            widgetToggleRow(widget)
                        }
                    }

                    SettingsSection(title: "Display") {
                        SettingsToggleRow(
                            icon: "circle.grid.3x3",
                            title: "Dot grid",
                            subtitle: "Animated dot matrix background",
                            isOn: $viewModel.settings.showDotGrid
                        )
                        if viewModel.settings.showDotGrid {
                            SettingsColorRow(
                                icon: "paintbrush",
                                title: "Accent color",
                                subtitle: "Used for the dot grid and player controls",
                                selectedHex: $viewModel.settings.dotGridColor
                            )
                            SettingsSliderRow(
                                icon: "circle.lefthalf.filled",
                                title: "Grid opacity",
                                subtitle: "Brightness of the dot grid",
                                value: $viewModel.settings.dotGridOpacity,
                                range: 0.1...1.0
                            )
                        }
                    }

                    SettingsSection(title: "Agents") {
                        SettingsToggleRow(
                            icon: "waveform",
                            title: "Live activity",
                            subtitle: "Real-time tool activity for agents",
                            isOn: $viewModel.settings.showAgentLiveState
                        )
                        SettingsToggleRow(
                            icon: "rectangle.compress.vertical",
                            title: "Compact rows",
                            subtitle: "Smaller rows in the agent list",
                            isOn: $viewModel.settings.compactAgentRows
                        )
                    }

                    SettingsSection(title: "Integrations") {
                        AppConnectionRow(viewModel: viewModel, appType: "gmail", displayName: "Gmail", icon: "envelope.fill")
                        AppConnectionRow(viewModel: viewModel, appType: "googlecalendar", displayName: "Google Calendar", icon: "calendar")
                        AppConnectionRow(viewModel: viewModel, appType: "googledocs", displayName: "Google Docs", icon: "doc.text.fill")
                        AppConnectionRow(viewModel: viewModel, appType: "github", displayName: "GitHub", icon: "chevron.left.forwardslash.chevron.right")
                    }

                    Spacer().frame(height: DN.spaceMD)
                }
            }
        }
        .onAppear {
            viewModel.loadProviderConfigs()
        }
    }

    @ViewBuilder
    private func widgetToggleRow(_ widget: PinnedWidget) -> some View {
        let isPinned = viewModel.settings.pinnedWidgets.contains(widget)
        let atMax = viewModel.settings.pinnedWidgets.count >= 3
        SettingsToggleRow(
            icon: widget.icon,
            title: widget.label,
            subtitle: widgetSubtitle(widget),
            isOn: Binding(
                get: { viewModel.settings.pinnedWidgets.contains(widget) },
                set: { newValue in
                    withAnimation(DN.transition) {
                        if !newValue {
                            viewModel.settings.pinnedWidgets.removeAll { $0 == widget }
                        } else if viewModel.settings.pinnedWidgets.count < 3 {
                            viewModel.settings.pinnedWidgets.append(widget)
                        }
                    }
                }
            )
        )
        .opacity(!isPinned && atMax ? 0.4 : 1.0)
    }

    private func widgetSubtitle(_ w: PinnedWidget) -> String {
        switch w {
        case .calendar: return "Date grid on overview"
        case .music: return "Now playing controls"
        case .ram: return "Memory usage gauge"
        case .disk: return "Storage usage ring"
        case .network: return "Upload & download speeds"
        case .uptime: return "System uptime counter"
        case .processes: return "Running process count"
        }
    }
}

// MARK: - Settings Components

// MARK: - App Connection Row (Generic)

struct DefaultProviderRow: View {
    @ObservedObject var viewModel: NotchViewModel

    private var isActive: Bool {
        !viewModel.providerConfigs.contains { $0.isActive }
    }

    var body: some View {
        SettingsRowChrome(icon: "server.rack", iconTint: iconTint(for: "server.rack"), title: "Default", subtitle: "Server API key") {
            if isActive {
                StatusBadge(text: "Active", color: .green)
            } else {
                SecondaryActionButton(label: "Use") {
                    viewModel.deactivateAllProviders()
                }
            }
        }
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous).fill(color.opacity(0.14))
            )
    }
}

struct SecondaryActionButton: View {
    let label: String
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous).fill(Color.white.opacity(0.10))
                )
                .overlay(
                    Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 0.6)
                )
        }
        .buttonStyle(.plain)
    }
}

struct ProviderRow: View {
    @ObservedObject var viewModel: NotchViewModel
    let providerType: String

    @State private var isExpanded = false
    @State private var apiKey = ""
    @State private var modelId = ""

    private var config: ProviderConfig? {
        viewModel.providerConfigs.first { $0.provider == providerType }
    }
    private var isActive: Bool { config?.isActive ?? false }
    private var isConfigured: Bool { config != nil }
    private var isVerifying: Bool { viewModel.providerVerifying[providerType] ?? false }
    private var isVerified: Bool {
        (viewModel.providerVerified[providerType] ?? false) || (config?.isVerified ?? false)
    }
    private var error: String? { viewModel.providerError[providerType] ?? nil }

    private var displayName: String {
        config?.displayName ?? ProviderConfig(
            id: "", provider: providerType, modelId: "", isActive: false
        ).displayName
    }

    private var icon: String {
        config?.icon ?? ProviderConfig(
            id: "", provider: providerType, modelId: "", isActive: false
        ).icon
    }

    private var defaultModel: String {
        ProviderConfig.defaultModels[providerType] ?? ""
    }

    private var providerTint: Color {
        switch providerType {
        case "anthropic": return Color(hex: 0xD97757)
        case "openai": return Color(hex: 0x10A37F)
        case "openrouter": return .purple
        default: return .blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            SettingsRowChrome(
                icon: icon,
                iconTint: providerTint,
                title: displayName,
                subtitle: isConfigured ? (isActive ? "Active · \(config?.modelId ?? "")" : config?.modelId ?? "") : "Not configured"
            ) {
                HStack(spacing: 6) {
                    if isActive { StatusBadge(text: "Active", color: .green) }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DN.textDisabled)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(DN.transition) {
                    isExpanded.toggle()
                    if isExpanded && modelId.isEmpty {
                        modelId = config?.modelId ?? defaultModel
                    }
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    formField(label: "API KEY", systemImage: "key.fill") {
                        SecureField("sk-…", text: $apiKey)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(DN.textPrimary)
                    }

                    formField(label: "MODEL", systemImage: "cube.fill") {
                        TextField(defaultModel, text: $modelId)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(DN.textPrimary)
                    }

                    HStack(spacing: 8) {
                        SecondaryActionButton(label: isVerifying ? "Verifying…" : (isVerified && apiKey.isEmpty ? "Verified" : "Verify"),
                                              tint: isVerified && apiKey.isEmpty ? .green : .white) {
                            guard !apiKey.isEmpty else { return }
                            let model = modelId.isEmpty ? defaultModel : modelId
                            viewModel.verifyProviderKey(provider: providerType, apiKey: apiKey, modelId: model)
                        }
                        .disabled(apiKey.isEmpty || isVerifying)
                        .opacity(apiKey.isEmpty && !isVerified ? 0.4 : 1)

                        PrimaryActionButton(label: "Save") {
                            guard !apiKey.isEmpty else { return }
                            let model = modelId.isEmpty ? defaultModel : modelId
                            viewModel.saveProviderConfig(provider: providerType, apiKey: apiKey, modelId: model)
                            apiKey = ""
                        }
                        .disabled(apiKey.isEmpty)
                        .opacity(apiKey.isEmpty ? 0.4 : 1)

                        Spacer()

                        if isConfigured {
                            SecondaryActionButton(label: "Delete", tint: DN.accent) {
                                viewModel.deleteProviderConfig(provider: providerType)
                                apiKey = ""
                                modelId = defaultModel
                            }
                        }
                    }

                    if let error = error {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(DN.accent)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .padding(.top, 4)
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private func formField<Content: View>(label: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(DN.textDisabled)
                .tracking(0.4)
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 10))
                    .foregroundColor(DN.textDisabled)
                content()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.30))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.6)
            )
        }
    }
}

struct PrimaryActionButton: View {
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous).fill(Color.accentColor.opacity(0.85))
                )
        }
        .buttonStyle(.plain)
    }
}

struct AppConnectionRow: View {
    @ObservedObject var viewModel: NotchViewModel
    let appType: String
    let displayName: String
    let icon: String

    private var isConnected: Bool { viewModel.appConnected[appType] ?? false }
    private var isLoading: Bool { viewModel.appLoading[appType] ?? false }
    private var error: String? { viewModel.appError[appType] ?? nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsRowChrome(
                icon: icon,
                iconTint: iconTint(for: icon),
                title: displayName,
                subtitle: isLoading ? "Checking…" : (isConnected ? "Connected" : "Not connected")
            ) {
                if isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    HStack(spacing: 6) {
                        if error != nil && !isConnected {
                            SecondaryActionButton(label: "Reset", tint: DN.warning) {
                                viewModel.resetApp(appType)
                            }
                        }
                        if isConnected {
                            SecondaryActionButton(label: "Disconnect", tint: DN.accent) {
                                viewModel.disconnectApp(appType)
                            }
                        } else {
                            PrimaryActionButton(label: "Connect") {
                                viewModel.connectApp(appType)
                            }
                        }
                    }
                }
            }

            if let error = error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(DN.accent)
                    .lineLimit(2)
                    .padding(.top, 2)
                    .padding(.bottom, 8)
                    .padding(.horizontal, 46)
            }
        }
        .onAppear {
            viewModel.checkAppStatus(appType)
        }
    }
}

// Apple System Settings-style section: header label above an `insetGrouped` glass card.
struct SettingsSection<Content: View>: View {
    let title: String
    var footer: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DN.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                _SettingsRowList { content }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.6)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let footer = footer {
                Text(footer)
                    .font(.system(size: 10))
                    .foregroundColor(DN.textDisabled)
                    .padding(.leading, 4)
                    .padding(.top, 2)
            }
        }
    }
}

// Helper that puts hairline dividers between rows. We can't easily inject between
// arbitrary child views, so the variadic build is approximated with VStack+overlay
// hairlines in the rows themselves where needed. Keep this transparent passthrough
// for now.
struct _SettingsRowList<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View { content() }
}

// Apple-style row: tinted square icon tile + title/subtitle + control on trailing edge.
struct SettingsRowChrome<Trailing: View>: View {
    let icon: String
    var iconTint: Color = .blue
    let title: String
    var subtitle: String? = nil
    let trailing: () -> Trailing

    init(icon: String, iconTint: Color = .blue, title: String, subtitle: String? = nil, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.icon = icon
        self.iconTint = iconTint
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            // Tinted icon tile (System Settings style)
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(iconTint.gradient)
                    .frame(width: 22, height: 22)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(DN.textPrimary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(DN.textDisabled)
                        .lineLimit(1)
                }
            }

            Spacer()

            trailing()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5)
                .padding(.leading, 46)
        }
    }
}

private func iconTint(for icon: String) -> Color {
    switch icon {
    case "bubble.left.and.text.bubble.right": return .blue
    case "arrow.counterclockwise": return .indigo
    case "lock.open": return .gray
    case "server.rack": return .gray
    case "circle.grid.3x3": return Color(red: 0.55, green: 0.55, blue: 0.95)
    case "paintbrush": return .pink
    case "circle.lefthalf.filled": return Color(red: 0.5, green: 0.5, blue: 0.55)
    case "waveform": return .green
    case "rectangle.compress.vertical": return .teal
    case "envelope.fill": return .red
    case "calendar": return .blue
    case "doc.text.fill": return .blue
    case "chevron.left.forwardslash.chevron.right": return Color(red: 0.18, green: 0.18, blue: 0.2)
    default: return .blue
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        SettingsRowChrome(icon: icon, iconTint: iconTint(for: icon), title: title, subtitle: subtitle) {
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .tint(.green)
        }
        .contentShape(Rectangle())
        .onTapGesture { isOn.toggle() }
    }
}

struct SettingsSliderRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(iconTint(for: icon).gradient)
                    .frame(width: 22, height: 22)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundColor(DN.textPrimary)
                    Spacer()
                    Text("\(Int(value * 100))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DN.textSecondary)
                        .monospacedDigit()
                }
                Slider(value: $value, in: range)
                    .controlSize(.mini)
                    .tint(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5)
                .padding(.leading, 46)
        }
    }
}

struct SettingsColorRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var selectedHex: String

    private let presets: [String] = [
        "#FFFFFF", "#D97757", "#00B4D8", "#D71921",
        "#4A9E5C", "#D4A843", "#A855F7", "#10A37F",
    ]

    var body: some View {
        SettingsRowChrome(icon: icon, iconTint: iconTint(for: icon), title: title, subtitle: subtitle) {
            HStack(spacing: 6) {
                ForEach(presets, id: \.self) { hex in
                    let isSelected = selectedHex == hex
                    Button(action: { withAnimation(DN.transition) { selectedHex = hex } }) {
                        Circle()
                            .fill(Color(hex: UInt32(hex.dropFirst(), radix: 16) ?? 0xFFFFFF))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white.opacity(isSelected ? 0.95 : 0.18), lineWidth: isSelected ? 1.5 : 0.5)
                            )
                            .scaleEffect(isSelected ? 1.1 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

import SwiftUI
import AppKit

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
        // Shoulders sit OUTSIDE the clip so they can extend left/right of
        // the notch shape and visually fillet the menu-bar junction.
        .overlay(alignment: .top) {
            shoulders
        }
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

        // Pitch black, always.
        return shape.fill(Color.black)
    }

    // Anti-aliased "shoulders" that bevel the junction between the notch's
    // rounded bottom corners and the flat menu-bar edge above. Each shoulder
    // is a small black tile with one concave rounded corner carved out, sat
    // flush against the OUTSIDE of the notch's bottom corner — the carved
    // arc curves outward so the notch+menu-bar meeting reads as one smooth
    // fillet.
    //
    //  ┌── menu bar ─────────────┐    ┌── menu bar ─────────────┐
    //  │                         │    │                         │
    //  │         ╲___notch___╱   │ →  │      ╲ ╲___notch___╱ ╱  │
    //  │                         │    │       └─ shoulders ─┘   │
    //
    // Left shoulder: the carved corner is BOTTOM-RIGHT (arc curls toward
    //   the notch's outside bottom-left corner).
    // Right shoulder: mirror — carved corner is BOTTOM-LEFT.
    private var shoulders: some View {
        let size = bottomRadius
        return ZStack(alignment: .topLeading) {
            // Left shoulder, anchored to the parent's top-leading edge and
            // shifted LEFT by its own width so it sits just outside the notch.
            NotchShoulder(corner: .bottomRight)
                .fill(Color.black)
                .frame(width: size, height: size)
                .offset(x: -size + 0.5, y: 0)

            // Right shoulder, pushed all the way to the trailing edge of the
            // notch (shapeWidth) and then OUTSIDE by its own width.
            NotchShoulder(corner: .bottomLeft)
                .fill(Color.black)
                .frame(width: size, height: size)
                .offset(x: shapeWidth - 0.5, y: 0)
        }
        .frame(width: shapeWidth, alignment: .topLeading)
        .allowsHitTesting(false)
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

    // Top bar: discrete capsule glass buttons, never .glassProminent (its
    // automatic foreground inversion turns active text black). Active state
    // is conveyed by a brighter tint on the same .glass style so the text
    // color and capsule shape stay constant across states.
    // Layout: [pad] [LEFT CLUSTER] [grow] [physical notch] [grow] [RIGHT CLUSTER] [pad]
    private var expandedTopBar: some View {
        let sideInset: CGFloat = DN.spaceMD

        return HStack(alignment: .center, spacing: 0) {
            Color.clear.frame(width: sideInset)

            // Left cluster — Home / Agents. spacing: 6 leaves a visible gap
            // between capsules; no GlassEffectContainer so they don't morph
            // into one continuous blob.
            HStack(spacing: 6) {
                topBarTab("Home", isActive: viewModel.viewState == .overview) {
                    withAnimation(DN.transition) { viewModel.viewState = .overview }
                }
                topBarTab("Agents", isActive: viewModel.isInTaskOrChat) {
                    withAnimation(DN.transition) { viewModel.viewState = .taskList }
                }
            }

            Spacer(minLength: DN.spaceSM)
            Color.clear.frame(width: notchW)
            Spacer(minLength: DN.spaceSM)

            // Right cluster — Stats / Bell / Settings
            HStack(spacing: 6) {
                topBarTab("Stats", isActive: viewModel.viewState == .stats || viewModel.viewState == .processList) {
                    withAnimation(DN.transition) { viewModel.viewState = .stats }
                }
                topBarIcon(
                    viewModel.viewState == .notifications ? "bell.fill" : "bell",
                    isActive: viewModel.viewState == .notifications,
                    badge: viewModel.unreadCount > 0
                ) {
                    withAnimation(DN.transition) { viewModel.viewState = .notifications }
                }
                topBarIcon(
                    viewModel.viewState == .settings ? "gearshape.fill" : "gearshape",
                    isActive: viewModel.viewState == .settings
                ) {
                    withAnimation(DN.transition) { viewModel.viewState = .settings }
                }
            }

            Color.clear.frame(width: sideInset)
        }
        .frame(width: shapeWidth, height: notchH)
    }

    /// A pill-shaped text button. Active uses a deep navy tint; the label
    /// stays white in every state. We fire the action on tap-release (not
    /// press) so there's no pressed-state color flash — only the post-click
    /// active state is visible.
    private func topBarTab(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Text(label)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 22)
            .glassEffect(
                isActive ? Glass.regular.tint(DN.activeAccent) : Glass.regular,
                in: .capsule
            )
            .contentShape(.capsule)
            .onTapGesture(perform: action)
    }

    /// A pill-shaped icon button. Same rules as topBarTab — release-fire,
    /// no press flash, white glyph in every state.
    private func topBarIcon(_ icon: String, isActive: Bool, badge: Bool = false, action: @escaping () -> Void) -> some View {
        Image(systemName: icon)
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 26, height: 22)
            .glassEffect(
                isActive ? Glass.regular.tint(DN.activeAccent) : Glass.regular,
                in: .capsule
            )
            .contentShape(.capsule)
            .onTapGesture(perform: action)
            .overlay(alignment: .topTrailing) {
                if badge {
                    Circle()
                        .fill(.red)
                        .frame(width: 5, height: 5)
                        .offset(x: -2, y: 2)
                }
            }
    }

}

// MARK: - Notch shoulder shape
//
// A unit square with one rounded *concave* corner. Used to bevel the
// junction between the notch and the screen's top edge. The carved corner
// is positioned so the arc curves outward, away from the menu bar, creating
// the visual illusion of a smooth fillet (the same trick used by macOS for
// its hardware notch and by display-mask apps like Notchbar).
struct NotchShoulder: Shape {
    enum Corner {
        case bottomLeft, bottomRight
    }

    let corner: Corner

    // SwiftUI/CoreGraphics coordinates: y=0 is top, y=h is bottom.
    // Each shoulder is a black square with one of its BOTTOM corners
    // carved by a concave quarter-circle (arc center = the corner itself,
    // radius = side length).
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let r = min(w, h)

        switch corner {
        case .bottomRight:
            // LEFT shoulder. Sits with its right edge flush to the notch's
            // left edge. Carving the bottom-right makes the arc curl up-and-
            // to-the-right, hugging the notch's bottom-left rounded corner.
            p.move(to: CGPoint(x: 0, y: 0))                                      // top-left
            p.addLine(to: CGPoint(x: w, y: 0))                                   // top-right
            p.addLine(to: CGPoint(x: w, y: h - r))                               // down right edge to start of arc
            // Concave arc: from (w, h-r) down to (w-r, h). Center is the
            // bottom-right corner (w, h). Angle 0° = +x, 90° = +y (down).
            // Going from 270° (which in SwiftUI's y-down system is the
            // point directly above center) ... actually keep it simple:
            // use a quadratic bezier with control = the carved corner.
            p.addQuadCurve(
                to: CGPoint(x: w - r, y: h),                                     // bottom, r in from right
                control: CGPoint(x: w, y: h)                                     // bottom-right corner pulls the curve concave
            )
            p.addLine(to: CGPoint(x: 0, y: h))                                   // bottom-left
            p.closeSubpath()

        case .bottomLeft:
            // RIGHT shoulder. Mirror — left edge flush to the notch's right
            // edge; carved bottom-left curls up-and-to-the-left.
            p.move(to: CGPoint(x: w, y: 0))                                      // top-right
            p.addLine(to: CGPoint(x: 0, y: 0))                                   // top-left
            p.addLine(to: CGPoint(x: 0, y: h - r))                               // down left edge to start of arc
            p.addQuadCurve(
                to: CGPoint(x: r, y: h),                                         // r in from left along bottom
                control: CGPoint(x: 0, y: h)                                     // bottom-left corner pulls curve concave
            )
            p.addLine(to: CGPoint(x: w, y: h))                                   // bottom-right
            p.closeSubpath()
        }
        return p
    }
}

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
                    Button("Mark all read") { viewModel.markAllRead() }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .tint(.clear)
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

// MARK: - Settings (vanilla Apple Form + Section + native controls)
//
// Per Apple's Liquid Glass guidance: never apply glass to content. The Settings
// page is a form, so we use SwiftUI's `Form` + `Section` directly and let the
// system render every row, toggle, slider, picker, and field. Action buttons
// use `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)` with
// `.tint(.clear)` on macOS where required.

struct SettingsPanel: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        Form {
            Section("Chat") {
                Toggle("Open chat on send", isOn: $viewModel.settings.openChatOnSend)
                Toggle("Restore last view", isOn: $viewModel.settings.restoreLastView)
                Toggle("Keep open in chat", isOn: $viewModel.settings.keepOpenInChat)
            }

            Section("Provider") {
                defaultProviderRow
                ForEach(["anthropic", "openai", "openrouter"], id: \.self) { providerType in
                    ProviderRow(viewModel: viewModel, providerType: providerType)
                }
            }

            Section {
                ForEach(PinnedWidget.allCases, id: \.rawValue) { widget in
                    widgetToggleRow(widget)
                }
            } header: {
                Text("Widgets")
            } footer: {
                Text("Pin up to 3 widgets to your overview.")
            }

            Section("Display") {
                Toggle("Dot grid", isOn: $viewModel.settings.showDotGrid)
                if viewModel.settings.showDotGrid {
                    LabeledContent("Accent color") {
                        ColorPicker(
                            "",
                            selection: Binding(
                                get: { viewModel.settings.dotGridSwiftColor },
                                set: { newValue in
                                    viewModel.settings.dotGridColor = newValue.toHexString()
                                }
                            ),
                            supportsOpacity: false
                        )
                        .labelsHidden()
                    }
                    LabeledContent("Grid opacity") {
                        HStack {
                            Slider(value: $viewModel.settings.dotGridOpacity, in: 0.1...1.0)
                                .frame(maxWidth: 140)
                            Text("\(Int(viewModel.settings.dotGridOpacity * 100))%")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }

            Section("Agents") {
                Toggle("Live activity", isOn: $viewModel.settings.showAgentLiveState)
                Toggle("Compact rows", isOn: $viewModel.settings.compactAgentRows)
            }

            Section("Integrations") {
                AppConnectionRow(viewModel: viewModel, appType: "gmail", displayName: "Gmail", icon: "envelope.fill")
                AppConnectionRow(viewModel: viewModel, appType: "googlecalendar", displayName: "Google Calendar", icon: "calendar")
                AppConnectionRow(viewModel: viewModel, appType: "googledocs", displayName: "Google Docs", icon: "doc.text.fill")
                AppConnectionRow(viewModel: viewModel, appType: "github", displayName: "GitHub", icon: "chevron.left.forwardslash.chevron.right")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.never)
        .padding(.horizontal, -8) // counteract the form's default inset so
                                  // section edges align with the top bar's
                                  // sideInset (DN.spaceMD = 12pt).
        .onAppear { viewModel.loadProviderConfigs() }
    }

    // MARK: - Default provider row

    private var defaultProviderRow: some View {
        let isUsingDefault = !viewModel.providerConfigs.contains { $0.isActive }
        return HStack {
            Label("Default", systemImage: "server.rack")
            Spacer()
            if isUsingDefault {
                Text("Active")
                    .foregroundStyle(.green)
                    .font(.callout)
            } else {
                Button("Use") {
                    viewModel.deactivateAllProviders()
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .tint(.clear)
            }
        }
    }

    // MARK: - Widget toggle row

    @ViewBuilder
    private func widgetToggleRow(_ widget: PinnedWidget) -> some View {
        let isPinned = viewModel.settings.pinnedWidgets.contains(widget)
        let atMax = viewModel.settings.pinnedWidgets.count >= 3
        Toggle(isOn: Binding(
            get: { isPinned },
            set: { newValue in
                withAnimation(DN.transition) {
                    if !newValue {
                        viewModel.settings.pinnedWidgets.removeAll { $0 == widget }
                    } else if viewModel.settings.pinnedWidgets.count < 3 {
                        viewModel.settings.pinnedWidgets.append(widget)
                    }
                }
            }
        )) {
            Label(widget.label, systemImage: widget.icon)
        }
        .disabled(!isPinned && atMax)
    }
}

// MARK: - Provider row (BYOK)

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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row — tappable to toggle expansion.
            HStack {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                Label(displayName, systemImage: icon)
                Spacer()
                if isActive {
                    Text("Active")
                        .foregroundStyle(.green)
                        .font(.callout)
                } else if isConfigured {
                    Text(config?.modelId ?? "")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
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
                    SecureField("API key", text: $apiKey)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )

                    Picker("Model", selection: Binding(
                        get: { modelId.isEmpty ? defaultModel : modelId },
                        set: { modelId = $0 }
                    )) {
                        ForEach(ProviderConfig.availableModels[providerType] ?? [defaultModel], id: \.self) { m in
                            Text(m).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    HStack(spacing: 8) {
                        Button(isVerifying ? "Verifying…" : (isVerified && apiKey.isEmpty ? "Verified" : "Verify")) {
                            guard !apiKey.isEmpty else { return }
                            let model = modelId.isEmpty ? defaultModel : modelId
                            viewModel.verifyProviderKey(provider: providerType, apiKey: apiKey, modelId: model)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .tint(.clear)
                        .disabled(apiKey.isEmpty || isVerifying)

                        Button("Save") {
                            guard !apiKey.isEmpty else { return }
                            let model = modelId.isEmpty ? defaultModel : modelId
                            viewModel.saveProviderConfig(provider: providerType, apiKey: apiKey, modelId: model)
                            apiKey = ""
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .tint(DN.activeAccent)
                        .foregroundStyle(.white)
                        .disabled(apiKey.isEmpty)

                        Spacer()

                        if isConfigured {
                            Button("Delete", role: .destructive) {
                                viewModel.deleteProviderConfig(provider: providerType)
                                apiKey = ""
                                modelId = defaultModel
                            }
                            .buttonStyle(.glass)
                            .controlSize(.small)
                            .tint(.clear)
                        }
                    }

                    if let error = error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                }
                .padding(.top, 10)
                .padding(.leading, 22)
                .transition(.opacity)
                .onAppear {
                    if modelId.isEmpty { modelId = config?.modelId ?? defaultModel }
                }
            }
        }
    }
}

// MARK: - App connection row (OAuth)

struct AppConnectionRow: View {
    @ObservedObject var viewModel: NotchViewModel
    let appType: String
    let displayName: String
    let icon: String

    private var isConnected: Bool { viewModel.appConnected[appType] ?? false }
    private var isLoading: Bool { viewModel.appLoading[appType] ?? false }
    private var error: String? { viewModel.appError[appType] ?? nil }

    var body: some View {
        HStack {
            Label(displayName, systemImage: icon)
            Spacer()
            if isLoading {
                ProgressView().controlSize(.small)
            } else if isConnected {
                Text("Connected")
                    .foregroundStyle(.green)
                    .font(.callout)
                Button("Disconnect") { viewModel.disconnectApp(appType) }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .tint(.clear)
            } else {
                if error != nil {
                    Button("Reset") { viewModel.resetApp(appType) }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .tint(.clear)
                }
                Button("Connect") { viewModel.connectApp(appType) }
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
                    .tint(.accentColor)
            }
        }
        .onAppear { viewModel.checkAppStatus(appType) }
    }
}

// MARK: - Color hex helper

private extension Color {
    func toHexString() -> String {
        #if os(macOS)
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .white
        let r = Int(round(ns.redComponent * 255))
        let g = Int(round(ns.greenComponent * 255))
        let b = Int(round(ns.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
        #else
        return "#FFFFFF"
        #endif
    }
}

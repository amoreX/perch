import AppKit
import SwiftUI

class DanotchPanel: NSPanel {
    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: backing,
            defer: flag
        )

        isFloatingPanel = true
        isOpaque = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        isMovable = false
        level = .mainMenu + 3
        hasShadow = false
        isReleasedWhenClosed = false
        appearance = NSAppearance(named: .darkAqua)

        collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle,
        ]
    }

    // Must be true for TextField to receive keyboard input
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // Make AppKit *render* controls as active (so .buttonStyle(.glass) shows
    // its proper key-window appearance) without actually stealing focus from
    // the foreground app. We never call makeKey unless the chat input is
    // being focused; until then the panel is visually key but inactive.
    override var isKeyWindow: Bool { true }
    override var isMainWindow: Bool { false }
}

class NotchWindowController: NSObject {
    let viewModel: NotchViewModel
    /// One panel per attached NSScreen, keyed by screen.dn_uuid.
    /// The first panel created hosts the SwiftUI view; secondary panels just
    /// mirror its frame so the UI stays in one place. We swap which panel is
    /// "active" as the cursor moves between monitors.
    private var panels: [String: DanotchPanel] = [:]
    /// The panel currently hosting the SwiftUI view + reacting to hover.
    private var activeScreenUUID: String?
    var globalMonitor: Any?
    var localMonitor: Any?
    var scrollMonitor: Any?
    var keyboardMonitor: Any?
    var localKeyboardMonitor: Any?
    var collapseTimer: Timer?
    var swipeAccumulator: CGFloat = 0

    private let panelWidth: CGFloat = 580
    private let panelHeight: CGFloat = 400

    private var activePanel: DanotchPanel? {
        if let uuid = activeScreenUUID { return panels[uuid] }
        return nil
    }

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        super.init()
    }

    func show() {
        rebuildPanels()
        startMouseTracking()
        startKeyboardShortcut()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    /// Tear down existing panels and create a fresh one for every attached
    /// screen. We do this on initial show and whenever the screen layout
    /// changes (monitor plug/unplug, resolution change).
    private func rebuildPanels() {
        for panel in panels.values {
            panel.orderOut(nil)
        }
        panels.removeAll()
        activeScreenUUID = nil

        let styleMask: NSWindow.StyleMask = [
            .borderless, .nonactivatingPanel, .utilityWindow, .hudWindow,
        ]

        for screen in NSScreen.screens {
            let panel = DanotchPanel(
                contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
                styleMask: styleMask,
                backing: .buffered,
                defer: false
            )
            panel.ignoresMouseEvents = true
            panel.acceptsMouseMovedEvents = true
            positionPanel(panel, on: screen)
            panel.orderFrontRegardless()
            panels[screen.dn_uuid] = panel
        }

        // Pick whichever screen currently has the mouse, falling back to the
        // main screen, then to any screen.
        let target = screenForMouse() ?? NSScreen.main ?? NSScreen.screens.first
        if let target = target {
            activateScreen(target)
        }
    }

    /// Move the SwiftUI host into the panel on `screen` and update tracking
    /// so that monitor becomes the interactive one.
    private func activateScreen(_ screen: NSScreen) {
        let uuid = screen.dn_uuid
        guard let panel = panels[uuid] else { return }
        if activeScreenUUID == uuid && panel.contentView is NSHostingView<NotchShellView> {
            return
        }

        // Strip the SwiftUI host from the previously active panel, if any.
        if let prevUUID = activeScreenUUID, prevUUID != uuid, let prev = panels[prevUUID] {
            prev.contentView = nil
            prev.ignoresMouseEvents = true
        }

        let shellView = NotchShellView(viewModel: viewModel)
        panel.contentView = NSHostingView(rootView: shellView)
        activeScreenUUID = uuid
    }

    private func positionPanel(_ panel: DanotchPanel, on screen: NSScreen) {
        let w = panel.frame.width
        let h = panel.frame.height
        panel.setFrameOrigin(NSPoint(
            x: screen.frame.origin.x + (screen.frame.width / 2) - w / 2,
            y: screen.frame.origin.y + screen.frame.height - h
        ))
    }

    @objc private func screenChanged() {
        rebuildPanels()
    }

    /// Return the NSScreen currently under the cursor (in global coords).
    private func screenForMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) }
    }

    // MARK: - Global Keyboard Shortcut (Cmd+Shift+Space)

    private func startKeyboardShortcut() {
        let checkShortcut: (NSEvent) -> Bool = { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            return flags.contains([.command, .shift]) && event.keyCode == 49
        }

        // Global monitor: fires when app is NOT key
        keyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if checkShortcut(event) {
                self?.handleGlobalShortcut()
            }
        }
        // Local monitor: fires when app IS key (panel has focus)
        localKeyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if checkShortcut(event) {
                self?.handleGlobalShortcut()
                return nil
            }
            // Escape to collapse
            if event.keyCode == 53 && self?.viewModel.isExpanded == true {
                self?.collapse()
                return nil
            }
            return event
        }
    }

    private func handleGlobalShortcut() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.viewModel.isExpanded {
                self.collapse()
            } else {
                // Drop down on whichever monitor currently has the cursor in
                // quick-prompt mode — a semi-expanded notch with just a glass
                // text field. Sending will spring the panel to full height
                // and continue in the chat view.
                if let screen = self.screenForMouse() {
                    self.activateScreen(screen)
                }
                self.viewModel.isQuickPrompt = true
                self.expand()
                self.viewModel.viewState = .overview
                self.viewModel.shouldFocusChatInput = true
                self.activePanel?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    // MARK: - Global Mouse Tracking

    private func startMouseTracking() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            self?.checkMouse()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.checkMouse()
            return event
        }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScroll(event)
            return event
        }
    }

    private func handleScroll(_ event: NSEvent) {
        guard viewModel.isExpanded else { return }
        guard viewModel.viewState == .taskList else { return }

        guard abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) * 2 else { return }

        guard event.phase == .changed || event.momentumPhase == .changed else {
            if event.phase == .ended || event.phase == .cancelled {
                swipeAccumulator = 0
            }
            return
        }

        swipeAccumulator += event.scrollingDeltaX

        if swipeAccumulator > 60 {
            swipeAccumulator = 0
            withAnimation(DN.viewStateSpring) {
                viewModel.viewState = .overview
            }
        }
    }

    private func checkMouse() {
        // Mouse position is in global coordinates, which span every attached
        // display, so we resolve which screen the cursor is on each tick.
        guard let screen = screenForMouse() else { return }
        let mouse = NSEvent.mouseLocation

        let cx = screen.frame.midX
        let nw = screen.notchWidth
        let nh = screen.notchHeight

        // Discrete trigger zones — no fuzzy in-between region:
        //  - Collapsed: only the physical notch rect (exact width, exact height)
        //  - Expanded: only the actual expanded shape rect
        //  No padding, no overshoot — state flips cleanly between off and on.
        let hit: Bool
        if viewModel.isExpanded {
            let ew = expandedShapeWidth(notchW: nw)
            let eh = expandedShapeHeight(notchH: nh)
            let expandedRect = NSRect(
                x: cx - ew / 2,
                y: screen.frame.maxY - eh,
                width: ew,
                height: eh
            )
            hit = expandedRect.contains(mouse)
        } else {
            // Extend the hit rect UP past the screen's top edge so the very
            // topmost row of pixels (which macOS sometimes reserves for the
            // menu-bar edge / system gestures and which NSRect.contains
            // treats as exclusive on the max edge) still counts as a hit.
            let edgeSlack: CGFloat = 4
            let notchRect = NSRect(
                x: cx - nw / 2,
                y: screen.frame.maxY - nh,
                width: nw,
                height: nh + edgeSlack
            )
            hit = notchRect.contains(mouse)
        }

        if hit {
            // The cursor is now on `screen`; make sure the SwiftUI host lives
            // there so this monitor's panel is the interactive one.
            if activeScreenUUID != screen.dn_uuid {
                activateScreen(screen)
            }
            collapseTimer?.invalidate()
            collapseTimer = nil
            if !viewModel.isExpanded {
                expand()
            }
        } else if viewModel.isExpanded {
            // Clear chat input focus when mouse leaves the panel entirely
            if viewModel.isChatInputActive {
                viewModel.isChatInputActive = false
                viewModel.shouldFocusChatInput = false
            }
            // Don't auto-collapse if in a chat and setting is on
            if case .agentChat = viewModel.viewState, viewModel.settings.keepOpenInChat {
                return
            }
            // Don't auto-collapse while an app connection is in progress
            if viewModel.appLoading.values.contains(true) {
                return
            }
            scheduleCollapse()
        }
    }

    // Single canonical expanded size — must match NotchShellView.expandedW/H
    private func expandedShapeWidth(notchW: CGFloat) -> CGFloat {
        if viewModel.isPeeking {
            return viewModel.peekHovering ? notchW + 200 : notchW + 140
        }
        return NotchShellView.expandedW
    }

    private func expandedShapeHeight(notchH: CGFloat) -> CGFloat {
        if viewModel.isPeeking {
            return viewModel.peekHovering ? notchH + 80 : notchH + 28
        }
        if viewModel.isQuickPrompt {
            return notchH + NotchShellView.quickPromptH
        }
        return notchH + NotchShellView.expandedH
    }

    private func expand() {
        activePanel?.ignoresMouseEvents = false
        // Keep window shadow off — AppKit renders it above the screen edge
        // as a hairline at the top of the notch shape. The drop shadow is
        // drawn inside SwiftUI instead, where we can clip it to the bottom.
        activePanel?.hasShadow = false
        viewModel.restoreOrResetView()
        // .nonactivatingPanel + makeKeyAndOrderFront makes the panel key —
        // so SwiftUI/AppKit renders controls in their proper active state —
        // WITHOUT activating the app. The foreground app stays main and
        // keeps its own focus, but our glass buttons no longer look flat.
        activePanel?.makeKeyAndOrderFront(nil)
        withAnimation(DN.expandSpring) {
            viewModel.isExpanded = true
        }
    }

    private func collapse() {
        withAnimation(DN.collapseSpring) {
            viewModel.isExpanded = false
            viewModel.isQuickPrompt = false
            viewModel.isChatInputActive = false
            viewModel.resetView()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self = self else { return }
            if !self.viewModel.isExpanded {
                self.activePanel?.ignoresMouseEvents = true
                self.activePanel?.resignKey()
            }
        }
    }

    private func scheduleCollapse() {
        guard collapseTimer == nil else { return }
        collapseTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.collapseTimer = nil
            if !self.viewModel.mouseInContent && !self.viewModel.isChatInputActive {
                self.collapse()
            }
        }
    }

    deinit {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        if let m = scrollMonitor { NSEvent.removeMonitor(m) }
        if let m = keyboardMonitor { NSEvent.removeMonitor(m) }
        if let m = localKeyboardMonitor { NSEvent.removeMonitor(m) }
        collapseTimer?.invalidate()
    }
}

extension NSScreen {
    /// Stable per-display identifier. Falls back to the address of the
    /// NSScreen if the device description is missing.
    var dn_uuid: String {
        if let n = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return "display-\(n.uint32Value)"
        }
        return "screen-\(ObjectIdentifier(self).hashValue)"
    }

    var hasNotch: Bool {
        safeAreaInsets.top > 0
    }

    var notchHeight: CGFloat {
        let menuBarHeight = frame.maxY - visibleFrame.maxY
        return max(menuBarHeight, 32)
    }

    var notchWidth: CGFloat {
        guard hasNotch else { return 180 }
        if let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea {
            return right.minX - left.maxX
        }
        return 200
    }
}

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
}

class NotchWindowController: NSObject {
    var panel: DanotchPanel!
    let viewModel: NotchViewModel
    var globalMonitor: Any?
    var localMonitor: Any?
    var scrollMonitor: Any?
    var keyboardMonitor: Any?
    var localKeyboardMonitor: Any?
    var collapseTimer: Timer?
    var swipeAccumulator: CGFloat = 0

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        super.init()
    }

    func show() {
        guard let screen = NSScreen.main else {
            print("[Danotch] No main screen found")
            return
        }

        let panelWidth: CGFloat = 580
        let panelHeight: CGFloat = 400
        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow]

        let panel = DanotchPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        panel.ignoresMouseEvents = true
        panel.acceptsMouseMovedEvents = true

        let shellView = NotchShellView(viewModel: viewModel)
        panel.contentView = NSHostingView(rootView: shellView)

        self.panel = panel
        positionPanel(on: screen)
        panel.orderFrontRegardless()

        startMouseTracking()
        startKeyboardShortcut()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func positionPanel(on screen: NSScreen) {
        let w = panel.frame.width
        let h = panel.frame.height
        panel.setFrameOrigin(NSPoint(
            x: screen.frame.origin.x + (screen.frame.width / 2) - w / 2,
            y: screen.frame.origin.y + screen.frame.height - h
        ))
    }

    @objc private func screenChanged() {
        guard let screen = NSScreen.main else { return }
        positionPanel(on: screen)
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
                self.expand()
                self.viewModel.viewState = .overview
                self.viewModel.shouldFocusChatInput = true
                // Make panel key so TextField can receive input
                self.panel.makeKeyAndOrderFront(nil)
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
        guard let screen = NSScreen.main else { return }
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
            let notchRect = NSRect(
                x: cx - nw / 2,
                y: screen.frame.maxY - nh,
                width: nw,
                height: nh
            )
            hit = notchRect.contains(mouse)
        }

        if hit {
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

    // Mirror NotchShellView.shapeWidth/Height so trigger zones match the visible shape exactly.
    private func expandedShapeWidth(notchW: CGFloat) -> CGFloat {
        if viewModel.isPeeking {
            return viewModel.peekHovering ? notchW + 200 : notchW + 140
        }
        switch viewModel.viewState {
        case .taskList, .agentChat, .processList: return 540
        case .stats, .settings, .notifications, .overview: return 520
        }
    }

    private func expandedShapeHeight(notchH: CGFloat) -> CGFloat {
        if viewModel.isPeeking {
            return viewModel.peekHovering ? notchH + 80 : notchH + 28
        }
        switch viewModel.viewState {
        case .overview, .taskList: return notchH + 260
        case .agentChat, .processList, .settings: return notchH + 320
        case .stats, .notifications: return notchH + 290
        }
    }

    private func expand() {
        panel.ignoresMouseEvents = false
        viewModel.restoreOrResetView()
        withAnimation(DN.expandSpring) {
            viewModel.isExpanded = true
        }
    }

    private func collapse() {
        withAnimation(DN.collapseSpring) {
            viewModel.isExpanded = false
            viewModel.isChatInputActive = false
            viewModel.resetView()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self = self else { return }
            if !self.viewModel.isExpanded {
                self.panel.ignoresMouseEvents = true
                self.panel.resignKey()
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

import AppKit
import Darwin
import SwiftUI

@main
enum AControlApp {
  @MainActor private static var delegate: AControlAppDelegate?

  @MainActor
  static func main() {
    RemoteShellLaunchGuard.exitIfNeeded()
    let app = NSApplication.shared
    let appDelegate = AControlAppDelegate()
    delegate = appDelegate
    app.delegate = appDelegate
    app.setActivationPolicy(.regular)
    appDelegate.installMainMenu()
    app.finishLaunching()
    app.run()
  }
}

private enum RemoteShellLaunchGuard {
  static func exitIfNeeded() {
    let environment = ProcessInfo.processInfo.environment
    guard environment["ACONTROL_ALLOW_REMOTE_SHELL_GUI_LAUNCH"] != "1" else { return }
    guard environment["SSH_CONNECTION"] != nil || environment["SSH_TTY"] != nil else { return }

    let message = """
      SSHcontroll is a macOS GUI app. Do not execute Contents/MacOS/SSHcontroll from SSH, tmux, or Codex.
      Launch it from the logged-in desktop with:
        open "$HOME/Desktop/SSHcontroll.app"
      or use SSHcontroll Settings > Permissions / the A-Cockpit Permission Host for A-side GUI work.
      Exiting before NSApplication registration to avoid a macOS RegisterApplication crash.

      """
    if let data = message.data(using: .utf8) {
      FileHandle.standardError.write(data)
    }
    Darwin.exit(64)
  }
}

@MainActor
final class AControlAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  private let model = AppModel()
  private var mainWindow: NSWindow?
  private var codeWorkspaceWindow: NSWindow?
  private var requestedInitialFullScreen = false
  private var requestedCodeWorkspaceFullScreen = false
  private var keepAliveActivity: NSObjectProtocol?

  override init() {
    super.init()
    let environment = ProcessInfo.processInfo.environment
    if let surface = environment["ACONTROL_SURFACE"].flatMap(AppSurface.init(rawValue:)) {
      model.selectedSurface = surface
    }
    if let theme = environment["ACONTROL_THEME"].flatMap(AppTheme.init(rawValue:)) {
      model.settings.theme = theme
    }
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    installMainMenu()
    beginKeepAliveActivity()
    showMainWindow()
    if shouldOpenCodeWorkspaceWindowOnLaunch {
      showCodeWorkspaceWindow()
    }
    Task {
      await model.bootstrapOnLaunch()
    }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    showMainWindow()
    return true
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  private func beginKeepAliveActivity() {
    guard keepAliveActivity == nil else { return }
    keepAliveActivity = ProcessInfo.processInfo.beginActivity(
      options: [
        .userInitiated,
        .idleSystemSleepDisabled,
        .suddenTerminationDisabled,
        .automaticTerminationDisabled,
      ],
      reason: "Keep SSHcontroll session sync, transcript polling, and file preview caches warm."
    )
  }

  private var shouldOpenCodeWorkspaceWindowOnLaunch: Bool {
    let environment = ProcessInfo.processInfo.environment
    return environment["ACONTROL_CODE_WORKSPACE"] == "1"
  }

  func showMainWindow() {
    if mainWindow == nil {
      let content = MainWindowContent()
        .environmentObject(model)
        .frame(minWidth: 900, minHeight: 620)

      let initialFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
      let window = NSWindow(
        contentRect: initialFrame,
        styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
        backing: .buffered,
        defer: false
      )
      window.title = "SSHcontroll"
      window.titleVisibility = .hidden
      window.titlebarAppearsTransparent = true
      window.isReleasedWhenClosed = false
      window.delegate = self
      window.collectionBehavior = [.fullScreenPrimary, .managed]
      window.contentView = NSHostingView(rootView: content)
      mainWindow = window
    }

    if mainWindow?.isMiniaturized == true {
      mainWindow?.deminiaturize(nil)
    }
    mainWindow?.makeKeyAndOrderFront(nil)
    mainWindow?.makeMain()
    mainWindow?.makeKey()
    mainWindow?.orderFrontRegardless()
    NSApp.activate(ignoringOtherApps: true)
    requestInitialFullScreenIfNeeded()
    if ProcessInfo.processInfo.environment["ACONTROL_CODE_WORKSPACE"] != "1" {
      scheduleSnapshotIfRequested()
    }
  }

  func showCodeWorkspaceWindow() {
    if codeWorkspaceWindow == nil {
      let content = CodeWorkspaceWindowContent()
        .environmentObject(model)

      let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1512, height: 982)
      let frame: NSRect
      if model.settings.openFullScreenOnLaunch {
        frame = screenFrame
      } else {
        let width = min(max(1180, screenFrame.width * 0.88), screenFrame.width)
        let height = min(max(760, screenFrame.height * 0.86), screenFrame.height)
        frame = NSRect(
          x: screenFrame.midX - width / 2,
          y: screenFrame.midY - height / 2,
          width: width,
          height: height
        )
      }
      let window = NSWindow(
        contentRect: frame,
        styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
        backing: .buffered,
        defer: false
      )
      window.title = "A Code Workspace"
      window.titlebarAppearsTransparent = true
      window.isReleasedWhenClosed = false
      window.delegate = self
      window.collectionBehavior = [.managed, .fullScreenPrimary]
      window.contentView = NSHostingView(rootView: content)
      codeWorkspaceWindow = window
    }

    model.setCodeWorkspaceDetachedOpen(true)
    model.alignCodeWorkspaceToActiveSessionDirectory()
    if codeWorkspaceWindow?.isMiniaturized == true {
      codeWorkspaceWindow?.deminiaturize(nil)
    }
    codeWorkspaceWindow?.makeKeyAndOrderFront(nil)
    codeWorkspaceWindow?.makeMain()
    codeWorkspaceWindow?.makeKey()
    codeWorkspaceWindow?.orderFrontRegardless()
    NSApp.activate(ignoringOtherApps: true)
    requestCodeWorkspaceFullScreenIfNeeded()
    Task {
      await model.prepareCodeWorkspaceForActiveSession()
      await model.refreshCodexWorkingStates(force: true)
      await model.captureCodexIfUseful(force: true)
      await model.captureShell()
    }
    if ProcessInfo.processInfo.environment["ACONTROL_CODE_WORKSPACE"] == "1" {
      scheduleSnapshotIfRequested()
    }
  }

  func windowWillClose(_ notification: Notification) {
    guard let window = notification.object as? NSWindow, window == codeWorkspaceWindow else {
      return
    }
    model.setCodeWorkspaceDetachedOpen(false)
    requestedCodeWorkspaceFullScreen = false
  }

  private func requestInitialFullScreenIfNeeded() {
    guard model.settings.openFullScreenOnLaunch,
      !requestedInitialFullScreen,
      ProcessInfo.processInfo.environment["ACONTROL_SNAPSHOT"] == nil,
      let mainWindow
    else { return }
    requestedInitialFullScreen = true
    requestFullScreen(mainWindow, delay: 0.25)
  }

  private func requestCodeWorkspaceFullScreenIfNeeded() {
    guard model.settings.openFullScreenOnLaunch,
      !requestedCodeWorkspaceFullScreen,
      ProcessInfo.processInfo.environment["ACONTROL_SNAPSHOT"] == nil,
      let codeWorkspaceWindow
    else { return }
    requestedCodeWorkspaceFullScreen = true
    requestFullScreen(codeWorkspaceWindow, delay: 0.45)
  }

  private func requestFullScreen(_ window: NSWindow, delay: TimeInterval) {
    if let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
      window.setFrame(visibleFrame, display: true)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
      if !window.styleMask.contains(.fullScreen) {
        window.toggleFullScreen(nil)
      }
    }
  }

  private func scheduleSnapshotIfRequested() {
    guard let path = ProcessInfo.processInfo.environment["ACONTROL_SNAPSHOT"] else { return }
    let delay =
      ProcessInfo.processInfo.environment["ACONTROL_SNAPSHOT_DELAY"].flatMap(Double.init) ?? 1.0
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
      self?.writeSnapshot(to: path)
    }
  }

  private func writeSnapshot(to path: String) {
    defer {
      if ProcessInfo.processInfo.environment["ACONTROL_SNAPSHOT_QUIT"] == "1" {
        DispatchQueue.main.async {
          NSApp.terminate(nil)
        }
      }
    }
    let snapshotWindow =
      ProcessInfo.processInfo.environment["ACONTROL_CODE_WORKSPACE"] == "1"
      ? codeWorkspaceWindow ?? mainWindow
      : mainWindow
    guard let contentView = snapshotWindow?.contentView else { return }
    let bounds = contentView.bounds
    guard let rep = contentView.bitmapImageRepForCachingDisplay(in: bounds) else { return }
    contentView.cacheDisplay(in: bounds, to: rep)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: URL(fileURLWithPath: path))
  }

  func installMainMenu() {
    let mainMenu = NSMenu()

    let appItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(
      withTitle: "Quit SSHcontroll", action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q")
    appItem.submenu = appMenu
    mainMenu.addItem(appItem)

    let fileItem = NSMenuItem()
    let fileMenu = NSMenu(title: "File")
    fileMenu.addItem(withTitle: "New Window", action: #selector(newWindow(_:)), keyEquivalent: "n")
    fileMenu.addItem(
      withTitle: "Open Code Workspace", action: #selector(openCodeWorkspace(_:)),
      keyEquivalent: "e")
    fileMenu.addItem(
      workspaceMenuItem(
        title: "Open Code Workspace in New Window",
        action: #selector(openCodeWorkspaceWindow(_:)),
        key: "e",
        modifiers: [.command, .shift]
      )
    )
    fileMenu.addItem(
      workspaceMenuItem(
        title: "Choose Workspace Folder",
        action: #selector(chooseWorkspaceFolder(_:)),
        key: "o",
        modifiers: [.control]
      )
    )
    fileMenu.addItem(
      withTitle: "Save Current File", action: #selector(saveCurrentFile(_:)),
      keyEquivalent: "s")
    fileMenu.addItem(NSMenuItem.separator())
    fileMenu.addItem(
      withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
    fileItem.submenu = fileMenu
    mainMenu.addItem(fileItem)

    let editItem = NSMenuItem()
    let editMenu = NSMenu(title: "Edit")
    editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
    editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
    editMenu.addItem(NSMenuItem.separator())
    editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    editMenu.addItem(NSMenuItem.separator())
    editMenu.addItem(
      withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    editItem.submenu = editMenu
    mainMenu.addItem(editItem)

    let actionsItem = NSMenuItem()
    let actionsMenu = NSMenu(title: "SSHcontroll")
    actionsMenu.addItem(withTitle: "Refresh", action: #selector(refresh(_:)), keyEquivalent: "r")
    actionsMenu.addItem(withTitle: "Send", action: #selector(send(_:)), keyEquivalent: "\r")
    actionsMenu.addItem(
      withTitle: "Codex Escape", action: #selector(codexEscape(_:)), keyEquivalent: "\u{1B}")
    actionsMenu.addItem(NSMenuItem.separator())
    actionsMenu.addItem(
      withTitle: "Open Mirror Folder", action: #selector(openMirrorFolder(_:)), keyEquivalent: "M")
    actionsItem.submenu = actionsMenu
    mainMenu.addItem(actionsItem)

    let windowItem = NSMenuItem()
    let windowMenu = NSMenu(title: "Window")
    windowMenu.addItem(
      workspaceMenuItem(
        title: "Back from Code Workspace",
        action: #selector(closeCodeWorkspaceInline(_:)),
        key: "[",
        modifiers: [.command]
      )
    )
    windowMenu.addItem(NSMenuItem.separator())
    windowMenu.addItem(
      withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
    windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: "")
    windowMenu.addItem(
      withTitle: "Toggle Full Screen", action: #selector(toggleFullScreen(_:)),
      keyEquivalent: "\u{1B}")
    windowMenu.addItem(NSMenuItem.separator())
    windowMenu.addItem(
      workspaceMenuItem(
        title: "Toggle Workspace Explorer",
        action: #selector(toggleWorkspaceExplorer(_:)),
        key: "b",
        modifiers: [.command]
      )
    )
    windowMenu.addItem(
      workspaceMenuItem(
        title: "Toggle Workspace Console",
        action: #selector(toggleWorkspaceConsole(_:)),
        key: "j",
        modifiers: [.command]
      )
    )
    windowMenu.addItem(
      workspaceMenuItem(
        title: "Toggle Workspace Codex",
        action: #selector(toggleWorkspaceCodex(_:)),
        key: "c",
        modifiers: [.command, .option]
      )
    )
    windowItem.submenu = windowMenu
    mainMenu.addItem(windowItem)
    NSApp.windowsMenu = windowMenu

    NSApp.mainMenu = mainMenu
  }

  private func workspaceMenuItem(
    title: String,
    action: Selector,
    key: String,
    modifiers: NSEvent.ModifierFlags
  ) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
    item.keyEquivalentModifierMask = modifiers
    return item
  }

  @objc private func newWindow(_ sender: Any?) {
    showMainWindow()
  }

  @objc private func openCodeWorkspace(_ sender: Any?) {
    showMainWindow()
    model.openCodeWorkspaceInline()
    Task {
      await model.prepareCodeWorkspaceForActiveSession()
      await model.refreshCodexWorkingStates(force: true)
      await model.captureCodexIfUseful(force: true)
      await model.captureShell()
    }
  }

  @objc private func openCodeWorkspaceWindow(_ sender: Any?) {
    showCodeWorkspaceWindow()
  }

  @objc private func chooseWorkspaceFolder(_ sender: Any?) {
    openCodeWorkspace(sender)
    model.isCodeWorkspaceDirectoryPickerPresented = true
  }

  @objc private func toggleWorkspaceExplorer(_ sender: Any?) {
    if !model.isCodeWorkspaceInlineActive && !model.isCodeWorkspaceDetachedOpen {
      openCodeWorkspace(sender)
    }
    model.toggleCodeWorkspaceExplorer()
  }

  @objc private func toggleWorkspaceConsole(_ sender: Any?) {
    if !model.isCodeWorkspaceInlineActive && !model.isCodeWorkspaceDetachedOpen {
      openCodeWorkspace(sender)
    }
    model.toggleCodeWorkspaceConsole()
  }

  @objc private func toggleWorkspaceCodex(_ sender: Any?) {
    if !model.isCodeWorkspaceInlineActive && !model.isCodeWorkspaceDetachedOpen {
      openCodeWorkspace(sender)
    }
    model.toggleCodeWorkspaceCodex()
  }

  @objc private func closeCodeWorkspaceInline(_ sender: Any?) {
    model.closeCodeWorkspaceInline()
  }

  @objc private func saveCurrentFile(_ sender: Any?) {
    Task { await model.saveRemoteFile() }
  }

  @objc private func refresh(_ sender: Any?) {
    Task { await model.refreshActiveSurface() }
  }

  @objc private func send(_ sender: Any?) {
    Task { await model.sendCurrentInput() }
  }

  @objc private func codexEscape(_ sender: Any?) {
    switch model.selectedSurface {
    case .codex:
      Task { await model.codexKey("esc") }
    case .claude:
      Task { await model.claudeKey("esc") }
    default:
      break
    }
  }

  @objc private func openMirrorFolder(_ sender: Any?) {
    model.openLocalFolder(model.settings.mirrorBase.expandingTilde)
  }

  @objc private func toggleFullScreen(_ sender: Any?) {
    NSApp.keyWindow?.toggleFullScreen(nil)
  }
}

private struct MainWindowContent: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    RootView()
      .preferredColorScheme(model.settings.theme.colorScheme)
  }
}

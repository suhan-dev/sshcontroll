import AppKit
import Foundation
import SwiftUI

private struct RemoteFileSignature: Equatable {
  var size: Int64
  var modifiedAt: String
}

private struct CodexAQueueBatchRequest: Encodable {
  var jobs: [CodexAQueueBatchJob]
}

private struct CodexAQueueBatchJob: Encodable {
  var clientID: String
  var kind: String
  var prompt: String
  var order: String
  var historyID: String
  var directory: String
  var forceNew: Bool = false
  var excludeHistoryIDs: [String] = []
}

@MainActor
final class AppModel: ObservableObject {
  private static let deliveredCodexQueueRetentionSeconds: TimeInterval = 6 * 60 * 60
  private static let deliveredResearchQueueRetentionSeconds: TimeInterval = 72 * 60 * 60
  private static let defaultCodexTranscriptTailBytes = 4 * 1024 * 1024
  private static let maxCodexTranscriptTailBytes = 64 * 1024 * 1024

  private static let fileSizeFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter
  }()

  private static func deliveredQueueRetentionSeconds(for item: CodexPromptQueueItem) -> TimeInterval {
    if item.researchGroupID?.trimmed.isEmpty == false {
      return deliveredResearchQueueRetentionSeconds
    }
    return deliveredCodexQueueRetentionSeconds
  }

  private static func shouldRetainDeliveredQueueItem(
    _ item: CodexPromptQueueItem,
    now: Date
  ) -> Bool {
    item.updatedAt >= now.addingTimeInterval(-deliveredQueueRetentionSeconds(for: item))
  }

  @Published var selectedSurface: AppSurface = .dashboard
  @Published var isCodeWorkspaceOpen = false
  @Published var isCodeWorkspaceInlineActive = false
  @Published var isCodeWorkspaceDetachedOpen = false
  @Published var codeWorkspaceExplorerWidth: CGFloat = 300
  @Published var codeWorkspaceCodexWidth: CGFloat = 330
  @Published var codeWorkspaceConsoleHeight: CGFloat = 170
  @Published var isCodeWorkspaceExplorerCollapsed = false
  @Published var isCodeWorkspaceCodexCollapsed = false
  @Published var isCodeWorkspaceConsoleVisible = true
  @Published var isCodeWorkspaceDirectoryPickerPresented = false
  @Published var settings: AppSettings
  @Published var isBusy = false
  @Published var statusText = "Ready"
  @Published var shellTranscript = ""
  @Published var codexTranscript = ""
  @Published var dashboardStatusSnapshot = ""
  @Published var monitorSnapshot = ""
  @Published var fanSnapshot = ""
  @Published var fanActionLog = ""
  @Published var isMeasuringFan = false
  @Published var isRefreshingMonitor = false
  @Published var monitorMetricInFlight: String?
  @Published var shellInput = ""
  @Published var shellCompletions: [ShellCompletion] = []
  @Published var activeFileTransfer: FileTransferProgress?
  @Published var fileTransferLogEntries: [String] = []
  @Published var codexInput = ""
  @Published var codexModel = "gpt-5.5"
  @Published var codexReasoningEffort = "xhigh"
  @Published var codexTranscriptCheckedAt: Date?
  @Published var codexTranscriptUpdatedAt: Date?
  @Published var codexTranscriptCanLoadMore = false
  @Published var isLoadingMoreCodexTranscript = false
  @Published var codexToken5h = "Tap Tokens"
  @Published var codexTokenWeekly = "Tap Tokens"
  @Published var codexTokenReset = "Codex /status has not been read yet."
  @Published var codexAttachments: [PromptAttachment] = []
  @Published var codexPromptQueue: [CodexPromptQueueItem] = [] {
    didSet {
      persistCodexPromptQueueIfReady()
    }
  }
  @Published var isProcessingCodexPromptQueue = false
  @Published var codexTranscriptAutoRefreshGeneration = 0
  @Published var codexHistoryRecords: [CodexHistoryRecord] = []
  @Published var codexArtifacts: [CodexArtifact] = []
  @Published var codexPreviewArtifact: CodexArtifact?
  @Published var codexArtifactPreviewText = ""
  @Published var codexArtifactPreviewURL: URL?
  @Published var codexInlineImagePreviewURLs: [String: URL] = [:]
  @Published var codexArtifactPreviewKind: RemotePreviewKind = .none
  @Published var isCodexArtifactPreviewLoading = false
  @Published var codexArtifactPreviewError = ""
  @Published var isCodexFilePanelVisible = false
  @Published var claudeTranscript = ""
  @Published var claudeInput = ""
  @Published var claudeAttachments: [PromptAttachment] = []
  @Published var toolCheckLog = ""
  @Published var codexPluginLog = ""
  @Published var permissionLog = ""
  @Published var remotePermissionCheckPassed = false
  @Published var appleSigningLog = ""
  @Published var remoteItems: [RemoteItem] = []
  @Published var currentRemoteDir: String
  @Published var fileBrowserDir: String
  @Published var fileBrowserItems: [RemoteItem] = []
  @Published var isFileBrowserLoading = false
  @Published var fileBrowserError = ""
  @Published var selectedRemoteItemID: String?
  @Published var selectedRemoteItemIDs: Set<String> = []
  @Published var remoteFileText = ""
  @Published var remoteFileSavedText = ""
  @Published var remoteFileIsPreviewOnly = false
  @Published var openedRemoteFile: String?
  @Published var remotePreviewURL: URL?
  @Published var remotePreviewKind: RemotePreviewKind = .none
  @Published var isRemotePreviewLoading = false
  @Published var sessions: [SessionCard] = []
  @Published var activeSessionID: UUID?
  @Published var workingSessionIDs: Set<UUID> = []
  @Published var codexWorkingSessionIDs: Set<UUID> = []
  @Published var codexWorkingStartedAtBySession: [UUID: Date] = [:]
  @Published var claudeWorkingSessionIDs: Set<UUID> = []
  @Published var lastMirrorLog = ""
  @Published var searchText = ""
  @Published var remoteOpenPath = ""
  private var codeWorkspaceReturnSurface: AppSurface = .dashboard
  private var lastSelectedRemoteItemID: String?
  private var selectedRemoteItemSnapshot: RemoteItem?

  private let client = SSHClient()
  private let settingsURL: URL
  private let sessionsURL: URL
  private let codexPromptQueueURL: URL
  private let previewDirectory: URL
  private let attachmentDirectory: URL
  private let transcriptDirectory: URL
  private let directoryCacheURL: URL
  private let maxEditableRemoteTextBytes: Int64 = 2_500_000
  private let maxTextPreviewBytes = 260_000
  private let maxBackgroundPreviewDownloadBytes: Int64 = 1_500_000
  private let maxInlineImagePreviewDownloadBytes: Int64 = 12_000_000
  private let largeRemoteTextSaveThreshold = 1_500_000
  private var remotePreviewRequestID = UUID()
  private var codexTranscriptAutoRefreshDeadline: Date?
  private var lastCodexHistoryRefresh: Date?
  private var lastCodexHistoryRefreshDirectory = ""
  private var codexTranscriptFingerprint = ""
  private var claudeTranscriptFingerprint = ""
  private var codexAnalysisTask: Task<Void, Never>?
  private var codexAnalysisFingerprint = ""
  private var codexArtifactPrewarmTask: Task<Void, Never>?
  private var isCapturingCodex = false
  private var isCapturingClaude = false
  private var backgroundDataRefreshTask: Task<Void, Never>?
  private var backgroundKeepAliveTask: Task<Void, Never>?
  private var isRunningBackgroundDataRefresh = false
  private var lastBackgroundDashboardRefresh = Date.distantPast
  private var lastBackgroundDirectoryRefresh = Date.distantPast
  private var lastBackgroundShellCapture = Date.distantPast
  private var lastBackgroundCodexSessionSync = Date.distantPast
  private var lastBackgroundCodexCapture = Date.distantPast
  private var lastBackgroundClaudeCapture = Date.distantPast
  private var lastBackgroundCodexQueueStatus = Date.distantPast
  private var lastBackgroundRecentSessionWarm = Date.distantPast
  private var lastBackgroundPermissionRefresh = Date.distantPast
  private var lastBackgroundPluginRefresh = Date.distantPast
  private var lastCodexWorkingStateRefresh = Date.distantPast
  private var isRefreshingCodexWorkingStates = false
  private var isWarmingRecentCodexSessions = false
  private var isPrewarmingVisibleCodexArtifacts = false
  private var codexArtifactPreviewRequestID = UUID()
  private var lastCodexUsefulCapture = Date.distantPast
  private var lastCodexTokenRefresh = Date.distantPast
  private var lastVisibleArtifactPrewarm = Date.distantPast
  private var isRefreshingCodexTokens = false
  private var codexTranscriptTailBytesByHistoryID: [String: Int] = [:]
  private var pendingCodexLocalTurnBlocksBySession: [UUID: [String]] = [:]
  private var codexDeliveredQueueBlocksBySession: [UUID: [String]] = [:]
  private var codexDraftsBySession: [UUID: String] = [:]
  private var loadingDirectoryPath: String?
  private var loadingFileBrowserPath: String?
  private var lastDirectoryLoadPath = ""
  private var lastDirectoryLoadDate: Date?
  private var lastFileBrowserBackgroundRefreshByPath: [String: Date] = [:]
  private var shellTranscriptFingerprint = ""
  private var shellCompletionCache: [String: [ShellCompletion]] = [:]
  private var remoteDirectoryCache: [String: [RemoteItem]] = [:]
  private var remoteDirectoryCacheDates: [String: Date] = [:]
  private var codexPromptQueuePersistenceEnabled = false
  private var remoteTextPreviewCache: [String: String] = [:]
  private var remoteDownloadedPreviewCache: [String: URL] = [:]
  private var remoteDownloadedPreviewSignatures: [String: RemoteFileSignature] = [:]
  private var remotePreviewDownloadsInFlight: Set<String> = []
  private var fileTransferDepth = 0
  private var fileTransferQuietUntil = Date.distantPast
  private var codexWorkingHoldUntil: [UUID: Date] = [:]
  private var codexLocalTurnHoldUntil: [UUID: Date] = [:]
  private let codexWorkingHoldSeconds: TimeInterval = 16
  private let codexWorkingFinishGraceSeconds: TimeInterval = 4
  private let workingSessionsDefaultsKey = "AControl.workingSessionIDs"
  private let codexWorkingSessionsDefaultsKey = "AControl.codexWorkingSessionIDs"
  private let claudeWorkingSessionsDefaultsKey = "AControl.claudeWorkingSessionIDs"
  private let deletedCodexHistoryDefaultsKey = "AControl.deletedCodexHistoryIDs"
  private let codexToken5hDefaultsKey = "AControl.codexToken5h"
  private let codexTokenWeeklyDefaultsKey = "AControl.codexTokenWeekly"
  private let codexTokenResetDefaultsKey = "AControl.codexTokenReset"
  private let codeWorkspaceExplorerWidthDefaultsKey = "AControl.codeWorkspace.explorerWidth"
  private let codeWorkspaceCodexWidthDefaultsKey = "AControl.codeWorkspace.codexWidth"
  private let codeWorkspaceConsoleHeightDefaultsKey = "AControl.codeWorkspace.consoleHeight"
  private let codeWorkspaceExplorerCollapsedDefaultsKey =
    "AControl.codeWorkspace.explorerCollapsed"
  private let codeWorkspaceCodexCollapsedDefaultsKey = "AControl.codeWorkspace.codexCollapsed"
  private let codeWorkspaceConsoleVisibleDefaultsKey = "AControl.codeWorkspace.consoleVisible"

  private struct CodexHistoryRunStatus: Decodable {
    var id: String
    var working: Bool
    var mtime: Int?
    var tmux: Bool?
    var session_name: String?
    var cwd: String?
  }

  private struct RemoteDirectoryCacheSnapshot: Codable, Sendable {
    var itemsByPath: [String: [RemoteItem]]
    var datesByPath: [String: Date]
  }

  private static func preparedApplicationSupportDirectory() -> URL {
    let fileManager = FileManager.default
    let supportRoot = fileManager.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support", isDirectory: true)
    let appSupport = supportRoot.appendingPathComponent("SSHcontroll", isDirectory: true)
    let legacySupport = supportRoot.appendingPathComponent("AControl", isDirectory: true)

    try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)

    if fileManager.fileExists(atPath: legacySupport.path) {
      for name in [
        "settings.json", "sessions.json", "codex-queue.json", "directory-cache.json",
        "Previews", "Prompt Attachments", "Sessions",
      ] {
        let source = legacySupport.appendingPathComponent(name)
        let destination = appSupport.appendingPathComponent(name)
        if fileManager.fileExists(atPath: source.path),
          !fileManager.fileExists(atPath: destination.path)
        {
          try? fileManager.copyItem(at: source, to: destination)
        }
      }
    }

    return appSupport
  }

  private static func ensureLocalTransferDirectories(for settings: AppSettings) {
    let fileManager = FileManager.default
    let base = URL(fileURLWithPath: settings.mirrorBase.expandingTilde, isDirectory: true)
    for directory in [
      base,
      base.appendingPathComponent("mirror", isDirectory: true),
      base.appendingPathComponent("save", isDirectory: true),
      base.appendingPathComponent("report", isDirectory: true),
    ] {
      try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }
  }

  init() {
    let appSupport = Self.preparedApplicationSupportDirectory()
    self.settingsURL = appSupport.appendingPathComponent("settings.json")
    self.sessionsURL = appSupport.appendingPathComponent("sessions.json")
    self.codexPromptQueueURL = appSupport.appendingPathComponent("codex-queue.json")
    self.previewDirectory = appSupport.appendingPathComponent("Previews", isDirectory: true)
    self.attachmentDirectory = appSupport.appendingPathComponent(
      "Prompt Attachments", isDirectory: true)
    self.transcriptDirectory = appSupport.appendingPathComponent("Sessions", isDirectory: true)
    self.directoryCacheURL = appSupport.appendingPathComponent("directory-cache.json")
    try? FileManager.default.createDirectory(
      at: previewDirectory, withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(
      at: attachmentDirectory, withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(
      at: transcriptDirectory, withIntermediateDirectories: true)

    let loadedSettings: AppSettings
    if let data = try? Data(contentsOf: settingsURL),
      let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
    {
      loadedSettings = decoded
    } else {
      loadedSettings = .defaults
    }
    var normalizedSettings = loadedSettings
    normalizedSettings.ensureDefaultPermissionTargets()
    if AppSettings.isAutomaticCodexPath(normalizedSettings.codexPath) {
      normalizedSettings.codexPath = ""
    }
    Self.ensureLocalTransferDirectories(for: normalizedSettings)
    let fullScreenMigrationKey = "AControl.singleWindowFullScreenDefaultV1"
    if !UserDefaults.standard.bool(forKey: fullScreenMigrationKey) {
      normalizedSettings.openFullScreenOnLaunch = true
      UserDefaults.standard.set(true, forKey: fullScreenMigrationKey)
    }
    self.settings = normalizedSettings
    self.currentRemoteDir = loadedSettings.explorerRoot
    self.fileBrowserDir = loadedSettings.explorerRoot
    self.codexToken5h =
      UserDefaults.standard.string(forKey: codexToken5hDefaultsKey) ?? self.codexToken5h
    self.codexTokenWeekly =
      UserDefaults.standard.string(forKey: codexTokenWeeklyDefaultsKey) ?? self.codexTokenWeekly
    self.codexTokenReset =
      UserDefaults.standard.string(forKey: codexTokenResetDefaultsKey) ?? self.codexTokenReset
    self.codeWorkspaceExplorerWidth = Self.clampedWorkspacePaneValue(
      UserDefaults.standard.double(forKey: codeWorkspaceExplorerWidthDefaultsKey),
      defaultValue: 300,
      range: 190...560
    )
    self.codeWorkspaceCodexWidth = Self.clampedWorkspacePaneValue(
      UserDefaults.standard.double(forKey: codeWorkspaceCodexWidthDefaultsKey),
      defaultValue: 330,
      range: 220...560
    )
    self.codeWorkspaceConsoleHeight = Self.clampedWorkspacePaneValue(
      UserDefaults.standard.double(forKey: codeWorkspaceConsoleHeightDefaultsKey),
      defaultValue: 170,
      range: 90...420
    )
    self.isCodeWorkspaceExplorerCollapsed = UserDefaults.standard.bool(
      forKey: codeWorkspaceExplorerCollapsedDefaultsKey)
    self.isCodeWorkspaceCodexCollapsed = UserDefaults.standard.bool(
      forKey: codeWorkspaceCodexCollapsedDefaultsKey)
    self.isCodeWorkspaceConsoleVisible =
      UserDefaults.standard.object(forKey: codeWorkspaceConsoleVisibleDefaultsKey) as? Bool ?? true

    if let data = try? Data(contentsOf: directoryCacheURL),
      let decoded = try? JSONDecoder().decode(RemoteDirectoryCacheSnapshot.self, from: data)
    {
      self.remoteDirectoryCache = decoded.itemsByPath
      self.remoteDirectoryCacheDates = decoded.datesByPath
    }

    if let data = try? Data(contentsOf: sessionsURL),
      let decoded = try? JSONDecoder().decode([SessionCard].self, from: data)
    {
      self.sessions = decoded
      let savedActiveID = UserDefaults.standard
        .string(forKey: "AControl.activeSessionID")
        .flatMap(UUID.init(uuidString:))
      let selectedSession =
        savedActiveID
        .flatMap { savedID in decoded.first(where: { $0.id == savedID }) } ?? decoded.first
      self.activeSessionID = selectedSession?.id
      if let selectedSession {
        self.currentRemoteDir = selectedSession.remoteDir
        self.fileBrowserDir = selectedSession.remoteDir
      }
    }

    loadCodexPromptQueue()
    codexPromptQueuePersistenceEnabled = true
    persistCodexPromptQueue()

    sanitizeCodexRuntimeSelection()
    pruneLocalCodexHistorySessions(save: true)
    pruneNoisyImportedCodexSessions(save: true)
    sanitizeImportedCodexSessionNames(save: true)
    if collapseDuplicateCodexHistorySessions() {
      saveSessions()
    }
    pruneNoisyImportedCodexSessions(save: true)
    restoreWorkingSessionIDs()
    loadCachedTranscriptsForActiveSession()
    if normalizedSettings != loadedSettings {
      saveSettings()
    }
    scheduleInitialServerCodexHistorySyncIfNeeded()
  }

  var activeSession: SessionCard? {
    sessions.first(where: { $0.id == activeSessionID })
  }

  private func scheduleInitialServerCodexHistorySyncIfNeeded() {
    guard sessions.isEmpty, settings.hasSSHTarget else { return }
    Task { [weak self] in
      try? await Task.sleep(nanoseconds: 700_000_000)
      guard let self, self.sessions.isEmpty else { return }
      await self.syncCodexAppSessions(
        showsActivity: false,
        refreshWorkingAfter: false,
        allowNewImports: true,
        onlyCurrentDirectory: false,
        includeAllDirectories: true
      )
    }
  }

  private func sessionSnapshot(for id: UUID?) -> SessionCard? {
    guard let id else { return activeSession }
    return sessions.first(where: { $0.id == id })
  }

  var activeCodexConversationIsEstablished: Bool {
    guard let activeSession else { return false }
    if !activeSession.codexHistoryID.trimmed.isEmpty
      || !activeSession.codexHistoryPath.trimmed.isEmpty
    {
      return true
    }
    return activeSession.codexState == .running || activeSession.codexState == .linked
  }

  private var activeCodexIsWorking: Bool {
    activeSessionID.map { codexWorkingSessionIDs.contains($0) } ?? false
  }

  var activeCodexCanSteer: Bool {
    guard let activeSessionID else { return false }
    if codexWorkingSessionIDs.contains(activeSessionID) {
      return true
    }
    return codexPromptQueue.contains { item in
      item.sessionID == activeSessionID
        && (item.status == .queued || item.status == .sending || item.status == .waitingForCodex)
    }
  }

  var detectedCodexPluginSnippets: [CodexPluginSnippet] {
    installedCodexPluginIDs().map { pluginID in
      CodexPluginSnippet(
        title: "@\(pluginDisplayName(for: pluginID))",
        snippet: pluginPromptMention(for: pluginID),
        category: "Installed",
        symbol: "puzzlepiece.extension",
        detail: "Available on the server Codex"
      )
    }
  }

  var activeClaudeConversationIsEstablished: Bool {
    guard activeSession != nil else { return false }
    if !claudeTranscript.trimmed.isEmpty {
      return true
    }
    return false
  }

  var selectedRemoteItem: RemoteItem? {
    get {
      guard let selectedRemoteItemID else { return nil }
      if let liveItem = activeRemoteItemsForSelection.first(where: { $0.id == selectedRemoteItemID }
      ) {
        return liveItem
      }
      if selectedRemoteItemSnapshot?.id == selectedRemoteItemID {
        return selectedRemoteItemSnapshot
      }
      return nil
    }
    set {
      selectedRemoteItemSnapshot = newValue
      selectedRemoteItemID = newValue?.id
      selectedRemoteItemIDs = newValue.map { [$0.id] } ?? []
      lastSelectedRemoteItemID = newValue?.id
    }
  }

  var selectedRemoteItems: [RemoteItem] {
    activeRemoteItemsForSelection.filter { selectedRemoteItemIDs.contains($0.id) }
  }

  var isRemoteFileDirty: Bool {
    openedRemoteFile != nil && remotePreviewKind == .text && !remoteFileIsPreviewOnly
      && remoteFileText != remoteFileSavedText
  }

  var selectedDirectoryOrCurrent: String {
    if let item = selectedRemoteItems.first, item.isDirectory {
      return item.path
    }
    let browserDir = fileBrowserDir.trimmed
    return browserDir.isEmpty ? currentRemoteDir : browserDir
  }

  private var activeRemoteItemsForSelection: [RemoteItem] {
    if !fileBrowserDir.trimmed.isEmpty {
      return fileBrowserItems
    }
    return remoteItems
  }

  var isCodexTranscriptAutoRefreshActive: Bool {
    guard let deadline = codexTranscriptAutoRefreshDeadline else { return false }
    return Date() < deadline
  }

  private enum TranscriptKind: String {
    case codex
    case claude
  }

  private var activeRemoteEnvironment: [String: String] {
    remoteEnvironment(for: activeSession, directory: currentRemoteDir)
  }

  private func remoteEnvironment(
    for session: SessionCard?,
    directory: String? = nil
  ) -> [String: String] {
    let sessionDirectory =
      directory?.trimmed.nilIfEmpty
      ?? session?.remoteDir.trimmed.nilIfEmpty
      ?? currentRemoteDir
    var environment = [
      "A_COCKPIT_SESSION_DIR": normalizedRemotePath(sessionDirectory)
    ]
    if let session {
      environment["A_COCKPIT_CODEX_SESSION"] = session.codexSession
      environment["A_COCKPIT_CLAUDE_SESSION"] = session.claudeSession
      let codexHistoryID = session.codexHistoryID.trimmed
      if !codexHistoryID.isEmpty && session.codexHistoryHost.trimmed.lowercased() != "local" {
        environment["A_COCKPIT_CODEX_HISTORY_ID"] = codexHistoryID
      }
    }
    return environment
  }

  private var activeTranscriptKey: String {
    activeSessionID?.uuidString ?? "default"
  }

  private func sessionDirectory(for key: String) -> URL {
    transcriptDirectory.appendingPathComponent(key, isDirectory: true)
  }

  private func activeSessionDirectory() -> URL {
    sessionDirectory(for: activeTranscriptKey)
  }

  private func transcriptURL(for kind: TranscriptKind) -> URL {
    let sessionDirectory = activeSessionDirectory()
    try? FileManager.default.createDirectory(
      at: sessionDirectory, withIntermediateDirectories: true)
    return sessionDirectory.appendingPathComponent("\(kind.rawValue)-transcript.txt")
  }

  private func transcriptURL(for kind: TranscriptKind, sessionID: UUID) -> URL {
    let sessionDirectory = sessionDirectory(for: sessionID.uuidString)
    try? FileManager.default.createDirectory(
      at: sessionDirectory, withIntermediateDirectories: true)
    return sessionDirectory.appendingPathComponent("\(kind.rawValue)-transcript.txt")
  }

  private func cachedTranscript(for kind: TranscriptKind) -> String {
    (try? String(contentsOf: transcriptURL(for: kind), encoding: .utf8)) ?? ""
  }

  private func loadCachedTranscriptsForActiveSession() {
    codexTranscriptCanLoadMore = false
    isLoadingMoreCodexTranscript = false
    guard activeSessionID != nil else {
      setCodexTranscript("", force: true)
      setClaudeTranscript("", force: true)
      clearCodexDerivedState()
      return
    }
    let cachedCodex = cachedTranscript(for: .codex)
    if activeSession?.codexState == .fresh, activeSession?.codexHistoryID.trimmed.isEmpty != false,
      cachedCodex.trimmed.isEmpty
    {
      setCodexTranscript("", force: true)
      clearCodexDerivedState()
    } else {
      setCodexTranscript(cachedCodex, force: true)
    }
    setClaudeTranscript(cachedTranscript(for: .claude), force: true)
    scheduleCodexTranscriptAnalysis(force: true)
  }

  private func transcriptFingerprint(_ value: String) -> String {
    "\(value.count):\(value.prefix(256).hashValue):\(value.suffix(2048).hashValue)"
  }

  @discardableResult
  private func setCodexTranscript(_ value: String, force: Bool = false) -> Bool {
    let fingerprint = transcriptFingerprint(value)
    guard force || fingerprint != codexTranscriptFingerprint else { return false }
    codexTranscript = value
    codexTranscriptFingerprint = fingerprint
    codexTranscriptUpdatedAt = Date()
    return true
  }

  @discardableResult
  private func setClaudeTranscript(_ value: String, force: Bool = false) -> Bool {
    let fingerprint = transcriptFingerprint(value)
    guard force || fingerprint != claudeTranscriptFingerprint else { return false }
    claudeTranscript = value
    claudeTranscriptFingerprint = fingerprint
    return true
  }

  @discardableResult
  private func persistTranscript(_ kind: TranscriptKind, value: String) -> String {
    guard !value.trimmed.isEmpty else { return cachedTranscript(for: kind) }
    let nextFingerprint = transcriptFingerprint(value)
    switch kind {
    case .codex:
      if codexTranscriptFingerprint == nextFingerprint {
        return codexTranscript
      }
    case .claude:
      if claudeTranscriptFingerprint == nextFingerprint {
        return claudeTranscript
      }
    }
    try? value.write(to: transcriptURL(for: kind), atomically: true, encoding: .utf8)
    return value
  }

  private func persistTranscript(_ kind: TranscriptKind, value: String, sessionID: UUID) {
    guard !value.trimmed.isEmpty else { return }
    try? value.write(
      to: transcriptURL(for: kind, sessionID: sessionID), atomically: true, encoding: .utf8)
  }

  private func normalizedCodexTurnText(_ value: String) -> String {
    value
      .replacingOccurrences(
        of: #"(?is)<environment_context\b[^>]*>.*?</environment_context>"#,
        with: "\n",
        options: .regularExpression
      )
      .replacingOccurrences(of: #"^[›>•]\s*"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmed
      .lowercased()
  }

  private func codexQueueOverlay(for sessionID: UUID?) -> String {
    ""
  }

  private func queueStatusRank(_ status: CodexPromptQueueStatus) -> Int {
    switch status {
    case .sending: 0
    case .waitingForCodex: 1
    case .queued: 2
    case .failed: 3
    case .delivered: 4
    }
  }

  private func codexQueueBlock(for item: CodexPromptQueueItem, includeStatus: Bool) -> String {
    if !includeStatus {
      switch item.kind {
      case .send:
        return ["› \(item.visibleText)"].filter { !$0.trimmed.isEmpty }.joined(separator: "\n")
      case .steer:
        return ["› \(item.visibleText)", "Steered conversation"]
          .filter { !$0.trimmed.isEmpty }
          .joined(separator: "\n")
      }
    }

    let title: String
    switch item.status {
    case .queued:
      title = item.kind == .steer ? "• Queued steer" : "• Queued prompt"
    case .sending:
      title = item.kind == .steer ? "• Sending steer" : "• Sending prompt"
    case .waitingForCodex:
      title = item.kind == .steer ? "• Steer queued on A" : "• Prompt queued on A"
    case .delivered:
      title = item.kind == .steer ? "Steered conversation" : "›"
    case .failed:
      title = item.kind == .steer ? "• Steer not delivered" : "• Prompt not delivered"
    }

    let lines = [title, item.visibleText].filter { !$0.trimmed.isEmpty }
    return lines.joined(separator: "\n")
  }

  private func codexTranscriptPreservingLocalTurns(_ incoming: String) -> String {
    guard let sessionID = activeSessionID else { return incoming }
    let hasUndeliveredLocalTurn = codexPromptQueue.contains { item in
      item.sessionID == sessionID
        && (item.status == .queued || item.status == .sending || item.status == .waitingForCodex)
    }
    guard hasUndeliveredLocalTurn else {
      pendingCodexLocalTurnBlocksBySession.removeValue(forKey: sessionID)
      codexDeliveredQueueBlocksBySession.removeValue(forKey: sessionID)
      return incoming
    }
    let incomingNorm = normalizedCodexTurnText(incoming)

    let pendingBlocks = pendingCodexLocalTurnBlocksBySession[sessionID] ?? []
    let missingPendingBlocks = pendingBlocks.filter { block in
      let norm = normalizedCodexTurnText(block)
      return !norm.isEmpty && !incomingNorm.contains(norm)
    }
    if missingPendingBlocks.isEmpty {
      pendingCodexLocalTurnBlocksBySession.removeValue(forKey: sessionID)
    } else {
      pendingCodexLocalTurnBlocksBySession[sessionID] = Array(missingPendingBlocks.suffix(8))
    }

    let deliveredBlocks = codexDeliveredQueueBlocksBySession[sessionID] ?? []
    let missingDeliveredBlocks = deliveredBlocks.filter { block in
      let norm = normalizedCodexTurnText(block)
      return !norm.isEmpty && !incomingNorm.contains(norm)
    }
    if missingDeliveredBlocks.isEmpty {
      codexDeliveredQueueBlocksBySession.removeValue(forKey: sessionID)
    } else {
      codexDeliveredQueueBlocksBySession[sessionID] = Array(missingDeliveredBlocks.suffix(8))
    }

    var seenLocalTurnBlocks = Set<String>()
    let localBlocks = (missingPendingBlocks + missingDeliveredBlocks)
      .map(\.trimmed)
      .filter { !$0.isEmpty }
      .filter { block in
        let key = normalizedCodexTurnText(block)
        guard !key.isEmpty, !seenLocalTurnBlocks.contains(key) else { return false }
        seenLocalTurnBlocks.insert(key)
        return true
    }
    guard !localBlocks.isEmpty else { return incoming }
    if let ordered = codexTranscriptWithLocalTurnsBeforeIncomingSuffix(
      incoming: incoming,
      localBlocks: localBlocks
    ) {
      return ordered
    }
    return ([incoming.trimmed] + localBlocks)
      .filter { !$0.isEmpty }
      .joined(separator: "\n\n")
  }

  private func codexTranscriptWithLocalTurnsBeforeIncomingSuffix(
    incoming: String,
    localBlocks: [String]
  ) -> String? {
    let previous = codexTranscript.trimmed
    let incomingTrimmed = incoming.trimmed
    guard !previous.isEmpty, !incomingTrimmed.isEmpty else { return nil }
    let base = codexTranscriptRemovingTrailingLocalTurns(previous, localBlocks: localBlocks)
    guard !base.isEmpty, incomingTrimmed.hasPrefix(base) else { return nil }
    let suffix = String(incomingTrimmed.dropFirst(base.count)).trimmed
    return ([base] + localBlocks + [suffix])
      .map(\.trimmed)
      .filter { !$0.isEmpty }
      .joined(separator: "\n\n")
  }

  private func codexTranscriptRemovingTrailingLocalTurns(
    _ value: String,
    localBlocks: [String]
  ) -> String {
    var output = value.trimmed
    for block in localBlocks.reversed() {
      let clean = block.trimmed
      guard !clean.isEmpty else { continue }
      if output == clean {
        output = ""
      } else if output.hasSuffix("\n\n" + clean) {
        output = String(output.dropLast(clean.count + 2)).trimmed
      } else if output.hasSuffix(clean) {
        output = String(output.dropLast(clean.count)).trimmed
      }
    }
    return output
  }

  private func codexTranscriptKeepingStableCache(_ incoming: String) -> String {
    let current = codexTranscript.trimmed
    let next = incoming.trimmed
    guard !current.isEmpty, !next.isEmpty else { return incoming }
    guard next.count < current.count else { return incoming }
    if current == next { return current }
    if current.hasPrefix(next), current.count - next.count > 600 {
      return current
    }
    let shortEnoughToBeCaptureFragment =
      Double(next.count) < Double(current.count) * 0.68
        && current.count - next.count > 1_200
    if shortEnoughToBeCaptureFragment && normalizedCodexTurnText(current).contains(normalizedCodexTurnText(next)) {
      return current
    }
    return incoming
  }

  private func applyCodexTranscriptResult(_ result: CommandResult, replaceOnFailure: Bool = false) {
    codexTranscriptCheckedAt = Date()
    if result.exitCode != 0, isCodexControlError(result.combined) {
      statusText = "Codex session not ready · \(Date().shortStamp)"
      markActiveSessionWorking(false, tool: .codex)
      return
    }
    var transcriptChanged = false
    if result.exitCode == 0 {
      let stableInput = codexTranscriptKeepingStableCache(result.combined)
      let mergedInput = codexTranscriptPreservingLocalTurns(stableInput)
      let merged = persistTranscript(.codex, value: mergedInput)
      transcriptChanged = setCodexTranscript(merged)
    } else if replaceOnFailure || codexTranscript.trimmed.isEmpty {
      transcriptChanged = setCodexTranscript(result.combined)
    }
    linkActiveCodexHistoryIfPresent(in: result.combined)
    updateActiveCodexWorkingState(from: result.combined, mayStart: transcriptChanged)
    guard transcriptChanged else { return }
    scheduleCodexTranscriptAnalysis()
  }

  private func appendCodexLocalActivity(title: String, detail: String = "") {
    let block =
      [title.trimmed, detail.trimmed]
      .filter { !$0.isEmpty }
      .joined(separator: "\n")
    guard !block.isEmpty else { return }
    let base = codexTranscript.trimmed
    let next = base.isEmpty ? block : base + "\n\n" + block
    let merged = persistTranscript(.codex, value: next)
    if setCodexTranscript(merged, force: true) {
      scheduleCodexTranscriptAnalysis()
    }
  }

  private func appendCodexLocalTurnBlock(_ block: String, preserveThroughCapture: Bool = true) {
    let cleanBlock = block.trimmed
    guard !cleanBlock.isEmpty else { return }
    if preserveThroughCapture, let sessionID = activeSessionID {
      var pendingBlocks = pendingCodexLocalTurnBlocksBySession[sessionID] ?? []
      pendingBlocks.append(cleanBlock)
      pendingCodexLocalTurnBlocksBySession[sessionID] = Array(pendingBlocks.suffix(8))
    }
    appendCodexLocalActivity(title: cleanBlock)
  }

  private func visibleQueueItem(_ item: CodexPromptQueueItem) -> CodexPromptQueueItem {
    var visible = item
    visible.attachments = []
    return visible
  }

  private func loadCodexPromptQueue() {
    guard let data = try? Data(contentsOf: codexPromptQueueURL),
      let decoded = try? JSONDecoder().decode([CodexPromptQueueItem].self, from: data)
    else { return }

    let sessionIDs = Set(sessions.map(\.id))
    codexPromptQueue = decoded.compactMap { item in
      if let sessionID = item.sessionID, !sessionIDs.contains(sessionID) {
        return nil
      }
      if item.status == .delivered {
        return nil
      }
      var restored = item
      if restored.status == .sending {
        let hasRemoteID = restored.remoteQueueID?.trimmed.isEmpty == false
        restored.status = hasRemoteID ? .waitingForCodex : .queued
        restored.lastError = hasRemoteID ? "Restored from A queue" : "Recovered before upload"
        restored.updatedAt = Date()
      }
      return restored
    }
  }

  private func persistCodexPromptQueueIfReady() {
    guard codexPromptQueuePersistenceEnabled else { return }
    persistCodexPromptQueue()
  }

  private func persistCodexPromptQueue() {
    let items = codexPromptQueue.filter { item in
      item.status != .delivered
    }
    guard let data = try? JSONEncoder().encode(items) else { return }
    try? data.write(to: codexPromptQueueURL, options: .atomic)
  }

  private func addCodexQueueItem(
    kind: CodexPromptQueueKind,
    text: String,
    attachments: [PromptAttachment]? = nil,
    displayText: String? = nil,
    researchGroupID: String? = nil,
    researchRole: String? = nil
  ) -> CodexPromptQueueItem {
    var item = CodexPromptQueueItem(
      sessionID: activeSessionID,
      kind: kind,
      text: text,
      displayText: displayText?.trimmed.nilIfEmpty,
      attachments: attachments ?? codexAttachments
    )
    item.researchGroupID = researchGroupID?.trimmed.nilIfEmpty
    item.researchRole = researchRole?.trimmed.nilIfEmpty
    codexPromptQueue.append(item)
    return item
  }

  private func updateCodexQueueItem(
    _ id: UUID,
    status: CodexPromptQueueStatus,
    error: String = "",
    remoteQueueID: String? = nil
  ) {
    guard let index = codexPromptQueue.firstIndex(where: { $0.id == id }) else { return }
    var items = codexPromptQueue
    items[index].status = status
    items[index].updatedAt = Date()
    items[index].lastError = error
    if let remoteQueueID {
      items[index].remoteQueueID = remoteQueueID
    }
    codexPromptQueue = items
    scheduleCodexTranscriptAnalysis(force: true)
  }

  func moveQueuedCodexPrompt(_ draggedID: UUID, before targetID: UUID) {
    guard draggedID != targetID,
      let dragged = codexPromptQueue.first(where: { $0.id == draggedID }),
      let target = codexPromptQueue.first(where: { $0.id == targetID }),
      dragged.status == target.status,
      (dragged.status == .queued || dragged.status == .waitingForCodex),
      dragged.sessionID == target.sessionID
    else { return }

    let movedStatus = dragged.status
    var queuedIDs =
      codexPromptQueue
      .filter { $0.sessionID == dragged.sessionID && $0.status == movedStatus }
      .sorted { $0.createdAt < $1.createdAt }
      .map(\.id)
    guard let fromIndex = queuedIDs.firstIndex(of: draggedID),
      queuedIDs.contains(targetID)
    else { return }
    queuedIDs.remove(at: fromIndex)
    let insertIndex = queuedIDs.firstIndex(of: targetID) ?? queuedIDs.count
    queuedIDs.insert(draggedID, at: insertIndex)

    let now = Date()
    let base = now.addingTimeInterval(-Double(queuedIDs.count) * 0.01)
    var items = codexPromptQueue
    for (offset, id) in queuedIDs.enumerated() {
      guard let itemIndex = items.firstIndex(where: { $0.id == id }) else { continue }
      items[itemIndex].createdAt = base.addingTimeInterval(Double(offset) * 0.01)
      items[itemIndex].updatedAt = now
    }
    codexPromptQueue = items
    if movedStatus == .waitingForCodex {
      guard let draggedRemoteID = dragged.remoteQueueID?.trimmed, !draggedRemoteID.isEmpty,
        let targetRemoteID = target.remoteQueueID?.trimmed, !targetRemoteID.isEmpty
      else {
        statusText = "A queue id is not available yet · \(Date().shortStamp)"
        return
      }
      statusText = "Updating A queue order · \(Date().shortStamp)"
      let sessionID = dragged.sessionID
      Task { [weak self] in
        await self?.reorderAQueuedCodexItem(
          draggedRemoteID: draggedRemoteID,
          targetRemoteID: targetRemoteID,
          sessionID: sessionID
        )
      }
    } else {
      statusText = "Queue order updated · \(Date().shortStamp)"
    }
  }

  private func reorderAQueuedCodexItem(
    draggedRemoteID: String,
    targetRemoteID: String,
    sessionID: UUID?
  ) async {
    let environment = remoteEnvironment(for: sessionSnapshot(for: sessionID))
    let result = await runRemote(
      "codex-queue-reorder",
      args: [draggedRemoteID, targetRemoteID],
      timeout: 30,
      showsActivity: false,
      bypassBackgroundQueue: true,
      environmentOverride: environment
    )
    if result.exitCode == 0 {
      statusText = "A queue order updated · \(Date().shortStamp)"
    } else {
      statusText = "A queue reorder failed · \(Date().shortStamp)"
      let detail =
        result.combined.trimmed.isEmpty ? "A queue reorder failed." : result.combined.trimmed
      for index in codexPromptQueue.indices
      where codexPromptQueue[index].remoteQueueID == draggedRemoteID
      {
        codexPromptQueue[index].lastError = detail
        codexPromptQueue[index].updatedAt = Date()
      }
      scheduleCodexTranscriptAnalysis(force: true)
    }
  }

  private func removeCodexQueueItem(_ id: UUID) {
    guard let index = codexPromptQueue.firstIndex(where: { $0.id == id }) else { return }
    codexPromptQueue.remove(at: index)
    scheduleCodexTranscriptAnalysis(force: true)
  }

  private func markCodexQueueItemDelivered(_ item: CodexPromptQueueItem) {
    removeCodexQueueItem(item.id)
    statusText = "Codex prompt handed to A · \(Date().shortStamp)"
  }

  private func monitorCodexQueueItemDelivery(_ id: UUID) {
    Task { [weak self] in
      let delays: [UInt64] = [
        350_000_000, 750_000_000, 1_200_000_000, 1_800_000_000, 2_600_000_000,
        4_000_000_000, 6_000_000_000, 9_000_000_000, 14_000_000_000, 22_000_000_000,
      ]
      for delay in delays {
        try? await Task.sleep(nanoseconds: delay)
        guard let self else { return }
        let shouldContinue = await MainActor.run {
          self.codexPromptQueue.contains {
            $0.id == id && $0.status == .waitingForCodex && $0.remoteQueueID?.trimmed.isEmpty == false
          }
        }
        guard shouldContinue else { return }
        await self.refreshCodexPromptQueueStatuses(ids: [id])
      }
    }
  }

  private func refreshCodexPromptQueueStatuses(ids: Set<UUID>? = nil) async {
    guard settings.hasSSHTarget else { return }
    let waitingItems = codexPromptQueue.filter { item in
      item.status == .waitingForCodex
        && item.remoteQueueID?.trimmed.isEmpty == false
        && (ids == nil || ids!.contains(item.id))
    }
    guard !waitingItems.isEmpty else { return }
    for item in waitingItems.prefix(40) {
      guard let remoteQueueID = item.remoteQueueID?.trimmed, !remoteQueueID.isEmpty else { continue }
      let environment = remoteEnvironment(for: sessionSnapshot(for: item.sessionID))
      let result = await runRemote(
        "codex-queue-job-status",
        args: [remoteQueueID],
        timeout: 30,
        showsActivity: false,
        bypassBackgroundQueue: true,
        environmentOverride: environment
      )
      let combined = result.combined
      let status = codexQueueItemStatus(from: combined)
      guard let current = codexPromptQueue.first(where: { $0.id == item.id }) else { continue }
      if let historyID = codexQueueHistoryID(from: combined) {
        await linkCodexHistoryFromQueueStatus(historyID, sessionID: current.sessionID)
      }
      switch status {
      case "done":
        markCodexQueueItemDelivered(current)
      case "failed":
        let error = codexQueueWorkerLogTail(from: combined) ?? "A queue worker failed."
        updateCodexQueueItem(item.id, status: .failed, error: error)
      case "queued":
        updateCodexQueueProgress(item.id, detail: "Queued on A")
      case "processing":
        updateCodexQueueProgress(item.id, detail: "Processing on A")
      default:
        if result.exitCode != 0 {
          updateCodexQueueProgress(item.id, detail: "A queue status unavailable")
        }
      }
    }
  }

  private func updateCodexQueueProgress(_ id: UUID, detail: String) {
    guard let index = codexPromptQueue.firstIndex(where: { $0.id == id }) else { return }
    var items = codexPromptQueue
    guard items[index].lastError != detail else { return }
    items[index].lastError = detail
    items[index].updatedAt = Date()
    codexPromptQueue = items
    scheduleCodexTranscriptAnalysis(force: true)
  }

  private func codexQueueItemStatus(from text: String) -> String? {
    text.split(whereSeparator: \.isNewline)
      .map { String($0).trimmed }
      .first { $0.hasPrefix("a_queue_item_status:") }?
      .replacingOccurrences(of: "a_queue_item_status:", with: "")
      .trimmed
      .lowercased()
  }

  private func codexQueueWorkerLogTail(from text: String) -> String? {
    let value = text.split(whereSeparator: \.isNewline)
      .map { String($0).trimmed }
      .first { $0.hasPrefix("a_queue_worker_log_tail:") }?
      .replacingOccurrences(of: "a_queue_worker_log_tail:", with: "")
      .trimmed
    return value?.isEmpty == false ? value : nil
  }

  private func codexQueueHistoryID(from text: String) -> String? {
    let value = text.split(whereSeparator: \.isNewline)
      .map { String($0).trimmed }
      .first { $0.hasPrefix("a_queue_history_id:") }?
      .replacingOccurrences(of: "a_queue_history_id:", with: "")
      .trimmed
    return value?.isEmpty == false ? value : nil
  }

  private func linkCodexHistoryFromQueueStatus(_ historyID: String, sessionID: UUID?) async {
    let trimmed = historyID.trimmed
    guard !trimmed.isEmpty, let sessionID else { return }
    if sessionSnapshot(for: sessionID)?.codexHistoryID.trimmed == trimmed {
      return
    }
    await refreshCodexHistory(force: true, showsActivity: false)
    if let record = codexHistoryRecords.first(where: { $0.id == trimmed }) {
      updateCodexHistory(
        for: sessionID,
        id: record.id,
        path: record.path,
        title: record.title,
        host: record.normalizedHost,
        updatedAt: record.mtime > 0
          ? Date(timeIntervalSince1970: TimeInterval(record.mtime))
          : Date()
      )
    } else {
      updateCodexHistory(for: sessionID, id: trimmed, host: "remote", updatedAt: Date())
    }
  }

  private func expireDeliveredCodexQueueItem(_ id: UUID) {
    let retentionSeconds = codexPromptQueue.first(where: { $0.id == id }).map {
      Self.deliveredQueueRetentionSeconds(for: $0)
    } ?? Self.deliveredCodexQueueRetentionSeconds
    Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(retentionSeconds * 1_000_000_000))
      await MainActor.run {
        guard let self,
          let item = self.codexPromptQueue.first(where: { $0.id == id }),
          item.status == .delivered
        else { return }
        self.removeCodexQueueItem(id)
      }
    }
  }

  func promoteQueuedCodexItemsToSteer() {
    guard let activeSessionID else { return }
    var changed = false
    var remoteIDs: [UUID] = []
    var items = codexPromptQueue
    for index in items.indices
    where items[index].sessionID == activeSessionID
      && items[index].kind == .send
    {
      if items[index].status == .queued {
        items[index].kind = .steer
        items[index].updatedAt = Date()
        changed = true
      } else if items[index].status == .waitingForCodex {
        remoteIDs.append(items[index].id)
      }
    }
    if changed {
      codexPromptQueue = items
      statusText = "Queued Codex prompts changed to steer · \(Date().shortStamp)"
      processCodexPromptQueue()
    }
    for id in remoteIDs {
      promoteCodexQueueItemToSteer(id)
    }
  }

  func promoteCodexQueueItemToSteer(_ id: UUID) {
    guard let index = codexPromptQueue.firstIndex(where: { $0.id == id && $0.kind == .send })
    else { return }
    var items = codexPromptQueue
    switch items[index].status {
    case .queued:
      items[index].kind = .steer
      items[index].updatedAt = Date()
      codexPromptQueue = items
      statusText = "Queued prompt changed to steer · \(Date().shortStamp)"
      processCodexPromptQueue()
    case .waitingForCodex:
      guard let remoteQueueID = items[index].remoteQueueID?.trimmed,
        !remoteQueueID.isEmpty
      else {
        statusText = "A queue id is not available yet · \(Date().shortStamp)"
        return
      }
      statusText = "Changing A queue item to steer · \(Date().shortStamp)"
      let sessionID = items[index].sessionID
      Task { [weak self] in
        await self?.promoteAQueuedCodexItemToSteer(
          id: id,
          remoteQueueID: remoteQueueID,
          sessionID: sessionID
        )
      }
    case .sending:
      statusText = "This prompt is already being uploaded · \(Date().shortStamp)"
    case .delivered, .failed:
      return
    }
  }

  private func promoteAQueuedCodexItemToSteer(
    id: UUID,
    remoteQueueID: String,
    sessionID: UUID?
  ) async {
    let environment = remoteEnvironment(for: sessionSnapshot(for: sessionID))
    let result = await runRemote(
      "codex-queue-promote-steer",
      args: [remoteQueueID],
      timeout: 30,
      showsActivity: false,
      bypassBackgroundQueue: true,
      environmentOverride: environment
    )
    guard let index = codexPromptQueue.firstIndex(where: { $0.id == id }) else { return }
    if result.exitCode == 0 {
      var items = codexPromptQueue
      items[index].kind = .steer
      items[index].updatedAt = Date()
      items[index].lastError = ""
      codexPromptQueue = items
      statusText = "A queue item changed to steer · \(Date().shortStamp)"
      scheduleCodexTranscriptAnalysis(force: true)
      monitorCodexQueueItemDelivery(id)
      Task { [weak self] in
        try? await Task.sleep(nanoseconds: 700_000_000)
        await self?.refreshCodexPromptQueueStatuses(ids: [id])
      }
    } else {
      statusText = "A queue item is already processing · \(Date().shortStamp)"
      var items = codexPromptQueue
      items[index].lastError =
        result.combined.trimmed.isEmpty ? "Already processing on A" : result.combined.trimmed
      items[index].updatedAt = Date()
      codexPromptQueue = items
      scheduleCodexTranscriptAnalysis(force: true)
    }
  }

  func discardCodexQueueItem(_ id: UUID) {
    guard let item = codexPromptQueue.first(where: { $0.id == id }) else { return }
    guard item.status != .sending else {
      statusText = "Cannot remove a prompt while it is sending · \(Date().shortStamp)"
      return
    }
    if item.status == .waitingForCodex,
      let remoteQueueID = item.remoteQueueID?.trimmed,
      !remoteQueueID.isEmpty
    {
      let sessionID = item.sessionID
      Task { [weak self] in
        await self?.cancelAQueuedCodexItem(remoteQueueID: remoteQueueID, sessionID: sessionID)
      }
    }
    removeCodexQueueItem(id)
    statusText = "Removed Codex queue item · \(Date().shortStamp)"
  }

  func editCodexQueueItem(_ id: UUID, text: String) async {
    let replacement = text.trimmed
    guard !replacement.isEmpty else {
      statusText = "Queue item cannot be empty · \(Date().shortStamp)"
      return
    }
    guard let item = codexPromptQueue.first(where: { $0.id == id }) else { return }
    guard item.status != .sending else {
      statusText = "Cannot edit while prompt is sending · \(Date().shortStamp)"
      return
    }
    guard item.status != .delivered else { return }
    if item.status == .waitingForCodex,
      let remoteQueueID = item.remoteQueueID?.trimmed,
      !remoteQueueID.isEmpty
    {
      let cancelled = await cancelAQueuedCodexItem(
        remoteQueueID: remoteQueueID,
        sessionID: item.sessionID
      )
      guard cancelled else {
        statusText = "A queue item is already processing · \(Date().shortStamp)"
        return
      }
    }
    guard let index = codexPromptQueue.firstIndex(where: { $0.id == id }) else { return }
    var items = codexPromptQueue
    items[index].text = replacement
    items[index].displayText = replacement
    items[index].status = .queued
    items[index].remoteQueueID = nil
    items[index].lastError = ""
    items[index].updatedAt = Date()
    codexPromptQueue = items
    statusText = "Queued prompt edited · \(Date().shortStamp)"
    scheduleCodexTranscriptAnalysis(force: true)
    processCodexPromptQueue()
  }

  @discardableResult
  private func cancelAQueuedCodexItem(remoteQueueID: String, sessionID: UUID?) async -> Bool {
    let environment = remoteEnvironment(for: sessionSnapshot(for: sessionID))
    let result = await runRemote(
      "codex-queue-cancel",
      args: [remoteQueueID],
      timeout: 30,
      showsActivity: false,
      bypassBackgroundQueue: true,
      environmentOverride: environment
    )
    if result.exitCode != 0 {
      lastMirrorLog = result.combined
      return false
    }
    return true
  }

  func retryCodexQueueItem(_ id: UUID) {
    guard
      let index = codexPromptQueue.firstIndex(where: {
        $0.id == id && $0.status == .failed
      })
    else { return }
    var items = codexPromptQueue
    items[index].status = .queued
    items[index].lastError = ""
    items[index].updatedAt = Date()
    codexPromptQueue = items
    processCodexPromptQueue()
  }

  func processCodexPromptQueue() {
    guard !isProcessingCodexPromptQueue else { return }
    isProcessingCodexPromptQueue = true
    Task { [weak self] in
      await self?.drainCodexPromptQueue()
    }
  }

  func retryFailedCodexQueueItems() {
    guard let activeSessionID else { return }
    var changed = false
    var items = codexPromptQueue
    for index in items.indices
    where items[index].sessionID == activeSessionID
      && items[index].status == .failed
    {
      items[index].status = .queued
      items[index].lastError = ""
      items[index].updatedAt = Date()
      changed = true
    }
    if changed {
      codexPromptQueue = items
      processCodexPromptQueue()
    }
  }

  func refreshCodexForVisibleSession() async {
    let shouldImportAllServerHistory = sessions.isEmpty
    await syncCodexAppSessions(
      allowNewImports: true,
      onlyCurrentDirectory: !shouldImportAllServerHistory,
      includeAllDirectories: shouldImportAllServerHistory
    )
    await refreshCodexPromptQueueStatuses()
    await captureCodexIfUseful(force: true)
  }

  func syncServerCodexHistoryAndRefreshVisibleSession() async {
    await importAllCodexHistorySessions()
    await refreshCodexWorkingStates(force: true)
    await refreshCodexPromptQueueStatuses()
    await captureCodexIfUseful(force: true)
  }

  private func isCodexControlError(_ text: String) -> Bool {
    let lower = text.lowercased()
    return lower.contains("can't find pane")
      || lower.contains("can't find session")
      || lower.contains("missing codex session")
      || lower.contains("codex runtime is not started")
      || lower.contains("no codex runtime")
  }

  private func applyClaudeTranscriptResult(_ result: CommandResult, replaceOnFailure: Bool = false)
  {
    var transcriptChanged = false
    if result.exitCode == 0 {
      let merged = persistTranscript(.claude, value: result.combined)
      transcriptChanged = setClaudeTranscript(merged)
    } else if replaceOnFailure || claudeTranscript.trimmed.isEmpty {
      transcriptChanged = setClaudeTranscript(result.combined)
    }
    updateActiveClaudeWorkingState(from: result.combined, mayStart: transcriptChanged)
  }

  private func startCodexTranscriptAutoRefresh() {
    codexTranscriptAutoRefreshDeadline = Date().addingTimeInterval(10 * 60)
    codexTranscriptAutoRefreshGeneration += 1
  }

  private func markActiveSessionWorking(_ isWorking: Bool, tool: AISessionTool) {
    guard let activeSessionID else { return }
    setSessionWorking(activeSessionID, isWorking: isWorking, tool: tool)
  }

  private func setSessionWorking(_ sessionID: UUID, isWorking: Bool, tool: AISessionTool) {
    switch tool {
    case .codex:
      if isWorking {
        if !codexWorkingSessionIDs.contains(sessionID) {
          codexWorkingStartedAtBySession[sessionID] = Date()
        } else if codexWorkingStartedAtBySession[sessionID] == nil {
          codexWorkingStartedAtBySession[sessionID] = Date()
        }
        codexWorkingSessionIDs.insert(sessionID)
        codexWorkingHoldUntil[sessionID] = Date().addingTimeInterval(codexWorkingHoldSeconds)
      } else {
        codexWorkingSessionIDs.remove(sessionID)
        codexWorkingHoldUntil.removeValue(forKey: sessionID)
        codexLocalTurnHoldUntil.removeValue(forKey: sessionID)
        codexWorkingStartedAtBySession.removeValue(forKey: sessionID)
      }
    case .claude:
      if isWorking {
        claudeWorkingSessionIDs.insert(sessionID)
      } else {
        claudeWorkingSessionIDs.remove(sessionID)
      }
    }
    syncCombinedWorkingSessions()
    saveWorkingSessionIDs()
  }

  private func settleCodexWorkingStateAfterCompletion(sessionID: UUID) {
    guard codexWorkingSessionIDs.contains(sessionID) else { return }
    let holdUntil = Date().addingTimeInterval(codexWorkingFinishGraceSeconds)
    codexWorkingHoldUntil[sessionID] = holdUntil
    codexLocalTurnHoldUntil[sessionID] = holdUntil
    syncCombinedWorkingSessions()
    saveWorkingSessionIDs()
  }

  private func holdCodexLocalTurn(sessionID: UUID?, seconds: TimeInterval) {
    guard let sessionID else { return }
    let holdUntil = Date().addingTimeInterval(seconds)
    codexLocalTurnHoldUntil[sessionID] = holdUntil
    codexWorkingHoldUntil[sessionID] = max(
      codexWorkingHoldUntil[sessionID] ?? .distantPast, holdUntil)
    if codexWorkingStartedAtBySession[sessionID] == nil {
      codexWorkingStartedAtBySession[sessionID] = Date()
    }
    codexWorkingSessionIDs.insert(sessionID)
    syncCombinedWorkingSessions()
    saveWorkingSessionIDs()
  }

  private func restoreWorkingSessionIDs() {
    let existing = Set(sessions.map(\.id))
    let savedClaude = Set(
      (UserDefaults.standard.stringArray(forKey: claudeWorkingSessionsDefaultsKey) ?? [])
        .compactMap(UUID.init(uuidString:))
    )
    // Codex "working" is runtime state, so never trust persisted badges after launch.
    // The launch bootstrap immediately asks Codex/tmux for real activity and lights only those rows.
    codexWorkingSessionIDs = []
    claudeWorkingSessionIDs = savedClaude.intersection(existing)
    codexWorkingHoldUntil.removeAll()
    codexLocalTurnHoldUntil.removeAll()
    codexWorkingStartedAtBySession.removeAll()
    syncCombinedWorkingSessions()
  }

  private func saveWorkingSessionIDs() {
    syncCombinedWorkingSessions()
    UserDefaults.standard.set(
      workingSessionIDs.map(\.uuidString),
      forKey: workingSessionsDefaultsKey
    )
    UserDefaults.standard.set(
      codexWorkingSessionIDs.map(\.uuidString),
      forKey: codexWorkingSessionsDefaultsKey
    )
    UserDefaults.standard.set(
      claudeWorkingSessionIDs.map(\.uuidString),
      forKey: claudeWorkingSessionsDefaultsKey
    )
  }

  private func syncCombinedWorkingSessions() {
    workingSessionIDs = codexWorkingSessionIDs.union(claudeWorkingSessionIDs)
  }

  private func clearCodexDerivedState() {
    codexAnalysisTask?.cancel()
    codexAnalysisTask = nil
    codexArtifactPrewarmTask?.cancel()
    codexArtifactPrewarmTask = nil
    codexAnalysisFingerprint = codexTranscriptFingerprint
    codexArtifacts = []
    codexPreviewArtifact = nil
    codexArtifactPreviewText = ""
    codexArtifactPreviewURL = nil
    codexArtifactPreviewKind = .none
    isCodexArtifactPreviewLoading = false
    codexArtifactPreviewError = ""
    codexTranscriptCanLoadMore = false
    isLoadingMoreCodexTranscript = false
    codexModel = "gpt-5.5"
  }

  func codexDraftForActiveSession() -> String {
    guard let activeSessionID else { return "" }
    if let draft = codexDraftsBySession[activeSessionID] {
      return draft
    }
    let url = sessionDirectory(for: activeSessionID.uuidString)
      .appendingPathComponent("codex-draft.txt")
    let draft = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    codexDraftsBySession[activeSessionID] = draft
    return draft
  }

  func cacheCodexDraftForActiveSession(_ value: String) {
    guard let activeSessionID else { return }
    codexDraftsBySession[activeSessionID] = value
  }

  func updateCodexDraftForActiveSession(_ value: String) {
    guard let activeSessionID else { return }
    codexDraftsBySession[activeSessionID] = value
    let folder = sessionDirectory(for: activeSessionID.uuidString)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appendingPathComponent("codex-draft.txt")
    if value.isEmpty {
      try? FileManager.default.removeItem(at: url)
    } else {
      try? value.write(to: url, atomically: true, encoding: .utf8)
    }
  }

  private func scheduleCodexTranscriptAnalysis(force: Bool = false) {
    let fingerprint = codexTranscriptFingerprint
    guard force || fingerprint != codexAnalysisFingerprint else { return }
    codexAnalysisTask?.cancel()
    codexAnalysisFingerprint = fingerprint

    let transcript = codexTranscript
    guard !transcript.trimmed.isEmpty else {
      clearCodexDerivedState()
      return
    }

    let remoteHome = settings.remoteHome
    let remoteDir =
      activeSession?.remoteDir.trimmed.isEmpty == false
      ? activeSession!.remoteDir
      : currentRemoteDir
    codexAnalysisTask = Task(priority: .userInitiated) { [weak self] in
      let analysis = await Task.detached(priority: .userInitiated) {
        CodexTranscriptAnalyzer.analyze(
          transcript,
          remoteHome: remoteHome,
          currentRemoteDir: remoteDir
        )
      }.value
      guard !Task.isCancelled, let self, self.codexTranscriptFingerprint == fingerprint else {
        return
      }
      self.applyCodexTranscriptAnalysis(analysis)
    }
  }

  private func applyCodexTranscriptAnalysis(_ analysis: CodexTranscriptAnalysis) {
    codexArtifacts = analysis.artifacts
    scheduleCodexArtifactPrewarm(for: analysis.artifacts)
    if let token5h = analysis.token5h {
      codexToken5h = token5h
    }
    if let tokenWeekly = analysis.tokenWeekly {
      codexTokenWeekly = tokenWeekly
    }
    if let tokenReset = analysis.tokenReset {
      codexTokenReset = tokenReset
    }
    if analysis.token5h != nil || analysis.tokenWeekly != nil || analysis.tokenReset != nil {
      saveCodexTokenStatus()
    }
    if let model = analysis.model, isValidCodexModelName(model) {
      codexModel = model
    }
    if let reasoningEffort = analysis.reasoningEffort {
      updateCodexReasoningEffort(reasoningEffort)
    }
  }

  private func scheduleCodexArtifactPrewarm(for artifacts: [CodexArtifact]) {
    codexArtifactPrewarmTask?.cancel()
    guard !activeCodexIsWorking, !isCodexArtifactPreviewLoading,
      !isCodexTranscriptAutoRefreshActive
    else { return }
    let currentSessionID = activeSessionID
    let candidates = Array(artifacts.suffix(32))
    guard !candidates.isEmpty else { return }
    codexArtifactPrewarmTask = Task(priority: .utility) { [weak self] in
      try? await Task.sleep(nanoseconds: 450_000_000)
      for artifact in candidates {
        guard !Task.isCancelled, let self else { return }
        guard self.activeSessionID == currentSessionID else { return }
        guard !self.activeCodexIsWorking, !self.isCodexArtifactPreviewLoading,
          !self.isCodexTranscriptAutoRefreshActive
        else { return }
        await self.prewarmCodexArtifact(artifact)
      }
    }
  }

  private func prewarmCodexArtifact(_ artifact: CodexArtifact) async {
    guard !activeCodexIsWorking, !isCodexArtifactPreviewLoading,
      !isCodexTranscriptAutoRefreshActive
    else { return }
    let path = await resolveRemotePreviewPath(
      codexRemotePathFromUserInput(artifact.path),
      context: artifact.sourceLine
    )
    guard !path.isEmpty else { return }
    switch previewKind(for: path) {
    case .text:
      guard remoteTextPreviewCache[path] == nil else { return }
      let result = await runRemoteBackground(
        "read-file-preview", args: ["180000"], input: path + "\n", timeout: 18)
      let previewText = result.output.trimmed.isEmpty ? result.combined : result.output
      if result.exitCode == 0, !previewText.trimmed.isEmpty {
        remoteTextPreviewCache[path] = previewText
      }
    case .image, .pdf, .video:
      return
    case .external, .none:
      return
    }
  }

  private func applyCodexTokenStatus(_ text: String) {
    let analysis = CodexTranscriptAnalyzer.analyze(
      text,
      remoteHome: settings.remoteHome,
      currentRemoteDir: currentRemoteDir
    )
    var updated = false
    if let token5h = analysis.token5h {
      codexToken5h = token5h
      updated = true
    }
    if let tokenWeekly = analysis.tokenWeekly {
      codexTokenWeekly = tokenWeekly
      updated = true
    }
    if let tokenReset = analysis.tokenReset {
      codexTokenReset = tokenReset
    } else if updated {
      codexTokenReset = "Updated \(Date().shortStamp)"
    }
    if !updated {
      codexTokenReset = "Token status unavailable · \(Date().shortStamp)"
    }
    saveCodexTokenStatus()
  }

  private func saveCodexTokenStatus() {
    UserDefaults.standard.set(codexToken5h, forKey: codexToken5hDefaultsKey)
    UserDefaults.standard.set(codexTokenWeekly, forKey: codexTokenWeeklyDefaultsKey)
    UserDefaults.standard.set(codexTokenReset, forKey: codexTokenResetDefaultsKey)
  }

  private func updateActiveCodexWorkingState(from text: String, mayStart: Bool) {
    let tail = recentText(text, maxCharacters: 12_000).lowercased()
    let latestWorkingMarker = latestIndex(
      in: tail,
      matching: [
        "• working", "working (", "working for", "esc to interrupt",
      ])
    let latestDoneMarker = latestIndex(
      in: tail,
      matching: [
        "process exited with code", "final answer", "implemented", "changed files", "checks run",
        "final status", "next recommended command", "10 seconds passed", "waited 10 seconds",
        "waited 20 seconds", "waited 30 seconds", "final_no_steer", "final_steer_ok",
        "final_queue_ok", "ui_no_steer", "ui_steer_ok", "\nok\n",
      ])

    if mayStart, let latestWorkingMarker,
      latestDoneMarker.map({ latestWorkingMarker > $0 }) ?? true
    {
      markActiveSessionWorking(true, tool: .codex)
    } else if let latestDoneMarker,
      latestWorkingMarker.map({ latestDoneMarker > $0 }) ?? true
    {
      if let activeSessionID {
        settleCodexWorkingStateAfterCompletion(sessionID: activeSessionID)
      }
    }
  }

  private func updateActiveClaudeWorkingState(from text: String, mayStart: Bool) {
    let tail = recentText(text, maxCharacters: 12_000).lowercased()
    if claudeTranscriptIsAtSetupPrompt(tail) {
      markActiveSessionWorking(false, tool: .claude)
      return
    }
    let latestWorkingMarker = latestIndex(
      in: tail,
      matching: [
        "thinking", "working", "esc to interrupt", "running", "processing", "tool use",
        "bash", "edit", "read",
      ])
    let latestDoneMarker = latestIndex(
      in: tail,
      matching: [
        "implemented", "changed files", "checks run", "final status", "next recommended command",
        "done", "complete",
      ])

    if mayStart, let latestWorkingMarker,
      latestDoneMarker.map({ latestWorkingMarker > $0 }) ?? true
    {
      markActiveSessionWorking(true, tool: .claude)
    } else if let latestDoneMarker,
      latestWorkingMarker.map({ latestDoneMarker > $0 }) ?? true
    {
      markActiveSessionWorking(false, tool: .claude)
    }
  }

  private func claudeTranscriptIsAtSetupPrompt(_ text: String) -> Bool {
    let tail = recentText(text, maxCharacters: 12_000).lowercased()
    guard
      let latestBlockingPrompt = latestIndex(
        in: tail,
        matching: [
          "choose the text style",
          "select login method",
          "claude code can be used with your claude subscription",
          "to change this later, run /theme",
          "login method:",
        ])
    else { return false }
    let afterPrompt = String(tail[latestBlockingPrompt...])
    let latestProgressAfterPrompt = latestIndex(
      in: afterPrompt,
      matching: [
        "thinking", "tool use", "bash", "edit", "read file", "wrote", "done", "complete",
        "claude_ok",
      ])
    return latestProgressAfterPrompt == nil
  }

  private func latestIndex(in text: String, matching needles: [String]) -> String.Index? {
    var latest: String.Index?
    for needle in needles {
      guard let range = text.range(of: needle, options: .backwards) else { continue }
      if latest.map({ range.lowerBound > $0 }) ?? true {
        latest = range.lowerBound
      }
    }
    return latest
  }

  private func ensureConversationSession(defaultTool: AISessionTool) {
    guard activeSession == nil else { return }
    let folderName = URL(fileURLWithPath: currentRemoteDir.expandingTilde).lastPathComponent
    let fallbackName: String
    switch defaultTool {
    case .codex:
      fallbackName = folderName.isEmpty ? "Codex Session" : "\(folderName) Codex"
    case .claude:
      fallbackName = folderName.isEmpty ? "Claude Session" : "\(folderName) Claude"
    }
    _ = addSession(name: fallbackName, path: currentRemoteDir, tool: defaultTool)
  }

  private func enableToolForActiveSession(_ tool: AISessionTool, touch: Bool = false) {
    guard let activeSessionID,
      let index = sessions.firstIndex(where: { $0.id == activeSessionID })
    else { return }
    sessions[index].enableTool(tool)
    if touch {
      sessions[index].updatedAt = Date()
    }
    saveSessions()
  }

  private func updateActiveSessionDirectory(_ path: String) {
    let normalized = normalizedRemotePath(path)
    guard let activeSessionID,
      let index = sessions.firstIndex(where: { $0.id == activeSessionID }),
      sessions[index].remoteDir != normalized
    else { return }
    sessions[index].remoteDir = normalized
    sessions[index].updatedAt = Date()
    saveSessions()
  }

  private func updateActiveCodexHistory(
    id: String,
    path: String = "",
    title: String = "",
    host: String = "remote",
    updatedAt: Date? = nil,
    touch: Bool = false
  ) {
    let trimmedID = id.trimmed
    guard !trimmedID.isEmpty,
      let activeSessionID,
      let index = sessions.firstIndex(where: { $0.id == activeSessionID })
    else { return }
    let displayTitle = titleForCodexHistory(
      id: trimmedID,
      cwd: sessions[index].remoteDir,
      rawTitle: title
    )
    sessions[index].codexHistoryID = trimmedID
    sessions[index].codexHistoryHost = host.trimmed.isEmpty ? "remote" : host.trimmed.lowercased()
    if !path.trimmed.isEmpty {
      sessions[index].codexHistoryPath = path.trimmed
    }
    if !displayTitle.isEmpty {
      sessions[index].codexHistoryTitle = displayTitle
      if sessions[index].nameSource == .codexApp {
        sessions[index].name = stableCodexSessionName(id: trimmedID, cwd: sessions[index].remoteDir)
      }
    }
    sessions[index].codexState = .linked
    sessions[index].enableTool(.codex)
    if let updatedAt {
      sessions[index].updatedAt = updatedAt
    } else if touch {
      sessions[index].updatedAt = Date()
    }
    saveSessions()
  }

  private func updateCodexHistory(
    for sessionID: UUID,
    id: String,
    path: String = "",
    title: String = "",
    host: String = "remote",
    updatedAt: Date? = nil,
    touch: Bool = false
  ) {
    let trimmedID = id.trimmed
    guard !trimmedID.isEmpty,
      let index = sessions.firstIndex(where: { $0.id == sessionID })
    else { return }
    let displayTitle = titleForCodexHistory(
      id: trimmedID,
      cwd: sessions[index].remoteDir,
      rawTitle: title
    )
    sessions[index].codexHistoryID = trimmedID
    sessions[index].codexHistoryHost = host.trimmed.isEmpty ? "remote" : host.trimmed.lowercased()
    if !path.trimmed.isEmpty {
      sessions[index].codexHistoryPath = path.trimmed
    }
    if !displayTitle.isEmpty {
      sessions[index].codexHistoryTitle = displayTitle
      if sessions[index].nameSource == .codexApp {
        sessions[index].name = stableCodexSessionName(id: trimmedID, cwd: sessions[index].remoteDir)
      }
    }
    sessions[index].codexState = .linked
    sessions[index].enableTool(.codex)
    if let updatedAt {
      sessions[index].updatedAt = updatedAt
    } else if touch {
      sessions[index].updatedAt = Date()
    }
    saveSessions()
  }

  private func sanitizeCodexRuntimeSelection() {
    if !isValidCodexModelName(codexModel) {
      codexModel = "gpt-5.5"
    }
    if codexReasoningEffort.trimmed.isEmpty {
      codexReasoningEffort = "xhigh"
    }
  }

  private func sanitizeImportedCodexSessionNames(save shouldSave: Bool) {
    var changed = false
    for index in sessions.indices {
      let currentTitle = sessions[index].codexHistoryTitle.trimmed
      let cleanTitle = cleanCodexHistoryTitle(currentTitle)
      let fallback = titleForCodexHistory(
        id: sessions[index].codexHistoryID,
        cwd: sessions[index].remoteDir,
        rawTitle: currentTitle
      )
      let nextTitle = cleanTitle ?? fallback
      if sessions[index].codexHistoryTitle != nextTitle {
        sessions[index].codexHistoryTitle = nextTitle
        changed = true
      }
      let stableName = stableCodexSessionName(
        id: sessions[index].codexHistoryID,
        cwd: sessions[index].remoteDir
      )
      let importedOrNoisy =
        sessions[index].nameSource == .codexApp
        || (sessions[index].nameSource == .generated
          && !sessions[index].codexHistoryID.trimmed.isEmpty
          && cleanCodexHistoryTitle(sessions[index].name) == nil)
      if importedOrNoisy && sessions[index].name != stableName {
        sessions[index].name = stableName
        sessions[index].nameSource = .codexApp
        changed = true
      } else if importedOrNoisy && sessions[index].nameSource != .codexApp {
        sessions[index].nameSource = .codexApp
        changed = true
      }
      if sessions[index].codexHistoryID.trimmed.isEmpty
        && sessions[index].codexHistoryTitle != ""
      {
        sessions[index].codexHistoryTitle = ""
        changed = true
      }
    }
    if changed {
      sortSessionsByRecent()
      if shouldSave {
        saveSessions()
      }
    }
  }

  private func titleForCodexHistory(
    id: String,
    cwd: String,
    rawTitle: String
  ) -> String {
    if let title = cleanCodexHistoryTitle(rawTitle) {
      return title
    }
    return stableCodexSessionName(id: id, cwd: cwd)
  }

  private func stableCodexSessionName(id: String, cwd: String) -> String {
    let folder = URL(fileURLWithPath: cwd.expandingTilde).lastPathComponent.trimmed
    let prefix = folder.isEmpty ? "Codex" : folder
    let short = id.trimmed.isEmpty ? "" : " \(String(id.trimmed.prefix(8)))"
    return "\(prefix)\(short)"
  }

  private func titleForCodexRecord(_ record: CodexHistoryRecord) -> String {
    titleForCodexHistory(id: record.id, cwd: record.cwd, rawTitle: record.title)
  }

  private func cleanCodexHistoryTitle(_ rawTitle: String) -> String? {
    let title =
      rawTitle
      .replacingOccurrences(of: "\u{0000}", with: "")
      .trimmed
    guard !title.isEmpty else { return nil }
    let lower = title.lowercased()
    let blockedFragments = [
      "<environment_context",
      "</environment_context",
      "<sshcontroll_attachments",
      "<current_date>",
      "<shell>",
      "<cwd>",
      "<subagent_notification",
      "</subagent_notification",
      "computer use is installed, but blocked",
      "apple event error",
      "could not create image from display",
      "codex/tcc relevant processes",
      "segment_ids =",
      "def ",
      "class ",
      "flutter analyze",
      "flutter build",
      "swift build",
      "process running with session id",
      "a_queue_",
      "steer the current codex work with this instruction",
      "basename:",
      "first line:",
      "smoke-test marker",
      "[@computer]",
    ]
    if blockedFragments.contains(where: { lower.contains($0) }) {
      return nil
    }
    let blockedPrefixes = ["`", "```", "{", "}", "[", "]", "import ", "from ", "let ", "var "]
    if blockedPrefixes.contains(where: { lower.hasPrefix($0) }) {
      return nil
    }
    if title.count > 160, title.contains("\n") || title.contains("<") {
      return nil
    }
    let firstLine = title.components(separatedBy: .newlines).first?.trimmed ?? title
    guard !firstLine.isEmpty else { return nil }
    if firstLine.range(
      of: #"^(?:cd(?:\s|$)|pwd(?:\s|$)|ls(?:\s|$)|clear$|/(?:status|model|permissions)\b)"#,
      options: [.regularExpression, .caseInsensitive]
    ) != nil {
      return nil
    }
    if firstLine.range(
      of: #"^Stage\s+\d+\b.*\brole:"#,
      options: [.regularExpression, .caseInsensitive]
    ) != nil {
      return nil
    }
    return firstLine
  }

  private func updateActiveCodexState(_ state: CodexSessionState) {
    guard let activeSessionID,
      let index = sessions.firstIndex(where: { $0.id == activeSessionID })
    else { return }
    sessions[index].codexState = state
    sessions[index].enableTool(.codex)
    sessions[index].updatedAt = Date()
    saveSessions()
  }

  func saveSettings() {
    Self.ensureLocalTransferDirectories(for: settings)
    if let data = try? JSONEncoder().encode(settings) {
      try? data.write(to: settingsURL, options: .atomic)
    }
  }

  func selectConnectionNetworkProfile(_ profile: ConnectionNetworkProfile) {
    let previous = settings.selectedNetworkProfile
    if previous != profile {
      settings.storeConnection(
        hostAlias: settings.hostAlias,
        sshPort: settings.sshPort,
        latencyTarget: settings.latencyTarget,
        in: previous
      )
    }
    settings.applyNetworkProfile(profile)
    saveSettings()
    statusText = "Connection profile: \(profile.title) · \(Date().shortStamp)"
  }

  func saveCurrentConnectionToSelectedProfile() {
    settings.storeActiveConnectionInSelectedProfile()
    saveSettings()
    statusText = "Saved \(settings.selectedNetworkProfile.title) connection · \(Date().shortStamp)"
  }

  func selectSurface(_ surface: AppSurface) {
    selectedSurface = surface
    isCodeWorkspaceInlineActive = false
    updateCodeWorkspaceVisibilityState()
  }

  func openCodeWorkspaceInline() {
    if !isCodeWorkspaceInlineActive {
      codeWorkspaceReturnSurface = selectedSurface
    }
    isCodeWorkspaceInlineActive = true
    updateCodeWorkspaceVisibilityState()
    alignCodeWorkspaceToActiveSessionDirectory()
  }

  func closeCodeWorkspaceInline() {
    guard isCodeWorkspaceInlineActive else { return }
    isCodeWorkspaceInlineActive = false
    selectedSurface = codeWorkspaceReturnSurface
    updateCodeWorkspaceVisibilityState()
  }

  func setCodeWorkspaceDetachedOpen(_ open: Bool) {
    isCodeWorkspaceDetachedOpen = open
    updateCodeWorkspaceVisibilityState()
  }

  private func updateCodeWorkspaceVisibilityState() {
    isCodeWorkspaceOpen = isCodeWorkspaceInlineActive || isCodeWorkspaceDetachedOpen
  }

  func setCodeWorkspaceExplorerWidth(_ width: CGFloat, persist: Bool = true) {
    codeWorkspaceExplorerWidth = clampedCodeWorkspaceExplorerWidth(width)
    if persist {
      UserDefaults.standard.set(
        Double(codeWorkspaceExplorerWidth), forKey: codeWorkspaceExplorerWidthDefaultsKey)
    }
  }

  func clampedCodeWorkspaceExplorerWidth(_ width: CGFloat) -> CGFloat {
    Self.clampedWorkspacePaneValue(Double(width), defaultValue: 300, range: 190...560)
  }

  func setCodeWorkspaceCodexWidth(_ width: CGFloat, persist: Bool = true) {
    codeWorkspaceCodexWidth = clampedCodeWorkspaceCodexWidth(width)
    if persist {
      UserDefaults.standard.set(
        Double(codeWorkspaceCodexWidth), forKey: codeWorkspaceCodexWidthDefaultsKey)
    }
  }

  func clampedCodeWorkspaceCodexWidth(_ width: CGFloat) -> CGFloat {
    Self.clampedWorkspacePaneValue(Double(width), defaultValue: 330, range: 220...560)
  }

  func setCodeWorkspaceConsoleHeight(_ height: CGFloat, persist: Bool = true) {
    codeWorkspaceConsoleHeight = clampedCodeWorkspaceConsoleHeight(height)
    if persist {
      UserDefaults.standard.set(
        Double(codeWorkspaceConsoleHeight), forKey: codeWorkspaceConsoleHeightDefaultsKey)
    }
  }

  func clampedCodeWorkspaceConsoleHeight(_ height: CGFloat) -> CGFloat {
    Self.clampedWorkspacePaneValue(Double(height), defaultValue: 170, range: 90...420)
  }

  func setCodeWorkspaceExplorerCollapsed(_ collapsed: Bool) {
    isCodeWorkspaceExplorerCollapsed = collapsed
    UserDefaults.standard.set(collapsed, forKey: codeWorkspaceExplorerCollapsedDefaultsKey)
  }

  func setCodeWorkspaceCodexCollapsed(_ collapsed: Bool) {
    isCodeWorkspaceCodexCollapsed = collapsed
    UserDefaults.standard.set(collapsed, forKey: codeWorkspaceCodexCollapsedDefaultsKey)
  }

  func setCodeWorkspaceConsoleVisible(_ visible: Bool) {
    isCodeWorkspaceConsoleVisible = visible
    UserDefaults.standard.set(visible, forKey: codeWorkspaceConsoleVisibleDefaultsKey)
  }

  func toggleCodeWorkspaceExplorer() {
    setCodeWorkspaceExplorerCollapsed(!isCodeWorkspaceExplorerCollapsed)
  }

  func toggleCodeWorkspaceCodex() {
    setCodeWorkspaceCodexCollapsed(!isCodeWorkspaceCodexCollapsed)
  }

  func toggleCodeWorkspaceConsole() {
    setCodeWorkspaceConsoleVisible(!isCodeWorkspaceConsoleVisible)
  }

  private static func clampedWorkspacePaneValue(
    _ value: Double,
    defaultValue: CGFloat,
    range: ClosedRange<CGFloat>
  ) -> CGFloat {
    guard value.isFinite, value > 0 else { return defaultValue }
    return min(range.upperBound, max(range.lowerBound, CGFloat(value)))
  }

  func applyExplorerRootAsActiveDirectory() {
    let normalized = normalizedRemotePath(settings.explorerRoot)
    currentRemoteDir = normalized
    updateActiveSessionDirectory(normalized)
    saveSettings()
  }

  func alignCodeWorkspaceToActiveSessionDirectory() {
    let sessionDirectory =
      activeSession?.remoteDir.trimmed.isEmpty == false ? activeSession!.remoteDir : currentRemoteDir
    let normalized = normalizedRemotePath(sessionDirectory)
    currentRemoteDir = normalized
    fileBrowserDir = normalized
    remoteOpenPath = normalized
    clearRemoteSelection()
  }

  func prepareCodeWorkspaceForActiveSession() async {
    alignCodeWorkspaceToActiveSessionDirectory()
    await loadFileBrowserDirectory(currentRemoteDir, force: false, showsActivity: false)
  }

  func saveSessions() {
    sortSessionsByRecent()
    if let data = try? JSONEncoder().encode(sessions) {
      try? data.write(to: sessionsURL, options: .atomic)
    }
    if let activeSessionID {
      UserDefaults.standard.set(activeSessionID.uuidString, forKey: "AControl.activeSessionID")
    } else {
      UserDefaults.standard.removeObject(forKey: "AControl.activeSessionID")
    }
  }

  private func sortSessionsByRecent() {
    let originalIndex = Dictionary(uniqueKeysWithValues: sessions.enumerated().map { index, session in
      (session.id, index)
    })
    sessions.sort { first, second in
      let firstWorking = codexWorkingSessionIDs.contains(first.id)
        || claudeWorkingSessionIDs.contains(first.id)
      let secondWorking = codexWorkingSessionIDs.contains(second.id)
        || claudeWorkingSessionIDs.contains(second.id)
      if firstWorking && secondWorking {
        return (originalIndex[first.id] ?? Int.max) < (originalIndex[second.id] ?? Int.max)
      }
      if first.updatedAt != second.updatedAt {
        return first.updatedAt > second.updatedAt
      }
      let nameOrder = first.name.localizedStandardCompare(second.name)
      if nameOrder != .orderedSame {
        return nameOrder == .orderedAscending
      }
      return first.id.uuidString < second.id.uuidString
    }
  }

  private func touchActiveSession() {
    guard let activeSessionID,
      let index = sessions.firstIndex(where: { $0.id == activeSessionID })
    else { return }
    sessions[index].updatedAt = Date()
    saveSessions()
  }

  private var deletedCodexHistoryIDs: Set<String> {
    get {
      Set(
        (UserDefaults.standard.stringArray(forKey: deletedCodexHistoryDefaultsKey) ?? [])
          .map(\.trimmed)
          .filter { !$0.isEmpty }
      )
    }
    set {
      UserDefaults.standard.set(
        Array(newValue).sorted(),
        forKey: deletedCodexHistoryDefaultsKey
      )
    }
  }

  private func tombstoneCodexHistoryID(_ id: String) {
    let trimmed = id.trimmed
    guard !trimmed.isEmpty else { return }
    var tombstones = deletedCodexHistoryIDs
    tombstones.insert(trimmed)
    deletedCodexHistoryIDs = tombstones
  }

  private func isCodexHistoryTombstoned(_ id: String) -> Bool {
    deletedCodexHistoryIDs.contains(id.trimmed)
  }

  func refreshActiveSurface() async {
    if isCodeWorkspaceInlineActive {
      let target = fileBrowserDir.trimmed.isEmpty ? currentRemoteDir : fileBrowserDir
      await loadFileBrowserDirectory(target, force: true, showsActivity: false)
      await refreshCodexPromptQueueStatuses()
      async let shellRefresh: Void = captureShellIfUseful()
      async let codexRefresh: Void = captureCodexIfUseful(force: true)
      _ = await (shellRefresh, codexRefresh)
      return
    }
    switch selectedSurface {
    case .dashboard:
      await refreshDashboard()
    case .shell:
      await captureShell()
    case .codex:
      await syncServerCodexHistoryAndRefreshVisibleSession()
    case .claude:
      await captureClaude()
    case .files:
      let target = fileBrowserDir.trimmed.isEmpty ? currentRemoteDir : fileBrowserDir
      await loadFileBrowserDirectory(target, force: true, showsActivity: false)
    case .monitor:
      await refreshMonitor()
    case .mirror:
      await latencyCheck()
    case .settings:
      break
    }
  }

  func sendCurrentInput() async {
    if isCodeWorkspaceInlineActive {
      await sendCodex(steer: false)
      return
    }
    switch selectedSurface {
    case .shell:
      await sendShell()
    case .codex:
      await sendCodex(steer: false)
    case .claude:
      await sendClaude(steer: false)
    default:
      break
    }
  }

  func runRemote(
    _ action: String, args: [String] = [], input: String? = nil, timeout: TimeInterval = 120,
    showsActivity: Bool = true,
    bypassBackgroundQueue: Bool = false,
    environmentOverride: [String: String]? = nil
  ) async -> CommandResult {
    if showsActivity {
      isBusy = true
      statusText = "Request sent · \(Date().shortStamp)"
    }
    defer {
      if showsActivity {
        isBusy = false
      }
    }
    let commandClient = (showsActivity || bypassBackgroundQueue) ? SSHClient() : client
    let result = await commandClient.remote(
      settings: settings, action: action, args: args, input: input, timeout: timeout,
      environment: environmentOverride ?? activeRemoteEnvironment)
    if showsActivity {
      if result.exitCode == 0 {
        statusText = "OK · \(Date().shortStamp)"
      } else if result.isMissingOptionalDependency {
        statusText = "Missing dependency · \(Date().shortStamp)"
      } else {
        statusText = "Error \(result.exitCode) · \(Date().shortStamp)"
      }
    }
    return result
  }

  private func runRemoteBackground(
    _ action: String, args: [String] = [], input: String? = nil, timeout: TimeInterval = 120,
    environmentOverride: [String: String]? = nil
  ) async -> CommandResult {
    guard !shouldThrottleBackgroundRemoteWork else {
      return CommandResult(
        exitCode: 75,
        output: "",
        error: "Background remote command skipped while file transfer is active.")
    }
    let settingsSnapshot = settings
    let environmentSnapshot = environmentOverride ?? activeRemoteEnvironment
    let backgroundClient = SSHClient()
    return await backgroundClient.remote(
      settings: settingsSnapshot, action: action, args: args, input: input, timeout: timeout,
      environment: environmentSnapshot)
  }

  private var shouldThrottleBackgroundRemoteWork: Bool {
    fileTransferDepth > 0 || Date() < fileTransferQuietUntil
  }

  private func beginFileTransferMode() {
    fileTransferDepth += 1
    fileTransferQuietUntil = Date().addingTimeInterval(20)
  }

  private func endFileTransferMode() {
    fileTransferDepth = max(0, fileTransferDepth - 1)
    fileTransferQuietUntil = Date().addingTimeInterval(20)
  }

  private func runLocalHelper(
    _ action: String,
    args: [String] = [],
    input: String? = nil,
    timeout: TimeInterval = 120,
    environment: [String: String] = [:]
  ) async -> CommandResult {
    guard let helperURL = bundledRemoteHelperURL() else {
      return CommandResult(exitCode: 127, output: "", error: "Bundled SSHcontroll helper not found.")
    }
    var commandArguments: [String] = []
    for key in environment.keys.sorted() {
      guard let value = environment[key], !value.trimmed.isEmpty else { continue }
      commandArguments.append("\(key)=\(value)")
    }
    commandArguments.append(helperURL.path)
    commandArguments.append(action)
    commandArguments.append(contentsOf: args)
    return await SSHClient().run(
      "/usr/bin/env",
      commandArguments,
      input: input?.data(using: .utf8),
      timeout: timeout
    )
  }

  private func decodedCodexHistoryRecords(from result: CommandResult, host: String)
    -> [CodexHistoryRecord]
  {
    guard result.exitCode == 0,
      let data = result.output.data(using: .utf8),
      let decoded = try? JSONDecoder().decode([CodexHistoryRecord].self, from: data)
    else { return [] }
    let normalizedHost = host.trimmed.isEmpty ? "remote" : host.trimmed.lowercased()
    return decoded.map { record in
      var next = record
      let recordHost = next.host?.trimmed.lowercased() ?? ""
      next.host = recordHost.isEmpty ? normalizedHost : recordHost
      return next
    }
  }

  private func mergedCodexHistoryRecords(_ records: [CodexHistoryRecord]) -> [CodexHistoryRecord] {
    var byKey: [String: CodexHistoryRecord] = [:]
    for record in records {
      let id = record.id.trimmed
      guard !id.isEmpty else { continue }
      let host = record.normalizedHost
      let key = "\(host)|\(id)"
      if let existing = byKey[key] {
        byKey[key] = betterCodexHistoryRecord(existing, record)
      } else {
        var next = record
        next.host = host
        byKey[key] = next
      }
    }
    return byKey.values.sorted { first, second in
      if first.mtime != second.mtime { return first.mtime > second.mtime }
      if first.normalizedHost != second.normalizedHost {
        return first.normalizedHost == "remote"
      }
      return first.id < second.id
    }
  }

  private func betterCodexHistoryRecord(
    _ first: CodexHistoryRecord,
    _ second: CodexHistoryRecord
  ) -> CodexHistoryRecord {
    if first.mtime != second.mtime {
      return first.mtime > second.mtime ? first : second
    }
    if !first.path.trimmed.isEmpty, second.path.trimmed.isEmpty { return first }
    if first.path.trimmed.isEmpty, !second.path.trimmed.isEmpty { return second }
    if first.normalizedHost == "remote", second.normalizedHost != "remote" { return first }
    if second.normalizedHost == "remote", first.normalizedHost != "remote" { return second }
    return second
  }

  func prepareNetworkOnLaunch() async {
    guard settings.startTailscaleOnLaunch else { return }
    let localScript = """
      set +e
      ts_bin=""
      if command -v tailscale >/dev/null 2>&1; then
        ts_bin="$(command -v tailscale)"
      elif [ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then
        ts_bin=/Applications/Tailscale.app/Contents/MacOS/Tailscale
      fi
      if [ -n "$ts_bin" ]; then
        "$ts_bin" set --exit-node= --accept-routes=false >/dev/null 2>&1 || true
      fi
      status_ok=1
      if [ -n "$ts_bin" ]; then
        "$ts_bin" status --self >/dev/null 2>&1 && status_ok=0
      fi
      if [ "$status_ok" = "0" ]; then
        echo ready
        exit 0
      fi
      if open -ga Tailscale >/dev/null 2>&1; then
        sleep 1
        if [ -n "$ts_bin" ]; then
          "$ts_bin" set --exit-node= --accept-routes=false >/dev/null 2>&1 || true
          "$ts_bin" status --self >/dev/null 2>&1 && echo ready && exit 0
        fi
        echo opened
      else
        echo missing
      fi
      """
    let result = await client.shell(localScript, timeout: 8)
    if result.exitCode == 0 {
      let state = result.output.trimmed.lowercased()
      if state.contains("ready") {
        statusText = "C Tailscale ready · \(Date().shortStamp)"
      } else if state.contains("opened") {
        statusText = "C Tailscale opened · \(Date().shortStamp)"
      } else {
        statusText = "C Tailscale not found · \(Date().shortStamp)"
      }
    }
  }

  func bootstrapOnLaunch() async {
    sanitizeCodexRuntimeSelection()
    await prepareNetworkOnLaunch()
    await syncBundledRemoteHelperOnLaunch()
    await resumeAQueuedCodexWorkersOnLaunch()
    await warmInteractiveDataOnLaunch()
    await refreshCodexPromptQueueStatuses()
    if codexPromptQueue.contains(where: { $0.status == .queued }) {
      processCodexPromptQueue()
    }
    startBackgroundDataRefresh()
  }

  private func resumeAQueuedCodexWorkersOnLaunch() async {
    guard settings.hasSSHTarget else { return }
    let result = await runRemote(
      "codex-queue-resume-all",
      timeout: 20,
      showsActivity: false,
      bypassBackgroundQueue: true
    )
    if result.exitCode == 0, result.output.contains("started="), !result.output.contains("started=0 pending=0") {
      statusText = "A queue resumed · \(Date().shortStamp)"
    }
  }

  func startBackgroundDataRefresh() {
    guard backgroundDataRefreshTask == nil else { return }
    backgroundDataRefreshTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 1_800_000_000)
      while !Task.isCancelled {
        guard let self else { break }
        await self.backgroundDataRefreshTick()
        let interval = self.backgroundRefreshInterval()
        try? await Task.sleep(nanoseconds: interval)
      }
    }
    startBackgroundKeepAlive()
  }

  private func startBackgroundKeepAlive() {
    guard backgroundKeepAliveTask == nil else { return }
    backgroundKeepAliveTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { break }
        if self.settings.hasSSHTarget, !self.shouldThrottleBackgroundRemoteWork {
          async let working: Void = self.refreshCodexWorkingStates()
          async let sessions: Void = self.syncCodexAppSessions(
            showsActivity: false,
            force: false,
            refreshWorkingAfter: false
          )
          _ = await (working, sessions)
        }
        try? await Task.sleep(nanoseconds: 8_000_000_000)
      }
    }
  }

  private func warmInteractiveDataOnLaunch() async {
    async let dashboard: Void = refreshDashboard(showsActivity: false)
    async let codexWorking: Void = refreshCodexWorkingStates(force: true)
    async let directory: Void =
      currentRemoteDir.trimmed.isEmpty
      ? ()
      : loadDirectory(currentRemoteDir, showsActivity: false)
    async let fileBrowser: Void =
      fileBrowserDir.trimmed.isEmpty
      ? ()
      : ensureFileBrowserLoaded(force: false)
    _ = await (
      dashboard, codexWorking, directory, fileBrowser
    )
    let deferredRefreshStart = Date()
    lastBackgroundCodexSessionSync = deferredRefreshStart
    lastCodexTokenRefresh = deferredRefreshStart
    lastBackgroundPluginRefresh = deferredRefreshStart
    lastBackgroundPermissionRefresh = deferredRefreshStart
    Task(priority: .utility) { [weak self] in
      try? await Task.sleep(nanoseconds: 4_000_000_000)
      await self?.syncCodexAppSessions(
        showsActivity: false,
        force: true,
        refreshWorkingAfter: false
      )
      try? await Task.sleep(nanoseconds: 2_000_000_000)
      await self?.refreshCodexTokenStatus(showStatus: false, force: true)
      try? await Task.sleep(nanoseconds: 2_000_000_000)
      await self?.refreshCodexPluginStatusSilently()
      try? await Task.sleep(nanoseconds: 2_000_000_000)
      await self?.refreshRemotePermissionStateSilently()
    }

    if selectedSurface == .codex {
      await syncServerCodexHistoryAndRefreshVisibleSession()
    } else if selectedSurface == .claude, activeClaudeConversationIsEstablished {
      await captureClaude()
    }
  }

  private func backgroundRefreshInterval() -> UInt64 {
    if shouldThrottleBackgroundRemoteWork {
      return 20_000_000_000
    }
    let activeWorking = activeSessionID.map { codexWorkingSessionIDs.contains($0) } ?? false
    if selectedSurface == .codex {
      return activeWorking ? 1_200_000_000 : 3_000_000_000
    }
    if isCodeWorkspaceOpen {
      return activeWorking ? 5_000_000_000 : 10_000_000_000
    }
    if !codexWorkingSessionIDs.isEmpty || !claudeWorkingSessionIDs.isEmpty {
      return 2_000_000_000
    }
    return 5_000_000_000
  }

  private func backgroundDataRefreshTick() async {
    guard !isRunningBackgroundDataRefresh else { return }
    guard !shouldThrottleBackgroundRemoteWork else { return }
    isRunningBackgroundDataRefresh = true
    defer { isRunningBackgroundDataRefresh = false }

    let now = Date()
    await refreshCodexWorkingStates()
    await Task.yield()

    let sessionSyncInterval: TimeInterval =
      !codexWorkingSessionIDs.isEmpty || !claudeWorkingSessionIDs.isEmpty ? 20.0 : 60.0
    if now.timeIntervalSince(lastBackgroundCodexSessionSync) >= sessionSyncInterval {
      lastBackgroundCodexSessionSync = now
      Task(priority: .userInitiated) { [weak self] in
        await self?.syncCodexAppSessions(
          showsActivity: false,
          force: false,
          refreshWorkingAfter: false
        )
      }
    }

    if now.timeIntervalSince(lastCodexTokenRefresh) >= 180 {
      lastCodexTokenRefresh = now
      Task(priority: .utility) { [weak self] in
        await self?.refreshCodexTokenStatus(showStatus: false, force: true)
      }
    }

    let recentWarmInterval: TimeInterval =
      !codexWorkingSessionIDs.isEmpty || isCodeWorkspaceOpen || selectedSurface == .codex
        ? 45.0 : 180.0
    if now.timeIntervalSince(lastBackgroundRecentSessionWarm) >= recentWarmInterval {
      lastBackgroundRecentSessionWarm = now
      Task(priority: .userInitiated) { [weak self] in
        await self?.warmRecentCodexSessionCaches()
      }
    }

    if selectedSurface == .codex,
      now.timeIntervalSince(lastVisibleArtifactPrewarm) >= 2.0
    {
      lastVisibleArtifactPrewarm = now
      Task(priority: .utility) { [weak self] in
        await self?.prewarmVisibleCodexArtifacts()
      }
    }

    if selectedSurface == .dashboard,
      now.timeIntervalSince(lastBackgroundDashboardRefresh) >= 8
    {
      lastBackgroundDashboardRefresh = now
      Task(priority: .utility) { [weak self] in
        await self?.refreshDashboard(showsActivity: false)
      }
    }

    if (selectedSurface == .files || isCodeWorkspaceOpen),
      fileBrowserDir.trimmed.isEmpty,
      now.timeIntervalSince(lastBackgroundDirectoryRefresh) >= 2.0
    {
      lastBackgroundDirectoryRefresh = now
      Task(priority: .utility) { [weak self] in
        await self?.ensureFileBrowserLoaded(force: false)
      }
    }

    let shellCaptureInterval: TimeInterval =
      selectedSurface == .shell || isCodeWorkspaceOpen
      ? (isCodeWorkspaceOpen ? 12.0 : 2.8) : (shellTranscript.trimmed.isEmpty ? 18.0 : 12.0)
    if now.timeIntervalSince(lastBackgroundShellCapture) >= shellCaptureInterval {
      lastBackgroundShellCapture = now
      Task(priority: selectedSurface == .shell ? .userInitiated : .utility) { [weak self] in
        await self?.captureShellIfUseful()
      }
    }

    if activeCodexConversationIsEstablished,
      now.timeIntervalSince(lastBackgroundCodexCapture)
        >= (selectedSurface == .codex || isCodeWorkspaceOpen || !codexWorkingSessionIDs.isEmpty
          ? (isCodeWorkspaceOpen ? 6.0 : 1.4) : 4.0)
    {
      lastBackgroundCodexCapture = now
      Task(priority: .userInitiated) { [weak self] in
        await self?.captureCodexIfUseful()
      }
    }

    if activeClaudeConversationIsEstablished,
      now.timeIntervalSince(lastBackgroundClaudeCapture) >= 4.0
    {
      lastBackgroundClaudeCapture = now
      Task(priority: .userInitiated) { [weak self] in
        await self?.captureClaudeIfUseful()
      }
    }

    if codexPromptQueue.contains(where: { $0.status == .waitingForCodex }),
      now.timeIntervalSince(lastBackgroundCodexQueueStatus) >= 6.0
    {
      lastBackgroundCodexQueueStatus = now
      Task(priority: .utility) { [weak self] in
        await self?.refreshCodexPromptQueueStatuses()
      }
    }

    if now.timeIntervalSince(lastBackgroundPermissionRefresh) >= 90 {
      lastBackgroundPermissionRefresh = now
      Task(priority: .utility) { [weak self] in
        await self?.refreshRemotePermissionStateSilently()
      }
    }

    if now.timeIntervalSince(lastBackgroundPluginRefresh) >= 120 {
      lastBackgroundPluginRefresh = now
      Task(priority: .utility) { [weak self] in
        await self?.refreshCodexPluginStatusSilently()
      }
    }
  }

  private func warmRecentCodexSessionCaches(force: Bool = false) async {
    guard !isWarmingRecentCodexSessions else { return }
    let candidates = Array(
      sessions
        .filter { !$0.codexHistoryID.trimmed.isEmpty }
        .filter { codexSessionWarmScore($0) >= 500 }
        .sorted { first, second in
          let firstScore = codexSessionWarmScore(first)
          let secondScore = codexSessionWarmScore(second)
          if firstScore != secondScore {
            return firstScore > secondScore
          }
          return first.updatedAt > second.updatedAt
        }
        .prefix(force ? 4 : 3)
    )
    guard !candidates.isEmpty else { return }
    isWarmingRecentCodexSessions = true
    defer { isWarmingRecentCodexSessions = false }

    let batchSize = 1
    var start = 0
    while start < candidates.count {
      guard !Task.isCancelled else { return }
      let end = min(start + batchSize, candidates.count)
      let batch = Array(candidates[start..<end])
      await withTaskGroup(of: Void.self) { group in
        for session in batch {
          group.addTask { [weak self] in
            await self?.warmCodexSessionCache(session)
          }
        }
      }
      start = end
      await Task.yield()
    }
  }

  private func codexSessionWarmScore(_ session: SessionCard) -> Int {
    var score = 0
    if session.id == activeSessionID {
      score += 1_000
    }
    if codexWorkingSessionIDs.contains(session.id) {
      score += 800
    }
    if codexPromptQueue.contains(where: { $0.sessionID == session.id && $0.status != .delivered }) {
      score += 500
    }
    if !session.codexHistoryPath.trimmed.isEmpty {
      score += 120
    }
    let age = Date().timeIntervalSince(session.updatedAt)
    if age < 60 {
      score += 220
    } else if age < 10 * 60 {
      score += 140
    } else if age < 60 * 60 {
      score += 70
    }
    return score
  }

  private func warmCodexSessionCache(_ session: SessionCard) async {
    let record = CodexHistoryRecord(
      id: session.codexHistoryID,
      cwd: session.remoteDir,
      path: session.codexHistoryPath,
      mtime: Int(session.updatedAt.timeIntervalSince1970),
      title: session.codexHistoryTitle,
      host: session.codexHistoryHost
    )
    let result = await codexHistoryTranscriptBackgroundResult(for: record)
    guard result.exitCode == 0, !result.output.trimmed.isEmpty else { return }
    if activeSessionID == session.id {
      applyCodexTranscriptResult(result)
    } else {
      persistTranscript(.codex, value: result.output, sessionID: session.id)
    }
  }

  private func prewarmVisibleCodexArtifacts() async {
    guard !isPrewarmingVisibleCodexArtifacts, !activeCodexIsWorking,
      !isCodexArtifactPreviewLoading, !isCodexTranscriptAutoRefreshActive
    else { return }
    let artifacts = Array(codexArtifacts.suffix(48))
    guard !artifacts.isEmpty else { return }
    isPrewarmingVisibleCodexArtifacts = true
    defer { isPrewarmingVisibleCodexArtifacts = false }

    let batchSize = 4
    var start = 0
    while start < artifacts.count {
      guard !Task.isCancelled else { return }
      let end = min(start + batchSize, artifacts.count)
      let batch = Array(artifacts[start..<end])
      await withTaskGroup(of: Void.self) { group in
        for artifact in batch {
          group.addTask { [weak self] in
            guard let self else { return }
            guard await !self.activeCodexIsWorking,
              await !self.isCodexArtifactPreviewLoading,
              await !self.isCodexTranscriptAutoRefreshActive
            else {
              return
            }
            await self.prewarmCodexArtifact(artifact)
          }
        }
      }
      start = end
      await Task.yield()
    }
  }

  private func syncBundledRemoteHelperOnLaunch() async {
    guard settings.hasSSHTarget,
      let helperURL = bundledRemoteHelperURL(),
      FileManager.default.fileExists(atPath: helperURL.path)
    else { return }

    let target =
      settings.remoteScript.trimmed.isEmpty
      ? "~/.local/bin/a-cockpit-remote" : settings.remoteScript.trimmed
    let installTarget = remoteShellPath(target)
    let scpTarget = remoteScpPath(target)
    let targetDirectory = remoteDirectory(containing: installTarget)
    let script = """
      \(settings.sshShellCommand) \("mkdir -p \(targetDirectory.shellQuoted)".shellQuoted)
      \(settings.scpShellCommand) \(helperURL.path.shellQuoted) \(settings.remoteSpec(scpTarget).shellQuoted)
      \(settings.sshShellCommand) \("chmod 755 \(installTarget.shellQuoted)".shellQuoted)
      """
    let result = await client.shell(script, timeout: 120)
    if result.exitCode == 0 {
      statusText = "Remote helper synced · \(Date().shortStamp)"
    }
  }

  func refreshDashboard(showsActivity: Bool = true) async {
    let result = await runRemote("status", timeout: 30, showsActivity: showsActivity)
    dashboardStatusSnapshot = result.combined
  }

  func captureShell(updateActiveSession: Bool = false) async {
    let displayDirectory = await syncShellWorkingDirectory(updateActiveSession: updateActiveSession)
    let result = await runRemote("capture-shell-console", timeout: 30)
    applyShellCaptureResult(result, displayDirectory: displayDirectory ?? currentRemoteDir)
    if displayDirectory == nil {
      await syncShellWorkingDirectory(updateActiveSession: updateActiveSession)
    }
  }

  private func captureShellIfUseful() async {
    guard settings.hasSSHTarget else { return }
    let displayDirectory = await syncShellWorkingDirectory(updateActiveSession: false)
    let result = await runRemote(
      "capture-shell-console",
      timeout: 18,
      showsActivity: false
    )
    guard result.exitCode == 0 else { return }
    let changed = applyShellCaptureResult(
      result, displayDirectory: displayDirectory ?? currentRemoteDir)
    if changed || selectedSurface == .shell {
      _ = await syncShellWorkingDirectory(updateActiveSession: false)
    }
  }

  @discardableResult
  private func applyShellCaptureResult(_ result: CommandResult, displayDirectory: String? = nil)
    -> Bool
  {
    let nextTranscript = readableShellTranscript(
      result.combined,
      displayDirectory: displayDirectory ?? currentRemoteDir
    )
    let nextFingerprint =
      "\(result.exitCode)|\(nextTranscript.count)|\(nextTranscript.suffix(4096))"
    guard nextFingerprint != shellTranscriptFingerprint || shellTranscript != nextTranscript else {
      return false
    }
    shellTranscriptFingerprint = nextFingerprint
    shellTranscript = nextTranscript
    return true
  }

  private func readableShellTranscript(_ transcript: String, displayDirectory: String?) -> String {
    guard let displayDirectory, !transcript.isEmpty else { return transcript }
    let readableDirectory = shellReadableDirectory(displayDirectory)
    guard readableDirectory.contains("/") else { return transcript }
    var output = transcript
    for compactPath in compactShellPathVariants(for: readableDirectory) {
      guard compactPath.count < readableDirectory.count else { continue }
      output = output.replacingOccurrences(of: compactPath, with: readableDirectory)
    }
    return output
  }

  private func shellReadableDirectory(_ path: String) -> String {
    var readable = normalizedRemotePath(path)
    let home = normalizedRemotePath(settings.remoteHome)
    if home.hasPrefix("/"), readable == home {
      readable = "~"
    } else if home.hasPrefix("/"), readable.hasPrefix(home + "/") {
      readable = "~/" + String(readable.dropFirst(home.count + 1))
    } else if readable.hasPrefix("/Users/") {
      let parts = readable.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
      if parts.count >= 3 {
        readable = "~/" + parts.dropFirst(2).joined(separator: "/")
      }
    }
    return readable
  }

  private func compactShellPathVariants(for readablePath: String) -> Set<String> {
    var variants = Set<String>()

    let homeRelative: String
    if readablePath.hasPrefix("~/") {
      homeRelative = String(readablePath.dropFirst(2))
    } else {
      return variants
    }

    let parts = homeRelative.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    guard parts.count >= 3, let first = parts.first, let last = parts.last else { return variants }
    let middle = parts.dropFirst().dropLast()
    for firstWidth in 1...min(4, first.count) {
      var compactParts = ["~", String(first.prefix(firstWidth))]
      compactParts.append(contentsOf: middle.map { String($0.prefix(1)) })
      compactParts.append(last)
      variants.insert(compactParts.joined(separator: "/"))
    }
    return variants
  }

  func sendShell() async {
    let text = shellInput.trimmed
    shellCompletions = []
    let result: CommandResult
    if text.isEmpty {
      result = await runRemote("shell-commit-line", timeout: 60, bypassBackgroundQueue: true)
      shellTranscript = result.combined
    } else {
      shellInput = ""
      result = await runRemote("run-shell", input: text, timeout: 60, bypassBackgroundQueue: true)
      if result.exitCode != 0 {
        shellInput = text
        shellTranscript = readableShellTranscript(
          result.combined, displayDirectory: currentRemoteDir)
      }
    }
    Task { [weak self] in
      try? await Task.sleep(nanoseconds: 220_000_000)
      await self?.captureShell(updateActiveSession: true)
    }
  }

  func completeShell() async {
    shellCompletions = []
    await syncShellWorkingDirectory(updateActiveSession: false)
    let context = shellCompletionContext(for: shellInput)
    let key = shellCompletionCacheKey(for: context)
    let matches: [ShellCompletion]
    if let cached = shellCompletionCache[key] {
      matches = cached
    } else {
      let items = await shellCompletionItems(in: context.searchDirectory)
      matches = shellCompletionMatches(for: context, items: items)
      shellCompletionCache[key] = matches
    }

    if matches.count == 1, let only = matches.first {
      shellInput = only.value
    } else if !matches.isEmpty {
      shellCompletions = Array(matches)
    } else {
      statusText = "No shell completions · \(Date().shortStamp)"
    }
  }

  func prefetchShellCompletions(for input: String) async {
    guard settings.hasSSHTarget else { return }
    let context = shellCompletionContext(for: input)
    guard context.prefix.count >= 1 || !context.typedDirectory.isEmpty else { return }
    let key = shellCompletionCacheKey(for: context)
    guard shellCompletionCache[key] == nil else { return }
    let items = await shellCompletionItems(in: context.searchDirectory)
    let matches = shellCompletionMatches(for: context, items: items)
    if !matches.isEmpty {
      shellCompletionCache[key] = matches
    }
  }

  func useShellCompletion(_ completion: ShellCompletion) {
    shellInput = completion.value
    shellCompletions = []
  }

  func clearShell() async {
    shellInput = ""
    shellCompletions = []
    shellTranscript = ""
    let result = await runRemote("shell-clear-line", timeout: 30, bypassBackgroundQueue: true)
    shellTranscript = result.combined
  }

  func interruptShell() async {
    shellInput = ""
    shellCompletions = []
    let result = await runRemote("shell-interrupt", timeout: 30, bypassBackgroundQueue: true)
    shellTranscript = result.combined
    Task { [weak self] in
      try? await Task.sleep(nanoseconds: 180_000_000)
      await self?.captureShell()
    }
  }

  func exitShellCodex() async {
    shellInput = ""
    shellCompletions = []
    statusText = "Exiting Codex in shell · \(Date().shortStamp)"
    let result = await runRemote("shell-exit-codex", timeout: 30, bypassBackgroundQueue: true)
    if result.exitCode == 0 {
      shellTranscript = readableShellTranscript(result.combined, displayDirectory: currentRemoteDir)
    } else {
      await escapeShell()
      try? await Task.sleep(nanoseconds: 120_000_000)
      await interruptShell()
      try? await Task.sleep(nanoseconds: 120_000_000)
      await interruptShell()
    }
    statusText = "Exit Codex sent to shell · \(Date().shortStamp)"
    Task { [weak self] in
      try? await Task.sleep(nanoseconds: 220_000_000)
      await self?.captureShell()
    }
  }

  func escapeShell() async {
    await sendShellKey("esc")
  }

  func shellTmuxPrefix() async {
    await sendShellKey("C-b")
  }

  private func sendShellKey(_ key: String) async {
    shellInput = ""
    shellCompletions = []
    let result = await runRemote(
      "shell-key",
      args: [key],
      timeout: 30,
      bypassBackgroundQueue: true
    )
    shellTranscript = readableShellTranscript(result.combined, displayDirectory: currentRemoteDir)
    Task { [weak self] in
      try? await Task.sleep(nanoseconds: 160_000_000)
      await self?.captureShell()
    }
  }

  func changeShellDirectory(_ path: String) async {
    currentRemoteDir = normalizedRemotePath(path)
    updateActiveSessionDirectory(currentRemoteDir)
    clearRemoteSelection()
    shellCompletions = []
    let result = await runRemote(
      "shell-cd",
      input: currentRemoteDir + "\n",
      timeout: 30,
      bypassBackgroundQueue: true
    )
    shellTranscript = result.combined
    await syncShellWorkingDirectory(updateActiveSession: true)
  }

  func resetSessionDirectory(_ path: String) async {
    let normalized = normalizedRemotePath(path)
    guard !normalized.trimmed.isEmpty else { return }
    currentRemoteDir = normalized
    fileBrowserDir = normalized
    remoteOpenPath = normalized
    ensureConversationSession(defaultTool: .codex)
    updateActiveSessionDirectory(normalized)
    clearRemoteSelection()
    await loadFileBrowserDirectory(normalized, force: false, showsActivity: false)
    await changeShellDirectory(normalized)
    await restartCodex(in: normalized)
    statusText = "Session dir set · \(Date().shortStamp)"
  }

  func captureCodex() async {
    guard !isCapturingCodex else { return }
    isCapturingCodex = true
    codexTranscriptCheckedAt = Date()
    defer { isCapturingCodex = false }
    guard let session = activeSession else {
      setCodexTranscript("", force: true)
      clearCodexDerivedState()
      return
    }
    if session.codexState == .running {
      let result = await runRemote("capture-codex", timeout: 30, showsActivity: false)
      if result.exitCode == 0, !result.combined.trimmed.isEmpty {
        applyCodexTranscriptResult(result)
        return
      }
    }
    if let record = activeCodexHistoryRecord() {
      let historyResult = await codexHistoryTranscriptResult(for: record)
      if historyResult.exitCode == 0, !historyResult.output.trimmed.isEmpty {
        updateCodexTranscriptWindowState(from: historyResult.output, record: record)
        applyCodexTranscriptResult(historyResult)
        return
      }
    }
    statusText = "Codex ready · \(Date().shortStamp)"
  }

  func captureCodexIfUseful(force: Bool = false) async {
    guard activeCodexConversationIsEstablished else { return }
    if isCodexArtifactPreviewLoading, !force {
      return
    }
    let now = Date()
    let interval = codexCaptureMinimumInterval()
    guard force || now.timeIntervalSince(lastCodexUsefulCapture) >= interval else { return }
    lastCodexUsefulCapture = now
    await captureCodex()
  }

  private func codexCaptureMinimumInterval() -> TimeInterval {
    let activeWorking =
      activeSessionID.map { codexWorkingSessionIDs.contains($0) } ?? false
    if selectedSurface == .codex {
      return activeWorking ? 0.40 : 0.80
    }
    if isCodeWorkspaceOpen {
      return activeWorking ? 0.55 : 1.20
    }
    if activeWorking {
      return 0.80
    }
    if !codexWorkingSessionIDs.isEmpty {
      return 1.20
    }
    return 1.60
  }

  func refreshCodexHistory(
    force: Bool = false,
    showsActivity: Bool? = nil,
    includeAllDirectories: Bool = false
  ) async {
    if !force, let lastCodexHistoryRefresh,
      lastCodexHistoryRefreshDirectory == normalizedRemotePath(currentRemoteDir),
      !includeAllDirectories,
      Date().timeIntervalSince(lastCodexHistoryRefresh) < 8
    {
      return
    }
    if !includeAllDirectories {
      lastCodexHistoryRefresh = Date()
      lastCodexHistoryRefreshDirectory = normalizedRemotePath(currentRemoteDir)
    }
    var remoteEnvironment = [
      "A_COCKPIT_CODEX_HISTORY_HOST": "remote"
    ]
    if force {
      remoteEnvironment["A_COCKPIT_CODEX_HISTORY_FORCE"] = "1"
    }
    if includeAllDirectories {
      remoteEnvironment["A_COCKPIT_CODEX_HISTORY_FORCE"] = "1"
      remoteEnvironment["A_COCKPIT_CODEX_HISTORY_SCOPE"] = "all"
    }
    let remoteResult = await runRemote(
      "codex-history-json", input: currentRemoteDir + "\n", timeout: 30,
      showsActivity: showsActivity ?? false,
      environmentOverride: remoteEnvironment)
    let prunedLocalSessions = pruneLocalCodexHistorySessions(save: false)
    let records = decodedCodexHistoryRecords(from: remoteResult, host: "remote").filter {
      $0.normalizedHost == "remote"
    }
    let visibleRecords = mergedCodexHistoryRecords(records).filter {
      !isCodexHistoryTombstoned($0.id) && !$0.isSubagent
    }
    guard !visibleRecords.isEmpty || remoteResult.exitCode == 0 else {
      if prunedLocalSessions {
        saveSessions()
      }
      return
    }
    codexHistoryRecords = visibleRecords
    reconcileExistingCodexHistorySessions(with: visibleRecords)
    if prunedLocalSessions {
      saveSessions()
    }
    var activeRecord: CodexHistoryRecord?
    let activeHistoryHost = activeSession?.codexHistoryHost.trimmed.lowercased().nilIfEmpty ?? "remote"
    if let activeID = activeSession?.codexHistoryID.trimmed, !activeID.isEmpty,
      let record = visibleRecords.first(where: {
        $0.id == activeID && $0.normalizedHost == activeHistoryHost
      }) ?? visibleRecords.first(where: { $0.id == activeID })
    {
      updateActiveCodexHistory(
        id: record.id,
        path: record.path,
        title: titleForCodexRecord(record),
        host: record.normalizedHost,
        updatedAt: record.mtime > 0
          ? Date(timeIntervalSince1970: TimeInterval(record.mtime))
          : nil
      )
      activeRecord = record
    }
    if selectedSurface == .codex, let activeRecord,
      shouldReplaceWithCodexHistoryTranscript(activeRecord)
    {
      await loadCodexHistoryTranscript(activeRecord)
    }
  }

  private func reconcileExistingCodexHistorySessions(with records: [CodexHistoryRecord]) {
    guard !records.isEmpty else { return }
    var changed = false
    for record in records {
      let historyID = record.id.trimmed
      guard !historyID.isEmpty else { continue }
      let title = titleForCodexRecord(record)
      let remoteDir = normalizedRemotePath(
        record.cwd.trimmed.isEmpty ? currentRemoteDir : record.cwd)
      let recordHost = record.normalizedHost
      if let index = sessions.firstIndex(where: {
        $0.codexHistoryID == historyID
          && ($0.codexHistoryHost.trimmed.isEmpty ? "remote" : $0.codexHistoryHost.trimmed.lowercased())
            == recordHost
      }) ?? sessions.firstIndex(where: { $0.codexHistoryID == historyID }) {
        if sessions[index].remoteDir != remoteDir {
          sessions[index].remoteDir = remoteDir
          changed = true
        }
        if sessions[index].codexHistoryHost != recordHost {
          sessions[index].codexHistoryHost = recordHost
          changed = true
        }
        if sessions[index].codexHistoryPath != record.path {
          sessions[index].codexHistoryPath = record.path
          changed = true
        }
        if sessions[index].codexHistoryTitle != title {
          sessions[index].codexHistoryTitle = title
          if sessions[index].nameSource == .codexApp {
            sessions[index].name = stableCodexSessionName(
              id: sessions[index].codexHistoryID,
              cwd: sessions[index].remoteDir
            )
          }
          changed = true
        }
        if sessions[index].codexState != .linked {
          sessions[index].codexState = .linked
          changed = true
        }
        if record.mtime > 0 {
          let recordDate = Date(timeIntervalSince1970: TimeInterval(record.mtime))
          if abs(sessions[index].updatedAt.timeIntervalSince(recordDate)) > 0.5 {
            sessions[index].updatedAt = recordDate
            changed = true
          }
        }
        sessions[index].enableTool(.codex)
      }
    }
    changed = collapseDuplicateCodexHistorySessions() || changed
    changed = pruneNoisyImportedCodexSessions(save: false) || changed
    if changed {
      sortSessionsByRecent()
      if activeSessionID == nil, let first = sessions.first {
        activeSessionID = first.id
        currentRemoteDir = first.remoteDir
        loadCachedTranscriptsForActiveSession()
      }
      saveSessions()
    }
  }

  @discardableResult
  private func collapseDuplicateCodexHistorySessions() -> Bool {
    let groups = Dictionary(grouping: sessions) { session in
      session.codexHistoryID.trimmed
    }
    let duplicateGroups = groups.filter { historyID, group in
      !historyID.isEmpty && group.count > 1
    }
    guard !duplicateGroups.isEmpty else { return false }

    var keepIDs = Set<UUID>()
    var removeIDs = Set<UUID>()
    var mergedToolsByKeepID: [UUID: Set<AISessionTool>] = [:]
    var activeReplacement: UUID?

    func priority(_ session: SessionCard) -> (Int, Date) {
      let sourceScore: Int
      switch session.nameSource {
      case .user:
        sourceScore = 3
      case .generated:
        sourceScore = 2
      case .codexApp:
        sourceScore = 1
      }
      return (sourceScore, session.updatedAt)
    }

    for (_, group) in duplicateGroups {
      let sorted = group.sorted { first, second in
        let firstPriority = priority(first)
        let secondPriority = priority(second)
        if firstPriority.0 != secondPriority.0 {
          return firstPriority.0 > secondPriority.0
        }
        return firstPriority.1 > secondPriority.1
      }
      guard let keep = sorted.first else { continue }
      keepIDs.insert(keep.id)
      var mergedTools = Set(keep.enabledTools)
      for removed in sorted.dropFirst() {
        removeIDs.insert(removed.id)
        mergedTools.formUnion(removed.enabledTools)
        if activeSessionID == removed.id {
          activeReplacement = keep.id
        }
      }
      mergedTools.insert(.codex)
      mergedToolsByKeepID[keep.id] = mergedTools
    }

    guard !removeIDs.isEmpty else { return false }
    for index in sessions.indices {
      guard keepIDs.contains(sessions[index].id),
        let mergedTools = mergedToolsByKeepID[sessions[index].id]
      else { continue }
      sessions[index].enabledTools = Array(mergedTools).sorted { $0.rawValue < $1.rawValue }
      sessions[index].enableTool(.codex)
    }
    sessions.removeAll { removeIDs.contains($0.id) }
    for removedID in removeIDs {
      try? FileManager.default.removeItem(at: sessionDirectory(for: removedID.uuidString))
    }
    codexWorkingSessionIDs.subtract(removeIDs)
    claudeWorkingSessionIDs.subtract(removeIDs)
    workingSessionIDs.subtract(removeIDs)
    if let activeReplacement {
      activeSessionID = activeReplacement
      if let activeSession {
        currentRemoteDir = activeSession.remoteDir
        loadCachedTranscriptsForActiveSession()
      }
    }
    saveWorkingSessionIDs()
    return true
  }

  @discardableResult
  private func pruneLocalCodexHistorySessions(save shouldSave: Bool) -> Bool {
    var removeIDs = Set<UUID>()
    for session in sessions {
      let historyID = session.codexHistoryID.trimmed
      let host = session.codexHistoryHost.trimmed.lowercased()
      guard !historyID.isEmpty, host == "local" else { continue }
      removeIDs.insert(session.id)
    }
    guard !removeIDs.isEmpty else { return false }

    sessions.removeAll { removeIDs.contains($0.id) }
    codexPromptQueue.removeAll { item in
      guard let sessionID = item.sessionID else { return false }
      return removeIDs.contains(sessionID)
    }
    for removedID in removeIDs {
      try? FileManager.default.removeItem(at: sessionDirectory(for: removedID.uuidString))
    }
    codexWorkingSessionIDs.subtract(removeIDs)
    claudeWorkingSessionIDs.subtract(removeIDs)
    workingSessionIDs.subtract(removeIDs)
    if let activeSessionID, removeIDs.contains(activeSessionID) {
      self.activeSessionID = sessions.first?.id
      if let activeSession {
        currentRemoteDir = activeSession.remoteDir
        loadCachedTranscriptsForActiveSession()
      }
    }
    saveWorkingSessionIDs()
    if shouldSave {
      saveSessions()
    }
    return true
  }

  @discardableResult
  private func pruneNoisyImportedCodexSessions(save shouldSave: Bool) -> Bool {
    let userDirectories = Set(
      sessions
        .filter { $0.nameSource == .user }
        .map { normalizedRemotePath($0.remoteDir) }
    )
    guard !userDirectories.isEmpty else { return false }
    var removeIDs = Set<UUID>()
    var removedHistoryIDs = Set<String>()
    for session in sessions {
      guard session.nameSource == .codexApp else { continue }
      let sameUserDirectory = userDirectories.contains(normalizedRemotePath(session.remoteDir))
      guard (sameUserDirectory && isGenericImportedCodexSession(session))
        || isSubagentLikeImportedCodexSession(session)
      else { continue }
      removeIDs.insert(session.id)
      let historyID = session.codexHistoryID.trimmed
      if !historyID.isEmpty {
        removedHistoryIDs.insert(historyID)
      }
    }
    guard !removeIDs.isEmpty else { return false }
    for historyID in removedHistoryIDs {
      tombstoneCodexHistoryID(historyID)
    }
    sessions.removeAll { removeIDs.contains($0.id) }
    codexPromptQueue.removeAll { item in
      guard let sessionID = item.sessionID else { return false }
      return removeIDs.contains(sessionID)
    }
    for removedID in removeIDs {
      try? FileManager.default.removeItem(at: sessionDirectory(for: removedID.uuidString))
    }
    codexWorkingSessionIDs.subtract(removeIDs)
    claudeWorkingSessionIDs.subtract(removeIDs)
    workingSessionIDs.subtract(removeIDs)
    if let activeSessionID, removeIDs.contains(activeSessionID) {
      self.activeSessionID = sessions.first?.id
      if let activeSession {
        currentRemoteDir = activeSession.remoteDir
        loadCachedTranscriptsForActiveSession()
      }
    }
    saveWorkingSessionIDs()
    if shouldSave {
      saveSessions()
    }
    return true
  }

  private func isGenericImportedCodexSession(_ session: SessionCard) -> Bool {
    let candidates = [
      session.name.trimmed,
      session.codexHistoryTitle.trimmed,
    ].filter { !$0.isEmpty }
    guard !candidates.isEmpty else { return true }
    let historyPrefix = String(session.codexHistoryID.trimmed.prefix(8)).lowercased()
    return candidates.allSatisfy { title in
      let lower = title.lowercased()
      if lower == "codex session" {
        return true
      }
      if !historyPrefix.isEmpty, lower.hasSuffix(" \(historyPrefix)") {
        return true
      }
      return lower.range(
        of: #"^[a-z0-9_. -]+ [0-9a-f]{8}$"#,
        options: .regularExpression
      ) != nil
    }
  }

  private func isSubagentLikeImportedCodexSession(_ session: SessionCard) -> Bool {
    let candidates = [
      session.name.trimmed,
      session.codexHistoryTitle.trimmed,
    ]
    return candidates.contains { title in
      let lower = title.lowercased()
      if lower.contains("basename:") || lower.contains("smoke-test marker")
        || lower.contains("[@computer]")
      {
        return true
      }
      return title.range(
        of: #"^Stage\s+\d+\b.*\brole:"#,
        options: [.regularExpression, .caseInsensitive]
      ) != nil
    }
  }

  func importCodexHistorySessionsForCurrentDirectory() async {
    await syncCodexAppSessions(allowNewImports: true, onlyCurrentDirectory: true)
  }

  func importAllCodexHistorySessions() async {
    await syncCodexAppSessions(
      allowNewImports: true,
      onlyCurrentDirectory: false,
      includeAllDirectories: true
    )
  }

  func syncCodexAppSessions(
    showsActivity: Bool = true,
    force: Bool = true,
    refreshWorkingAfter: Bool = true,
    allowNewImports: Bool = false,
    onlyCurrentDirectory: Bool = false,
    includeAllDirectories: Bool = false
  ) async {
    await refreshCodexHistory(
      force: force,
      showsActivity: showsActivity,
      includeAllDirectories: includeAllDirectories
    )
    var existingIDs = Set(sessions.map { $0.codexHistoryID.trimmed }.filter { !$0.isEmpty })
    var changed = false
    if allowNewImports {
      let currentDir = normalizedRemotePath(currentRemoteDir)
      for record in codexHistoryRecords {
        let historyID = record.id.trimmed
        guard !record.isSubagent, !historyID.isEmpty, !existingIDs.contains(historyID),
          !isCodexHistoryTombstoned(historyID)
        else { continue }
        let remoteDir = normalizedRemotePath(
          record.cwd.trimmed.isEmpty ? currentRemoteDir : record.cwd)
        if onlyCurrentDirectory, remoteDir != currentDir {
          continue
        }
        let title = titleForCodexRecord(record)
        let sessionName = stableCodexSessionName(id: historyID, cwd: remoteDir)
        var session = SessionCard(name: sessionName, remoteDir: remoteDir, tool: .codex)
        session.codexHistoryID = historyID
        session.codexHistoryPath = record.path
        session.codexHistoryTitle = title
        session.codexHistoryHost = record.normalizedHost
        session.codexState = .linked
        session.nameSource = .codexApp
        if record.mtime > 0 {
          session.updatedAt = Date(timeIntervalSince1970: TimeInterval(record.mtime))
        }
        sessions.append(session)
        existingIDs.insert(historyID)
        changed = true
      }
    }
    changed = pruneNoisyImportedCodexSessions(save: false) || changed
    sanitizeImportedCodexSessionNames(save: true)
    changed = collapseDuplicateCodexHistorySessions() || changed
    changed = pruneNoisyImportedCodexSessions(save: false) || changed
    if changed {
      sortSessionsByRecent()
      if activeSessionID == nil, let first = sessions.first {
        activeSessionID = first.id
        currentRemoteDir = first.remoteDir
        loadCachedTranscriptsForActiveSession()
      }
      saveSessions()
    }
    if refreshWorkingAfter {
      await refreshCodexWorkingStates()
    }
  }

  func startCodexWorkingStateMonitor() {
    codexTranscriptAutoRefreshDeadline = Date().addingTimeInterval(10 * 60)
    codexTranscriptAutoRefreshGeneration += 1
  }

  func refreshCodexWorkingStates(force: Bool = false) async {
    guard !isRefreshingCodexWorkingStates else { return }
    let now = Date()
    let minimumInterval = codexWorkingStateMinimumInterval()
    guard force || now.timeIntervalSince(lastCodexWorkingStateRefresh) >= minimumInterval else {
      return
    }
    lastCodexWorkingStateRefresh = now
    isRefreshingCodexWorkingStates = true
    defer { isRefreshingCodexWorkingStates = false }
    let result = await runRemote("codex-history-status-json", timeout: 20, showsActivity: false)
    guard result.exitCode == 0,
      let data = result.output.data(using: .utf8),
      let decoded = try? JSONDecoder().decode([CodexHistoryRunStatus].self, from: data)
    else { return }
    let refreshDate = Date()
    let activeWasWorking = activeSessionID.map { codexWorkingSessionIDs.contains($0) } ?? false
    var activeHistoryIDs = Set<String>()
    var statusByHistoryID: [String: CodexHistoryRunStatus] = [:]
    for item in decoded {
      let historyID = item.id.trimmed
      guard !historyID.isEmpty else { continue }
      statusByHistoryID[historyID] = item
      if item.working {
        activeHistoryIDs.insert(historyID)
      }
    }
    let workingHistoryIDs = activeHistoryIDs
    let existingSessionIDs = Set(sessions.map(\.id))
    let locallyHeldWorkingSessionIDs = Set(
      codexLocalTurnHoldUntil.compactMap { sessionID, holdUntil in
        holdUntil > refreshDate && existingSessionIDs.contains(sessionID) ? sessionID : nil
      }
    )
    var next = Set<UUID>()
    var explicitlyIdleSessionIDs = Set<UUID>()
    var sessionsChanged = false
    for index in sessions.indices {
      let sessionID = sessions[index].id
      let historyID = sessions[index].codexHistoryID.trimmed
      if let item = statusByHistoryID[historyID],
        let mtime = item.mtime,
        mtime > 0
      {
        let statusDate = Date(timeIntervalSince1970: TimeInterval(mtime))
        if statusDate > sessions[index].updatedAt.addingTimeInterval(0.5) {
          sessions[index].updatedAt = statusDate
          sessionsChanged = true
        }
      }
      if !historyID.isEmpty, workingHistoryIDs.contains(historyID) {
        next.insert(sessionID)
        codexWorkingHoldUntil[sessionID] =
          refreshDate.addingTimeInterval(codexWorkingHoldSeconds)
        continue
      }
      if !historyID.isEmpty, let item = statusByHistoryID[historyID], !item.working {
        explicitlyIdleSessionIDs.insert(sessionID)
        codexWorkingHoldUntil.removeValue(forKey: sessionID)
        codexLocalTurnHoldUntil.removeValue(forKey: sessionID)
      } else if locallyHeldWorkingSessionIDs.contains(sessionID) {
        next.insert(sessionID)
        continue
      }
      let sessionName = sessions[index].codexSession.trimmed
      if !sessionName.isEmpty {
        let matchingTmuxStatuses = decoded.filter { item in
          item.tmux == true && item.session_name?.trimmed == sessionName
        }
        if matchingTmuxStatuses.contains(where: { item in
          item.working
        }) {
          next.insert(sessionID)
          codexWorkingHoldUntil[sessionID] =
            refreshDate.addingTimeInterval(codexWorkingHoldSeconds)
          continue
        }
        if !matchingTmuxStatuses.isEmpty {
          explicitlyIdleSessionIDs.insert(sessionID)
          codexWorkingHoldUntil.removeValue(forKey: sessionID)
        }
      }

    }
    next.formUnion(
      codexWorkingHoldUntil.compactMap { sessionID, holdUntil in
        holdUntil > refreshDate && existingSessionIDs.contains(sessionID)
          && !explicitlyIdleSessionIDs.contains(sessionID) ? sessionID : nil
      }
    )
    codexWorkingHoldUntil = codexWorkingHoldUntil.filter { sessionID, holdUntil in
      holdUntil > refreshDate && existingSessionIDs.contains(sessionID)
        && !explicitlyIdleSessionIDs.contains(sessionID)
    }
    codexLocalTurnHoldUntil = codexLocalTurnHoldUntil.filter { sessionID, holdUntil in
      holdUntil > refreshDate && existingSessionIDs.contains(sessionID)
    }
    codexWorkingStartedAtBySession = codexWorkingStartedAtBySession.filter { sessionID, _ in
      next.contains(sessionID)
    }
    if sessionsChanged {
      saveSessions()
    }
    if next != codexWorkingSessionIDs {
      codexWorkingSessionIDs = next
      syncCombinedWorkingSessions()
      saveWorkingSessionIDs()
    }
    let activeIsNowWorking = activeSessionID.map { next.contains($0) } ?? false
    if activeWasWorking, !activeIsNowWorking {
      await refreshOpenedRemoteFileFromAIfSafe()
    }
    let shouldDrainQueue = codexPromptQueue.contains { item in
      guard item.status == .queued else { return false }
      if item.kind == .steer { return true }
      guard let sessionID = item.sessionID else { return true }
      return !next.contains(sessionID)
    }
    if shouldDrainQueue {
      processCodexPromptQueue()
    }
  }

  private func codexWorkingStateMinimumInterval() -> TimeInterval {
    if selectedSurface == .codex {
      return 0.70
    }
    if !codexWorkingSessionIDs.isEmpty || !claudeWorkingSessionIDs.isEmpty {
      return 1.0
    }
    return 1.5
  }

  @discardableResult
  private func ensureCodexSessionDirectory() async -> CommandResult {
    let historyID = activeSession?.codexHistoryID.trimmed ?? ""
    let action = historyID.isEmpty ? "ensure-codex-dir" : "resume-codex-session-dir"
    let args =
      historyID.isEmpty
      ? [codexModel, codexReasoningEffort]
      : [historyID, codexModel, codexReasoningEffort]
    let result = await runRemote(
      action,
      args: args,
      input: currentRemoteDir + "\n",
      timeout: 45
    )
    if result.exitCode == 65, result.combined.lowercased().contains("is working") {
      return CommandResult(exitCode: 0, output: result.output, error: result.error)
    }
    if result.exitCode != 0 {
      statusText = "Codex dir blocked · \(Date().shortStamp)"
    }
    return result
  }

  private func sendCodexPayloadWithRetry(
    action: String,
    prompt: String,
    attempts: Int = 3
  ) async -> CommandResult {
    var lastResult = CommandResult(exitCode: 1, output: "", error: "Codex send was not attempted.")
    let maxAttempts = max(1, attempts)
    for attempt in 1...maxAttempts {
      lastResult = await runRemote(
        action,
        args: [codexModel, codexReasoningEffort],
        input: prompt + "\n",
        timeout: 75,
        showsActivity: false)
      if lastResult.exitCode == 0 {
        return lastResult
      }
      let lower = lastResult.combined.lowercased()
      if lower.contains("interactive choice")
        || lower.contains("slash commands cannot be queued")
        || lower.contains("pick an option")
      {
        return lastResult
      }
      if attempt < maxAttempts {
        let delay = UInt64(350_000_000 * attempt)
        try? await Task.sleep(nanoseconds: delay)
      }
    }
    return lastResult
  }

  private func enqueueCodexPayloadOnA(
    kind: CodexPromptQueueKind,
    prompt: String,
    environment: [String: String]? = nil,
    forceNew: Bool = false,
    excludeHistoryIDs: [String] = []
  ) async -> CommandResult {
    var mergedEnvironment = environment ?? [:]
    if forceNew {
      mergedEnvironment["A_COCKPIT_CODEX_FORCE_NEW"] = "1"
    }
    if !excludeHistoryIDs.isEmpty {
      mergedEnvironment["A_COCKPIT_CODEX_EXCLUDE_HISTORY_IDS"] =
        excludeHistoryIDs.sorted().joined(separator: ",")
    }
    return await runRemote(
      kind == .steer ? "codex-queue-enqueue-steer" : "codex-queue-enqueue",
      args: [codexModel, codexReasoningEffort],
      input: prompt + "\n",
      timeout: 75,
      showsActivity: false,
      bypassBackgroundQueue: true,
      environmentOverride: mergedEnvironment.isEmpty ? nil : mergedEnvironment
    )
  }

  private func enqueueCodexPayloadBatchOnA(
    payload: String,
    environment: [String: String]? = nil
  ) async -> CommandResult {
    await runRemote(
      "codex-queue-enqueue-batch",
      args: [codexModel, codexReasoningEffort],
      input: payload,
      timeout: 90,
      showsActivity: false,
      bypassBackgroundQueue: true,
      environmentOverride: environment
    )
  }

  private func codexAQueueReceipt(from result: CommandResult) -> String {
    let lines = result.output
      .split(whereSeparator: \.isNewline)
      .map { String($0).trimmed }
      .filter { !$0.isEmpty }
    let queueID = lines.first { $0.hasPrefix("a_queue_id:") }?
      .replacingOccurrences(of: "a_queue_id:", with: "")
      .trimmed
    if let queueID, !queueID.isEmpty {
      return "A queue \(queueID)"
    }
    if lines.contains(where: { $0.contains("queued_on_a") }) {
      return "A queue received"
    }
    return "A queue accepted"
  }

  private func codexAQueueID(from result: CommandResult) -> String? {
    result.output
      .split(whereSeparator: \.isNewline)
      .map { String($0).trimmed }
      .first { $0.hasPrefix("a_queue_id:") }?
      .replacingOccurrences(of: "a_queue_id:", with: "")
      .trimmed
  }

  private func codexAQueueBatchIDs(from result: CommandResult) -> [String: String] {
    var output: [String: String] = [:]
    for line in result.output.split(whereSeparator: \.isNewline).map({ String($0).trimmed }) {
      guard line.hasPrefix("a_queue_id:") else { continue }
      let parts = line.split(separator: ":", maxSplits: 2).map(String.init)
      if parts.count == 3 {
        output[parts[1]] = parts[2]
      }
    }
    return output
  }

  @discardableResult
  func sendCodex(steer: Bool, displayText: String? = nil) async -> Bool {
    let text = codexInput.trimmed
    guard !text.isEmpty || !codexAttachments.isEmpty else { return false }
    if !isValidCodexModelName(codexModel) {
      codexModel = "gpt-5.5"
    }
    ensureConversationSession(defaultTool: .codex)
    if steer, !activeCodexCanSteer {
      statusText = "Send first, then steer the running or A-queued task · \(Date().shortStamp)"
      return false
    }
    enableToolForActiveSession(.codex, touch: true)
    let item = addCodexQueueItem(
      kind: steer ? .steer : .send,
      text: text,
      displayText: displayText
    )
    if steer {
      appendCodexLocalTurnBlock(
        codexQueueBlock(for: visibleQueueItem(item), includeStatus: false),
        preserveThroughCapture: true
      )
    }
    codexInput = ""
    codexAttachments.removeAll()
    statusText =
      steer
      ? "Queueing steer on A · \(Date().shortStamp)"
      : "Queueing prompt on A · \(Date().shortStamp)"
    startCodexTranscriptAutoRefresh()
    processCodexPromptQueue()
    return true
  }

  func enqueueCodexResearchPreset(
    _ preset: CodexResearchPreset,
    seedPrompt: String = "",
    displayPrompt: String? = nil,
    attachments: [PromptAttachment]? = nil,
    loopCount requestedLoopCount: Int = CodexResearchPreset.defaultLoopCount
  ) async -> Bool {
    if codexPluginLog.trimmed.isEmpty {
      await checkCodexPlugins()
    }
    if !isValidCodexModelName(codexModel) {
      codexModel = "gpt-5.5"
    }
    codexReasoningEffort = "xhigh"
    ensureConversationSession(defaultTool: .codex)
    enableToolForActiveSession(.codex, touch: true)

    let sessionName = activeSession?.name.trimmed.isEmpty == false ? activeSession!.name : "Active session"
    let sessionDir =
      activeSession?.remoteDir.trimmed.isEmpty == false ? activeSession!.remoteDir : currentRemoteDir
    let loopCount = CodexResearchPreset.clampedLoopCount(requestedLoopCount)
    let researchGroupID =
      "\(DateFormatter.attachmentStamp.string(from: Date()))-\(String(UUID().uuidString.prefix(6)).lowercased())"
    let prompts = preset.prompts(
      sessionName: sessionName,
      sessionDir: sessionDir,
      pluginContext: codexPluginContextForResearch(),
      seedPrompt: seedPrompt,
      loopCount: loopCount,
      groupID: researchGroupID
    )
    guard !prompts.isEmpty else { return false }

    let researchAttachments = attachments ?? codexAttachments
    let promptCount = prompts.count
    let visibleSeed = (displayPrompt ?? seedPrompt).trimmed
    let seedSummary =
      visibleSeed.isEmpty
      ? ""
      : " · \(String(visibleSeed.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).prefix(42)))"
    for (index, prompt) in prompts.enumerated() {
      let roleLabel = preset.queueRoleLabel(index: index, total: promptCount)
      let compactDisplay =
        "\(preset.title) · \(roleLabel) · \(index + 1)/\(promptCount)"
        + (index == 0 ? seedSummary : "")
      _ = addCodexQueueItem(
        kind: .send,
        text: prompt,
        attachments: index == 0 ? researchAttachments : [],
        displayText: compactDisplay,
        researchGroupID: researchGroupID,
        researchRole: roleLabel
      )
    }
    codexInput = ""
    codexAttachments.removeAll()
    statusText = "\(preset.title) \(promptCount)x Professor Lab queued · \(Date().shortStamp)"
    startCodexTranscriptAutoRefresh()
    scheduleCodexTranscriptAnalysis(force: true)
    processCodexPromptQueue()
    return true
  }

  private func drainCodexPromptQueue() async {
    defer { isProcessingCodexPromptQueue = false }
    while true {
      let batch = nextCodexQueueBatchToDeliver()
      guard !batch.isEmpty else { break }
      await deliverCodexQueueBatch(batch)
      try? await Task.sleep(nanoseconds: 90_000_000)
    }
  }

  private func nextCodexQueueBatchToDeliver(maxCount: Int = 24) -> [CodexPromptQueueItem] {
    let queued = codexPromptQueue
      .filter { item in
        item.status == .queued
      }
    let sorted = queued.sorted(by: codexQueueDeliveryPrecedes)
    guard let first = sorted.first else { return [] }
    return Array(
      queued
        .filter { $0.sessionID == first.sessionID }
        .sorted(by: codexQueueDeliveryPrecedes)
        .prefix(maxCount)
    )
  }

  private func codexQueueDeliveryPrecedes(
    _ first: CodexPromptQueueItem,
    _ second: CodexPromptQueueItem
  ) -> Bool {
    if first.kind != second.kind {
      return first.kind == .steer
    }
    return first.createdAt < second.createdAt
  }

  private func deliverCodexQueueBatch(_ batch: [CodexPromptQueueItem]) async {
    guard let first = batch.first else { return }
    for item in batch {
      updateCodexQueueItem(item.id, status: .sending)
    }
    startCodexTranscriptAutoRefresh()
    let knownHistoryIDs = Set(codexHistoryRecords.map { $0.id.trimmed }.filter { !$0.isEmpty })
    let sentAt = Date()
    guard let targetSession = sessionSnapshot(for: first.sessionID) else {
      for item in batch {
        updateCodexQueueItem(item.id, status: .failed, error: "Session no longer exists.")
      }
      statusText = "Codex queue session missing · \(Date().shortStamp)"
      return
    }
    let targetDir = normalizedRemotePath(
      targetSession.remoteDir.trimmed.isEmpty ? currentRemoteDir : targetSession.remoteDir)
    let environment = remoteEnvironment(for: targetSession, directory: targetDir)
    var jobs: [CodexAQueueBatchJob] = []
    var assignedFreshStart = false
    let sortedKnownHistoryIDs = Array(knownHistoryIDs).sorted()
    for item in batch {
      guard
        let prompt = await promptWithUploadedCodexAttachments(
          base: item.text,
          attachments: item.attachments,
          session: targetSession,
          directory: targetDir,
          environment: environment
        )
      else {
        updateCodexQueueItem(item.id, status: .failed, error: "Attachment upload failed.")
        continue
      }
      let order = String(format: "%013.0f", item.createdAt.timeIntervalSince1970 * 1000)
      let startsFreshHistory =
        targetSession.codexHistoryID.trimmed.isEmpty && item.kind == .send && !assignedFreshStart
      if startsFreshHistory {
        assignedFreshStart = true
      }
      jobs.append(
        CodexAQueueBatchJob(
          clientID: item.id.uuidString,
          kind: item.kind.rawValue,
          prompt: prompt,
          order: order,
          historyID: targetSession.codexHistoryID.trimmed,
          directory: targetDir,
          forceNew: startsFreshHistory,
          excludeHistoryIDs: startsFreshHistory ? sortedKnownHistoryIDs : []
        )
      )
    }
    guard !jobs.isEmpty else {
      statusText = "Attachment upload failed · \(Date().shortStamp)"
      return
    }
    let request = CodexAQueueBatchRequest(jobs: jobs)
    guard let data = try? JSONEncoder().encode(request),
      let payload = String(data: data, encoding: .utf8)
    else {
      for item in batch where jobs.contains(where: { $0.clientID == item.id.uuidString }) {
        updateCodexQueueItem(item.id, status: .failed, error: "A queue batch encode failed.")
      }
      return
    }
    let result = await enqueueCodexPayloadBatchOnA(payload: payload, environment: environment)
    if result.exitCode != 0 {
      for item in batch where jobs.contains(where: { $0.clientID == item.id.uuidString }) {
        updateCodexQueueItem(
          item.id,
          status: .failed,
          error: "A queue upload failed. The item stays here.")
      }
      applyCodexTranscriptResult(result)
      return
    }
    let remoteIDs = codexAQueueBatchIDs(from: result)
    startCodexTranscriptAutoRefresh()
    statusText = "Codex batch queued on A · \(Date().shortStamp)"
    for item in batch where jobs.contains(where: { $0.clientID == item.id.uuidString }) {
      let remoteQueueID = remoteIDs[item.id.uuidString]
      updateCodexQueueItem(
        item.id,
        status: .waitingForCodex,
        error: remoteQueueID.map { "A queue \($0)" } ?? codexAQueueReceipt(from: result),
        remoteQueueID: remoteQueueID
      )
      monitorCodexQueueItemDelivery(item.id)
    }
    Task { [weak self] in
      try? await Task.sleep(nanoseconds: 1_200_000_000)
      await self?.linkNewestCodexHistory(
        for: targetSession.id,
        knownHistoryIDs: knownHistoryIDs,
        sentAt: sentAt,
        targetDir: targetDir
      )
      if self?.activeSessionID == targetSession.id {
        await self?.captureCodexIfUseful(force: false)
      }
    }
  }

  private func deliverCodexQueueItem(_ item: CodexPromptQueueItem) async {
    updateCodexQueueItem(item.id, status: .sending)
    startCodexTranscriptAutoRefresh()
    let knownHistoryIDs = Set(codexHistoryRecords.map { $0.id.trimmed }.filter { !$0.isEmpty })
    let sentAt = Date()
    guard let targetSession = sessionSnapshot(for: item.sessionID) else {
      updateCodexQueueItem(item.id, status: .failed, error: "Session no longer exists.")
      statusText = "Codex queue session missing · \(Date().shortStamp)"
      return
    }
    let targetDir = normalizedRemotePath(
      targetSession.remoteDir.trimmed.isEmpty ? currentRemoteDir : targetSession.remoteDir)
    let environment = remoteEnvironment(for: targetSession, directory: targetDir)
    guard
      let prompt = await promptWithUploadedCodexAttachments(
        base: item.text,
        attachments: item.attachments,
        session: targetSession,
        directory: targetDir,
        environment: environment
      )
    else {
      updateCodexQueueItem(item.id, status: .failed, error: "Attachment upload failed.")
      statusText = "Attachment upload failed · \(Date().shortStamp)"
      return
    }
    let startsFreshHistory = targetSession.codexHistoryID.trimmed.isEmpty && item.kind == .send
    let result = await enqueueCodexPayloadOnA(
      kind: item.kind,
      prompt: prompt,
      environment: environment,
      forceNew: startsFreshHistory,
      excludeHistoryIDs: startsFreshHistory ? Array(knownHistoryIDs).sorted() : []
    )
    if result.exitCode != 0 {
      updateCodexQueueItem(
        item.id,
        status: .failed,
        error: "A queue upload failed. The item stays here.")
      applyCodexTranscriptResult(result)
    } else {
      startCodexTranscriptAutoRefresh()
      let remoteQueueID = codexAQueueID(from: result)
      statusText =
        item.kind == .steer
        ? "Codex steer queued on A · \(Date().shortStamp)"
        : "Codex prompt queued on A · \(Date().shortStamp)"
      updateCodexQueueItem(
        item.id,
        status: .waitingForCodex,
        error: codexAQueueReceipt(from: result),
        remoteQueueID: remoteQueueID
      )
      monitorCodexQueueItemDelivery(item.id)
      Task { [weak self] in
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        await self?.linkNewestCodexHistory(
          for: targetSession.id,
          knownHistoryIDs: knownHistoryIDs,
          sentAt: sentAt,
          targetDir: targetDir
        )
        if self?.activeSessionID == targetSession.id {
          await self?.captureCodexIfUseful(force: false)
        }
      }
    }
  }

  func refreshCodexTokenStatus(showStatus: Bool = true, force: Bool = false) async {
    guard force || !isRefreshingCodexTokens else { return }
    let now = Date()
    guard force || now.timeIntervalSince(lastCodexTokenRefresh) >= 20 else { return }
    isRefreshingCodexTokens = true
    defer { isRefreshingCodexTokens = false }
    let selectedModel = isValidCodexModelName(codexModel) ? codexModel.trimmed : "gpt-5.5"
    let selectedReasoningEffort = codexReasoningEffort.trimmed
    if showStatus {
      statusText = "Checking Codex tokens · \(Date().shortStamp)"
    }
    let result = await runRemote(
      "codex-token-status",
      args: [selectedModel, selectedReasoningEffort],
      input: currentRemoteDir + "\n",
      timeout: 45,
      showsActivity: false
    )
    if result.exitCode == 0 {
      applyCodexTokenStatus(result.combined)
      lastCodexTokenRefresh = Date()
      if showStatus {
        statusText = "Token status updated · \(Date().shortStamp)"
      }
    } else {
      codexTokenReset = "Token check failed · \(Date().shortStamp)"
      if showStatus {
        statusText = "Token check failed · \(Date().shortStamp)"
      }
    }
  }

  func codexSlash(_ command: String) async {
    let result = await runRemote("codex-command", args: [command], timeout: 45)
    applyCodexTranscriptResult(result)
    startCodexTranscriptAutoRefresh()
    if command == "/status" {
      scheduleCodexTranscriptAnalysis(force: true)
    }
  }

  func codexKey(_ key: String) async {
    let result = await runRemote("codex-key", args: [key], timeout: 30)
    applyCodexTranscriptResult(result)
    startCodexTranscriptAutoRefresh()
  }

  func restartCodex(in path: String, model: String? = nil, reasoningEffort: String? = nil) async {
    currentRemoteDir = normalizedRemotePath(path)
    updateActiveSessionDirectory(currentRemoteDir)
    let selectedModel = model?.trimmed.isEmpty == false ? model!.trimmed : codexModel
    let selectedReasoningEffort =
      reasoningEffort?.trimmed.isEmpty == false ? reasoningEffort!.trimmed : codexReasoningEffort
    if isValidCodexModelName(selectedModel) {
      codexModel = selectedModel
    } else {
      codexModel = "gpt-5.5"
    }
    if !selectedReasoningEffort.isEmpty {
      codexReasoningEffort = selectedReasoningEffort
    }
    var args: [String] = []
    if isValidCodexModelName(codexModel) {
      args.append(codexModel)
    }
    if !selectedReasoningEffort.isEmpty {
      args.append(selectedReasoningEffort)
    }
    let result = await runRemote(
      "restart-codex", args: args, input: currentRemoteDir + "\n", timeout: 60)
    if result.exitCode != 0 || codexTranscript.trimmed.isEmpty {
      _ = setCodexTranscript(result.combined)
    }
    startCodexTranscriptAutoRefresh()
  }

  func resumeLatestCodexFromApp() async {
    ensureConversationSession(defaultTool: .codex)
    enableToolForActiveSession(.codex)
    let selectedModel = isValidCodexModelName(codexModel) ? codexModel.trimmed : "gpt-5.5"
    codexModel = selectedModel
    let selectedReasoningEffort = codexReasoningEffort.trimmed
    var args: [String] = []
    if !selectedModel.isEmpty {
      args.append(selectedModel)
    }
    if !selectedReasoningEffort.isEmpty {
      args.append(selectedReasoningEffort)
    }
    statusText = "Resuming Codex app session · \(Date().shortStamp)"
    let result = await runRemote(
      "resume-codex-latest-dir", args: args, input: currentRemoteDir + "\n", timeout: 60)
    if result.exitCode != 0 || codexTranscript.trimmed.isEmpty {
      _ = setCodexTranscript(result.combined)
    }
    linkActiveCodexHistoryIfPresent(in: result.combined)
    await refreshCodexHistory(force: true)
    startCodexTranscriptAutoRefresh()
    try? await Task.sleep(nanoseconds: 650_000_000)
    await captureCodex()
  }

  func resumeCodexHistory(_ record: CodexHistoryRecord) async {
    ensureConversationSession(defaultTool: .codex)
    enableToolForActiveSession(.codex)
    updateActiveCodexHistory(
      id: record.id,
      path: record.path,
      title: record.title,
      host: record.normalizedHost,
      updatedAt: record.mtime > 0 ? Date(timeIntervalSince1970: TimeInterval(record.mtime)) : nil
    )
    markActiveSessionWorking(false, tool: .codex)
    await loadCodexHistoryTranscript(record)
    if record.normalizedHost == "local" {
      statusText = "Local Codex history linked · \(Date().shortStamp)"
      return
    }
    let selectedModel = isValidCodexModelName(codexModel) ? codexModel.trimmed : "gpt-5.5"
    codexModel = selectedModel
    let selectedReasoningEffort = codexReasoningEffort.trimmed
    var args = [record.id]
    if !selectedModel.isEmpty {
      args.append(selectedModel)
    }
    if !selectedReasoningEffort.isEmpty {
      args.append(selectedReasoningEffort)
    }
    statusText = "Resuming Codex \(record.shortID) · \(Date().shortStamp)"
    startCodexWorkingStateMonitor()
    let result = await runRemote(
      "resume-codex-session-dir", args: args, input: currentRemoteDir + "\n", timeout: 60)
    if result.exitCode != 0 {
      applyCodexTranscriptResult(result, replaceOnFailure: codexTranscript.trimmed.isEmpty)
    } else {
      statusText = "Codex \(record.shortID) linked · \(Date().shortStamp)"
    }
  }

  private func loadCodexHistoryTranscript(_ record: CodexHistoryRecord) async {
    let result = await codexHistoryTranscriptResult(for: record)
    guard result.exitCode == 0, !result.output.trimmed.isEmpty else { return }
    updateCodexTranscriptWindowState(from: result.output, record: record)
    let mergedInput = codexTranscriptPreservingLocalTurns(result.output)
    let merged = persistTranscript(.codex, value: mergedInput)
    updateActiveCodexWorkingState(from: result.output, mayStart: true)
    guard setCodexTranscript(merged) else { return }
    scheduleCodexTranscriptAnalysis()
  }

  func loadMoreCodexTranscript() async {
    guard !isLoadingMoreCodexTranscript, let record = activeCodexHistoryRecord() else { return }
    let historyID = record.id.trimmed
    guard !historyID.isEmpty else { return }
    let currentBytes =
      codexTranscriptTailBytesByHistoryID[historyID] ?? Self.defaultCodexTranscriptTailBytes
    let nextBytes = min(
      max(currentBytes * 2, Self.defaultCodexTranscriptTailBytes * 2),
      Self.maxCodexTranscriptTailBytes
    )
    guard nextBytes > currentBytes || codexTranscriptCanLoadMore else { return }
    isLoadingMoreCodexTranscript = true
    statusText = "Loading older transcript · \(Date().shortStamp)"
    defer { isLoadingMoreCodexTranscript = false }
    let result = await codexHistoryTranscriptResult(for: record, tailBytes: nextBytes)
    guard result.exitCode == 0, !result.output.trimmed.isEmpty else {
      statusText = "Older transcript unavailable · \(Date().shortStamp)"
      return
    }
    codexTranscriptTailBytesByHistoryID[historyID] = nextBytes
    updateCodexTranscriptWindowState(from: result.output, record: record, tailBytes: nextBytes)
    let mergedInput = codexTranscriptPreservingLocalTurns(result.output)
    let merged = persistTranscript(.codex, value: mergedInput)
    updateActiveCodexWorkingState(from: result.output, mayStart: true)
    if setCodexTranscript(merged, force: true) {
      scheduleCodexTranscriptAnalysis()
    }
    statusText = "Older transcript loaded · \(Date().shortStamp)"
  }

  private func codexHistoryTranscriptResult(
    for record: CodexHistoryRecord,
    tailBytes: Int? = nil
  ) async -> CommandResult {
    var environment: [String: String] = [:]
    if let tailBytes {
      environment["A_COCKPIT_CODEX_TRANSCRIPT_TAIL_BYTES"] =
        "\(min(max(tailBytes, 1_048_576), Self.maxCodexTranscriptTailBytes))"
    }
    if record.normalizedHost == "local" {
      return await runLocalHelper(
        "codex-history-transcript",
        args: [record.id],
        input: record.path + "\n",
        timeout: 60,
        environment: environment
      )
    }
    return await runRemote(
      "codex-history-transcript", args: [record.id], input: record.path + "\n", timeout: 60,
      showsActivity: false,
      environmentOverride: environment.isEmpty ? nil : environment)
  }

  private func codexHistoryTranscriptBackgroundResult(for record: CodexHistoryRecord) async
    -> CommandResult
  {
    if record.normalizedHost == "local" {
      return await runLocalHelper(
        "codex-history-transcript",
        args: [record.id],
        input: record.path + "\n",
        timeout: 16
      )
    }
    return await runRemoteBackground(
      "codex-history-transcript", args: [record.id], input: record.path + "\n", timeout: 16)
  }

  private func updateCodexTranscriptWindowState(
    from transcript: String,
    record: CodexHistoryRecord,
    tailBytes: Int? = nil
  ) {
    let historyID = record.id.trimmed
    guard !historyID.isEmpty else {
      codexTranscriptCanLoadMore = false
      return
    }
    if let tailBytes {
      codexTranscriptTailBytesByHistoryID[historyID] = tailBytes
    } else if codexTranscriptTailBytesByHistoryID[historyID] == nil {
      codexTranscriptTailBytesByHistoryID[historyID] = Self.defaultCodexTranscriptTailBytes
    }
    let currentBytes =
      codexTranscriptTailBytesByHistoryID[historyID] ?? Self.defaultCodexTranscriptTailBytes
    let isWindowed = transcript.contains("transcript_window: last ")
    codexTranscriptCanLoadMore = isWindowed && currentBytes < Self.maxCodexTranscriptTailBytes
  }

  private func shouldReplaceWithCodexHistoryTranscript(_ record: CodexHistoryRecord) -> Bool {
    let transcript = codexTranscript.trimmed
    guard !record.id.trimmed.isEmpty else { return false }
    guard !transcript.isEmpty else { return true }
    if transcript.contains("resumed Codex history") {
      return true
    }
    if transcript.contains("codex_history_id: \(record.id)") {
      return false
    }
    return false
  }

  private func activeCodexHistoryRecord() -> CodexHistoryRecord? {
    guard let session = activeSession else { return nil }
    let historyID = session.codexHistoryID.trimmed
    guard !historyID.isEmpty else { return nil }
    let host = session.codexHistoryHost.trimmed.isEmpty
      ? "remote"
      : session.codexHistoryHost.trimmed.lowercased()
    let matchingRecord =
      codexHistoryRecords.first { $0.id == historyID && $0.normalizedHost == host }
      ?? codexHistoryRecords.first { $0.id == historyID }
    return CodexHistoryRecord(
      id: historyID,
      cwd: matchingRecord?.cwd ?? session.remoteDir,
      path: matchingRecord?.path ?? session.codexHistoryPath,
      mtime: matchingRecord?.mtime ?? Int(session.updatedAt.timeIntervalSince1970),
      title: titleForCodexHistory(
        id: historyID,
        cwd: matchingRecord?.cwd ?? session.remoteDir,
        rawTitle: matchingRecord?.title ?? session.codexHistoryTitle
      ),
      source: matchingRecord?.source,
      threadSource: matchingRecord?.threadSource,
      host: matchingRecord?.normalizedHost ?? host
    )
  }

  func openCodexArtifact(_ artifact: CodexArtifact) async {
    var path = codexRemotePathFromUserInput(artifact.path)
    guard !path.isEmpty else { return }
    path = await resolveRemotePreviewPath(path, context: artifact.sourceLine)
    remoteOpenPath = path
    let parent = URL(fileURLWithPath: path).deletingLastPathComponent().path
    await loadFileBrowserDirectory(parent == "/" ? "/" : parent)
    if let item = fileBrowserItems.first(where: { $0.path == path }) {
      selectedRemoteItem = item
    }
    await readRemoteFile(path)
  }

  func ensureCodexInlineImagePreview(for rawPath: String, context: String = "") async {
    let requestedPath = codexRemotePathFromUserInput(rawPath)
    guard !requestedPath.isEmpty else { return }
    let resolvedPath = await resolveRemotePreviewPath(requestedPath, context: context)
    guard previewKind(for: resolvedPath) == .image else { return }
    if let cachedURL = cachedRemotePreviewURL(for: resolvedPath) {
      codexInlineImagePreviewURLs[rawPath] = cachedURL
      codexInlineImagePreviewURLs[resolvedPath] = cachedURL
      return
    }
    let signature = await freshRemoteFileSignature(for: resolvedPath)
    guard (signature?.size ?? maxInlineImagePreviewDownloadBytes) <= maxInlineImagePreviewDownloadBytes
    else { return }
    guard let url = await downloadRemoteFileToPreview(
      resolvedPath,
      attempts: 2,
      useBackground: true,
      expectedSignature: signature
    ) else { return }
    codexInlineImagePreviewURLs[rawPath] = url
    codexInlineImagePreviewURLs[resolvedPath] = url
  }

  func previewCodexPath(_ path: String) async {
    let normalizedPath = codexRemotePathFromUserInput(path)
    guard !normalizedPath.isEmpty else { return }
    isCodexFilePanelVisible = true
    await previewCodexArtifact(
      CodexArtifact(path: normalizedPath, kind: artifactKind(for: normalizedPath), sourceLine: "")
    )
  }

  func previewCodexArtifactInPanel(_ artifact: CodexArtifact) async {
    isCodexFilePanelVisible = true
    await previewCodexArtifact(artifact)
  }

  func previewCodexArtifact(_ artifact: CodexArtifact) async {
    let requestID = UUID()
    codexArtifactPreviewRequestID = requestID
    codexArtifactPrewarmTask?.cancel()
    var path = codexRemotePathFromUserInput(artifact.path)
    guard !path.isEmpty else { return }
    path = await resolveRemotePreviewPath(path, context: artifact.sourceLine)
    guard codexArtifactPreviewRequestID == requestID else { return }
    let normalizedArtifact = CodexArtifact(
      path: path,
      kind: artifactKind(for: path),
      sourceLine: artifact.sourceLine
    )
    invalidateRemotePreviewCache(for: path)
    codexPreviewArtifact = normalizedArtifact
    codexArtifactPreviewText = ""
    codexArtifactPreviewURL = nil
    codexArtifactPreviewKind = previewKind(for: path)
    codexArtifactPreviewError = ""
    isCodexArtifactPreviewLoading = true
    statusText = "Preview requested · \(Date().shortStamp)"
    defer {
      if codexArtifactPreviewRequestID == requestID {
        isCodexArtifactPreviewLoading = false
      }
    }
    switch codexArtifactPreviewKind {
    case .text:
      let result = await runRemoteBackground(
        "read-file-preview", args: ["180000"], input: path + "\n", timeout: 18,
      )
      guard codexArtifactPreviewRequestID == requestID else { return }
      let previewText = result.output.trimmed.isEmpty ? result.combined : result.output
      codexArtifactPreviewText =
        previewText.trimmed.isEmpty
        ? "No preview text available for \(URL(fileURLWithPath: path).lastPathComponent)."
        : previewText
      if result.exitCode == 0 {
        remoteTextPreviewCache[path] = codexArtifactPreviewText
      } else {
        codexArtifactPreviewError =
          "Resolving preview from A. SSHcontroll will keep retrying while this file appears."
      }
    case .image, .pdf, .external:
      codexArtifactPreviewURL = await downloadRemoteFileToPreview(
        path,
        attempts: 30,
        forceRefresh: true
      )
      guard codexArtifactPreviewRequestID == requestID else { return }
      if codexArtifactPreviewURL == nil, codexArtifactPreviewKind != .external {
        codexArtifactPreviewError =
          "Still resolving this preview from A. The file may be large or still being written."
        scheduleCodexArtifactPreviewRetry(normalizedArtifact)
      }
    case .video:
      codexArtifactPreviewURL = nil
      codexArtifactPreviewError =
        "Video preview skipped. Use Save to download the video and play it locally."
    case .none:
      break
    }
  }

  func openCodexPreviewExternally() {
    if let url = codexArtifactPreviewURL {
      NSWorkspace.shared.open(url)
    }
  }

  private func scheduleCodexArtifactPreviewRetry(_ artifact: CodexArtifact) {
    Task(priority: .utility) { [weak self] in
      guard let self else { return }
      try? await Task.sleep(nanoseconds: 900_000_000)
      guard self.codexPreviewArtifact?.id == artifact.id,
        self.codexArtifactPreviewURL == nil
      else { return }
      await self.previewCodexArtifact(artifact)
    }
  }

  private func resolveRemotePreviewPath(_ path: String, context: String = "") async -> String {
    guard !path.contains("*"), !path.contains("${"), !path.contains("$(") else { return path }
    let baseDirectory =
      activeSession?.remoteDir.trimmed.isEmpty == false
      ? activeSession!.remoteDir
      : currentRemoteDir
    let result = await runRemoteBackground(
      "resolve-file",
      input: path + "\n" + baseDirectory + "\n" + context + "\n",
      timeout: 18
    )
    let resolved = result.output.trimmed
    if result.exitCode == 0, !resolved.isEmpty {
      return normalizedRemotePath(resolved)
    }
    return path
  }

  private func codexRemotePathFromUserInput(_ value: String) -> String {
    let trimmed = value.trimmed
    guard !trimmed.isEmpty else { return "" }
    if trimmed == "~" {
      return normalizedRemotePath(settings.remoteHome)
    }
    if trimmed.hasPrefix("~/") {
      let suffix = String(trimmed.dropFirst(2))
      return normalizedRemotePath(settings.remoteHome + "/" + suffix)
    }
    if trimmed.hasPrefix("/") {
      return normalizedRemotePath(trimmed)
    }
    let base =
      activeSession?.remoteDir.trimmed.isEmpty == false
      ? activeSession!.remoteDir : currentRemoteDir
    return normalizedRemotePath(base + "/" + trimmed)
  }

  func selectCodexModel(_ model: String) async {
    codexModel = model
    guard activeCodexConversationIsEstablished else {
      statusText = "Codex model saved · \(Date().shortStamp)"
      return
    }
    await restartCodex(in: currentRemoteDir, model: model, reasoningEffort: codexReasoningEffort)
    try? await Task.sleep(nanoseconds: 450_000_000)
    await captureCodex()
  }

  func selectCodexReasoningEffort(_ effort: String) async {
    updateCodexReasoningEffort(effort)
    guard activeCodexConversationIsEstablished else {
      statusText = "Codex depth saved · \(Date().shortStamp)"
      return
    }
    await restartCodex(in: currentRemoteDir, model: codexModel, reasoningEffort: effort)
    try? await Task.sleep(nanoseconds: 450_000_000)
    await captureCodex()
  }

  func captureClaude() async {
    guard !isCapturingClaude else { return }
    isCapturingClaude = true
    defer { isCapturingClaude = false }
    let result = await runRemote("capture-claude", timeout: 30, showsActivity: false)
    applyClaudeTranscriptResult(result)
  }

  func captureClaudeIfUseful() async {
    guard activeClaudeConversationIsEstablished else { return }
    await captureClaude()
  }

  @discardableResult
  private func ensureClaudeSessionDirectory() async -> CommandResult {
    let result = await runRemote("ensure-claude-dir", input: currentRemoteDir + "\n", timeout: 45)
    if result.exitCode != 0 {
      statusText = "Claude dir blocked · \(Date().shortStamp)"
    }
    return result
  }

  func sendClaude(steer: Bool) async {
    let text = claudeInput.trimmed
    guard !text.isEmpty || !claudeAttachments.isEmpty else { return }
    ensureConversationSession(defaultTool: .claude)
    touchActiveSession()
    enableToolForActiveSession(.claude, touch: true)
    markActiveSessionWorking(true, tool: .claude)
    claudeInput = ""
    let ensureResult = await ensureClaudeSessionDirectory()
    guard ensureResult.exitCode == 0 else {
      claudeInput = text
      markActiveSessionWorking(false, tool: .claude)
      applyClaudeTranscriptResult(ensureResult, replaceOnFailure: true)
      return
    }
    guard let prompt = await promptWithUploadedClaudeAttachments(base: text) else {
      claudeInput = text
      markActiveSessionWorking(false, tool: .claude)
      statusText = "Claude attachment upload failed · \(Date().shortStamp)"
      return
    }
    let result = await runRemote(
      steer ? "steer-claude" : "send-claude", input: prompt + "\n", timeout: 60)
    if result.exitCode != 0 {
      claudeInput = text
      markActiveSessionWorking(false, tool: .claude)
      applyClaudeTranscriptResult(result)
    } else {
      claudeAttachments.removeAll()
      try? await Task.sleep(nanoseconds: 550_000_000)
      await captureClaude()
      if claudeTranscriptIsAtSetupPrompt(claudeTranscript) {
        claudeInput = text
        markActiveSessionWorking(false, tool: .claude)
        statusText = "Claude setup required · \(Date().shortStamp)"
      }
    }
  }

  func claudeKey(_ key: String) async {
    let result = await runRemote("claude-key", args: [key], timeout: 30)
    applyClaudeTranscriptResult(result)
  }

  func restartClaude(in path: String) async {
    currentRemoteDir = normalizedRemotePath(path)
    updateActiveSessionDirectory(currentRemoteDir)
    let result = await runRemote("restart-claude", input: currentRemoteDir + "\n", timeout: 60)
    if result.exitCode != 0 || claudeTranscript.trimmed.isEmpty {
      _ = setClaudeTranscript(result.combined)
    }
  }

  func checkAITool(_ tool: String) async {
    let normalized = tool.lowercased()
    let result = await runRemote("tool-status", args: [normalized], timeout: 30)
    toolCheckLog = result.combined.isEmpty ? "\(normalized) is available." : result.combined
    if result.exitCode == 0,
      let discoveredPath = discoveredToolPath(in: result.combined, tool: normalized),
      normalized == "claude"
    {
      if settings.claudePath.trimmed != discoveredPath {
        settings.claudePath = discoveredPath
        saveSettings()
      }
    }
    statusText =
      result.exitCode == 0
      ? "\(normalized.capitalized) OK · \(Date().shortStamp)"
      : "\(normalized.capitalized) missing · \(Date().shortStamp)"
  }

  func checkCodexPlugins() async {
    let result = await runRemote("plugins", timeout: 35)
    codexPluginLog = redactedPermissionOutput(result.combined)
    statusText =
      result.exitCode == 0
      ? "Codex plugins checked · \(Date().shortStamp)"
      : "Plugin check failed · \(Date().shortStamp)"
  }

  private func installedCodexPluginIDs() -> [String] {
    var ids: [String] = []
    var seen = Set<String>()
    for rawLine in codexPluginLog.components(separatedBy: .newlines) {
      let line = rawLine.trimmed
      guard line.hasPrefix("- ") else { continue }
      let pluginID = String(line.dropFirst(2)).trimmed
      guard pluginID.contains("@"), !seen.contains(pluginID) else { continue }
      seen.insert(pluginID)
      ids.append(pluginID)
    }
    return ids
  }

  private func codexPluginContextForResearch() -> String {
    let ids = installedCodexPluginIDs()
    guard !ids.isEmpty else {
      return
        "No installed-plugin list is cached yet. Use available local tools first; if plugin access is useful, inspect available plugins before relying on them."
    }
    let mentions = ids
      .map { "- \(pluginPromptMention(for: $0))" }
      .joined(separator: "\n")
    return """
      Installed Codex plugins detected on A:
      \(mentions)

      Use these plugins when they materially improve the research stage.
      Plugin routing:
      - Peer Review: Documents/PDF rendering, Browser/Chrome for artifact inspection, GitHub for provenance, and literature tools for novelty risk.
      - Physics Research: Browser/Chrome or literature plugins for prior art, Documents for PDFs/reports, Spreadsheets for tables, and local computation first for evidence.
      - DFT: Documents for input/output notes, Spreadsheets for convergence tables, Browser/literature tools for methodology checks, and local files as the source of truth.
      - App Build: GitHub, Linear, Browser/Chrome, Computer, and deployment/runtime tools when they materially verify the installed app.
      - Design: Figma/Canva when available, Browser/Chrome/Computer for real UI screenshots, Presentations for visual critique decks.
      - General Research: choose the smallest useful plugin set and record what each plugin changed in PLUGIN_AUDIT.md.
      If a queued runtime is intentionally plugin-lean for stability, continue with local repository/filesystem evidence and explicitly record which plugin checks should be repeated in an interactive full-plugin Codex session.
      """
  }

  private func pluginPromptMention(for pluginID: String) -> String {
    let name = pluginDisplayName(for: pluginID)
    return "[@\(name)](plugin://\(pluginID))"
  }

  private func pluginDisplayName(for pluginID: String) -> String {
    let base = pluginID.components(separatedBy: "@").first ?? pluginID
    switch base {
    case "computer-use": return "Computer"
    case "browser": return "Browser"
    case "chrome": return "Chrome"
    case "github": return "GitHub"
    case "figma": return "Figma"
    case "canva": return "Canva"
    case "zotero": return "Zotero"
    case "scite": return "Scite"
    case "life-science-research": return "Life Science Research"
    case "documents": return "Documents"
    case "spreadsheets": return "Spreadsheets"
    case "presentations": return "Presentations"
    case "linear": return "Linear"
    case "notion": return "Notion"
    case "vercel": return "Vercel"
    default:
      return base
        .split(separator: "-")
        .map { part in
          let word = String(part)
          return word.prefix(1).uppercased() + word.dropFirst()
        }
        .joined(separator: " ")
    }
  }

  func prepareCodexDeveloperSettings() async {
    let setupResult = await runRemote("codex-dev-setup", timeout: 45)
    let pluginResult = await runRemote("plugins", timeout: 35)
    codexPluginLog = redactedPermissionOutput(
      [setupResult.combined, pluginResult.combined].joined(separator: "\n\n"))
    statusText =
      setupResult.exitCode == 0 && pluginResult.exitCode == 0
      ? "Codex developer settings ready · \(Date().shortStamp)"
      : "Codex developer setup failed · \(Date().shortStamp)"
  }

  func prepareCodexCLIPermissionHost() async {
    let prepResult = await runRemote("codex-cli-permission-prep", timeout: 45)
    let statusResult = await runRemote("codex-cli-permission-status", timeout: 45)
    permissionLog = redactedPermissionOutput(
      [prepResult.combined, statusResult.combined].joined(separator: "\n\n"))
    statusText =
      statusResult.exitCode == 0
      ? "Codex CLI host checked · \(Date().shortStamp)"
      : "Codex CLI host needs approval · \(Date().shortStamp)"
  }

  private func refreshCodexPluginStatusSilently() async {
    guard settings.hasSSHTarget else { return }
    let result = await runRemoteBackground("plugins", timeout: 35)
    guard result.exitCode == 0 else { return }
    codexPluginLog = redactedPermissionOutput(result.combined)
  }

  func installClaudeCLI() async {
    let result = await runRemote("install-claude", timeout: 600)
    toolCheckLog = result.combined
    statusText =
      result.exitCode == 0
      ? "Claude installed · \(Date().shortStamp)" : "Claude install failed · \(Date().shortStamp)"
    if result.exitCode == 0 {
      await checkAITool("claude")
    }
  }

  func checkRemotePermissions() async {
    let result = await runRemote("permission-status", timeout: 45)
    remotePermissionCheckPassed = result.exitCode == 0
    permissionLog =
      result.exitCode == 0
      ? concisePermissionOutput(result.combined)
      : redactedPermissionOutput(result.combined)
    statusText =
      result.exitCode == 0
      ? "Permissions checked · \(Date().shortStamp)"
      : "Permission check failed · \(Date().shortStamp)"
  }

  func checkRemoteComputerBridge() async {
    let result = await runRemote("computer-status", timeout: 75)
    remotePermissionCheckPassed = result.exitCode == 0
    permissionLog =
      result.exitCode == 0
      ? concisePermissionOutput(result.combined)
      : redactedPermissionOutput(result.combined)
    statusText =
      result.exitCode == 0
      ? "A Computer bridge ready · \(Date().shortStamp)"
      : "A Computer bridge blocked · \(Date().shortStamp)"
  }

  func prepareDeveloperPermissions() async {
    remotePermissionCheckPassed = false
    let installResult = await runRemote("permission-install", timeout: 45)
    let prepResult = await runRemote("permission-prep", timeout: 60)
    let codexResult = await runRemote("codex-permission-prep", timeout: 60)
    let cliHostResult = await runRemote("codex-cli-permission-prep", timeout: 45)
    let targetResult = await openSavedPermissionTargets(updateStatus: false)
    let screenshotResult = await runRemote("permission-screenshot", timeout: 20)
    let statusResult = await runRemote("permission-status", timeout: 45)
    let pluginResult = await runRemote("plugins", timeout: 35)
    remotePermissionCheckPassed = statusResult.exitCode == 0
    permissionLog = redactedPermissionOutput(
      [
        "Developer permission setup",
        installResult.combined,
        prepResult.combined,
        codexResult.combined,
        cliHostResult.combined,
        targetResult,
        "Screenshot smoke:",
        screenshotResult.combined,
        "Permission status:",
        statusResult.combined,
      ].joined(separator: "\n\n"))
    codexPluginLog = redactedPermissionOutput(pluginResult.combined)
    statusText =
      statusResult.exitCode == 0 && screenshotResult.exitCode == 0 && cliHostResult.exitCode == 0
      ? "A developer permissions ready · \(Date().shortStamp)"
      : "A needs permission approval · \(Date().shortStamp)"
  }

  private func refreshRemotePermissionStateSilently() async {
    guard settings.hasSSHTarget else { return }
    let result = await runRemote("permission-status", timeout: 45, showsActivity: false)
    remotePermissionCheckPassed = result.exitCode == 0
  }

  func prepareRemotePermissions() async {
    remotePermissionCheckPassed = false
    let result = await runRemote("permission-prep", timeout: 60)
    permissionLog = redactedPermissionOutput(result.combined)
    statusText =
      result.exitCode == 0
      ? "A permission panes opened · \(Date().shortStamp)"
      : "A permission prep failed · \(Date().shortStamp)"
  }

  func prepareCodexAppPermissions() async {
    remotePermissionCheckPassed = false
    let result = await runRemote("codex-permission-prep", timeout: 60)
    permissionLog = redactedPermissionOutput(result.combined)
    statusText =
      result.exitCode == 0
      ? "Codex.app permissions opened · \(Date().shortStamp)"
      : "Codex permission prep failed · \(Date().shortStamp)"
  }

  func prepareAllRemotePermissions() async {
    remotePermissionCheckPassed = false
    let permissionResult = await runRemote("permission-prep", timeout: 60)
    let codexResult = await runRemote("codex-permission-prep", timeout: 60)
    let cliHostResult = await runRemote("codex-cli-permission-prep", timeout: 45)
    let targetResult = await openSavedPermissionTargets(updateStatus: false)
    permissionLog = redactedPermissionOutput(
      [permissionResult.combined, codexResult.combined, cliHostResult.combined, targetResult]
        .joined(
          separator: "\n\n"))
    statusText =
      permissionResult.exitCode == 0 && codexResult.exitCode == 0 && cliHostResult.exitCode == 0
      ? "A permission setup opened · \(Date().shortStamp)"
      : "Some permission setup failed · \(Date().shortStamp)"
  }

  func installRemotePermissionHost() async {
    remotePermissionCheckPassed = false
    let result = await runRemote("permission-install", timeout: 45)
    permissionLog = redactedPermissionOutput(
      result.combined.isEmpty
        ? "A-Cockpit Permission Host install command completed." : result.combined)
    statusText =
      result.exitCode == 0
      ? "Permission host installed · \(Date().shortStamp)"
      : "Permission host install failed · \(Date().shortStamp)"
    if result.exitCode == 0 {
      await checkRemotePermissions()
    }
  }

  func openLocalPrivacyPane(_ pane: MacPrivacyPane) {
    guard let url = URL(string: pane.urlString) else { return }
    NSWorkspace.shared.open(url)
    statusText = "Opened \(pane.title) settings · \(Date().shortStamp)"
  }

  func addPermissionTarget(name: String, remotePath: String, pane: MacPrivacyPane) {
    let normalizedPath = remotePath.trimmed
    guard !normalizedPath.isEmpty else {
      statusText = "Add target path · \(Date().shortStamp)"
      return
    }
    let normalizedName = name.trimmed.isEmpty ? normalizedPath : name.trimmed
    if let existingIndex = settings.permissionTargets.firstIndex(where: {
      $0.remotePath.trimmed == normalizedPath
    }) {
      settings.permissionTargets[existingIndex].name = normalizedName
      settings.permissionTargets[existingIndex].pane = pane
    } else {
      settings.permissionTargets.append(
        RemotePermissionTarget(name: normalizedName, remotePath: normalizedPath, pane: pane))
    }
    saveSettings()
    statusText = "Permission target saved · \(Date().shortStamp)"
  }

  func removePermissionTarget(_ target: RemotePermissionTarget) {
    settings.permissionTargets.removeAll { $0.id == target.id }
    saveSettings()
    statusText = "Permission target removed · \(Date().shortStamp)"
  }

  func openRemotePermissionTarget(_ target: RemotePermissionTarget) async {
    let result = await runPermissionTarget(target)
    permissionLog = redactedPermissionOutput(result.combined)
    statusText =
      result.exitCode == 0
      ? "A target opened · \(Date().shortStamp)" : "A target open failed · \(Date().shortStamp)"
  }

  func openSavedPermissionTargets() async {
    let combined = await openSavedPermissionTargets(updateStatus: true)
    permissionLog = redactedPermissionOutput(combined)
  }

  private func openSavedPermissionTargets(updateStatus: Bool) async -> String {
    guard !settings.permissionTargets.isEmpty else {
      if updateStatus {
        statusText = "No saved targets · \(Date().shortStamp)"
      }
      return "No saved A permission targets."
    }
    var chunks: [String] = []
    var allSucceeded = true
    for target in settings.permissionTargets {
      let result = await runPermissionTarget(target)
      chunks.append(result.combined)
      allSucceeded = allSucceeded && result.exitCode == 0
    }
    if updateStatus {
      statusText =
        allSucceeded
        ? "A targets opened · \(Date().shortStamp)" : "Some targets failed · \(Date().shortStamp)"
    }
    return chunks.joined(separator: "\n\n")
  }

  private func runPermissionTarget(_ target: RemotePermissionTarget) async -> CommandResult {
    let payload =
      [
        target.pane.rawValue,
        target.remotePath.trimmed,
        target.displayName,
      ].joined(separator: "\n") + "\n"
    return await runRemote("permission-open-target", input: payload, timeout: 45)
  }

  func runMobileQAGuiOnA() async {
    let result = await runRemote("mobile-qa-gui", input: "\n", timeout: 60)
    permissionLog = redactedPermissionOutput(result.combined)
    statusText =
      result.exitCode == 0
      ? "Mobile QA launched on A · \(Date().shortStamp)"
      : "Mobile QA launch failed · \(Date().shortStamp)"
  }

  func checkGuiRunLog() async {
    let result = await runRemote("gui-run-status", timeout: 45)
    permissionLog = redactedPermissionOutput(result.combined)
    statusText =
      result.exitCode == 0
      ? "GUI log checked · \(Date().shortStamp)" : "GUI log check failed · \(Date().shortStamp)"
  }

  func prepareAppleSigning() async {
    let result = await runRemote("apple-signing-prep", input: appleSigningPayload, timeout: 45)
    appleSigningLog = redactedPermissionOutput(result.combined)
    statusText =
      result.exitCode == 0
      ? "Apple signing prep opened · \(Date().shortStamp)"
      : "Apple signing prep failed · \(Date().shortStamp)"
  }

  func checkAppleSigning() async {
    let result = await runRemote("apple-signing-status", input: appleSigningPayload, timeout: 60)
    appleSigningLog = redactedPermissionOutput(result.combined)
    statusText =
      result.exitCode == 0
      ? "Apple signing checked · \(Date().shortStamp)"
      : "Apple signing check failed · \(Date().shortStamp)"
  }

  func testAppleSigning() async {
    let result = await runRemote("apple-signing-test", input: appleSigningPayload, timeout: 240)
    appleSigningLog = redactedPermissionOutput(result.combined)
    statusText =
      result.exitCode == 0
      ? "Apple signing passed · \(Date().shortStamp)"
      : "Apple signing blocked · \(Date().shortStamp)"
  }

  private var appleSigningPayload: String {
    [
      "",
      settings.appleDevelopmentTeamID.trimmed,
      settings.appleBundleID.trimmed,
    ].joined(separator: "\n") + "\n"
  }

  func refreshMonitor() async {
    guard !isRefreshingMonitor else { return }
    isRefreshingMonitor = true
    monitorMetricInFlight = nil
    fanSnapshot = ""
    fanActionLog = ""
    defer { isRefreshingMonitor = false }
    let snapshot = await runRemote("monitor-once", timeout: 45)
    monitorSnapshot = monitorSummaryWithoutCachedFan(snapshot.combined)
    let fan = await runRemote("fan-rpm", timeout: 20)
    fanSnapshot = fan.combined
  }

  func measureFan(refreshSnapshotIfEmpty: Bool = true) async {
    guard !isMeasuringFan else { return }
    if refreshSnapshotIfEmpty, monitorSnapshot.trimmed.isEmpty {
      let snapshot = await runRemote("monitor-once", timeout: 45)
      monitorSnapshot = monitorSummaryWithoutCachedFan(snapshot.combined)
      fanActionLog = ""
    }
    isMeasuringFan = true
    fanActionLog = ""
    fanSnapshot = "Measuring fan RPM for 5 sec..."
    defer { isMeasuringFan = false }
    let result = await runRemote("fan-rpm", timeout: 20)
    fanSnapshot = result.combined
  }

  func refreshMonitorMetric(_ metric: String) async {
    guard monitorMetricInFlight == nil, !isRefreshingMonitor else { return }
    monitorMetricInFlight = metric
    defer { monitorMetricInFlight = nil }
    if metric == "fan" {
      await measureFan(refreshSnapshotIfEmpty: true)
      return
    }
    let result = await runRemote("monitor-metric", args: [metric], timeout: 45)
    guard result.exitCode == 0 else {
      monitorSnapshot = result.combined
      return
    }
    mergeMonitorMetric(result.output, metric: metric)
  }

  func applyFan(_ preset: String) async {
    fanSnapshot = ""
    fanActionLog = "Applying fan preset..."
    let result = await runRemote("fan-apply", args: [preset], timeout: 30)
    fanActionLog = result.combined
    try? await Task.sleep(nanoseconds: 350_000_000)
    let snapshot = await runRemote("monitor-once", timeout: 45)
    monitorSnapshot = monitorSummaryWithoutCachedFan(snapshot.combined)
  }

  var combinedMonitorSnapshot: String {
    [monitorSnapshot, fanSnapshot, fanActionLog]
      .map(\.trimmed)
      .filter { !$0.isEmpty }
      .joined(separator: "\n\n")
  }

  private func mergeMonitorMetric(_ metricOutput: String, metric: String) {
    let newLines =
      metricOutput
      .components(separatedBy: .newlines)
      .filter { !$0.trimmed.isEmpty && !$0.hasPrefix("A Monitor") }
    guard !newLines.isEmpty else { return }
    let prefixes = monitorLinePrefixes(for: metric)
    var lines = monitorSnapshot.components(separatedBy: .newlines)
    let matchingIndexes = lines.indices.filter { index in
      let line = lines[index]
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      return prefixes.contains { trimmed.lowercased().hasPrefix($0) }
    }
    if let firstIndex = matchingIndexes.first {
      for index in matchingIndexes.dropFirst().reversed() {
        lines.remove(at: index)
      }
      lines.replaceSubrange(firstIndex...firstIndex, with: newLines)
    } else {
      lines.append(contentsOf: newLines)
    }
    monitorSnapshot =
      lines
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: "\n")
  }

  private func monitorSummaryWithoutCachedFan(_ value: String) -> String {
    var kept: [String] = []
    var droppingFanBlock = false
    for line in value.components(separatedBy: .newlines) {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      let lower = trimmed.lowercased()
      if lower.hasPrefix("a fan rpm") {
        droppingFanBlock = true
        continue
      }
      if droppingFanBlock {
        if lower.hasPrefix("a monitor") {
          droppingFanBlock = false
        } else {
          continue
        }
      }
      kept.append(line)
    }
    return
      kept
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: "\n")
  }

  private func monitorLinePrefixes(for metric: String) -> [String] {
    switch metric {
    case "cpu": ["cpu:"]
    case "gpu": ["gpu:"]
    case "memory": ["memory:"]
    case "network": ["network:"]
    case "battery": ["battery:"]
    case "fan":
      [
        "macs fan control setting:", "fan rpm:", "fan 1", "fan 2", "measured at:", "sample window:",
        "source:",
      ]
    default: []
    }
  }

  private func shellCompletionItems(in directory: String) async -> [RemoteItem] {
    let normalizedDirectory = normalizedRemotePath(directory)
    if let cached = remoteDirectoryCache[normalizedDirectory] {
      return cached
    }
    if normalizedDirectory == normalizedRemotePath(currentRemoteDir), !remoteItems.isEmpty {
      return remoteItems
    }
    let result = await runRemote("list-dir", input: normalizedDirectory + "\n", timeout: 45)
    guard result.exitCode == 0,
      let data = result.output.data(using: .utf8),
      let decoded = try? JSONDecoder().decode([RemoteItem].self, from: data)
    else {
      return []
    }
    cacheDirectoryItems(decoded, for: normalizedDirectory)
    if normalizedDirectory == normalizedRemotePath(currentRemoteDir) {
      remoteItems = decoded
    }
    return decoded
  }

  private func shellCompletionCacheKey(for context: ShellCompletionContext) -> String {
    "\(normalizedRemotePath(context.searchDirectory))|\(context.typedDirectory)|\(context.prefix)"
  }

  private func shellCompletionMatches(
    for context: ShellCompletionContext,
    items: [RemoteItem]
  ) -> [ShellCompletion] {
    items
      .filter { item in
        if !context.prefix.hasPrefix("."), item.name.hasPrefix(".") {
          return false
        }
        return item.name.hasPrefix(context.prefix)
      }
      .sorted { first, second in
        if first.isDirectory != second.isDirectory {
          return first.isDirectory && !second.isDirectory
        }
        return first.name.localizedStandardCompare(second.name) == .orderedAscending
      }
      .prefix(30)
      .map { item in
        ShellCompletion(
          label: item.name + (item.isDirectory ? "/" : ""),
          value: context.replacingToken(with: item),
          isDirectory: item.isDirectory
        )
      }
  }

  @discardableResult
  private func syncShellWorkingDirectory(updateActiveSession: Bool) async -> String? {
    guard settings.hasSSHTarget else { return nil }
    let result = await runRemoteBackground("session-pwd", args: ["shell"], timeout: 10)
    guard result.exitCode == 0 else { return nil }
    guard
      let path = result.output
        .components(separatedBy: .newlines)
        .map(\.trimmed)
        .first(where: { !$0.isEmpty })
    else {
      return nil
    }
    let normalizedPath = normalizedRemotePath(path)
    if updateActiveSession, normalizedRemotePath(currentRemoteDir) != normalizedPath {
      currentRemoteDir = normalizedPath
      updateActiveSessionDirectory(normalizedPath)
      clearRemoteSelection()
      remoteItems = []
    }
    return normalizedPath
  }

  private func clearRemoteSelection() {
    selectedRemoteItemID = nil
    selectedRemoteItemIDs = []
    lastSelectedRemoteItemID = nil
    selectedRemoteItemSnapshot = nil
  }

  private func shellCompletionContext(for input: String) -> ShellCompletionContext {
    let lineStart = input.lastIndex(of: "\n").map { input.index(after: $0) } ?? input.startIndex
    let breakers = Set<Character>(" \t\r\n;|&()<>")
    var tokenStart = input.endIndex
    var cursor = input.endIndex
    while cursor > lineStart {
      let previous = input.index(before: cursor)
      if breakers.contains(input[previous]) {
        break
      }
      tokenStart = previous
      cursor = previous
    }

    let token = String(input[tokenStart..<input.endIndex])
    let rawToken = unescapedShellToken(token)
    let typedDirectory: String
    let prefix: String
    if let slash = rawToken.lastIndex(of: "/") {
      typedDirectory = String(rawToken[...slash])
      prefix = String(rawToken[rawToken.index(after: slash)...])
    } else {
      typedDirectory = ""
      prefix = rawToken
    }
    let searchDirectory = resolvedRemoteDirectory(typedDirectory)
    return ShellCompletionContext(
      before: String(input[..<tokenStart]),
      after: String(input[input.endIndex...]),
      typedDirectory: typedDirectory,
      prefix: prefix,
      searchDirectory: searchDirectory
    )
  }

  private func resolvedRemoteDirectory(_ typedDirectory: String) -> String {
    if typedDirectory.isEmpty {
      return currentRemoteDir
    }
    if typedDirectory == "~/" {
      return settings.remoteHome
    }
    if typedDirectory.hasPrefix("~/") {
      let suffix = String(typedDirectory.dropFirst(2))
      return normalizedRemotePath(settings.remoteHome + "/" + suffix)
    }
    if typedDirectory.hasPrefix("/") {
      return normalizedRemotePath(typedDirectory)
    }
    return normalizedRemotePath(currentRemoteDir + "/" + typedDirectory)
  }

  func normalizedRemotePath(_ path: String) -> String {
    let normalized = (path as NSString).standardizingPath
    return normalized.isEmpty ? "/" : normalized
  }

  private func unescapedShellToken(_ value: String) -> String {
    var output = ""
    var escaped = false
    for character in value {
      if escaped {
        output.append(character)
        escaped = false
      } else if character == "\\" {
        escaped = true
      } else {
        output.append(character)
      }
    }
    if escaped {
      output.append("\\")
    }
    return output
  }

  private struct ShellCompletionContext {
    var before: String
    var after: String
    var typedDirectory: String
    var prefix: String
    var searchDirectory: String

    func replacingToken(with item: RemoteItem) -> String {
      before + typedDirectory + escapedShellTokenComponent(item.name)
        + (item.isDirectory ? "/" : " ") + after
    }

    private func escapedShellTokenComponent(_ value: String) -> String {
      var output = ""
      for character in value {
        if "\\ \t\"'$`!&;|<>()[]{}*?".contains(character) {
          output.append("\\")
        }
        output.append(character)
      }
      return output
    }
  }

  func latencyCheck() async {
    guard !settings.latencyTarget.trimmed.isEmpty else {
      lastMirrorLog =
        "No latency target configured. Add one in Settings, or use Check Connection for SSH."
      statusText = "No latency target · \(Date().shortStamp)"
      return
    }
    let script = """
      if command -v tailscale >/dev/null 2>&1; then
        tailscale ping \(settings.latencyTarget.shellQuoted)
      elif [ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then
        /Applications/Tailscale.app/Contents/MacOS/Tailscale ping \(settings.latencyTarget.shellQuoted)
      else
        echo 'tailscale command not found'
      fi
      """
    let result = await client.shell(script, timeout: 45)
    lastMirrorLog = result.combined
    statusText =
      result.exitCode == 0
      ? "Latency OK · \(Date().shortStamp)" : "Latency error · \(Date().shortStamp)"
  }

  func loadDirectory(_ path: String, force: Bool = false, showsActivity: Bool = true) async {
    let normalizedPath = normalizedRemotePath(path)
    let cachedBeforeFetch = remoteDirectoryCache[normalizedPath]
    let previousItems = remoteItems
    let previousDirectory = currentRemoteDir
    if !force, let cached = remoteDirectoryCache[normalizedPath] {
      currentRemoteDir = normalizedPath
      remoteItems = cached
      lastDirectoryLoadPath = normalizedPath
      lastDirectoryLoadDate = remoteDirectoryCacheDates[normalizedPath] ?? Date()
      if Date().timeIntervalSince(remoteDirectoryCacheDates[normalizedPath] ?? .distantPast) < 3.0 {
        return
      }
    }
    if !force,
      normalizedPath == currentRemoteDir,
      normalizedPath == lastDirectoryLoadPath,
      !remoteItems.isEmpty,
      let lastDirectoryLoadDate,
      Date().timeIntervalSince(lastDirectoryLoadDate) < 2.0
    {
      return
    }
    if loadingDirectoryPath == normalizedPath {
      return
    }
    loadingDirectoryPath = normalizedPath
    defer {
      if loadingDirectoryPath == normalizedPath {
        loadingDirectoryPath = nil
      }
    }
    currentRemoteDir = normalizedPath
    let result = await runRemote(
      "list-dir",
      input: normalizedPath + "\n",
      timeout: 45,
      showsActivity: showsActivity,
      bypassBackgroundQueue: true
    )
    guard result.exitCode == 0, let data = result.output.data(using: .utf8) else {
      if let cachedBeforeFetch {
        remoteItems = cachedBeforeFetch
      } else if previousDirectory == normalizedPath, !previousItems.isEmpty {
        remoteItems = previousItems
      }
      lastMirrorLog = result.combined
      return
    }
    do {
      var decoded = try JSONDecoder().decode([RemoteItem].self, from: data)
      if decoded.isEmpty, let cachedBeforeFetch, !cachedBeforeFetch.isEmpty {
        decoded = cachedBeforeFetch
      } else if decoded.isEmpty, previousDirectory == normalizedPath, !previousItems.isEmpty {
        decoded = previousItems
      }
      remoteItems = decoded
      cacheDirectoryItems(decoded, for: normalizedPath)
      lastDirectoryLoadPath = normalizedPath
      lastDirectoryLoadDate = Date()
      selectedRemoteItemID = nil
      selectedRemoteItemIDs = []
      lastSelectedRemoteItemID = nil
      selectedRemoteItemSnapshot = nil
      if fileBrowserDir.trimmed.isEmpty {
        fileBrowserDir = normalizedPath
        fileBrowserItems = decoded
      }
    } catch {
      if let cachedBeforeFetch {
        remoteItems = cachedBeforeFetch
      } else if previousDirectory == normalizedPath, !previousItems.isEmpty {
        remoteItems = previousItems
      }
      lastMirrorLog = "Could not parse directory listing: \(error)\n\(result.output)"
    }
  }

  func cachedDirectoryItems(for path: String) -> [RemoteItem]? {
    remoteDirectoryCache[normalizedRemotePath(path)]
  }

  func directoryItems(for path: String, force: Bool = false) async -> [RemoteItem] {
    let normalizedPath = normalizedRemotePath(path)
    if !force, let cached = remoteDirectoryCache[normalizedPath] {
      return cached
    }
    let cachedBeforeFetch = remoteDirectoryCache[normalizedPath]
    let result = await runRemoteBackground(
      "list-dir",
      input: normalizedPath + "\n",
      timeout: 25
    )
    guard result.exitCode == 0,
      let data = result.output.data(using: .utf8),
      let decoded = try? JSONDecoder().decode([RemoteItem].self, from: data)
    else {
      return cachedBeforeFetch ?? []
    }
    cacheDirectoryItems(decoded, for: normalizedPath)
    return decoded
  }

  func ensureFileBrowserLoaded(force: Bool = false) async {
    if fileBrowserDir.trimmed.isEmpty {
      fileBrowserDir = normalizedRemotePath(currentRemoteDir)
      remoteOpenPath = fileBrowserDir
    }
    let target = fileBrowserDir
    await loadFileBrowserDirectory(target, force: force, showsActivity: false)
  }

  func loadFileBrowserDirectory(
    _ path: String,
    force: Bool = false,
    showsActivity: Bool = false
  ) async {
    let normalizedPath = normalizedRemotePath(path)
    let didChangeDirectory = normalizedRemotePath(fileBrowserDir) != normalizedPath
    let cachedForTarget = remoteDirectoryCache[normalizedPath]
    let previousItems = fileBrowserItems
    let previousDirectory = normalizedRemotePath(fileBrowserDir)
    fileBrowserDir = normalizedPath
    fileBrowserError = ""
    if didChangeDirectory {
      clearRemoteSelection()
      remoteOpenPath = normalizedPath
    }
    if let cachedForTarget, didChangeDirectory || fileBrowserItems.isEmpty || force {
      fileBrowserItems = cachedForTarget
    }
    if fileBrowserItems.isEmpty {
      isFileBrowserLoading = true
    }
    if !force, cachedForTarget != nil {
      isFileBrowserLoading = false
      refreshCachedFileBrowserDirectoryInBackground(normalizedPath)
      return
    }
    if loadingFileBrowserPath == normalizedPath {
      return
    }
    loadingFileBrowserPath = normalizedPath
    isFileBrowserLoading = true
    defer {
      if loadingFileBrowserPath == normalizedPath {
        loadingFileBrowserPath = nil
      }
      if fileBrowserDir == normalizedPath {
        isFileBrowserLoading = false
      }
    }
    let result = await runRemote(
      "list-dir",
      input: normalizedPath + "\n",
      timeout: 45,
      showsActivity: showsActivity,
      bypassBackgroundQueue: true
    )
    guard fileBrowserDir == normalizedPath else { return }
    guard result.exitCode == 0, let data = result.output.data(using: .utf8) else {
      fileBrowserError = "Could not load \(normalizedPath)."
      lastMirrorLog = result.combined
      return
    }
    do {
      var decoded = try JSONDecoder().decode([RemoteItem].self, from: data)
      if decoded.isEmpty, !previousItems.isEmpty, previousDirectory == normalizedPath {
        let retry = await runRemoteBackground(
          "list-dir", input: normalizedPath + "\n", timeout: 18)
        if retry.exitCode == 0, let retryData = retry.output.data(using: .utf8),
          let retryDecoded = try? JSONDecoder().decode([RemoteItem].self, from: retryData),
          !retryDecoded.isEmpty
        {
          decoded = retryDecoded
        }
      }
      if decoded.isEmpty, !previousItems.isEmpty, previousDirectory == normalizedPath {
        fileBrowserItems = previousItems
        fileBrowserError = "A returned an empty refresh; keeping the cached listing."
        return
      }
      fileBrowserItems = decoded
      cacheDirectoryItems(decoded, for: normalizedPath)
    } catch {
      fileBrowserError = "Could not parse directory listing."
      lastMirrorLog = "Could not parse directory listing: \(error)\n\(result.output)"
    }
  }

  private func refreshCachedFileBrowserDirectoryInBackground(_ normalizedPath: String) {
    let now = Date()
    let lastRefresh = lastFileBrowserBackgroundRefreshByPath[normalizedPath] ?? .distantPast
    guard now.timeIntervalSince(lastRefresh) >= 12 else { return }
    lastFileBrowserBackgroundRefreshByPath[normalizedPath] = now
    Task(priority: .utility) { [weak self] in
      guard let self else { return }
      let result = await self.runRemoteBackground(
        "list-dir", input: normalizedPath + "\n", timeout: 22)
      guard result.exitCode == 0,
        let data = result.output.data(using: .utf8),
        let decoded = try? JSONDecoder().decode([RemoteItem].self, from: data)
      else {
        return
      }
      await MainActor.run { [weak self] in
        guard let self else { return }
        guard !decoded.isEmpty || self.remoteDirectoryCache[normalizedPath]?.isEmpty == true else {
          return
        }
        self.cacheDirectoryItems(decoded, for: normalizedPath)
        if self.fileBrowserDir == normalizedPath {
          self.fileBrowserItems = decoded
          self.fileBrowserError = ""
        }
      }
    }
  }

  func openFileBrowserItem(_ item: RemoteItem) async {
    selectedRemoteItem = item
    if item.isDirectory {
      searchText = ""
      openedRemoteFile = nil
      remoteFileText = ""
      remoteFileSavedText = ""
      remotePreviewURL = nil
      remotePreviewKind = .none
      await loadFileBrowserDirectory(item.path)
    } else {
      await readRemoteFile(item.path)
    }
  }

  func openCodeWorkspaceItem(_ item: RemoteItem) async {
    selectedRemoteItem = item
    if item.isDirectory {
      searchText = ""
      openedRemoteFile = nil
      remoteFileText = ""
      remoteFileSavedText = ""
      remotePreviewURL = nil
      remotePreviewKind = .none
      remoteOpenPath = item.path
      await loadFileBrowserDirectory(item.path)
    } else {
      await readRemoteFile(item.path, switchToFiles: false)
    }
  }

  func previewFileBrowserItem(_ item: RemoteItem) async {
    guard !item.isDirectory else { return }
    selectedRemoteItem = item
    await readRemoteFile(item.path)
  }

  func goUpFileBrowserDirectory() async {
    searchText = ""
    openedRemoteFile = nil
    remoteFileText = ""
    remoteFileSavedText = ""
    remotePreviewURL = nil
    remotePreviewKind = .none
    let parent = URL(fileURLWithPath: fileBrowserDir).deletingLastPathComponent().path
    await loadFileBrowserDirectory(parent == "/" ? "/" : parent)
  }

  func preloadDirectoryTree(around path: String, depth: Int = 2) async {
    let normalizedPath = normalizedRemotePath(path)
    if remoteDirectoryCache[normalizedPath] != nil, depth <= 1 {
      return
    }
    let result = await runRemoteBackground(
      "list-dir-tree",
      args: ["\(max(1, min(depth, 3)))"],
      input: normalizedPath + "\n",
      timeout: 25
    )
    guard result.exitCode == 0,
      let data = result.output.data(using: .utf8),
      let decoded = try? JSONDecoder().decode([String: [RemoteItem]].self, from: data)
    else {
      let items = await directoryItems(for: normalizedPath, force: false)
      await preloadNeighborDirectories(from: items)
      return
    }
    for (directory, items) in decoded {
      cacheDirectoryItems(items, for: directory)
    }
  }

  @discardableResult
  func createRemoteDirectory(named name: String, in parent: String) async -> String? {
    let trimmedName = name.trimmed
    guard !trimmedName.isEmpty else { return nil }
    guard !trimmedName.contains("/"), trimmedName != ".", trimmedName != ".." else {
      statusText = "Use a folder name, not a path · \(Date().shortStamp)"
      return nil
    }
    let targetPath = normalizedRemotePath(parent + "/" + trimmedName)
    let result = await runRemoteBackground(
      "mkdir-path",
      input: targetPath + "\n",
      timeout: 25
    )
    guard result.exitCode == 0 else {
      statusText = "New directory failed · \(Date().shortStamp)"
      lastMirrorLog = result.combined
      return nil
    }
    let parentPath = normalizedRemotePath(parent)
    remoteDirectoryCache.removeValue(forKey: parentPath)
    remoteDirectoryCacheDates.removeValue(forKey: parentPath)
    statusText = "Directory created · \(Date().shortStamp)"
    await preloadDirectoryTree(around: targetPath, depth: 1)
    if normalizedRemotePath(fileBrowserDir) == parentPath {
      await loadFileBrowserDirectory(parentPath, force: true, showsActivity: false)
    }
    return targetPath
  }

  func preloadNeighborDirectories(from items: [RemoteItem]) async {
    let candidates =
      items
      .filter(\.isDirectory)
      .filter { !$0.name.hasPrefix(".") }
      .prefix(96)
    await withTaskGroup(of: Void.self) { group in
      for item in candidates {
        group.addTask { [weak self] in
          _ = await self?.directoryItems(for: item.path, force: false)
        }
      }
    }
  }

  private func warmDirectoryNeighborhood() async {
    guard settings.hasSSHTarget else { return }
    let current = currentRemoteDir
    let items = await directoryItems(for: current, force: false)
    await preloadNeighborDirectories(from: items)
  }

  private func warmFileBrowserNeighborhood() async {
    guard settings.hasSSHTarget else { return }
    let current = fileBrowserDir.trimmed.isEmpty ? currentRemoteDir : fileBrowserDir
    guard !current.trimmed.isEmpty else { return }
    let items = await directoryItems(for: current, force: false)
    if fileBrowserDir == current, fileBrowserItems.isEmpty, !items.isEmpty {
      fileBrowserItems = items
    }
  }

  private func cacheDirectoryItems(_ items: [RemoteItem], for path: String) {
    let normalizedPath = normalizedRemotePath(path)
    remoteDirectoryCache[normalizedPath] = items
    remoteDirectoryCacheDates[normalizedPath] = Date()
    shellCompletionCache = shellCompletionCache.filter { key, _ in
      !key.hasPrefix("\(normalizedPath)|")
    }
    if remoteDirectoryCache.count > 1_024 {
      let keep = Set(
        remoteDirectoryCacheDates
          .sorted { $0.value > $1.value }
          .prefix(1_024)
          .map(\.key)
      )
      remoteDirectoryCache = remoteDirectoryCache.filter { keep.contains($0.key) }
      remoteDirectoryCacheDates = remoteDirectoryCacheDates.filter { keep.contains($0.key) }
    }
    persistDirectoryCache()
  }

  private func persistDirectoryCache() {
    let snapshot = RemoteDirectoryCacheSnapshot(
      itemsByPath: remoteDirectoryCache,
      datesByPath: remoteDirectoryCacheDates
    )
    let url = directoryCacheURL
    Task.detached(priority: .utility) {
      guard let data = try? JSONEncoder().encode(snapshot) else { return }
      try? data.write(to: url, options: .atomic)
    }
  }

  func selectRemoteItem(
    _ item: RemoteItem, visibleItems: [RemoteItem],
    modifiers explicitModifiers: NSEvent.ModifierFlags? = nil
  ) {
    let modifiers = explicitModifiers ?? NSApp.currentEvent?.modifierFlags ?? []
    let isCommand = modifiers.contains(.command) || modifiers.contains(.control)
    let isShift = modifiers.contains(.shift)
    if isShift,
      let lastSelectedRemoteItemID,
      let start = visibleItems.firstIndex(where: { $0.id == lastSelectedRemoteItemID }),
      let end = visibleItems.firstIndex(where: { $0.id == item.id })
    {
      let range = start <= end ? start...end : end...start
      selectedRemoteItemIDs = Set(visibleItems[range].map(\.id))
    } else if isCommand {
      if selectedRemoteItemIDs.contains(item.id) {
        selectedRemoteItemIDs.remove(item.id)
      } else {
        selectedRemoteItemIDs.insert(item.id)
      }
    } else {
      selectedRemoteItemIDs = [item.id]
    }
    selectedRemoteItemSnapshot = item
    if selectedRemoteItemIDs.isEmpty {
      selectedRemoteItemID = nil
      selectedRemoteItemSnapshot = nil
    } else if selectedRemoteItemIDs.contains(item.id) {
      selectedRemoteItemID = item.id
    } else {
      selectedRemoteItemID = selectedRemoteItemIDs.sorted().first
    }
    lastSelectedRemoteItemID = selectedRemoteItemID
  }

  func openRemoteItem(_ item: RemoteItem) async {
    selectedRemoteItem = item
    if item.isDirectory {
      searchText = ""
      openedRemoteFile = nil
      remoteFileText = ""
      remoteFileSavedText = ""
      remotePreviewURL = nil
      remotePreviewKind = .none
      await loadDirectory(item.path)
    } else {
      await readRemoteFile(item.path)
    }
  }

  func goUpDirectory() async {
    searchText = ""
    openedRemoteFile = nil
    remoteFileText = ""
    remoteFileSavedText = ""
    remotePreviewURL = nil
    remotePreviewKind = .none
    let parent = URL(fileURLWithPath: currentRemoteDir).deletingLastPathComponent().path
    await loadDirectory(parent == "/" ? "/" : parent)
  }

  func readRemoteFile(_ path: String, switchToFiles: Bool = true) async {
    let requestID = UUID()
    remotePreviewRequestID = requestID
    isRemotePreviewLoading = true
    defer {
      if remotePreviewRequestID == requestID {
        isRemotePreviewLoading = false
      }
    }
    let normalizedPath = remotePathFromUserInput(path)
    let filePath =
      normalizedPath.isEmpty
      ? normalizedRemotePath(path) : await resolveRemotePreviewPath(normalizedPath)
    openedRemoteFile = filePath
    remotePreviewURL = nil
    remotePreviewKind = previewKind(for: filePath)
    remoteFileIsPreviewOnly = false
    remoteOpenPath = filePath
    if [.image, .pdf, .external].contains(remotePreviewKind),
      let cachedURL = cachedRemotePreviewURL(for: filePath)
    {
      remotePreviewURL = cachedURL
      lastMirrorLog =
        "Cached preview opened immediately: \(filePath)\n\(cachedURL.path)\nChecking A in the background before replacing it."
      statusText = "Preview cache shown · \(Date().shortStamp)"
    }
    let latestSignature = await freshRemoteFileSignature(for: filePath)
    let latestFileSize = latestSignature?.size ?? knownRemoteFileSize(for: filePath)
    let sizeDescription =
      latestFileSize.map {
        " (\(Self.fileSizeFormatter.string(fromByteCount: $0)))"
      }
      ?? ""
    lastMirrorLog = "Preview request sent: \(filePath)\(sizeDescription)\nWaiting for A to return the file..."
    statusText = "Preview requested · \(Date().shortStamp)"
    switch remotePreviewKind {
    case .text:
      remoteFileText = ""
      remoteFileSavedText = ""
      if let knownSize = latestFileSize,
        knownSize > maxEditableRemoteTextBytes
      {
        let result = await runRemote(
          "read-file-preview",
          args: ["\(maxTextPreviewBytes)"],
          input: filePath + "\n",
          timeout: 30,
          showsActivity: false,
          bypassBackgroundQueue: true
        )
        let previewText = result.output.trimmed.isEmpty ? result.combined : result.output
        remoteFileText = previewText
        remoteFileSavedText = previewText
        remoteFileIsPreviewOnly = true
        lastMirrorLog =
          result.exitCode == 0
          ? "Preview-only loaded: \(filePath)\n\(Self.fileSizeFormatter.string(fromByteCount: knownSize)) is kept read-only so the editor stays responsive. Use Save A → C for the full file."
          : result.combined
      } else {
        let result = await runRemote(
          "read-file",
          input: filePath + "\n",
          timeout: 45,
          bypassBackgroundQueue: true
        )
        remoteFileText = result.output
        if result.exitCode == 0 {
          remoteFileSavedText = result.output
          remoteTextPreviewCache[filePath] = result.output
          lastMirrorLog = "Text loaded: \(filePath)"
        } else {
          remoteFileSavedText = ""
          lastMirrorLog = result.combined
        }
      }
    case .image, .pdf, .external:
      remoteFileText = ""
      remoteFileSavedText = ""
      if let url = await downloadRemoteFileToPreview(
        filePath,
        attempts: 1,
        forceRefresh: false,
        expectedSignature: latestSignature
      ) {
        remotePreviewURL = url
        if remotePreviewKind == .external {
          NSWorkspace.shared.open(url)
        }
      }
    case .video:
      remoteFileText = ""
      remoteFileSavedText = ""
      remotePreviewURL = nil
      lastMirrorLog =
        "Video preview skipped: \(filePath)\(sizeDescription)\nUse Save to download the video and play it locally."
      statusText = "Video preview skipped · \(Date().shortStamp)"
    case .none:
      remoteFileText = ""
      remoteFileSavedText = ""
    }
    if switchToFiles {
      selectedSurface = .files
    }
  }

  private func refreshOpenedRemoteFileFromAIfSafe() async {
    guard let path = openedRemoteFile,
      !isRemoteFileDirty,
      !isRemotePreviewLoading
    else { return }
    await readRemoteFile(path, switchToFiles: false)
  }

  private func prewarmVisibleRemoteFiles() async {
    await prewarmRemoteFiles(in: fileBrowserItems.isEmpty ? remoteItems : fileBrowserItems)
  }

  private func prewarmRemoteItems(around item: RemoteItem, visibleItems: [RemoteItem]) async {
    guard !item.isDirectory else { return }
    let index = visibleItems.firstIndex(where: { $0.id == item.id }) ?? 0
    let lower = max(0, index - 3)
    let upper = min(visibleItems.count, index + 5)
    await prewarmRemoteFiles(in: Array(visibleItems[lower..<upper]), limit: 8)
  }

  private func prewarmRemoteFiles(in items: [RemoteItem], limit: Int = 48) async {
    guard settings.hasSSHTarget else { return }
    let candidates =
      items
      .filter { !$0.isDirectory }
      .filter { item in
        switch previewKind(for: item.path) {
        case .text:
          return item.size > 0 && item.size <= Int64(maxTextPreviewBytes)
        case .image:
          return item.size > 0 && item.size <= maxBackgroundPreviewDownloadBytes
        case .pdf, .video, .external, .none:
          return false
        }
      }
      .sorted { first, second in
        if previewKind(for: first.path) != previewKind(for: second.path) {
          return previewKind(for: first.path).prewarmRank
            < previewKind(for: second.path).prewarmRank
        }
        return first.name.localizedStandardCompare(second.name) == .orderedAscending
      }
      .prefix(limit)

    var processed = 0
    for item in candidates {
      guard !Task.isCancelled else { return }
      await prewarmRemoteFilePreview(item.path)
      processed += 1
      if processed % 6 == 0 {
        await Task.yield()
      }
    }
  }

  private func prewarmRemoteFilePreview(_ path: String) async {
    let normalizedPath = remotePathFromUserInput(path)
    guard !normalizedPath.isEmpty else { return }
    switch previewKind(for: normalizedPath) {
    case .text:
      guard remoteTextPreviewCache[normalizedPath] == nil else { return }
      guard (knownRemoteFileSize(for: normalizedPath) ?? Int64(maxTextPreviewBytes)) <= Int64(maxTextPreviewBytes)
      else { return }
      let result = await runRemoteBackground(
        "read-file",
        input: normalizedPath + "\n",
        timeout: 14
      )
      let previewText = result.output.trimmed.isEmpty ? result.combined : result.output
      if result.exitCode == 0, !previewText.trimmed.isEmpty {
        remoteTextPreviewCache[normalizedPath] = previewText
      }
    case .image, .pdf:
      guard remoteDownloadedPreviewCache[normalizedPath] == nil else { return }
      _ = await downloadRemoteFileToPreview(normalizedPath, attempts: 1, useBackground: true)
    case .video:
      return
    case .external, .none:
      return
    }
  }

  func openRemotePathFromInput() async {
    var path = remotePathFromUserInput(remoteOpenPath)
    guard !path.isEmpty else { return }
    let stat = await runRemote(
      "stat-file",
      input: path + "\n",
      timeout: 12,
      showsActivity: false,
      bypassBackgroundQueue: true
    )
    if stat.exitCode != 0 {
      let resolved = await resolveRemotePreviewPath(path)
      if resolved != path {
        path = resolved
      }
    }
    let resolvedStat =
      stat.exitCode == 0
      ? stat
      : await runRemote(
        "stat-file",
        input: path + "\n",
        timeout: 12,
        showsActivity: false,
        bypassBackgroundQueue: true
      )
    guard resolvedStat.exitCode == 0 else {
      remoteOpenPath = path
      lastMirrorLog = resolvedStat.combined.trimmed.isEmpty ? "Path not found: \(path)" : resolvedStat.combined
      statusText = "Open path failed · \(Date().shortStamp)"
      return
    }
    remoteOpenPath = path
    if resolvedStat.output.hasPrefix("dir ") {
      searchText = ""
      openedRemoteFile = nil
      remoteFileText = ""
      remoteFileSavedText = ""
      remotePreviewURL = nil
      remotePreviewKind = .none
      await loadFileBrowserDirectory(path, force: true, showsActivity: false)
      statusText = "Folder opened · \(Date().shortStamp)"
      return
    }
    let parent = URL(fileURLWithPath: path).deletingLastPathComponent().path
    if normalizedRemotePath(fileBrowserDir) != normalizedRemotePath(parent) {
      await loadFileBrowserDirectory(parent, force: false, showsActivity: false)
    }
    if let item = fileBrowserItems.first(where: { normalizedRemotePath($0.path) == normalizedRemotePath(path) }) {
      selectedRemoteItem = item
    }
    await readRemoteFile(path)
  }

  func openFileBrowserFolderFromInput(_ value: String, force: Bool = false) async {
    let path = remotePathFromUserInput(value)
    guard !path.isEmpty else { return }
    remoteOpenPath = path
    await loadFileBrowserDirectory(path, force: force, showsActivity: false)
  }

  private func remotePathFromUserInput(_ value: String) -> String {
    let trimmed = value.trimmed
    guard !trimmed.isEmpty else { return "" }
    if trimmed == "~" {
      return normalizedRemotePath(settings.remoteHome)
    }
    if trimmed.hasPrefix("~/") {
      let suffix = String(trimmed.dropFirst(2))
      return normalizedRemotePath(settings.remoteHome + "/" + suffix)
    }
    if trimmed.hasPrefix("/") {
      return normalizedRemotePath(trimmed)
    }
    let base = fileBrowserDir.trimmed.isEmpty ? currentRemoteDir : fileBrowserDir
    return normalizedRemotePath(base + "/" + trimmed)
  }

  func saveRemoteFile() async {
    guard let path = openedRemoteFile else { return }
    guard remotePreviewKind == .text else {
      lastMirrorLog = "Binary preview is read-only here. Use Save A → C to download it."
      return
    }
    guard !remoteFileIsPreviewOnly else {
      lastMirrorLog = "This is a read-only preview for a large file. Use Save A → C to download the full file."
      statusText = "Preview-only file · \(Date().shortStamp)"
      return
    }
    guard remoteFileText != remoteFileSavedText else {
      statusText = "File already saved · \(Date().shortStamp)"
      return
    }
    let byteCount = Int64(remoteFileText.lengthOfBytes(using: .utf8))
    beginFileTransferMode()
    isBusy = true
    let transferID = beginTrackedFileTransfer(
      title: "Saving file on A",
      source: "Editor buffer",
      destination: path,
      totalBytes: byteCount,
      phase: byteCount >= Int64(largeRemoteTextSaveThreshold) ? "Preparing upload" : "Saving"
    )
    defer {
      isBusy = false
      endFileTransferMode()
    }
    statusText = "Saving file on A · \(Date().shortStamp)"
    let result: CommandResult
    if byteCount >= Int64(largeRemoteTextSaveThreshold) {
      result = await saveRemoteTextFileViaUpload(
        path: path,
        text: remoteFileText,
        progressID: transferID,
        byteCount: byteCount
      )
    } else {
      updateTrackedFileTransfer(transferID, phase: "Writing", completedBytes: 0, totalBytes: byteCount)
      let payload = path + "\n" + remoteFileText
      result = await runRemote(
        "write-file",
        input: payload,
        timeout: 60,
        showsActivity: false,
        bypassBackgroundQueue: true
      )
      updateTrackedFileTransfer(
        transferID,
        phase: "Verifying",
        completedBytes: result.exitCode == 0 ? byteCount : 0,
        totalBytes: byteCount
      )
    }
    lastMirrorLog = result.combined.isEmpty ? "Saved \(path)" : result.combined
    if result.exitCode == 0 {
      remoteFileSavedText = remoteFileText
      remoteTextPreviewCache[path] = remoteFileText
      statusText = "Saved file · \(Date().shortStamp)"
      finishTrackedFileTransfer(
        transferID,
        succeeded: true,
        message:
          "Saved A file: \(path) · \(Self.fileSizeFormatter.string(fromByteCount: byteCount))"
      )
    } else {
      statusText = "Save failed · \(Date().shortStamp)"
      finishTrackedFileTransfer(
        transferID,
        succeeded: false,
        message: "Save A failed: \(path)"
      )
    }
  }

  private func saveRemoteTextFileViaUpload(
    path: String,
    text: String,
    progressID: UUID,
    byteCount: Int64
  ) async -> CommandResult {
    let localURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("acontrol-save-\(UUID().uuidString).txt")
    do {
      try text.write(to: localURL, atomically: true, encoding: .utf8)
    } catch {
      return CommandResult(exitCode: 74, output: "", error: error.localizedDescription)
    }
    defer {
      try? FileManager.default.removeItem(at: localURL)
    }
    let remoteTmp = "/tmp/.sshcontroll-save-\(UUID().uuidString).tmp"
    statusText = "Uploading save to A · \(Date().shortStamp)"
    lastMirrorLog = "Save upload request sent: \(path)\n\(Self.fileSizeFormatter.string(fromByteCount: byteCount))"
    updateTrackedFileTransfer(
      progressID,
      phase: "Uploading",
      completedBytes: 0,
      totalBytes: byteCount
    )
    let progressMonitor = startRemoteFileProgressMonitor(
      id: progressID,
      path: remoteTmp,
      totalBytes: byteCount,
      phase: "Uploading"
    )
    let upload = await runFastSCP(
      arguments: "\(localURL.path.shellQuoted) \(settings.remoteSpec(remoteTmp).shellQuoted)",
      timeout: Self.transferTimeout(forByteCount: byteCount)
    )
    progressMonitor.cancel()
    guard upload.exitCode == 0 else { return upload }
    updateTrackedFileTransfer(
      progressID,
      phase: "Installing",
      completedBytes: byteCount,
      totalBytes: byteCount
    )
    let install = await runRemote(
      "install-uploaded-file",
      input: remoteTmp + "\n" + path + "\n",
      timeout: 60,
      showsActivity: false,
      bypassBackgroundQueue: true
    )
    if install.exitCode != 0 {
      _ = await runRemote(
        "delete-path",
        input: remoteTmp + "\n",
        timeout: 20,
        showsActivity: false,
        bypassBackgroundQueue: true
      )
    }
    return install
  }

  func openPreviewExternally() {
    if let remotePreviewURL {
      NSWorkspace.shared.open(remotePreviewURL)
    }
  }

  private static func scpFastOptionsUnsupported(_ result: CommandResult) -> Bool {
    let lower = result.combined.lowercased()
    return lower.contains("illegal option")
      || lower.contains("unknown option")
      || lower.contains("invalid buffer size")
      || lower.contains("usage: scp")
  }

  private static func rsyncTransferUnsupported(_ result: CommandResult) -> Bool {
    let lower = result.combined.lowercased()
    return lower.contains("command not found")
      || lower.contains("unknown option")
      || lower.contains("unrecognized option")
      || lower.contains("rsync error: syntax")
      || lower.contains("usage: rsync")
  }

  private static func transferRateText(bytes: Int64, elapsed: TimeInterval) -> String {
    guard bytes > 0, elapsed > 0 else { return "unknown speed" }
    return String(format: "%.1f MB/s", (Double(bytes) / 1_000_000.0) / elapsed)
  }

  private static func transferTimeout(forByteCount bytes: Int64) -> TimeInterval {
    guard bytes > 0 else { return 240 }
    let seconds = Double(bytes) / 1_000_000.0 + 60
    return min(1_800, max(120, seconds))
  }

  private static func parallelTransferWorkerCount(totalBlocks: Int64) -> Int {
    Int(min(Int64(4), max(Int64(2), (totalBlocks + 7) / 8)))
  }

  private func currentTailscaleTransferLatencyMs() async -> Double? {
    let target =
      settings.latencyTarget.trimmed.nilIfEmpty
      ?? settings.sshTarget.trimmed.nilIfEmpty
    guard let target else { return nil }
    let script = """
      set +e
      if [ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then
        ts=/Applications/Tailscale.app/Contents/MacOS/Tailscale
      elif command -v tailscale >/dev/null 2>&1; then
        ts="$(command -v tailscale)"
      else
        exit 127
      fi
      "$ts" ping --c 2 --until-direct \(target.shellQuoted) 2>&1
      """
    let result = await client.shell(script, timeout: 10)
    guard !result.combined.trimmed.isEmpty else { return nil }
    guard let regex = try? NSRegularExpression(pattern: #"in\s+([0-9]+(?:\.[0-9]+)?)ms"#)
    else { return nil }
    let text = result.combined
    let range = NSRange(text.startIndex..., in: text)
    let values = regex.matches(in: text, range: range).compactMap { match -> Double? in
      guard match.numberOfRanges >= 2,
        let swiftRange = Range(match.range(at: 1), in: text)
      else { return nil }
      return Double(text[swiftRange])
    }
    return values.min()
  }

  private func shouldUseParallelTransfer(forByteCount bytes: Int64) async -> Bool {
    guard bytes >= 8 * 1_024 * 1_024 else { return false }
    guard let latency = await currentTailscaleTransferLatencyMs() else { return true }
    return latency < 140
  }

  private static func stoppedTransferMessage(
    title: String,
    source: String,
    destination: String? = nil,
    timeout: TimeInterval,
    result: CommandResult
  ) -> String {
    var lines = [
      "Transfer stopped: \(title)",
      "Source: \(source)",
    ]
    if let destination, !destination.trimmed.isEmpty {
      lines.append("Destination: \(destination)")
    }
    if result.exitCode == 124 {
      lines.append(
        "Reason: transfer timed out after \(Int(timeout))s; local child transfer processes were stopped.")
    } else {
      lines.append("Reason: remote connection closed or transfer command failed.")
    }
    let details = result.combined.trimmed
    if !details.isEmpty {
      lines.append("")
      lines.append(details)
    }
    return lines.joined(separator: "\n")
  }

  private func beginTrackedFileTransfer(
    title: String,
    source: String,
    destination: String,
    totalBytes: Int64 = 0,
    phase: String = "Preparing"
  ) -> UUID {
    var progress = FileTransferProgress(
      title: title,
      source: source,
      destination: destination,
      phase: phase,
      completedBytes: 0,
      totalBytes: max(0, totalBytes)
    )
    progress.updatedAt = Date()
    activeFileTransfer = progress
    appendFileTransferLog("\(phase): \(source) -> \(destination)")
    return progress.id
  }

  private func updateTrackedFileTransfer(
    _ id: UUID,
    phase: String? = nil,
    completedBytes: Int64? = nil,
    totalBytes: Int64? = nil
  ) {
    guard var progress = activeFileTransfer, progress.id == id else { return }
    if let phase {
      progress.phase = phase
    }
    if let completedBytes {
      progress.completedBytes = max(0, completedBytes)
    }
    if let totalBytes {
      progress.totalBytes = max(0, totalBytes)
    }
    progress.updatedAt = Date()
    activeFileTransfer = progress
  }

  private func finishTrackedFileTransfer(
    _ id: UUID,
    succeeded: Bool,
    message: String
  ) {
    guard var progress = activeFileTransfer, progress.id == id else {
      appendFileTransferLog(message)
      return
    }
    if succeeded, progress.totalBytes > 0 {
      progress.completedBytes = progress.totalBytes
    }
    progress.phase = succeeded ? "Complete" : "Failed"
    progress.isFinished = true
    progress.succeeded = succeeded
    progress.updatedAt = Date()
    activeFileTransfer = progress
    appendFileTransferLog(message)
    Task { [weak self] in
      try? await Task.sleep(nanoseconds: 5_000_000_000)
      await MainActor.run {
        guard let self, self.activeFileTransfer?.id == id,
          self.activeFileTransfer?.isFinished == true
        else { return }
        self.activeFileTransfer = nil
      }
    }
  }

  private func appendFileTransferLog(_ message: String) {
    let stamp = Date().shortStamp
    let entry = "[\(stamp)] \(message.trimmed)"
    fileTransferLogEntries.append(entry)
    fileTransferLogEntries = Array(fileTransferLogEntries.suffix(40))
    if !fileTransferLogEntries.isEmpty {
      lastMirrorLog = fileTransferLogEntries.joined(separator: "\n")
    }
  }

  private func fileTransferLogText(with result: String) -> String {
    var parts = fileTransferLogEntries
    let trimmed = result.trimmed
    if !trimmed.isEmpty {
      parts.append(trimmed)
    }
    return parts.isEmpty ? result : parts.joined(separator: "\n")
  }

  private func startLocalFileProgressMonitor(
    id: UUID,
    url: URL,
    totalBytes: Int64
  ) -> Task<Void, Never> {
    Task { [weak self] in
      while !Task.isCancelled {
        let bytes =
          ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber)?
          .int64Value ?? 0
        await MainActor.run {
          self?.updateTrackedFileTransfer(
            id,
            phase: "Downloading",
            completedBytes: bytes,
            totalBytes: totalBytes
          )
        }
        try? await Task.sleep(nanoseconds: 450_000_000)
      }
    }
  }

  private func startRemoteFileProgressMonitor(
    id: UUID,
    path: String,
    totalBytes: Int64,
    phase: String
  ) -> Task<Void, Never> {
    Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        if let bytes = await self.remoteFileSize(at: path) {
          await MainActor.run {
            self.updateTrackedFileTransfer(
              id,
              phase: phase,
              completedBytes: bytes,
              totalBytes: totalBytes
            )
          }
        }
        try? await Task.sleep(nanoseconds: 1_200_000_000)
      }
    }
  }

  private static func localByteCount(at url: URL) -> Int64 {
    let fileManager = FileManager.default
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }
    if !isDirectory.boolValue {
      return ((try? fileManager.attributesOfItem(atPath: url.path)[.size]) as? NSNumber)?
        .int64Value ?? 0
    }
    guard
      let enumerator = fileManager.enumerator(
        at: url,
        includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
        options: []
      )
    else { return 0 }
    var total: Int64 = 0
    for case let fileURL as URL in enumerator {
      guard
        let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
        values.isRegularFile == true
      else { continue }
      total += Int64(values.fileSize ?? 0)
    }
    return total
  }

  private static func localByteCount(paths: [String]) -> Int64 {
    paths.reduce(Int64(0)) { total, path in
      total + localByteCount(at: URL(fileURLWithPath: path))
    }
  }

  private func runFastSCP(arguments: String, timeout: TimeInterval = 3600) async -> CommandResult {
    let fastResult = await client.shell(
      "\(settings.fastTransferSCPShellCommand) \(arguments)",
      timeout: timeout
    )
    guard fastResult.exitCode != 0, Self.scpFastOptionsUnsupported(fastResult) else {
      return fastResult
    }
    return await client.shell(
      "\(settings.transferSCPShellCommand) \(arguments)",
      timeout: timeout
    )
  }

  private func runFastRsync(arguments: String, timeout: TimeInterval = 3600) async -> CommandResult {
    await client.shell(
      """
      /usr/bin/rsync -a --partial --inplace --whole-file --progress --stats --timeout=45 -e \(settings.rsyncSSHCommand.shellQuoted) \(arguments)
      """,
      timeout: timeout
    )
  }

  private func downloadRemotePathViaFastSCP(
    _ remotePath: String,
    to outputURL: URL,
    timeout: TimeInterval = 3600
  ) async -> CommandResult {
    try? FileManager.default.createDirectory(
      at: outputURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try? FileManager.default.removeItem(at: outputURL)
    let arguments = "\(settings.remoteSpec(remotePath).shellQuoted) \(outputURL.path.shellQuoted)"
    let rsync = await runFastRsync(arguments: arguments, timeout: timeout)
    if rsync.exitCode == 0 {
      return rsync
    }
    guard Self.rsyncTransferUnsupported(rsync) else {
      return rsync
    }
    try? FileManager.default.removeItem(at: outputURL)
    let scp = await runFastSCP(arguments: arguments, timeout: timeout)
    return CommandResult(
      exitCode: scp.exitCode,
      output: scp.output,
      error: [rsync.error, scp.error].filter { !$0.trimmed.isEmpty }.joined(separator: "\n")
    )
  }

  private func downloadRemotePathFastest(
    _ remotePath: String,
    to outputURL: URL,
    expectedSize: Int64,
    timeout: TimeInterval = 3600
  ) async -> CommandResult {
    let result = await downloadRemotePathViaFastSCP(remotePath, to: outputURL, timeout: timeout)
    guard result.exitCode == 0, expectedSize > 0 else { return result }
    let actualSize = Self.localByteCount(at: outputURL)
    guard actualSize == expectedSize else {
      try? FileManager.default.removeItem(at: outputURL)
      return CommandResult(
        exitCode: 74,
        output: result.output,
        error:
          "Downloaded file size mismatch: expected \(expectedSize) bytes, got \(actualSize) bytes.")
    }
    return result
  }

  private func downloadRemotePathViaParallelSSH(
    _ remotePath: String,
    to outputURL: URL,
    expectedSize: Int64,
    timeout: TimeInterval = 3600
  ) async -> CommandResult {
    guard expectedSize > 0 else {
      return await downloadRemotePathViaFastSCP(remotePath, to: outputURL, timeout: timeout)
    }
    try? FileManager.default.createDirectory(
      at: outputURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try? FileManager.default.removeItem(at: outputURL)

    let blockSize: Int64 = 1_048_576
    let totalBlocks = max(Int64(1), (expectedSize + blockSize - 1) / blockSize)
    let workers = Self.parallelTransferWorkerCount(totalBlocks: totalBlocks)
    let blocksPerPart = (totalBlocks + Int64(workers) - 1) / Int64(workers)
    let sshCommand = "/usr/bin/ssh \(settings.transferSSHShellOptions) \(settings.sshTarget.shellQuoted)"
    var lines: [String] = [
      "set -euo pipefail",
      "tmpdir=$(/usr/bin/mktemp -d /tmp/acontrol-fast-download.XXXXXX)",
      "pids=()",
      "parts=()",
      "commands=()",
      "expected=()",
      #"kill_tree() { local parent="$1" child; for child in $(/usr/bin/pgrep -P "$parent" 2>/dev/null); do kill_tree "$child"; /bin/kill -TERM "$child" 2>/dev/null || true; done; /bin/kill -TERM "$parent" 2>/dev/null || true; }"#,
      #"stop_workers() { local pid; for pid in "${pids[@]}"; do kill_tree "$pid"; done; }"#,
      #"cleanup() { if ((${#pids[@]})); then stop_workers; fi; rm -rf "$tmpdir"; }"#,
      "trap cleanup EXIT INT TERM HUP",
      #"part_bytes() { local total=0 size=0 file; for file in "$tmpdir"/part_*; do [[ -e "$file" ]] || continue; size=$(/usr/bin/stat -f%z "$file" 2>/dev/null || echo 0); total=$((total + size)); done; echo "$total"; }"#,
      #"part_ok() { local i="$1"; local part="$tmpdir/${parts[$i]}"; [[ -f "$part" ]] || return 1; local actual; actual=$(/usr/bin/stat -f%z "$part" 2>/dev/null || echo 0); [[ "$actual" == "${expected[$i]}" ]]; }"#,
      #"missing_count() { local bad=0 i; for i in "${!parts[@]}"; do part_ok "$i" || bad=$((bad + 1)); done; echo "$bad"; }"#,
      "download_index() { local i=\"$1\"; local part=\"$tmpdir/${parts[$i]}\"; rm -f \"$part\"; \(sshCommand) \"${commands[$i]}\" > \"$part\"; }",
      "run_wave() {",
      "  pids=()",
      "  local i",
      "  for i in \"${!parts[@]}\"; do",
      "    if ! part_ok \"$i\"; then download_index \"$i\" & pids+=(\"$!\"); fi",
      "  done",
      "  if ((${#pids[@]} == 0)); then return 0; fi",
      "  watchdog &",
      "  watchdog_pid=$!",
      "  local failed=0 pid",
      "  for pid in \"${pids[@]}\"; do wait \"$pid\" || failed=1; done",
      "  kill \"$watchdog_pid\" >/dev/null 2>&1 || true",
      "  wait \"$watchdog_pid\" >/dev/null 2>&1 || true",
      "  pids=()",
      "  return \"$failed\"",
      "}",
    ]

    var chunkCount = 0
    for index in 0..<workers {
      let skipBlocks = Int64(index) * blocksPerPart
      guard skipBlocks < totalBlocks else { continue }
      let countBlocks = min(blocksPerPart, totalBlocks - skipBlocks)
      let expectedBytes = min(countBlocks * blockSize, expectedSize - skipBlocks * blockSize)
      let remoteCommand =
        "dd if=\(remotePath.shellQuoted) bs=\(blockSize) skip=\(skipBlocks) count=\(countBlocks) 2>/dev/null"
      lines.append("parts+=(\(String(format: "part_%04d", index).shellQuoted))")
      lines.append("commands+=(\(remoteCommand.shellQuoted))")
      lines.append("expected+=(\(expectedBytes))")
      chunkCount += 1
    }

    lines += [
      "watchdog() {",
      "  local last_bytes=0",
      "  local last_progress=$(/bin/date +%s)",
      "  while true; do",
      "    local bytes=$(part_bytes)",
      "    local now=$(/bin/date +%s)",
      "    if (( bytes > last_bytes )); then last_bytes=$bytes; last_progress=$now; fi",
      "    if (( now - last_progress > 30 )); then echo \"Transfer stalled: no bytes received for 30s; stopping parallel SSH download.\" >&2; if ((${#pids[@]})); then stop_workers; fi; exit 0; fi",
      "    /bin/sleep 2",
      "  done",
      "}",
      "run_wave || true",
      "for retry in 1 2; do",
      "  bad=$(missing_count)",
      "  if [[ \"$bad\" == \"0\" ]]; then break; fi",
      "  echo \"Retrying $bad incomplete chunk(s), round $retry.\" >&2",
      "  run_wave || true",
      "done",
      "bad=$(missing_count)",
      "if [[ \"$bad\" != \"0\" ]]; then echo \"Parallel SSH download failed: $bad chunk(s) incomplete after retries.\" >&2; exit 75; fi",
      "cat \"$tmpdir\"/part_* > \(outputURL.path.shellQuoted)",
      "actual=$(/usr/bin/stat -f%z \(outputURL.path.shellQuoted))",
      "if [[ \"$actual\" != \"\(expectedSize)\" ]]; then echo \"Parallel SSH download size mismatch: expected \(expectedSize), got $actual\" >&2; exit 74; fi",
      "echo \"Mode: parallel ssh dd download\"",
      "echo \"Chunks: \(chunkCount)\"",
    ]
    let script = """
      /bin/bash <<'ACONTROL_FAST_DOWNLOAD'
      \(lines.joined(separator: "\n"))
      ACONTROL_FAST_DOWNLOAD
      """
    return await client.shell(script, timeout: timeout)
  }

  private func remoteFileSize(at path: String) async -> Int64? {
    let stat = await runRemote(
      "stat-file",
      input: path + "\n",
      timeout: 30,
      showsActivity: false,
      bypassBackgroundQueue: true
    )
    guard stat.exitCode == 0 else { return nil }
    let parts = stat.output.split(separator: " ")
    guard parts.count >= 2, parts[0] == "file", let size = Int64(parts[1]) else {
      return nil
    }
    return size
  }

  private func deleteRemoteSaveTemporary(_ path: String) async {
    _ = await runRemote(
      "delete-path",
      input: path + "\n",
      timeout: 30,
      showsActivity: false,
      bypassBackgroundQueue: true
    )
  }

  private func uploadLocalFileFastest(
    _ localURL: URL,
    toRemoteFile remotePath: String,
    expectedSize: Int64,
    timeout: TimeInterval = 3600
  ) async -> CommandResult {
    _ = expectedSize
    let arguments = "\(localURL.path.shellQuoted) \(settings.remoteSpec(remotePath).shellQuoted)"
    let rsync = await runFastRsync(arguments: arguments, timeout: timeout)
    if rsync.exitCode == 0 { return await verifyUploadedFile(remotePath, expectedSize, rsync) }
    guard Self.rsyncTransferUnsupported(rsync) else {
      return rsync
    }
    let scp = await runFastSCP(arguments: arguments, timeout: timeout)
    let result = CommandResult(
      exitCode: scp.exitCode,
      output: scp.output,
      error: [rsync.error, scp.error].filter { !$0.trimmed.isEmpty }.joined(separator: "\n")
    )
    guard result.exitCode == 0 else { return result }
    return await verifyUploadedFile(remotePath, expectedSize, result)
  }

  private func verifyUploadedFile(
    _ remotePath: String,
    _ expectedSize: Int64,
    _ result: CommandResult
  ) async -> CommandResult {
    guard expectedSize > 0 else { return result }
    guard let actualSize = await remoteFileSize(at: remotePath) else { return result }
    guard actualSize == expectedSize else {
      return CommandResult(
        exitCode: 74,
        output: result.output,
        error:
          "Uploaded file size mismatch: expected \(expectedSize) bytes, got \(actualSize) bytes.")
    }
    return result
  }

  private func uploadLocalFileViaParallelSSH(
    _ localURL: URL,
    toRemoteFile remotePath: String,
    expectedSize: Int64,
    timeout: TimeInterval = 3600
  ) async -> CommandResult {
    guard expectedSize > 0 else {
      return await runFastSCP(
        arguments: "\(localURL.path.shellQuoted) \(settings.remoteSpec(remotePath).shellQuoted)",
        timeout: timeout
      )
    }
    let remoteParent = remoteDirectory(containing: remotePath)
    let remoteTempRoot = normalizedRemotePath(
      (settings.remoteHome.trimmed.nilIfEmpty ?? currentRemoteDir)
        + "/.sshcontroll_buffer/tmp"
    )
    let remoteTempDir = "\(remoteTempRoot)/acontrol-upload-\(UUID().uuidString)"
    let remotePartial = "\(remoteTempDir)/joined.partial"
    let blockSize: Int64 = 1_048_576
    let totalBlocks = max(Int64(1), (expectedSize + blockSize - 1) / blockSize)
    let workers = Self.parallelTransferWorkerCount(totalBlocks: totalBlocks)
    let blocksPerPart = (totalBlocks + Int64(workers) - 1) / Int64(workers)
    let sshCommand = "/usr/bin/ssh \(settings.transferSSHShellOptions) \(settings.sshTarget.shellQuoted)"
    let prepareRemote = "mkdir -p \(remoteParent.shellQuoted) \(remoteTempDir.shellQuoted)"
    let cleanupRemote = "rm -rf \(remoteTempDir.shellQuoted)"
    var lines: [String] = [
      "set -euo pipefail",
      "\(sshCommand) \(prepareRemote.shellQuoted)",
      "pids=()",
      #"kill_tree() { local parent="$1" child; for child in $(/usr/bin/pgrep -P "$parent" 2>/dev/null); do kill_tree "$child"; /bin/kill -TERM "$child" 2>/dev/null || true; done; /bin/kill -TERM "$parent" 2>/dev/null || true; }"#,
      #"stop_workers() { local pid; for pid in "${pids[@]}"; do kill_tree "$pid"; done; }"#,
      #"cleanup() { if ((${#pids[@]})); then stop_workers; fi; "# + "\(sshCommand) \(cleanupRemote.shellQuoted)" + #" >/dev/null 2>&1 || true; }"#,
      "trap cleanup EXIT INT TERM HUP",
    ]

    var chunkCount = 0
    for index in 0..<workers {
      let skipBlocks = Int64(index) * blocksPerPart
      guard skipBlocks < totalBlocks else { continue }
      let countBlocks = min(blocksPerPart, totalBlocks - skipBlocks)
      let remotePart = "\(remoteTempDir)/part_\(String(format: "%04d", index))"
      let receiveCommand = "cat > \(remotePart.shellQuoted)"
      lines.append(
        "(/bin/dd if=\(localURL.path.shellQuoted) bs=\(blockSize) skip=\(skipBlocks) count=\(countBlocks) 2>/dev/null | \(sshCommand) \(receiveCommand.shellQuoted)) &"
      )
      lines.append(#"pids+=("$!")"#)
      chunkCount += 1
    }

    let finishRemote = """
      set -e
      cat \(remoteTempDir.shellQuoted)/part_* > \(remotePartial.shellQuoted)
      mv \(remotePartial.shellQuoted) \(remotePath.shellQuoted)
      actual=$(stat -f %z \(remotePath.shellQuoted))
      if [ "$actual" != "\(expectedSize)" ]; then
        echo "Parallel SSH upload size mismatch: expected \(expectedSize), got $actual" >&2
        exit 74
      fi
      rm -rf \(remoteTempDir.shellQuoted)
      """
    lines += [
      "failed=0",
      #"for pid in "${pids[@]}"; do wait "$pid" || failed=1; done"#,
      "pids=()",
      "if [[ \"$failed\" -ne 0 ]]; then \(sshCommand) \(cleanupRemote.shellQuoted) >/dev/null 2>&1 || true; echo \"Parallel SSH upload failed.\" >&2; exit 75; fi",
      "\(sshCommand) \(finishRemote.shellQuoted)",
      "echo \"Mode: parallel ssh dd upload\"",
      "echo \"Chunks: \(chunkCount)\"",
    ]
    let script = """
      /bin/bash <<'ACONTROL_FAST_UPLOAD'
      \(lines.joined(separator: "\n"))
      ACONTROL_FAST_UPLOAD
      """
    return await client.shell(script, timeout: timeout)
  }

  private func uploadLocalSelectionViaFastArchive(
    paths: [String],
    to targetDir: String,
    label: String,
    progressID: UUID? = nil
  ) async -> CommandResult {
    let workspaceURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("acontrol-upload-\(UUID().uuidString)", isDirectory: true)
    let archiveURL = workspaceURL.appendingPathComponent("selection.tar")
    defer {
      try? FileManager.default.removeItem(at: workspaceURL)
    }
    let tarArgs = paths.map { path -> String in
      if path.hasSuffix("/.") {
        let parent = String(path.dropLast(2))
        return "-C \(parent.shellQuoted) ."
      }
      let url = URL(fileURLWithPath: path)
      let parent = url.deletingLastPathComponent().path
      return "-C \(parent.shellQuoted) \(url.lastPathComponent.shellQuoted)"
    }.joined(separator: " ")
    let createArchiveScript = """
      rm -rf \(workspaceURL.path.shellQuoted)
      mkdir -p \(workspaceURL.path.shellQuoted)
      COPYFILE_DISABLE=1 /usr/bin/tar -cf \(archiveURL.path.shellQuoted) \(tarArgs)
      """
    if let progressID {
      updateTrackedFileTransfer(progressID, phase: "Archiving")
      appendFileTransferLog("Archiving local selection: \(label)")
    }
    let create = await client.shell(createArchiveScript, timeout: 3600)
    guard create.exitCode == 0 else { return create }

    let archiveSize = Self.localByteCount(at: archiveURL)
    let remoteTempRoot = normalizedRemotePath(
      (settings.remoteHome.trimmed.nilIfEmpty ?? currentRemoteDir)
        + "/.sshcontroll_buffer/tmp"
    )
    let remoteArchive = "\(remoteTempRoot)/acontrol-upload-\(UUID().uuidString).tar"
    let mkdir = await runRemote(
      "mkdir-path",
      input: remoteTempRoot + "\n",
      timeout: 30,
      showsActivity: false,
      bypassBackgroundQueue: true
    )
    guard mkdir.exitCode == 0 else { return mkdir }

    if let progressID {
      updateTrackedFileTransfer(
        progressID,
        phase: "Uploading archive",
        completedBytes: 0,
        totalBytes: archiveSize
      )
      appendFileTransferLog(
        "Uploading archive to A: \(Self.fileSizeFormatter.string(fromByteCount: archiveSize))"
      )
    }
    let progressMonitor = progressID.map {
      startRemoteFileProgressMonitor(
        id: $0,
        path: remoteArchive,
        totalBytes: archiveSize,
        phase: "Uploading archive"
      )
    }
    let upload = await uploadLocalFileFastest(
      archiveURL,
      toRemoteFile: remoteArchive,
      expectedSize: archiveSize,
      timeout: Self.transferTimeout(forByteCount: archiveSize)
    )
    progressMonitor?.cancel()
    guard upload.exitCode == 0 else {
      await deleteRemoteSaveTemporary(remoteArchive)
      return CommandResult(
        exitCode: upload.exitCode,
        output: "",
        error: Self.stoppedTransferMessage(
          title: "upload archive to A",
          source: paths.count == 1 ? paths[0] : "\(paths.count) local item(s)",
          destination: remoteArchive,
          timeout: Self.transferTimeout(forByteCount: archiveSize),
          result: upload
        )
      )
    }

    if let progressID {
      updateTrackedFileTransfer(
        progressID,
        phase: "Installing on A",
        completedBytes: archiveSize,
        totalBytes: archiveSize
      )
      appendFileTransferLog("Installing uploaded archive on A: \(targetDir)")
    }
    let extractRemote = """
      set -e
      mkdir -p \(targetDir.shellQuoted)
      COPYFILE_DISABLE=1 /usr/bin/tar -xf \(remoteArchive.shellQuoted) -C \(targetDir.shellQuoted)
      rm -f \(remoteArchive.shellQuoted)
      """
    let extract = await client.shell(
      "\(settings.transferSSHShellCommand) \(extractRemote.shellQuoted)",
      timeout: 3600
    )
    if extract.exitCode != 0 {
      await deleteRemoteSaveTemporary(remoteArchive)
      return extract
    }
    return CommandResult(
      exitCode: 0,
      output:
        "Uploaded \(label) to \(targetDir)\nArchive: \(Self.fileSizeFormatter.string(fromByteCount: archiveSize))\nMode: local tar + single rsync transfer, no compression",
      error: [create.error, upload.error, extract.error].filter { !$0.isEmpty }.joined(separator: "\n")
    )
  }

  func uploadFilesToA() async {
    guard hasConfiguredSSHTarget() else { return }
    let targetDir = fileBrowserDir.trimmed.isEmpty ? currentRemoteDir : fileBrowserDir
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = true
    panel.message = "Choose files or folders from C to upload into \(targetDir) on A"
    guard panel.runModal() == .OK else { return }
    let paths = panel.urls.map(\.path)
    guard !paths.isEmpty else { return }
    let totalBytes = Self.localByteCount(paths: paths)
    let startedAt = Date()
    let sourceDescription = paths.count == 1 ? paths[0] : "\(paths.count) local item(s)"
    beginFileTransferMode()
    isBusy = true
    defer {
      isBusy = false
      endFileTransferMode()
    }
    let transferID = beginTrackedFileTransfer(
      title: "Uploading to A",
      source: sourceDescription,
      destination: targetDir,
      totalBytes: totalBytes,
      phase: "Preparing"
    )
    statusText = "Uploading to A · \(Date().shortStamp)"
    lastMirrorLog =
      "Upload request sent: \(paths.count) item(s)\nDestination: \(targetDir)\nMode: local tar + single rsync transfer, no compression"
    let result = await uploadLocalSelectionViaFastArchive(
      paths: paths,
      to: targetDir,
      label: "\(paths.count) item(s)",
      progressID: transferID
    )
    let elapsed = Date().timeIntervalSince(startedAt)
    let rate = Self.transferRateText(bytes: totalBytes, elapsed: elapsed)
    let sizeText = Self.fileSizeFormatter.string(fromByteCount: totalBytes)
    finishTrackedFileTransfer(
      transferID,
      succeeded: result.exitCode == 0,
      message:
        result.exitCode == 0
        ? "Uploaded: \(sourceDescription) -> \(targetDir) · \(sizeText) · \(rate)"
        : "Upload failed: \(sourceDescription) -> \(targetDir)"
    )
    lastMirrorLog =
      result.exitCode == 0
      ? fileTransferLogText(
        with:
          "Uploaded \(paths.count) item(s) to \(targetDir)\nSize: \(sizeText)\nSpeed: \(rate)\nMode: local tar + single rsync transfer, no compression"
      )
      : fileTransferLogText(with: result.combined)
    await loadFileBrowserDirectory(targetDir, force: true)
  }

  func chooseCodexAttachments() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = true
    panel.message = "Choose files or folders from C to attach to the next Codex prompt"
    guard panel.runModal() == .OK else { return }
    addCodexAttachments(panel.urls)
  }

  func addCodexAttachments(_ urls: [URL]) {
    let newItems =
      urls
      .filter { FileManager.default.fileExists(atPath: $0.path) }
      .map { url in
        makeAttachment(from: url)
      }
    guard !newItems.isEmpty else {
      statusText = "No local files found · \(Date().shortStamp)"
      return
    }
    codexAttachments.append(contentsOf: newItems)
    statusText = "\(codexAttachments.count) attachment(s) ready · \(Date().shortStamp)"
  }

  func addCodexImageAttachment(data: Data, suggestedExtension: String = "png") {
    let stamp = DateFormatter.attachmentStamp.string(from: Date())
    let ext = suggestedExtension.sanitizedFileName.lowercased()
    let url = attachmentDirectory.appendingPathComponent(
      "pasted-image-\(stamp).\(ext.isEmpty ? "png" : ext)")
    do {
      try data.write(to: url, options: .atomic)
      codexAttachments.append(makeAttachment(from: url, kind: "image"))
      statusText = "Image attached · \(Date().shortStamp)"
    } catch {
      statusText = "Attach failed · \(Date().shortStamp)"
      lastMirrorLog = "Could not save pasted image: \(error.localizedDescription)"
    }
  }

  func removeCodexAttachment(_ attachment: PromptAttachment) {
    codexAttachments.removeAll { $0.id == attachment.id }
  }

  func clearCodexAttachments() {
    codexAttachments.removeAll()
  }

  func chooseClaudeAttachments() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = true
    panel.message = "Choose files or folders from C to attach to the next Claude prompt"
    guard panel.runModal() == .OK else { return }
    addClaudeAttachments(panel.urls)
  }

  func addClaudeAttachments(_ urls: [URL]) {
    let newItems =
      urls
      .filter { FileManager.default.fileExists(atPath: $0.path) }
      .map { url in
        makeAttachment(from: url)
      }
    guard !newItems.isEmpty else {
      statusText = "No local files found · \(Date().shortStamp)"
      return
    }
    claudeAttachments.append(contentsOf: newItems)
    statusText = "\(claudeAttachments.count) Claude attachment(s) ready · \(Date().shortStamp)"
  }

  func addClaudeImageAttachment(data: Data, suggestedExtension: String = "png") {
    let stamp = DateFormatter.attachmentStamp.string(from: Date())
    let ext = suggestedExtension.sanitizedFileName.lowercased()
    let url = attachmentDirectory.appendingPathComponent(
      "pasted-claude-image-\(stamp).\(ext.isEmpty ? "png" : ext)")
    do {
      try data.write(to: url, options: .atomic)
      claudeAttachments.append(makeAttachment(from: url, kind: "image"))
      statusText = "Claude image attached · \(Date().shortStamp)"
    } catch {
      statusText = "Attach failed · \(Date().shortStamp)"
      lastMirrorLog = "Could not save pasted image: \(error.localizedDescription)"
    }
  }

  func removeClaudeAttachment(_ attachment: PromptAttachment) {
    claudeAttachments.removeAll { $0.id == attachment.id }
  }

  func clearClaudeAttachments() {
    claudeAttachments.removeAll()
  }

  func deleteRemoteSelection() async {
    let items = selectedRemoteItems
    guard !items.isEmpty else { return }
    let alert = NSAlert()
    alert.messageText = "Delete from \(settings.remoteLabel)?"
    alert.informativeText =
      "This will remove \(items.count) selected item(s) on \(settings.hostAlias). This cannot be undone from C."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Delete")
    alert.addButton(withTitle: "Cancel")
    guard alert.runModal() == .alertFirstButtonReturn else { return }

    var logs: [String] = []
    for item in items {
      let result = await runRemote("delete-path", input: item.path + "\n", timeout: 60)
      logs.append(result.combined.isEmpty ? "Deleted \(item.path)" : result.combined)
    }
    lastMirrorLog = logs.joined(separator: "\n")
    if let currentOpenedFile = openedRemoteFile,
      items.contains(where: { $0.path == currentOpenedFile })
    {
      openedRemoteFile = nil
      remoteFileText = ""
      remoteFileSavedText = ""
      remotePreviewURL = nil
      remotePreviewKind = .none
    }
    let target = fileBrowserDir.trimmed.isEmpty ? currentRemoteDir : fileBrowserDir
    await loadFileBrowserDirectory(target, force: true, showsActivity: false)
  }

  func saveASelectionToC() async {
    guard hasConfiguredSSHTarget() else { return }
    let items = selectedRemoteItems
    guard !items.isEmpty else { return }
    let saveBaseURL = localSaveBaseURL()
    let saveBase = saveBaseURL.path
    try? FileManager.default.createDirectory(atPath: saveBase, withIntermediateDirectories: true)
    beginFileTransferMode()
    defer { endFileTransferMode() }
    if items.count == 1, let item = items.first, !item.isDirectory {
      let result = await saveRemoteSingleFileFast(item, to: saveBaseURL)
      lastMirrorLog = fileTransferLogText(with: result.combined)
      if result.exitCode == 0 {
        statusText = "Saved to C · \(Date().shortStamp)"
        openLocalFolder(saveBase)
      } else {
        statusText = "Save failed · \(Date().shortStamp)"
      }
      return
    }
    let result = await saveRemoteSelectionFast(items, to: saveBaseURL)
    lastMirrorLog = fileTransferLogText(with: result.combined)
    if result.exitCode == 0 {
      statusText = "Saved to C · \(Date().shortStamp)"
      openLocalFolder(saveBase)
    } else {
      statusText = "Save failed · \(Date().shortStamp)"
    }
  }

  private func saveRemoteSingleFileFast(
    _ item: RemoteItem,
    to saveBaseURL: URL
  ) async -> CommandResult {
    let selectionDescription = item.path
    let destinationURL = uniqueLocalSaveURL(named: item.name, in: saveBaseURL)
    let partialURL = saveBaseURL
      .appendingPathComponent(".\(destinationURL.lastPathComponent).\(UUID().uuidString).partial")
    lastMirrorLog =
      "File save request sent: \(selectionDescription)\nDestination: \(destinationURL.path)\nMode: single rsync transfer, no compression"
    statusText = "Save requested · \(Date().shortStamp)"
    let startedAt = Date()
    isBusy = true
    defer {
      isBusy = false
      try? FileManager.default.removeItem(at: partialURL)
    }
    let transferID = beginTrackedFileTransfer(
      title: "Saving A file",
      source: selectionDescription,
      destination: destinationURL.path,
      totalBytes: max(0, item.size),
      phase: "Preparing"
    )
    let expectedSize =
      item.size > 0
      ? item.size : (await remoteFileSize(at: item.path) ?? 0)
    if expectedSize >= 8 * 1_024 * 1_024 {
      lastMirrorLog =
        "File save request sent: \(selectionDescription)\nDestination: \(destinationURL.path)\nSize: \(Self.fileSizeFormatter.string(fromByteCount: expectedSize))\nMode: single rsync transfer, no compression"
    }
    let transferTimeout = Self.transferTimeout(forByteCount: expectedSize)
    updateTrackedFileTransfer(transferID, phase: "Downloading", totalBytes: expectedSize)
    let progressMonitor = startLocalFileProgressMonitor(
      id: transferID,
      url: partialURL,
      totalBytes: expectedSize
    )
    let result = await downloadRemotePathFastest(
      item.path,
      to: partialURL,
      expectedSize: expectedSize,
      timeout: transferTimeout
    )
    progressMonitor.cancel()
    guard result.exitCode == 0 else {
      finishTrackedFileTransfer(
        transferID,
        succeeded: false,
        message: "Failed: \(selectionDescription) -> \(destinationURL.path)"
      )
      return CommandResult(
        exitCode: result.exitCode,
        output: "",
        error: Self.stoppedTransferMessage(
          title: "save file from A",
          source: selectionDescription,
          destination: destinationURL.path,
          timeout: transferTimeout,
          result: result
        )
      )
    }
    do {
      updateTrackedFileTransfer(transferID, phase: "Verifying", completedBytes: expectedSize)
      try FileManager.default.createDirectory(
        at: saveBaseURL, withIntermediateDirectories: true)
      try FileManager.default.moveItem(at: partialURL, to: destinationURL)
      let size = (try? FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size])
        as? NSNumber
      let sizeText = size.map {
        Self.fileSizeFormatter.string(fromByteCount: $0.int64Value)
      } ?? "unknown size"
      let speedText = size.map {
        Self.transferRateText(
          bytes: $0.int64Value,
          elapsed: Date().timeIntervalSince(startedAt)
        )
      } ?? "unknown speed"
      let modeText =
        expectedSize >= 8 * 1_024 * 1_024
        ? "single rsync transfer, no compression"
        : "single scp transfer, no compression"
      finishTrackedFileTransfer(
        transferID,
        succeeded: true,
        message: "Saved: \(destinationURL.path) · \(sizeText) · \(speedText)"
      )
      return CommandResult(
        exitCode: 0,
        output:
          "Saved: \(destinationURL.path)\nSource: \(selectionDescription)\nSize: \(sizeText)\nSpeed: \(speedText)\nMode: \(modeText)",
        error: result.error
      )
    } catch {
      finishTrackedFileTransfer(
        transferID,
        succeeded: false,
        message: "Save failed after transfer: \(error.localizedDescription)"
      )
      return CommandResult(exitCode: 74, output: "", error: error.localizedDescription)
    }
  }

  private func localSaveBaseURL() -> URL {
    URL(fileURLWithPath: settings.mirrorBase.expandingTilde, isDirectory: true)
      .appendingPathComponent("save", isDirectory: true)
  }

  private func saveRemoteSelectionFast(
    _ items: [RemoteItem],
    to saveBaseURL: URL
  ) async -> CommandResult {
    let stamp = Date().attachmentSafeStamp
    let workspaceURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("acontrol-save-\(UUID().uuidString)", isDirectory: true)
    let archiveURL = workspaceURL.appendingPathComponent("selection.tar")
    let extractURL = workspaceURL.appendingPathComponent("extract", isDirectory: true)
    let selectionDescription =
      items.count == 1 ? items[0].path : "\(items.count) selected item(s)"
    let remoteTempRoot = normalizedRemotePath(
      (settings.remoteHome.trimmed.nilIfEmpty ?? currentRemoteDir)
        + "/.sshcontroll_buffer/tmp"
    )
    let remoteArchive = "\(remoteTempRoot)/acontrol-save-\(UUID().uuidString).tar"
    lastMirrorLog =
      "Folder save request sent: \(selectionDescription)\nDestination: \(saveBaseURL.path)\nMode: remote tar + single rsync transfer, no compression"
    statusText = "Folder save requested · \(Date().shortStamp)"
    let transferID = beginTrackedFileTransfer(
      title: "Saving A selection",
      source: selectionDescription,
      destination: saveBaseURL.path,
      phase: "Preparing archive"
    )
    let startedAt = Date()
    isBusy = true
    defer {
      isBusy = false
      try? FileManager.default.removeItem(at: workspaceURL)
    }

    let pathList = items.map(\.path).joined(separator: "\n") + "\n"
    let mkdir = await runRemote(
      "mkdir-path",
      input: remoteTempRoot + "\n",
      timeout: 30,
      showsActivity: false,
      bypassBackgroundQueue: true
    )
    guard mkdir.exitCode == 0 else {
      finishTrackedFileTransfer(
        transferID,
        succeeded: false,
        message: "Could not prepare A temporary folder: \(remoteTempRoot)"
      )
      return mkdir
    }

    let createRemoteArchiveCommand =
      "\(remoteHelperShellCommand("tar-paths")) > \(remoteArchive.shellQuoted)"
    let createScript = """
      set -o pipefail
      /usr/bin/printf %s \(pathList.shellQuoted) | \(settings.transferSSHShellCommand) \(createRemoteArchiveCommand.shellQuoted)
      """
    lastMirrorLog =
      "Preparing archive on A: \(selectionDescription)\nDestination: \(saveBaseURL.path)\nMode: remote tar + single rsync transfer"
    let create = await client.shell(createScript, timeout: 3600)
    guard create.exitCode == 0 else {
      await deleteRemoteSaveTemporary(remoteArchive)
      finishTrackedFileTransfer(
        transferID,
        succeeded: false,
        message: "Archive preparation failed: \(selectionDescription)"
      )
      return create
    }
    let archiveSize = await remoteFileSize(at: remoteArchive) ?? 0
    let sizeText = Self.fileSizeFormatter.string(fromByteCount: archiveSize)
    updateTrackedFileTransfer(
      transferID,
      phase: "Downloading archive",
      totalBytes: archiveSize
    )
    lastMirrorLog =
      "Archive ready on A: \(selectionDescription)\nArchive size: \(sizeText)\nDownloading with single rsync transfer..."
    try? FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
    let transferTimeout = Self.transferTimeout(forByteCount: archiveSize)
    let progressMonitor = startLocalFileProgressMonitor(
      id: transferID,
      url: archiveURL,
      totalBytes: archiveSize
    )
    let download = await downloadRemotePathFastest(
      remoteArchive,
      to: archiveURL,
      expectedSize: archiveSize,
      timeout: transferTimeout
    )
    progressMonitor.cancel()
    await deleteRemoteSaveTemporary(remoteArchive)
    guard download.exitCode == 0 else {
      finishTrackedFileTransfer(
        transferID,
        succeeded: false,
        message: "Download failed: \(selectionDescription) -> \(saveBaseURL.path)"
      )
      return CommandResult(
        exitCode: download.exitCode,
        output: "",
        error: Self.stoppedTransferMessage(
          title: "save archive from A",
          source: selectionDescription,
          destination: saveBaseURL.path,
          timeout: transferTimeout,
          result: download
        )
      )
    }

    let extractScript = """
      rm -rf \(extractURL.path.shellQuoted)
      mkdir -p \(extractURL.path.shellQuoted) \(saveBaseURL.path.shellQuoted)
      COPYFILE_DISABLE=1 /usr/bin/tar -xf \(archiveURL.path.shellQuoted) -C \(extractURL.path.shellQuoted)
      """
    let extract = await client.shell(extractScript, timeout: 3600)
    guard extract.exitCode == 0 else {
      finishTrackedFileTransfer(
        transferID,
        succeeded: false,
        message: "Extract failed: \(selectionDescription)"
      )
      return extract
    }

    do {
      updateTrackedFileTransfer(transferID, phase: "Saving locally", completedBytes: archiveSize)
      let destinationURL: URL
      if items.count == 1, let item = items.first {
        let base = item.name.sanitizedFileName.trimmed.isEmpty
          ? "A-folder" : item.name.sanitizedFileName
        let destinationName = item.isDirectory ? "\(base)-\(stamp)" : base
        let extractedURL = extractURL.appendingPathComponent(item.name, isDirectory: item.isDirectory)
        guard FileManager.default.fileExists(atPath: extractedURL.path) else {
          return CommandResult(
            exitCode: 74,
            output: "",
            error: "A transfer completed, but \(item.name) was not found in the extracted folder.")
        }
        destinationURL = uniqueLocalSaveURL(named: destinationName, in: saveBaseURL)
        try FileManager.default.moveItem(at: extractedURL, to: destinationURL)
      } else {
        destinationURL = uniqueLocalSaveURL(named: "A-selection-\(stamp)", in: saveBaseURL)
        try FileManager.default.moveItem(at: extractURL, to: destinationURL)
      }
      let localBytes = Self.localByteCount(at: destinationURL)
      finishTrackedFileTransfer(
        transferID,
        succeeded: true,
        message:
          "Saved: \(destinationURL.path) · \(Self.fileSizeFormatter.string(fromByteCount: localBytes))"
      )
      return CommandResult(
        exitCode: 0,
        output:
          "Saved: \(destinationURL.path)\nSource: \(selectionDescription)\nSize: \(Self.fileSizeFormatter.string(fromByteCount: localBytes))\nArchive: \(sizeText)\nSpeed: \(Self.transferRateText(bytes: archiveSize > 0 ? archiveSize : localBytes, elapsed: Date().timeIntervalSince(startedAt)))\nMode: remote tar + single rsync transfer, no compression",
        error: [create.error, download.error, extract.error].filter { !$0.isEmpty }.joined(separator: "\n")
      )
    } catch {
      finishTrackedFileTransfer(
        transferID,
        succeeded: false,
        message: "Save failed after archive download: \(error.localizedDescription)"
      )
      return CommandResult(exitCode: 74, output: "", error: error.localizedDescription)
    }
  }

  private func remoteHelperShellCommand(
    _ action: String,
    args: [String] = [],
    environment: [String: String]? = nil
  ) -> String {
    let remoteEnvironment = environment ?? activeRemoteEnvironment
    let dynamicEnvironment = remoteEnvironment.keys.sorted()
      .compactMap { key -> String? in
        guard let value = remoteEnvironment[key], !value.trimmed.isEmpty else { return nil }
        return "\(key)=\(value.shellQuoted)"
      }
      .joined(separator: " ")
    let environmentPrefix = [settings.remoteToolEnvironment.trimmed, dynamicEnvironment]
      .filter { !$0.isEmpty }
      .joined(separator: " ")
    let commandArgs = args.map(\.shellQuoted).joined(separator: " ")
    return "\(environmentPrefix.isEmpty ? "" : environmentPrefix + " ")\(settings.remoteScript) \(action)\(commandArgs.isEmpty ? "" : " " + commandArgs)"
  }

  private func uniqueLocalSaveURL(named name: String, in directory: URL) -> URL {
    let safeName = name.sanitizedFileName.trimmed.isEmpty ? "download.zip" : name.sanitizedFileName
    let baseURL = directory.appendingPathComponent(safeName, isDirectory: false)
    guard FileManager.default.fileExists(atPath: baseURL.path) else { return baseURL }
    let ext = baseURL.pathExtension
    let stem = baseURL.deletingPathExtension().lastPathComponent
    for index in 2...999 {
      let candidateName = ext.isEmpty ? "\(stem)-\(index)" : "\(stem)-\(index).\(ext)"
      let candidate = directory.appendingPathComponent(candidateName, isDirectory: false)
      if !FileManager.default.fileExists(atPath: candidate.path) {
        return candidate
      }
    }
    return directory.appendingPathComponent(
      "\(stem)-\(Date().attachmentSafeStamp)\(ext.isEmpty ? "" : ".\(ext)")",
      isDirectory: false
    )
  }

  func mirrorFull() async {
    guard hasConfiguredSSHTarget() else { return }
    let target = settings.mirrorBase.expandingTilde + "/mirror"
    let remote = settings.remoteSpec(currentRemoteDir + "/")
    let script = """
      mkdir -p \(target.shellQuoted)
      /usr/bin/rsync -a --delete --partial --inplace --whole-file --stats --itemize-changes -e \(settings.rsyncSSHCommand.shellQuoted) \(remote.shellQuoted) \(target.shellQuoted)/
      """
    isBusy = true
    lastMirrorLog = "Full mirror started: \(currentRemoteDir) -> \(target)"
    statusText = "Mirror full started · \(Date().shortStamp)"
    let result = await client.shell(script, timeout: 7200)
    isBusy = false
    lastMirrorLog = result.combined.isEmpty ? "Full mirror complete: \(target)" : result.combined
    statusText =
      result.exitCode == 0
      ? "Mirror full done · \(Date().shortStamp)" : "Mirror full error · \(Date().shortStamp)"
    openLocalFolder(target)
  }

  func mirrorDelta() async {
    guard hasConfiguredSSHTarget() else { return }
    let target = settings.mirrorBase.expandingTilde + "/mirror"
    try? FileManager.default.createDirectory(atPath: target, withIntermediateDirectories: true)
    let remote = settings.remoteSpec(currentRemoteDir + "/")
    let script =
      "/usr/bin/rsync -a --delete --partial --inplace --whole-file --stats --itemize-changes -e \(settings.rsyncSSHCommand.shellQuoted) \(remote.shellQuoted) \(target.shellQuoted)/"
    isBusy = true
    lastMirrorLog = "Delta mirror started: \(currentRemoteDir) -> \(target)"
    statusText = "Mirror delta started · \(Date().shortStamp)"
    let result = await client.shell(script, timeout: 7200)
    isBusy = false
    lastMirrorLog = result.combined.isEmpty ? "Delta mirror complete: \(target)" : result.combined
    statusText =
      result.exitCode == 0
      ? "Mirror delta done · \(Date().shortStamp)" : "Mirror delta error · \(Date().shortStamp)"
    openLocalFolder(target)
  }

  @discardableResult
  func addSession(name: String, path: String, tool: AISessionTool = .codex) -> SessionCard {
    var card = SessionCard(name: name, remoteDir: path, tool: tool)
    card.codexState = .fresh
    card.codexHistoryID = ""
    card.codexHistoryPath = ""
    card.codexHistoryTitle = ""
    card.nameSource = name.trimmed.isEmpty ? .generated : .user
    card.updatedAt = Date()
    sessions.insert(card, at: 0)
    activeSessionID = card.id
    codexWorkingSessionIDs.remove(card.id)
    claudeWorkingSessionIDs.remove(card.id)
    syncCombinedWorkingSessions()
    saveWorkingSessionIDs()
    let folder = sessionDirectory(for: card.id.uuidString)
    try? FileManager.default.removeItem(at: folder)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    loadCachedTranscriptsForActiveSession()
    saveSessions()
    return card
  }

  func openSession(
    _ session: SessionCard, initialTool: AISessionTool? = nil, syncShell: Bool = true
  ) async {
    let wasActive = activeSessionID == session.id
    let previousRemoteDir = currentRemoteDir
    let remoteDirChanged =
      normalizedRemotePath(previousRemoteDir) != normalizedRemotePath(session.remoteDir)
    activeSessionID = session.id
    currentRemoteDir = session.remoteDir
    loadCachedTranscriptsForActiveSession()
    let shouldSave = !wasActive
    if syncShell, !wasActive || remoteDirChanged {
      let result = await runRemote("shell-cd", input: session.remoteDir + "\n", timeout: 30)
      shellTranscript = result.combined
    }
    if !wasActive || remoteDirChanged || remoteItems.isEmpty {
      await loadDirectory(session.remoteDir)
    }
    switch initialTool {
    case .some(.codex):
      selectedSurface = .codex
      await openCodexForActiveSession()
    case .some(.claude):
      selectedSurface = .claude
      await openClaudeForActiveSession()
    case .none:
      switch selectedSurface {
      case .codex:
        await openCodexForActiveSession()
      case .claude:
        await openClaudeForActiveSession()
      default:
        break
      }
    }
    if codexPromptQueue.contains(where: { $0.sessionID == session.id && $0.status == .queued }) {
      processCodexPromptQueue()
    }
    if shouldSave {
      saveSessions()
    }
  }

  private func openCodexForActiveSession() async {
    if let session = activeSession, !session.codexHistoryID.trimmed.isEmpty {
      await resumeCodexHistory(
        CodexHistoryRecord(
          id: session.codexHistoryID,
          cwd: session.remoteDir,
          path: session.codexHistoryPath,
          mtime: Int(session.updatedAt.timeIntervalSince1970),
          title: session.codexHistoryTitle,
          host: session.codexHistoryHost
        )
      )
    } else {
      guard let session = activeSession, activeCodexConversationIsEstablished else {
        markActiveSessionWorking(false, tool: .codex)
        setCodexTranscript("", force: true)
        clearCodexDerivedState()
        statusText = "Codex ready · \(Date().shortStamp)"
        return
      }
      if session.codexState == .running {
        await captureCodex()
      } else {
        statusText = "Codex ready · \(Date().shortStamp)"
      }
    }
  }

  private func openClaudeForActiveSession() async {
    guard activeClaudeConversationIsEstablished else {
      statusText = "Claude ready · \(Date().shortStamp)"
      return
    }
    await captureClaude()
  }

  func renameSession(_ session: SessionCard, to name: String) {
    let trimmed = name.trimmed
    guard !trimmed.isEmpty, let index = sessions.firstIndex(where: { $0.id == session.id }) else {
      return
    }
    sessions[index].name = trimmed
    sessions[index].nameSource = .user
    sessions[index].updatedAt = Date()
    saveSessions()
  }

  func deleteSession(_ session: SessionCard) async {
    let historyID = session.codexHistoryID.trimmed
    if !historyID.isEmpty {
      tombstoneCodexHistoryID(historyID)
      codexHistoryRecords.removeAll { $0.id == historyID }
    }
    let wasActive = activeSessionID == session.id
    sessions.removeAll { $0.id == session.id }
    workingSessionIDs.remove(session.id)
    codexWorkingSessionIDs.remove(session.id)
    claudeWorkingSessionIDs.remove(session.id)
    saveWorkingSessionIDs()
    try? FileManager.default.removeItem(at: sessionDirectory(for: session.id.uuidString))
    if wasActive {
      activeSessionID = sessions.first?.id
      if let activeSession {
        currentRemoteDir = activeSession.remoteDir
      }
      loadCachedTranscriptsForActiveSession()
    }
    saveSessions()
    statusText = "Session deleted locally · \(Date().shortStamp)"
    if !historyID.isEmpty {
      let result = await runRemote(
        "codex-history-delete",
        args: [historyID],
        input: session.codexHistoryPath + "\n",
        timeout: 60,
        showsActivity: false
      )
      statusText =
        result.exitCode == 0
        ? "Session deleted · \(Date().shortStamp)"
        : "Session hidden locally · Codex delete blocked · \(Date().shortStamp)"
    }
  }

  func openSessionFolder(_ session: SessionCard) {
    let folder = sessionDirectory(for: session.id.uuidString)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    NSWorkspace.shared.open(folder)
  }

  func openActiveTranscriptFolder() {
    let folder = activeSessionDirectory()
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    NSWorkspace.shared.open(folder)
    statusText = "Transcript folder opened · \(Date().shortStamp)"
  }

  func copyActiveCodexTranscript() {
    let value = codexTranscript.trimmed
    guard !value.isEmpty else {
      statusText = "Transcript is empty · \(Date().shortStamp)"
      return
    }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
    statusText = "Transcript copied · \(Date().shortStamp)"
  }

  func openLocalFolder(_ path: String) {
    NSWorkspace.shared.open(URL(fileURLWithPath: path.expandingTilde, isDirectory: true))
  }

  func chooseSSHKeyFile() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
      ".ssh", isDirectory: true)
    panel.message = "Choose the private SSH key SSHcontroll should use."
    guard panel.runModal() == .OK, let url = panel.url else { return }
    settings.sshIdentityFile = url.path
    saveSettings()
  }

  func installRemoteHelper() async {
    guard settings.hasSSHTarget else {
      statusText = "Add SSH target · \(Date().shortStamp)"
      lastMirrorLog = "Add an SSH target in Settings before installing the remote helper."
      return
    }
    guard let helperURL = bundledRemoteHelperURL(),
      FileManager.default.fileExists(atPath: helperURL.path)
    else {
      statusText = "Helper missing · \(Date().shortStamp)"
      lastMirrorLog = "Could not find bundled remote helper."
      return
    }

    let target =
      settings.remoteScript.trimmed.isEmpty
      ? "~/.local/bin/a-cockpit-remote" : settings.remoteScript.trimmed
    let installTarget = remoteShellPath(target)
    let scpTarget = remoteScpPath(target)
    let targetDirectory = remoteDirectory(containing: installTarget)
    let mkdirRemote = "mkdir -p \(targetDirectory.shellQuoted)"
    let chmodRemote = "chmod 755 \(installTarget.shellQuoted)"
    let script = """
      \(settings.sshShellCommand) \(mkdirRemote.shellQuoted)
      \(settings.scpShellCommand) \(helperURL.path.shellQuoted) \(settings.remoteSpec(scpTarget).shellQuoted)
      \(settings.sshShellCommand) \(chmodRemote.shellQuoted)
      """

    isBusy = true
    statusText = "Installing helper · \(Date().shortStamp)"
    let result = await client.shell(script, timeout: 120)
    isBusy = false
    lastMirrorLog =
      result.combined.isEmpty ? "Remote helper installed at \(target)" : result.combined
    statusText =
      result.exitCode == 0
      ? "Helper installed · \(Date().shortStamp)" : "Helper install failed · \(Date().shortStamp)"
    if result.exitCode == 0 {
      await refreshDashboard()
    }
  }

  private func bundledRemoteHelperURL() -> URL? {
    if let bundled = Bundle.main.url(forResource: "a-cockpit-remote", withExtension: nil) {
      return bundled
    }
    let workingDirectory = URL(
      fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    let candidates = [
      workingDirectory.appendingPathComponent("Remote/a-cockpit-remote"),
      workingDirectory.deletingLastPathComponent().appendingPathComponent(
        "Remote/a-cockpit-remote"),
    ]
    return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
  }

  private func remoteDirectory(containing path: String) -> String {
    let trimmed = path.trimmed
    guard let slash = trimmed.lastIndex(of: "/") else { return "." }
    let directory = String(trimmed[..<slash])
    return directory.isEmpty ? "/" : directory
  }

  private func remoteShellPath(_ path: String) -> String {
    let trimmed = path.trimmed
    let remoteHome = settings.remoteHome.trimmed
    if trimmed == "~" {
      return remoteHome.hasPrefix("/") ? remoteHome : "$HOME"
    }
    if trimmed.hasPrefix("~/") {
      return (remoteHome.hasPrefix("/") ? remoteHome : "$HOME") + "/" + trimmed.dropFirst(2)
    }
    return trimmed
  }

  private func remoteScpPath(_ path: String) -> String {
    remoteShellPath(path)
  }

  private func hasConfiguredSSHTarget() -> Bool {
    guard settings.hasSSHTarget else {
      statusText = "Add SSH target · \(Date().shortStamp)"
      lastMirrorLog = "Add an SSH target in Settings before using remote file transfer."
      return false
    }
    return true
  }

  private func discoveredToolPath(in text: String, tool: String) -> String? {
    let key = tool == "codex" ? "codex_bin:" : "claude_bin:"
    for line in text.components(separatedBy: .newlines) {
      let trimmed = line.trimmed
      guard trimmed.hasPrefix(key) else { continue }
      let path = trimmed.dropFirst(key.count).trimmingCharacters(in: .whitespaces)
      if !path.isEmpty, path != "missing" {
        return path
      }
    }
    return nil
  }

  private func redactedPermissionOutput(_ text: String) -> String {
    let teamID = settings.appleDevelopmentTeamID.trimmed
    return
      text
      .components(separatedBy: .newlines)
      .map { line in
        let lower = line.lowercased()
        if lower.hasPrefix("host:") {
          return "Host: hidden  GUI user: hidden"
        }
        var redacted =
          line
          .replacingOccurrences(
            of: #"/Users/[^/\s]+"#,
            with: "/Users/[hidden]",
            options: .regularExpression
          )
          .replacingOccurrences(
            of: #"/home/[^/\s]+"#,
            with: "/home/[hidden]",
            options: .regularExpression
          )
          .replacingOccurrences(
            of: #"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#,
            with: "[hidden]",
            options: [.regularExpression, .caseInsensitive]
          )
        if !teamID.isEmpty {
          redacted = redacted.replacingOccurrences(of: teamID, with: "[team]")
        }
        return redacted
      }
      .joined(separator: "\n")
  }

  private func concisePermissionOutput(_ text: String) -> String {
    let allowedPrefixes = [
      "A-Cockpit Permission Host.app:",
      "Codex CLI Permission Host.app:",
      "Bundle id:",
      "macOS permission bridge:",
      "Screen capture via Codex CLI Permission Host:",
      "Codex.app:",
      "Screen capture via Permission Host:",
      "Accessibility/System Events via Permission Host:",
      "CoreSimulator/simctl via Permission Host:",
      "ADB via Permission Host:",
      "Overall:",
    ]
    let lines = text.components(separatedBy: .newlines)
      .map(\.trimmed)
      .filter { line in
        allowedPrefixes.contains { line.hasPrefix($0) }
      }
    let summary =
      lines.isEmpty
      ? "A permissions OK. Stable Permission Host is ready."
      : lines.joined(separator: "\n")
    return redactedPermissionOutput(summary)
  }

  private func promptWithUploadedCodexAttachments(
    base: String,
    attachments: [PromptAttachment]? = nil,
    session: SessionCard? = nil,
    directory: String? = nil,
    environment: [String: String]? = nil
  ) async -> String? {
    let promptAttachments = attachments ?? codexAttachments
    guard !promptAttachments.isEmpty else { return base }
    let uploaded = await uploadAttachmentsForPrompt(
      promptAttachments,
      session: session,
      directory: directory,
      environment: environment
    )
    guard !uploaded.isEmpty else { return nil }
    return promptWithUploadedAttachmentList(base: base, uploaded: uploaded)
  }

  private func promptWithUploadedClaudeAttachments(base: String) async -> String? {
    guard !claudeAttachments.isEmpty else { return base }
    let uploaded = await uploadAttachmentsForPrompt(claudeAttachments)
    guard !uploaded.isEmpty else { return nil }
    return promptWithUploadedAttachmentList(base: base, uploaded: uploaded)
  }

  private func promptWithUploadedAttachmentList(base: String, uploaded: [PromptAttachment])
    -> String
  {
    let remotePaths = uploaded.compactMap(\.remotePath)
    guard let bufferDir = remotePaths.first.map(remoteDirectory(containing:)) else { return base }
    let fileLines =
      uploaded
      .map { attachment in
        let remotePath = attachment.remotePath ?? "\(bufferDir)/\(attachment.name.sanitizedFileName)"
        return """
          - name: \(attachment.name)
            kind: \(attachment.kind)
            path: \(remotePath)
          """
      }
      .joined(separator: "\n")
    let lookupHint = """
      <sshcontroll_attachments>
      A-side buffer_dir: \(bufferDir)
      Use these exact A-side absolute paths for the attached files. Do not use bare filenames.
      \(fileLines)
      rules: Inspect files directly from the exact path when needed. For images, open/read the path shown above exactly. Do not quote/paste raw file contents or remote paths into the visible answer. Summarize only the useful result and refer to file names. Do not use clipboard APIs.
      </sshcontroll_attachments>
      """
    let request =
      base.trimmed.isEmpty
      ? "The user attached file(s). Inspect the A-side buffer and briefly confirm what is available."
      : base
    return """
      \(request)

      \(lookupHint)
      """
  }

  private func uploadAttachmentsForPrompt(
    _ attachments: [PromptAttachment],
    session: SessionCard? = nil,
    directory: String? = nil,
    environment: [String: String]? = nil
  ) async
    -> [PromptAttachment]
  {
    guard hasConfiguredSSHTarget() else { return [] }
    let stamp = DateFormatter.attachmentStamp.string(from: Date())
    let baseDir =
      directory?.trimmed.nilIfEmpty
      ?? session?.remoteDir.trimmed.nilIfEmpty
      ?? activeSession?.remoteDir.trimmed.nilIfEmpty
      ?? currentRemoteDir
    let targetDir = "\(normalizedRemotePath(baseDir))/.sshcontroll_buffer/attachments/\(stamp)"
    let mkdir = await runRemote(
      "mkdir-path",
      input: targetDir + "\n",
      timeout: 30,
      environmentOverride: environment
    )
    guard mkdir.exitCode == 0 else {
      lastMirrorLog = mkdir.combined
      return []
    }

    let uploadNames = uniqueAttachmentUploadNames(for: attachments)
    let stagingURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("acontrol-attachments-\(UUID().uuidString)", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: stagingURL, withIntermediateDirectories: true)
      for attachment in attachments {
        let uploadName = uploadNames[attachment.id] ?? attachment.uploadName
        let destinationURL = stagingURL.appendingPathComponent(uploadName)
        try FileManager.default.copyItem(at: attachment.localURL, to: destinationURL)
      }
    } catch {
      try? FileManager.default.removeItem(at: stagingURL)
      lastMirrorLog = "Attachment staging failed: \(error.localizedDescription)"
      return []
    }
    defer {
      try? FileManager.default.removeItem(at: stagingURL)
    }
    let totalBytes = Self.localByteCount(at: stagingURL)
    let startedAt = Date()
    beginFileTransferMode()
    isBusy = true
    defer {
      isBusy = false
      endFileTransferMode()
    }
    let transferID = beginTrackedFileTransfer(
      title: "Uploading attachments",
      source: "\(attachments.count) prompt attachment(s)",
      destination: targetDir,
      totalBytes: totalBytes,
      phase: "Preparing"
    )
    statusText = "Uploading attachment(s) to A · \(Date().shortStamp)"
    lastMirrorLog =
      "Uploading \(attachments.count) prompt attachment(s) to \(targetDir)\nMode: local tar + single rsync transfer, no compression"
    let result = await uploadLocalSelectionViaFastArchive(
      paths: [stagingURL.path + "/."],
      to: targetDir,
      label: "\(attachments.count) prompt attachment(s)",
      progressID: transferID
    )
    guard result.exitCode == 0 else {
      finishTrackedFileTransfer(
        transferID,
        succeeded: false,
        message: "Attachment upload failed: \(attachments.count) item(s) -> \(targetDir)"
      )
      lastMirrorLog = fileTransferLogText(with: result.combined)
      return []
    }

    let uploaded = attachments.map { attachment in
      var copy = attachment
      copy.remotePath = "\(targetDir)/\(uploadNames[attachment.id] ?? attachment.uploadName)"
      return copy
    }
    let summary =
      "Uploaded \(uploaded.count) prompt attachment(s) to \(targetDir)\nSize: \(Self.fileSizeFormatter.string(fromByteCount: totalBytes))\nSpeed: \(Self.transferRateText(bytes: totalBytes, elapsed: Date().timeIntervalSince(startedAt)))\nMode: local tar + single rsync transfer, no compression"
    finishTrackedFileTransfer(
      transferID,
      succeeded: true,
      message:
        "Uploaded attachments: \(uploaded.count) item(s) -> \(targetDir) · \(Self.fileSizeFormatter.string(fromByteCount: totalBytes))"
    )
    lastMirrorLog =
      fileTransferLogText(with: summary)
    return uploaded
  }

  private func uniqueAttachmentUploadNames(for attachments: [PromptAttachment]) -> [UUID: String] {
    var used = Set<String>()
    var names: [UUID: String] = [:]
    for attachment in attachments {
      let baseName = attachment.name.sanitizedFileName
      let uploadName = uniqueAttachmentUploadName(baseName, used: &used)
      names[attachment.id] = uploadName
    }
    return names
  }

  private func uniqueAttachmentUploadName(_ baseName: String, used: inout Set<String>) -> String {
    let safeName = baseName.trimmed.isEmpty ? "attachment" : baseName
    var candidate = safeName
    var index = 2
    let url = URL(fileURLWithPath: safeName)
    let ext = url.pathExtension
    let stem =
      ext.isEmpty
      ? safeName
      : String(safeName.dropLast(ext.count + 1))
    while used.contains(candidate) {
      candidate = ext.isEmpty ? "\(stem)-\(index)" : "\(stem)-\(index).\(ext)"
      index += 1
    }
    used.insert(candidate)
    return candidate
  }

  private func makeAttachment(from url: URL, kind explicitKind: String? = nil) -> PromptAttachment {
    let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
    let isDirectory = resourceValues?.isDirectory == true
    let size = Int64(resourceValues?.fileSize ?? 0)
    let ext = url.pathExtension.lowercased()
    let kind =
      explicitKind
      ?? (isDirectory
        ? "folder"
        : (["png", "jpg", "jpeg", "gif", "heic", "tif", "tiff", "bmp", "webp"].contains(ext)
          ? "image" : "file"))
    return PromptAttachment(
      localURL: url,
      remotePath: nil,
      name: url.lastPathComponent,
      size: size,
      kind: kind
    )
  }

  private func linkActiveCodexHistoryIfPresent(in text: String) {
    for line in recentText(text, maxCharacters: 20_000).components(separatedBy: .newlines) {
      let trimmedLine = line.trimmed
      guard trimmedLine.lowercased().hasPrefix("codex_history_id:") else { continue }
      let value = String(trimmedLine.dropFirst("codex_history_id:".count)).trimmed
      guard !value.isEmpty else { continue }
      let record = codexHistoryRecords.first { $0.id == value }
      updateActiveCodexHistory(
        id: value,
        path: record?.path ?? "",
        title: record?.title ?? "",
        host: record?.normalizedHost ?? "remote",
        updatedAt: (record?.mtime ?? 0) > 0
          ? Date(timeIntervalSince1970: TimeInterval(record?.mtime ?? 0))
          : nil
      )
      return
    }
  }

  private func linkNewestCodexHistory(
    for sessionID: UUID,
    knownHistoryIDs: Set<String>,
    sentAt: Date,
    targetDir: String
  ) async {
    guard let targetSession = sessionSnapshot(for: sessionID) else { return }
    guard targetSession.codexHistoryID.trimmed.isEmpty else { return }
    let normalizedTargetDir = normalizedRemotePath(targetDir)
    let threshold = sentAt.addingTimeInterval(-6)
    for attempt in 0..<14 {
      await refreshCodexHistory(force: true)
      let matching = codexHistoryRecords.filter { record in
        normalizedRemotePath(record.cwd.trimmed.isEmpty ? normalizedTargetDir : record.cwd)
          == normalizedTargetDir
          && !isCodexHistoryTombstoned(record.id)
      }
      let selected =
        matching.first { !knownHistoryIDs.contains($0.id) }
        ?? matching.first { record in
          record.mtime > 0
            && Date(timeIntervalSince1970: TimeInterval(record.mtime)) >= threshold
        }
      if let selected {
        updateCodexHistory(
          for: sessionID,
          id: selected.id,
          path: selected.path,
          title: selected.title,
          host: selected.normalizedHost,
          updatedAt: max(
            sentAt,
            selected.mtime > 0
              ? Date(timeIntervalSince1970: TimeInterval(selected.mtime))
              : sentAt)
        )
        return
      }
      guard attempt < 13 else { break }
      try? await Task.sleep(nanoseconds: 600_000_000)
    }
  }

  private func recentText(_ value: String, maxCharacters: Int) -> String {
    guard value.count > maxCharacters else { return value }
    return String(value.suffix(maxCharacters))
  }

  private func extractCodexArtifacts(from text: String) -> [CodexArtifact] {
    let source = recentText(text, maxCharacters: 140_000)
    let extensions =
      #"png|jpe?g|gif|heic|tiff?|bmp|webp|mp4|mov|m4v|webm|avi|mkv|pdf|md|txt|json|ya?ml|csv|html|log|apk|ipa|pkg|dmg|zip|tar|tgz|gz|app|exe|msi|swift|dart|kt|java|gradle|properties|plist|xcconfig|xcodeproj|xcworkspace|py|js|ts|tsx|jsx|css|scss|xml|toml|rs|go|c|cc|cpp|h|hpp"#
    let absolutePattern =
      #"(?:(?:~)|(?:/Users/[A-Za-z0-9._-]+)|(?:/private/tmp)|(?:/tmp))[^ \t\r\n"'<>|()\[\]]*\.(?:\#(extensions))"#
    let relativePattern =
      #"(?:(?:build_outputs)|(?:screenshots)|(?:artifacts)|(?:dist)|(?:release)|(?:releases)|(?:reports)|(?:research_reports)|(?:research_loops)|(?:final_deliverables)|(?:outputs)|(?:precomputed_cache)|(?:gui_app)|(?:tools)|(?:tmp)|(?:test-results)|(?:coverage)|(?:\.acontrol_attachments)|(?:\.sshcontroll_buffer))/[^ \t\r\n"'<>|()\[\]]*\.(?:\#(extensions))"#
    let regexes = [absolutePattern, relativePattern].compactMap {
      try? NSRegularExpression(pattern: $0, options: [.caseInsensitive])
    }
    var ordered: [CodexArtifact] = []
    var seen: Set<String> = []

    func addArtifact(_ rawPath: String, sourceLine: String) {
      let path = normalizeArtifactPath(rawPath)
      guard !path.isEmpty, !seen.contains(path) else { return }
      seen.insert(path)
      ordered.append(
        CodexArtifact(path: path, kind: artifactKind(for: path), sourceLine: sourceLine.trimmed))
    }

    for line in source.components(separatedBy: .newlines) {
      let lowerLine = line.lowercased()
      if lowerLine.contains("/bin/java ") || lowerLine.contains("gradledaemon")
        || lowerLine.contains("kotlincompiledaemon") || lowerLine.contains("/.gradle/caches/")
        || lowerLine.contains("dartaotruntime") || lowerLine.contains("frontend_server")
        || lowerLine.contains("/.dart_tool/") || lowerLine.contains("/build/unit_test_assets/")
        || lowerLine.contains("flutter_tester") || lowerLine.contains("--packages=")
        || lowerLine.contains("/bin/cache/") || lowerLine.contains("/.pub-cache/")
        || lowerLine.contains("$stamp") || lowerLine.contains("$safe_device")
        || lowerLine.contains("${") || lowerLine.contains("%s.") || lowerLine.contains("*.")
      {
        continue
      }
      let nsRange = NSRange(line.startIndex..., in: line)
      for regex in regexes {
        for match in regex.matches(in: line, range: nsRange) {
          guard let range = Range(match.range, in: line) else { continue }
          addArtifact(String(line[range]), sourceLine: line)
        }
      }
      for candidate in artifactCandidates(in: line, extensions: extensions) {
        addArtifact(candidate, sourceLine: line)
      }
    }
    return Array(ordered.suffix(18))
  }

  private func artifactCandidates(in line: String, extensions: String) -> [String] {
    let stripped =
      line
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: #"^[-•*]\s+"#, with: "", options: .regularExpression)
      .replacingOccurrences(
        of:
          #"^(?:코드\s*반영\s*파일|변경\s*파일|생성\s*파일|갱신\s*파일|검증|파일|산출물|files?|outputs?|artifacts?|reports?)\s*[:：]\s*"#,
        with: "",
        options: [.regularExpression, .caseInsensitive]
      )
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !stripped.isEmpty else { return [] }

    let barePattern =
      #"(^|[\s:：,;()\[\]<>`"'•*\-])([A-Za-z0-9][A-Za-z0-9._@+\-]{0,140}\.(?:\#(extensions)))(?=$|[\s,;:：)\]}>`"'])"#
    guard
      let regex = try? NSRegularExpression(pattern: barePattern, options: [.caseInsensitive])
    else { return [] }
    let range = NSRange(stripped.startIndex..., in: stripped)
    return regex.matches(in: stripped, range: range).compactMap { match in
      guard match.numberOfRanges > 2, let swiftRange = Range(match.range(at: 2), in: stripped)
      else { return nil }
      return String(stripped[swiftRange])
    }
  }

  private func normalizeArtifactPath(_ value: String) -> String {
    guard !value.contains("*"), !value.contains("$"), !value.contains("${"),
      !value.contains("$("), !value.contains("%s")
    else {
      return ""
    }
    var path = value.trimmingCharacters(
      in: CharacterSet(charactersIn: " \t\r\n\"'`<>[]{}(),.;:"))
    if let marker = path.range(of: "](") {
      path = String(path[marker.upperBound...])
    }
    guard !path.isEmpty else { return "" }
    while path.contains("//") {
      path = path.replacingOccurrences(of: "//", with: "/")
    }
    let lowerPath = path.lowercased()
    guard !lowerPath.contains("/.tools/"), !lowerPath.contains("/.gradle/"),
      !lowerPath.contains("/.dart_tool/"), !lowerPath.contains("/build/unit_test_assets/"),
      !lowerPath.contains("/bin/cache/"), !lowerPath.contains("/.pub-cache/"),
      !lowerPath.contains("flutter_tester"),
      !lowerPath.contains("docs.gradle.org/"),
      !lowerPath.contains("/library/application support/kotlin/")
    else { return "" }
    let name = URL(fileURLWithPath: path).lastPathComponent
    guard !name.hasPrefix(".") else { return "" }
    let lowerName = name.lowercased()
    guard !lowerName.contains("flutter_macos"),
      !(lowerName.hasPrefix("gradle-") && lowerName.hasSuffix(".zip")),
      !lowerName.contains("$stamp"), !lowerName.contains("$safe_device"),
      !lowerName.contains("%s.")
    else { return "" }
    if path == "~" {
      return settings.remoteHome
    }
    if path.hasPrefix("~/") {
      return normalizedRemotePath(settings.remoteHome + "/" + String(path.dropFirst(2)))
    }
    if path.hasPrefix("/") {
      return normalizedRemotePath(path)
    }
    return normalizedRemotePath(currentRemoteDir + "/" + path)
  }

  private func artifactKind(for path: String) -> CodexArtifact.Kind {
    let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
    if ["png", "jpg", "jpeg", "gif", "heic", "tif", "tiff", "bmp", "webp"].contains(ext) {
      return .image
    }
    if ["mp4", "mov", "m4v", "webm", "avi", "mkv"].contains(ext) {
      return .video
    }
    if [
      "md", "txt", "json", "yaml", "yml", "csv", "html", "pdf", "swift", "dart", "kt", "java",
      "gradle", "properties", "plist", "xcconfig", "py", "js", "ts", "tsx", "jsx", "css", "scss",
      "xml", "toml", "rs", "go", "c", "cc", "cpp", "h", "hpp",
    ].contains(ext) {
      return .report
    }
    if ["apk", "ipa", "pkg", "dmg", "app", "exe", "msi"].contains(ext) {
      return .package
    }
    if ["zip", "tar", "tgz", "gz"].contains(ext) {
      return .archive
    }
    if ext == "log" {
      return .log
    }
    return .other
  }

  private func updateCodexTokens(from text: String) {
    let cleaned =
      recentText(text, maxCharacters: 80_000)
      .replacingOccurrences(
        of: "\u{001B}\\[[0-9;?]*[ -/]*[@-~]", with: "", options: .regularExpression
      )
      .replacingOccurrences(of: "█", with: "")
      .replacingOccurrences(of: "░", with: "")
      .replacingOccurrences(of: "▒", with: "")
      .replacingOccurrences(of: "▓", with: "")
    let latestStatus: String
    if let range = cleaned.range(of: "Model:", options: .backwards) {
      latestStatus = String(cleaned[range.lowerBound...])
    } else {
      latestStatus = cleaned
    }
    let mainLimitBlock =
      latestStatus
      .components(separatedBy: "GPT-5.3-Codex-Spark limit:")
      .first ?? latestStatus
    var resetParts: [String] = []
    if let match = firstMatch(
      in: mainLimitBlock, pattern: #"5h limit:[\s\S]*?([0-9]+)% left[\s\S]*?\(resets ([^)]+)\)"#)
    {
      codexToken5h = "\(match[0])% left"
      if match.count > 1, !match[1].isEmpty {
        resetParts.append("5hr resets \(match[1])")
      }
    } else if let match = firstMatch(
      in: mainLimitBlock, pattern: #"5h limit:[\s\S]*?([0-9]+)% left"#)
    {
      codexToken5h = "\(match[0])% left"
    }
    if let match = firstMatch(
      in: mainLimitBlock, pattern: #"Weekly limit:[\s\S]*?([0-9]+)% left[\s\S]*?\(resets ([^)]+)\)"#
    ) {
      codexTokenWeekly = "\(match[0])% left"
      if match.count > 1, !match[1].isEmpty {
        resetParts.append("Weekly resets \(match[1])")
      }
    } else if let match = firstMatch(
      in: mainLimitBlock, pattern: #"Weekly limit:[\s\S]*?([0-9]+)% left"#)
    {
      codexTokenWeekly = "\(match[0])% left"
    }
    if !resetParts.isEmpty {
      codexTokenReset = resetParts.joined(separator: " · ")
    }
  }

  private func updateCodexModel(from text: String) {
    let cleaned =
      recentText(text, maxCharacters: 80_000)
      .replacingOccurrences(
        of: "\u{001B}\\[[0-9;?]*[ -/]*[@-~]", with: "", options: .regularExpression)
    if let match = firstMatch(
      in: cleaned, pattern: #"Model:\s+([A-Za-z0-9._-]+)\s+\(reasoning\s+([A-Za-z0-9_-]+)"#)
    {
      if isValidCodexModelName(match[0]) {
        codexModel = match[0]
      }
      updateCodexReasoningEffort(match.count > 1 ? match[1] : nil)
      return
    }
    if let match = firstMatch(
      in: cleaned, pattern: #"model:\s+([A-Za-z0-9._-]+)(?:\s+([A-Za-z0-9_-]+))?"#)
    {
      if isValidCodexModelName(match[0]) {
        codexModel = match[0]
      }
      updateCodexReasoningEffort(match.count > 1 ? match[1] : nil)
      return
    }
    if let match = firstMatch(in: cleaned, pattern: #"Model:\s+([A-Za-z0-9._-]+)"#) {
      if isValidCodexModelName(match[0]) {
        codexModel = match[0]
      }
    }
  }

  private func isValidCodexModelName(_ value: String) -> Bool {
    let model = value.trimmed.lowercased()
    guard !model.isEmpty else { return false }
    if model.contains("codexmodeloption") { return false }
    return model.hasPrefix("gpt-") || model.hasPrefix("o") || model.hasPrefix("codex-")
  }

  private func updateCodexReasoningEffort(_ effort: String?) {
    guard let effort = effort?.trimmed.lowercased(),
      ["none", "minimal", "low", "medium", "high", "xhigh"].contains(effort)
    else { return }
    codexReasoningEffort = effort
  }

  private func firstMatch(in text: String, pattern: String) -> [String]? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
      return nil
    }
    let nsRange = NSRange(text.startIndex..., in: text)
    guard let match = regex.firstMatch(in: text, range: nsRange) else { return nil }
    var values: [String] = []
    for index in 1..<match.numberOfRanges {
      let range = match.range(at: index)
      if let swiftRange = Range(range, in: text) {
        values.append(String(text[swiftRange]))
      } else {
        values.append("")
      }
    }
    return values
  }

  private func previewKind(for path: String) -> RemotePreviewKind {
    let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
    if [
      "txt", "md", "py", "swift", "js", "ts", "tsx", "jsx", "json", "toml", "yaml", "yml", "sh",
      "zsh", "html", "css", "tex", "csv", "log", "dart", "kt", "java", "gradle", "properties",
      "plist", "xcconfig", "xml", "scss", "rs", "go", "c", "cc", "cpp", "h", "hpp",
    ].contains(ext) {
      return .text
    }
    if ["png", "jpg", "jpeg", "gif", "heic", "tif", "tiff", "bmp", "webp"].contains(ext) {
      return .image
    }
    if ext == "pdf" {
      return .pdf
    }
    if ["mp4", "mov", "m4v", "webm", "avi", "mkv"].contains(ext) {
      return .video
    }
    return .external
  }

  private func knownRemoteFileSize(for path: String) -> Int64? {
    let normalized = normalizedRemotePath(path)
    if let item = fileBrowserItems.first(where: { normalizedRemotePath($0.path) == normalized }) {
      return item.size
    }
    if let item = remoteItems.first(where: { normalizedRemotePath($0.path) == normalized }) {
      return item.size
    }
    for items in remoteDirectoryCache.values {
      if let item = items.first(where: { normalizedRemotePath($0.path) == normalized }) {
        return item.size
      }
    }
    return nil
  }

  private func freshRemoteFileSize(for path: String) async -> Int64? {
    await freshRemoteFileSignature(for: path)?.size
  }

  private func freshRemoteFileSignature(for path: String) async -> RemoteFileSignature? {
    let normalized = normalizedRemotePath(path)
    let result = await runRemote(
      "stat-file",
      input: normalized + "\n",
      timeout: 12,
      showsActivity: false,
      bypassBackgroundQueue: true
    )
    guard result.exitCode == 0 else { return nil }
    let parts = result.output.split(whereSeparator: \.isWhitespace).map(String.init)
    guard parts.count >= 3, parts[0] == "file", let size = Int64(parts[1]) else {
      return nil
    }
    return RemoteFileSignature(size: size, modifiedAt: parts[2])
  }

  private func invalidateRemotePreviewCache(for path: String) {
    let normalized = normalizedRemotePath(path)
    remoteTextPreviewCache.removeValue(forKey: normalized)
    if normalized != path {
      remoteTextPreviewCache.removeValue(forKey: path)
    }
    if let cachedURL = remoteDownloadedPreviewCache.removeValue(forKey: normalized) {
      try? FileManager.default.removeItem(at: cachedURL)
    } else {
      try? FileManager.default.removeItem(at: previewFileURL(for: normalized))
    }
    remoteDownloadedPreviewSignatures.removeValue(forKey: normalized)
    if normalized != path, let cachedURL = remoteDownloadedPreviewCache.removeValue(forKey: path) {
      try? FileManager.default.removeItem(at: cachedURL)
      remoteDownloadedPreviewSignatures.removeValue(forKey: path)
    }
  }

  private func previewFileURL(for path: String) -> URL {
    let name = URL(fileURLWithPath: path).lastPathComponent
    let safeName =
      name
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: ":", with: "_")
    return previewDirectory.appendingPathComponent("\(stablePreviewDigest(for: path))-\(safeName)")
  }

  private func cachedRemotePreviewURL(for path: String) -> URL? {
    if let cachedURL = remoteDownloadedPreviewCache[path],
      FileManager.default.fileExists(atPath: cachedURL.path)
    {
      return cachedURL
    }
    let previewURL = previewFileURL(for: path)
    guard FileManager.default.fileExists(atPath: previewURL.path) else { return nil }
    remoteDownloadedPreviewCache[path] = previewURL
    return previewURL
  }

  private func downloadRemoteFileToPreview(
    _ path: String,
    attempts: Int = 3,
    useBackground: Bool = false,
    forceRefresh: Bool = false,
    expectedSignature: RemoteFileSignature? = nil
  ) async -> URL? {
    if let expectedSignature,
      let cachedURL = remoteDownloadedPreviewCache[path],
      remoteDownloadedPreviewSignatures[path] == expectedSignature,
      FileManager.default.fileExists(atPath: cachedURL.path)
    {
      return cachedURL
    }
    if !forceRefresh, let cachedURL = remoteDownloadedPreviewCache[path],
      FileManager.default.fileExists(atPath: cachedURL.path)
    {
      return cachedURL
    }
    if remotePreviewDownloadsInFlight.contains(path) {
      for _ in 0..<160 {
        try? await Task.sleep(nanoseconds: 120_000_000)
        if let cachedURL = remoteDownloadedPreviewCache[path],
          FileManager.default.fileExists(atPath: cachedURL.path)
        {
          return cachedURL
        }
        if !remotePreviewDownloadsInFlight.contains(path) {
          return nil
        }
      }
      return nil
    }
    remotePreviewDownloadsInFlight.insert(path)
    defer { remotePreviewDownloadsInFlight.remove(path) }
    let targetURL = previewFileURL(for: path)
    try? FileManager.default.createDirectory(at: previewDirectory, withIntermediateDirectories: true)
    if forceRefresh {
      remoteDownloadedPreviewCache.removeValue(forKey: path)
      remoteDownloadedPreviewSignatures.removeValue(forKey: path)
      try? FileManager.default.removeItem(at: targetURL)
    }
    let transferTimeout = previewTransferTimeout(expectedSignature: expectedSignature)
    if !useBackground, settings.hasSSHTarget {
      try? FileManager.default.removeItem(at: targetURL)
      lastMirrorLog =
        "Preview download request sent: \(path)\nDestination: \(targetURL.path)\nMode: single rsync preview transfer, no compression"
      statusText = "Preview downloading · \(Date().shortStamp)"
      let startedAt = Date()
      let result = await downloadRemotePathFastest(
        path,
        to: targetURL,
        expectedSize: expectedSignature?.size ?? 0,
        timeout: transferTimeout
      )
      if result.exitCode == 0, FileManager.default.fileExists(atPath: targetURL.path) {
        remoteDownloadedPreviewCache[path] = targetURL
        if let expectedSignature {
          remoteDownloadedPreviewSignatures[path] = expectedSignature
        }
        let bytes = Self.localByteCount(at: targetURL)
        lastMirrorLog =
          "Preview downloaded: \(path)\n\(targetURL.path)\nSize: \(Self.fileSizeFormatter.string(fromByteCount: bytes))\nSpeed: \(Self.transferRateText(bytes: bytes, elapsed: Date().timeIntervalSince(startedAt)))\nMode: single rsync preview transfer, no compression"
        return targetURL
      }
      lastMirrorLog =
        result.combined.trimmed.isEmpty
        ? "Fast preview transfer failed for \(path); retrying once."
        : result.combined
    }
    let tries = max(attempts, 1)
    for attempt in 0..<tries {
      if !useBackground {
        lastMirrorLog =
          "Preview transfer request sent: \(path)\nRetry \(attempt + 1)/\(tries)\nMode: single rsync preview transfer, no compression"
      }
      try? FileManager.default.removeItem(at: targetURL)
      let startedAt = Date()
      let result = await downloadRemotePathFastest(
        path,
        to: targetURL,
        expectedSize: expectedSignature?.size ?? 0,
        timeout: transferTimeout
      )
      if result.exitCode == 0, FileManager.default.fileExists(atPath: targetURL.path) {
        remoteDownloadedPreviewCache[path] = targetURL
        if let expectedSignature {
          remoteDownloadedPreviewSignatures[path] = expectedSignature
        }
        if !useBackground {
          let bytes = Self.localByteCount(at: targetURL)
          lastMirrorLog =
            "Preview downloaded: \(path)\n\(targetURL.path)\nSize: \(Self.fileSizeFormatter.string(fromByteCount: bytes))\nSpeed: \(Self.transferRateText(bytes: bytes, elapsed: Date().timeIntervalSince(startedAt)))\nMode: single rsync preview transfer, no compression"
        }
        return targetURL
      }
      lastMirrorLog = result.combined
      if attempt + 1 < tries {
        try? await Task.sleep(nanoseconds: UInt64(280_000_000 * (attempt + 1)))
      }
    }
    return nil
  }

  private func previewTransferTimeout(expectedSignature: RemoteFileSignature?) -> TimeInterval {
    guard let size = expectedSignature?.size else { return 45 }
    let seconds = Double(size) / 500_000.0 + 15
    return min(180, max(20, seconds))
  }

  private func stablePreviewDigest(for value: String) -> String {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in value.utf8 {
      hash ^= UInt64(byte)
      hash &*= 1_099_511_628_211
    }
    return String(hash, radix: 16)
  }
}

private struct CodexTranscriptAnalysis: Sendable {
  var artifacts: [CodexArtifact]
  var token5h: String?
  var tokenWeekly: String?
  var tokenReset: String?
  var model: String?
  var reasoningEffort: String?
}

private enum CodexTranscriptAnalyzer {
  private static let artifactExtensions =
    #"png|jpe?g|gif|heic|tiff?|bmp|webp|mp4|mov|m4v|webm|avi|mkv|pdf|md|txt|json|ya?ml|csv|html|log|apk|ipa|pkg|dmg|zip|tar|tgz|gz|app|exe|msi|swift|dart|kt|java|gradle|properties|plist|xcconfig|xcodeproj|xcworkspace|py|js|ts|tsx|jsx|css|scss|xml|toml|rs|go|c|cc|cpp|h|hpp"#

  private static let absoluteArtifactRegex = try? NSRegularExpression(
    pattern:
      #"(?:(?:~)|(?:/Users/[A-Za-z0-9._-]+)|(?:/private/tmp)|(?:/tmp))[^ \t\r\n"'<>|()\[\]]*\.(?:\#(artifactExtensions))"#,
    options: [.caseInsensitive]
  )

  private static let relativeArtifactRegex = try? NSRegularExpression(
    pattern:
      #"(?:(?:build_outputs)|(?:screenshots)|(?:artifacts)|(?:dist)|(?:release)|(?:releases)|(?:reports)|(?:research_reports)|(?:research_loops)|(?:final_deliverables)|(?:outputs)|(?:precomputed_cache)|(?:gui_app)|(?:tools)|(?:tmp)|(?:test-results)|(?:coverage)|(?:\.acontrol_attachments)|(?:\.sshcontroll_buffer))/[^ \t\r\n"'<>|()\[\]]*\.(?:\#(artifactExtensions))"#,
    options: [.caseInsensitive]
  )

  private static let ansiRegex = try? NSRegularExpression(
    pattern: "\u{001B}\\[[0-9;?]*[ -/]*[@-~]"
  )

  static func analyze(
    _ text: String,
    remoteHome: String,
    currentRemoteDir: String
  ) -> CodexTranscriptAnalysis {
    let cleanedStatus = cleanedStatusText(from: text)
    let tokenInfo = tokenStatus(from: cleanedStatus)
    let modelInfo = modelStatus(from: cleanedStatus)
    return CodexTranscriptAnalysis(
      artifacts: artifacts(from: text, remoteHome: remoteHome, currentRemoteDir: currentRemoteDir),
      token5h: tokenInfo.token5h,
      tokenWeekly: tokenInfo.tokenWeekly,
      tokenReset: tokenInfo.tokenReset,
      model: modelInfo.model,
      reasoningEffort: modelInfo.reasoningEffort
    )
  }

  private static func artifacts(
    from text: String,
    remoteHome: String,
    currentRemoteDir: String
  ) -> [CodexArtifact] {
    let source = recentText(text, maxCharacters: 140_000)
    let regexes = [absoluteArtifactRegex, relativeArtifactRegex].compactMap { $0 }
    var ordered: [CodexArtifact] = []
    var seen: Set<String> = []

    func addArtifact(_ rawPath: String, sourceLine: String) {
      let path = normalizeArtifactPath(
        rawPath,
        remoteHome: remoteHome,
        currentRemoteDir: currentRemoteDir
      )
      guard !path.isEmpty, !seen.contains(path) else { return }
      seen.insert(path)
      ordered.append(
        CodexArtifact(path: path, kind: artifactKind(for: path), sourceLine: sourceLine.trimmed)
      )
    }

    for line in source.components(separatedBy: .newlines) {
      guard !Task.isCancelled else { return Array(ordered.suffix(18)) }
      let lowerLine = line.lowercased()
      if isNoisyArtifactLine(lowerLine) {
        continue
      }
      let nsRange = NSRange(line.startIndex..., in: line)
      for regex in regexes {
        for match in regex.matches(in: line, range: nsRange) {
          guard let range = Range(match.range, in: line) else { continue }
          addArtifact(String(line[range]), sourceLine: line)
        }
      }
      for candidate in artifactCandidates(in: line) {
        addArtifact(candidate, sourceLine: line)
      }
    }
    return Array(ordered.suffix(18))
  }

  private static func artifactCandidates(in line: String) -> [String] {
    let stripped =
      line
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: #"^[-•*]\s+"#, with: "", options: .regularExpression)
      .replacingOccurrences(
        of:
          #"^(?:코드\s*반영\s*파일|변경\s*파일|생성\s*파일|갱신\s*파일|검증|파일|산출물|files?|outputs?|artifacts?|reports?)\s*[:：]\s*"#,
        with: "",
        options: [.regularExpression, .caseInsensitive]
      )
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !stripped.isEmpty else { return [] }

    let pattern =
      #"(^|[\s:：,;()\[\]<>`"'•*\-])([A-Za-z0-9][A-Za-z0-9._@+\-]{0,140}\.(?:\#(artifactExtensions)))(?=$|[\s,;:：)\]}>`"'])"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    else { return [] }
    let range = NSRange(stripped.startIndex..., in: stripped)
    return regex.matches(in: stripped, range: range).compactMap { match in
      guard match.numberOfRanges > 2, let swiftRange = Range(match.range(at: 2), in: stripped)
      else { return nil }
      return String(stripped[swiftRange])
    }
  }

  private static func cleanedStatusText(from text: String) -> String {
    let recent = recentText(text, maxCharacters: 80_000)
    let range = NSRange(recent.startIndex..., in: recent)
    let noAnsi =
      ansiRegex?.stringByReplacingMatches(in: recent, range: range, withTemplate: "") ?? recent
    return
      noAnsi
      .replacingOccurrences(of: "█", with: "")
      .replacingOccurrences(of: "░", with: "")
      .replacingOccurrences(of: "▒", with: "")
      .replacingOccurrences(of: "▓", with: "")
  }

  private static func tokenStatus(from cleaned: String) -> (
    token5h: String?, tokenWeekly: String?, tokenReset: String?
  ) {
    let latestStatus: String
    if let range = cleaned.range(of: "Model:", options: .backwards) {
      latestStatus = String(cleaned[range.lowerBound...])
    } else {
      latestStatus = cleaned
    }
    let mainLimitBlock =
      latestStatus.components(separatedBy: "GPT-5.3-Codex-Spark limit:").first ?? latestStatus
    let lowerStatus = mainLimitBlock.lowercased()
    var token5h: String?
    var tokenWeekly: String?
    var resetParts: [String] = []
    if let match = firstMatch(
      in: mainLimitBlock,
      pattern: #"5h limit:[\s\S]*?([0-9]+)% left[\s\S]*?\(resets ([^)]+)\)"#)
    {
      token5h = "\(match[0])% left"
      if match.count > 1, !match[1].isEmpty {
        resetParts.append("5hr resets \(match[1])")
      }
    } else if let match = firstMatch(
      in: mainLimitBlock, pattern: #"5h limit:[\s\S]*?([0-9]+)% left"#)
    {
      token5h = "\(match[0])% left"
    }
    if token5h == nil,
      let match = firstMatch(
        in: lowerStatus, pattern: #"less than\s+([0-9]+)%\s+of your 5h limit"#
      )
    {
      token5h = "<\(match[0])% left"
    }
    if let match = firstMatch(
      in: mainLimitBlock,
      pattern: #"Weekly limit:[\s\S]*?([0-9]+)% left[\s\S]*?\(resets ([^)]+)\)"#
    ) {
      tokenWeekly = "\(match[0])% left"
      if match.count > 1, !match[1].isEmpty {
        resetParts.append("Weekly resets \(match[1])")
      }
    } else if let match = firstMatch(
      in: mainLimitBlock, pattern: #"Weekly limit:[\s\S]*?([0-9]+)% left"#)
    {
      tokenWeekly = "\(match[0])% left"
    }
    if tokenWeekly == nil,
      let match = firstMatch(
        in: lowerStatus, pattern: #"less than\s+([0-9]+)%\s+of your weekly limit"#
      )
    {
      tokenWeekly = "<\(match[0])% left"
    }
    if lowerStatus.contains("refresh requested") {
      resetParts.append("Codex usage refresh requested")
    }
    return (token5h, tokenWeekly, resetParts.isEmpty ? nil : resetParts.joined(separator: " · "))
  }

  private static func modelStatus(from cleaned: String) -> (
    model: String?, reasoningEffort: String?
  ) {
    if let match = firstMatch(
      in: cleaned,
      pattern: #"Model:\s+([A-Za-z0-9._-]+)\s+\(reasoning\s+([A-Za-z0-9_-]+)"#)
    {
      return (match[0], match.count > 1 ? match[1] : nil)
    }
    if let match = firstMatch(
      in: cleaned, pattern: #"model:\s+([A-Za-z0-9._-]+)(?:\s+([A-Za-z0-9_-]+))?"#)
    {
      return (match[0], match.count > 1 ? match[1] : nil)
    }
    if let match = firstMatch(in: cleaned, pattern: #"Model:\s+([A-Za-z0-9._-]+)"#) {
      return (match[0], nil)
    }
    return (nil, nil)
  }

  private static func isNoisyArtifactLine(_ lowerLine: String) -> Bool {
    lowerLine.contains("/bin/java ") || lowerLine.contains("gradledaemon")
      || lowerLine.contains("kotlincompiledaemon") || lowerLine.contains("/.gradle/caches/")
      || lowerLine.contains("dartaotruntime") || lowerLine.contains("frontend_server")
      || lowerLine.contains("/.dart_tool/") || lowerLine.contains("/build/unit_test_assets/")
      || lowerLine.contains("flutter_tester") || lowerLine.contains("--packages=")
      || lowerLine.contains("/bin/cache/") || lowerLine.contains("/.pub-cache/")
      || lowerLine.contains("$stamp") || lowerLine.contains("$safe_device")
      || lowerLine.contains("${") || lowerLine.contains("%s.")
      || lowerLine.contains("/.codex/") || lowerLine.contains("extensions/chronicle/resources/")
      || lowerLine.contains("/tmp/a-control") || lowerLine.contains("/private/tmp/a-control")
  }

  private static func normalizeArtifactPath(
    _ value: String,
    remoteHome: String,
    currentRemoteDir: String
  ) -> String {
    guard !value.contains("*"), !value.contains("$"), !value.contains("${"),
      !value.contains("$("), !value.contains("%s")
    else {
      return ""
    }
    var path = value.trimmingCharacters(
      in: CharacterSet(charactersIn: " \t\r\n\"'`<>[]{}(),.;:"))
    if let marker = path.range(of: "](") {
      path = String(path[marker.upperBound...])
    }
    guard !path.isEmpty else { return "" }
    while path.contains("//") {
      path = path.replacingOccurrences(of: "//", with: "/")
    }
    let lowerPath = path.lowercased()
    guard !lowerPath.contains("/.tools/"), !lowerPath.contains("/.gradle/"),
      !lowerPath.contains("/.dart_tool/"), !lowerPath.contains("/build/unit_test_assets/"),
      !lowerPath.contains("/bin/cache/"), !lowerPath.contains("/.pub-cache/"),
      !lowerPath.contains("flutter_tester"),
      !lowerPath.contains("docs.gradle.org/"),
      !lowerPath.contains("/library/application support/kotlin/"),
      !lowerPath.contains("/.codex/"),
      !lowerPath.contains("extensions/chronicle/resources/"),
      !lowerPath.contains("/tmp/a-control"),
      !lowerPath.contains("/private/tmp/a-control")
    else { return "" }
    let name = URL(fileURLWithPath: path).lastPathComponent
    guard !name.hasPrefix(".") else { return "" }
    let lowerName = name.lowercased()
    guard !lowerName.contains("flutter_macos"),
      !(lowerName.hasPrefix("gradle-") && lowerName.hasSuffix(".zip")),
      !(lowerName.hasPrefix("rollout-")
        && (lowerName.hasSuffix(".json") || lowerName.hasSuffix(".jsonl"))),
      !lowerName.contains("$stamp"), !lowerName.contains("$safe_device"),
      !lowerName.contains("%s.")
    else { return "" }
    if path == "~" {
      return normalizeRemotePath(remoteHome)
    }
    if path.hasPrefix("~/") {
      return normalizeRemotePath(remoteHome + "/" + String(path.dropFirst(2)))
    }
    if path.hasPrefix("/") {
      return normalizeRemotePath(path)
    }
    return normalizeRemotePath(currentRemoteDir + "/" + path)
  }

  private static func artifactKind(for path: String) -> CodexArtifact.Kind {
    let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
    if ["png", "jpg", "jpeg", "gif", "heic", "tif", "tiff", "bmp", "webp"].contains(ext) {
      return .image
    }
    if ["mp4", "mov", "m4v", "webm", "avi", "mkv"].contains(ext) {
      return .video
    }
    if [
      "md", "txt", "json", "yaml", "yml", "csv", "html", "pdf", "swift", "dart", "kt", "java",
      "gradle", "properties", "plist", "xcconfig", "py", "js", "ts", "tsx", "jsx", "css", "scss",
      "xml", "toml", "rs", "go", "c", "cc", "cpp", "h", "hpp",
    ].contains(ext) {
      return .report
    }
    if ["apk", "ipa", "pkg", "dmg", "app", "exe", "msi"].contains(ext) {
      return .package
    }
    if ["zip", "tar", "tgz", "gz"].contains(ext) {
      return .archive
    }
    if ext == "log" {
      return .log
    }
    return .other
  }

  private static func firstMatch(in text: String, pattern: String) -> [String]? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
      return nil
    }
    let nsRange = NSRange(text.startIndex..., in: text)
    guard let match = regex.firstMatch(in: text, range: nsRange) else { return nil }
    var values: [String] = []
    for index in 1..<match.numberOfRanges {
      let range = match.range(at: index)
      if let swiftRange = Range(range, in: text) {
        values.append(String(text[swiftRange]))
      } else {
        values.append("")
      }
    }
    return values
  }

  private static func recentText(_ value: String, maxCharacters: Int) -> String {
    guard value.count > maxCharacters else { return value }
    return String(value.suffix(maxCharacters))
  }

  private static func normalizeRemotePath(_ path: String) -> String {
    let normalized = (path as NSString).standardizingPath
    return normalized.isEmpty ? "/" : normalized
  }
}

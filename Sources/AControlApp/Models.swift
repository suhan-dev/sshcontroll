import Foundation
import SwiftUI

enum AppSurface: String, CaseIterable, Identifiable {
  case dashboard
  case shell
  case codex
  case claude
  case files
  case monitor
  case mirror
  case settings

  var id: String { rawValue }

  var title: String {
    switch self {
    case .dashboard: "Home"
    case .shell: "Shell"
    case .codex: "Codex"
    case .claude: "Claude"
    case .files: "Files"
    case .monitor: "Monitor"
    case .mirror: "Mirror"
    case .settings: "Settings"
    }
  }

  var symbol: String {
    switch self {
    case .dashboard: "rectangle.3.group"
    case .shell: "terminal"
    case .codex: "sparkles"
    case .claude: "text.bubble"
    case .files: "folder"
    case .monitor: "waveform.path.ecg"
    case .mirror: "arrow.triangle.2.circlepath"
    case .settings: "gearshape"
    }
  }
}

enum AppTheme: String, CaseIterable, Identifiable, Codable {
  case system
  case light
  case dark

  var id: String { rawValue }

  var title: String {
    switch self {
    case .system: "System"
    case .light: "Light"
    case .dark: "Dark"
    }
  }

  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }
}

enum ConnectionNetworkProfile: String, CaseIterable, Identifiable, Codable {
  case otherNetwork
  case sameNetwork

  var id: String { rawValue }

  var title: String {
    switch self {
    case .otherNetwork: "Other network"
    case .sameNetwork: "Same network"
    }
  }

  var symbol: String {
    switch self {
    case .otherNetwork: "globe"
    case .sameNetwork: "wifi"
    }
  }
}

enum MacPrivacyPane: String, CaseIterable, Identifiable, Codable {
  case fullDiskAccess
  case accessibility
  case screenRecording
  case automation
  case inputMonitoring

  var id: String { rawValue }

  var title: String {
    switch self {
    case .fullDiskAccess: "Full Disk"
    case .accessibility: "Accessibility"
    case .screenRecording: "Screen Recording"
    case .automation: "Automation"
    case .inputMonitoring: "Input Monitoring"
    }
  }

  var systemImage: String {
    switch self {
    case .fullDiskAccess: "externaldrive.badge.checkmark"
    case .accessibility: "figure"
    case .screenRecording: "rectangle.dashed.badge.record"
    case .automation: "applescript"
    case .inputMonitoring: "keyboard"
    }
  }

  var urlString: String {
    switch self {
    case .fullDiskAccess:
      "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    case .accessibility:
      "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    case .screenRecording:
      "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    case .automation:
      "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
    case .inputMonitoring:
      "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
    }
  }
}

struct RemotePermissionTarget: Identifiable, Codable, Equatable {
  var id: UUID
  var name: String
  var remotePath: String
  var pane: MacPrivacyPane

  init(id: UUID = UUID(), name: String, remotePath: String, pane: MacPrivacyPane) {
    self.id = id
    self.name = name
    self.remotePath = remotePath
    self.pane = pane
  }

  var displayName: String {
    let trimmed = name.trimmed
    return trimmed.isEmpty ? remotePath.trimmed : trimmed
  }

  static let defaults: [RemotePermissionTarget] = [
    RemotePermissionTarget(
      name: "A Permission Host", remotePath: "~/Applications/A-Cockpit Permission Host.app",
      pane: .accessibility),
    RemotePermissionTarget(
      name: "A Permission Host Screen", remotePath: "~/Applications/A-Cockpit Permission Host.app",
      pane: .screenRecording),
    RemotePermissionTarget(
      name: "A Permission Host Input", remotePath: "~/Applications/A-Cockpit Permission Host.app",
      pane: .inputMonitoring),
    RemotePermissionTarget(
      name: "Codex.app", remotePath: "/Applications/Codex.app", pane: .fullDiskAccess),
    RemotePermissionTarget(
      name: "Codex.app Accessibility", remotePath: "/Applications/Codex.app",
      pane: .accessibility),
    RemotePermissionTarget(
      name: "Codex CLI Permission Host Screen",
      remotePath: "~/Applications/Codex CLI Permission Host.app",
      pane: .screenRecording),
    RemotePermissionTarget(
      name: "Codex CLI Permission Host Automation",
      remotePath: "~/Applications/Codex CLI Permission Host.app",
      pane: .automation),
    RemotePermissionTarget(
      name: "Codex CLI Permission Host Accessibility",
      remotePath: "~/Applications/Codex CLI Permission Host.app",
      pane: .accessibility),
    RemotePermissionTarget(
      name: "Xcode.app", remotePath: "/Applications/Xcode.app", pane: .fullDiskAccess),
    RemotePermissionTarget(
      name: "Remote Login sshd", remotePath: "/usr/sbin/sshd", pane: .fullDiskAccess),
    RemotePermissionTarget(
      name: "Remote Login sshd Accessibility", remotePath: "/usr/sbin/sshd",
      pane: .accessibility),
    RemotePermissionTarget(
      name: "Terminal", remotePath: "/System/Applications/Utilities/Terminal.app",
      pane: .accessibility),
    RemotePermissionTarget(
      name: "Simulator",
      remotePath: "/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app",
      pane: .screenRecording),
  ]
}

enum AISessionTool: String, CaseIterable, Identifiable, Codable {
  case codex
  case claude

  var id: String { rawValue }

  var title: String {
    switch self {
    case .codex: "Codex"
    case .claude: "Claude"
    }
  }

  var symbol: String {
    switch self {
    case .codex: "sparkles"
    case .claude: "text.bubble"
    }
  }
}

enum CodexSessionState: String, Codable, Hashable {
  case fresh
  case running
  case linked
}

enum SessionNameSource: String, Codable, Hashable {
  case user
  case generated
  case codexApp
}

struct AppSettings: Codable, Equatable {
  var remoteLabel: String
  var selectedNetworkProfile: ConnectionNetworkProfile
  var hostAlias: String
  var sshIdentityFile: String
  var sshPort: String
  var sameNetworkHostAlias: String
  var sameNetworkSSHPort: String
  var sameNetworkLatencyTarget: String
  var otherNetworkHostAlias: String
  var otherNetworkSSHPort: String
  var otherNetworkLatencyTarget: String
  var remoteHome: String
  var remoteScript: String
  var codexPath: String
  var claudePath: String
  var explorerRoot: String
  var mirrorBase: String
  var latencyTarget: String
  var appleDevelopmentTeamID: String
  var appleBundleID: String
  var theme: AppTheme
  var startTailscaleOnLaunch: Bool
  var openFullScreenOnLaunch: Bool
  var permissionTargets: [RemotePermissionTarget]

  static var defaults: AppSettings {
    AppSettings(
      remoteLabel: "A",
      selectedNetworkProfile: .otherNetwork,
      hostAlias: "",
      sshIdentityFile: "",
      sshPort: "",
      sameNetworkHostAlias: "",
      sameNetworkSSHPort: "",
      sameNetworkLatencyTarget: "",
      otherNetworkHostAlias: "",
      otherNetworkSSHPort: "",
      otherNetworkLatencyTarget: "",
      remoteHome: "~",
      remoteScript: "~/.local/bin/a-cockpit-remote",
      codexPath: "",
      claudePath: "",
      explorerRoot: "~",
      mirrorBase: "~/remote",
      latencyTarget: "",
      appleDevelopmentTeamID: "",
      appleBundleID: "dev.suhan.sshcontroll",
      theme: .system,
      startTailscaleOnLaunch: true,
      openFullScreenOnLaunch: true,
      permissionTargets: RemotePermissionTarget.defaults
    )
  }

  init(
    remoteLabel: String,
    selectedNetworkProfile: ConnectionNetworkProfile,
    hostAlias: String,
    sshIdentityFile: String,
    sshPort: String,
    sameNetworkHostAlias: String,
    sameNetworkSSHPort: String,
    sameNetworkLatencyTarget: String,
    otherNetworkHostAlias: String,
    otherNetworkSSHPort: String,
    otherNetworkLatencyTarget: String,
    remoteHome: String,
    remoteScript: String,
    codexPath: String,
    claudePath: String,
    explorerRoot: String,
    mirrorBase: String,
    latencyTarget: String,
    appleDevelopmentTeamID: String,
    appleBundleID: String,
    theme: AppTheme,
    startTailscaleOnLaunch: Bool,
    openFullScreenOnLaunch: Bool,
    permissionTargets: [RemotePermissionTarget]
  ) {
    self.remoteLabel = remoteLabel
    self.selectedNetworkProfile = selectedNetworkProfile
    self.hostAlias = hostAlias
    self.sshIdentityFile = sshIdentityFile
    self.sshPort = sshPort
    self.sameNetworkHostAlias = sameNetworkHostAlias
    self.sameNetworkSSHPort = sameNetworkSSHPort
    self.sameNetworkLatencyTarget = sameNetworkLatencyTarget
    self.otherNetworkHostAlias = otherNetworkHostAlias
    self.otherNetworkSSHPort = otherNetworkSSHPort
    self.otherNetworkLatencyTarget = otherNetworkLatencyTarget
    self.remoteHome = remoteHome
    self.remoteScript = remoteScript
    self.codexPath = codexPath
    self.claudePath = claudePath
    self.explorerRoot = explorerRoot
    self.mirrorBase = mirrorBase
    self.latencyTarget = latencyTarget
    self.appleDevelopmentTeamID = appleDevelopmentTeamID
    self.appleBundleID = appleBundleID
    self.theme = theme
    self.startTailscaleOnLaunch = startTailscaleOnLaunch
    self.openFullScreenOnLaunch = openFullScreenOnLaunch
    self.permissionTargets = permissionTargets
  }

  enum CodingKeys: String, CodingKey {
    case remoteLabel
    case selectedNetworkProfile
    case hostAlias
    case sshIdentityFile
    case sshPort
    case sameNetworkHostAlias
    case sameNetworkSSHPort
    case sameNetworkLatencyTarget
    case otherNetworkHostAlias
    case otherNetworkSSHPort
    case otherNetworkLatencyTarget
    case remoteHome
    case remoteScript
    case codexPath
    case claudePath
    case explorerRoot
    case mirrorBase
    case latencyTarget
    case appleDevelopmentTeamID
    case appleBundleID
    case theme
    case startTailscaleOnLaunch
    case openFullScreenOnLaunch
    case permissionTargets
  }

  init(from decoder: Decoder) throws {
    let defaults = Self.defaults
    let container = try decoder.container(keyedBy: CodingKeys.self)
    remoteLabel =
      try container.decodeIfPresent(String.self, forKey: .remoteLabel) ?? defaults.remoteLabel
    selectedNetworkProfile =
      try container.decodeIfPresent(ConnectionNetworkProfile.self, forKey: .selectedNetworkProfile)
      ?? defaults.selectedNetworkProfile
    hostAlias = try container.decodeIfPresent(String.self, forKey: .hostAlias) ?? defaults.hostAlias
    sshIdentityFile =
      try container.decodeIfPresent(String.self, forKey: .sshIdentityFile)
      ?? defaults.sshIdentityFile
    sshPort = try container.decodeIfPresent(String.self, forKey: .sshPort) ?? defaults.sshPort
    sameNetworkHostAlias =
      try container.decodeIfPresent(String.self, forKey: .sameNetworkHostAlias)
      ?? defaults.sameNetworkHostAlias
    sameNetworkSSHPort =
      try container.decodeIfPresent(String.self, forKey: .sameNetworkSSHPort)
      ?? defaults.sameNetworkSSHPort
    sameNetworkLatencyTarget =
      try container.decodeIfPresent(String.self, forKey: .sameNetworkLatencyTarget)
      ?? defaults.sameNetworkLatencyTarget
    otherNetworkHostAlias =
      try container.decodeIfPresent(String.self, forKey: .otherNetworkHostAlias)
      ?? defaults.otherNetworkHostAlias
    otherNetworkSSHPort =
      try container.decodeIfPresent(String.self, forKey: .otherNetworkSSHPort)
      ?? defaults.otherNetworkSSHPort
    otherNetworkLatencyTarget =
      try container.decodeIfPresent(String.self, forKey: .otherNetworkLatencyTarget)
      ?? defaults.otherNetworkLatencyTarget
    remoteHome =
      try container.decodeIfPresent(String.self, forKey: .remoteHome) ?? defaults.remoteHome
    remoteScript =
      try container.decodeIfPresent(String.self, forKey: .remoteScript) ?? defaults.remoteScript
    codexPath = try container.decodeIfPresent(String.self, forKey: .codexPath) ?? defaults.codexPath
    claudePath =
      try container.decodeIfPresent(String.self, forKey: .claudePath) ?? defaults.claudePath
    explorerRoot =
      try container.decodeIfPresent(String.self, forKey: .explorerRoot) ?? defaults.explorerRoot
    mirrorBase =
      try container.decodeIfPresent(String.self, forKey: .mirrorBase) ?? defaults.mirrorBase
    latencyTarget =
      try container.decodeIfPresent(String.self, forKey: .latencyTarget) ?? defaults.latencyTarget
    appleDevelopmentTeamID =
      try container.decodeIfPresent(String.self, forKey: .appleDevelopmentTeamID)
      ?? defaults.appleDevelopmentTeamID
    appleBundleID =
      try container.decodeIfPresent(String.self, forKey: .appleBundleID) ?? defaults.appleBundleID
    theme = try container.decodeIfPresent(AppTheme.self, forKey: .theme) ?? defaults.theme
    startTailscaleOnLaunch =
      try container.decodeIfPresent(Bool.self, forKey: .startTailscaleOnLaunch)
      ?? defaults.startTailscaleOnLaunch
    openFullScreenOnLaunch =
      try container.decodeIfPresent(Bool.self, forKey: .openFullScreenOnLaunch)
      ?? defaults.openFullScreenOnLaunch
    permissionTargets =
      try container.decodeIfPresent([RemotePermissionTarget].self, forKey: .permissionTargets)
      ?? defaults.permissionTargets
    seedNetworkProfilesIfNeeded()
    ensureDefaultPermissionTargets()
  }

  mutating func seedNetworkProfilesIfNeeded() {
    switch selectedNetworkProfile {
    case .otherNetwork:
      if otherNetworkHostAlias.trimmed.isEmpty { otherNetworkHostAlias = hostAlias }
      if otherNetworkSSHPort.trimmed.isEmpty { otherNetworkSSHPort = sshPort }
      if otherNetworkLatencyTarget.trimmed.isEmpty { otherNetworkLatencyTarget = latencyTarget }
    case .sameNetwork:
      if sameNetworkHostAlias.trimmed.isEmpty { sameNetworkHostAlias = hostAlias }
      if sameNetworkSSHPort.trimmed.isEmpty { sameNetworkSSHPort = sshPort }
      if sameNetworkLatencyTarget.trimmed.isEmpty { sameNetworkLatencyTarget = latencyTarget }
    }
  }

  mutating func storeActiveConnectionInSelectedProfile() {
    storeConnection(hostAlias: hostAlias, sshPort: sshPort, latencyTarget: latencyTarget, in: selectedNetworkProfile)
  }

  mutating func applyNetworkProfile(_ profile: ConnectionNetworkProfile) {
    selectedNetworkProfile = profile
    let values = connectionValues(for: profile)
    if !values.hostAlias.trimmed.isEmpty {
      hostAlias = values.hostAlias
    }
    if !values.sshPort.trimmed.isEmpty {
      sshPort = values.sshPort
    }
    if !values.latencyTarget.trimmed.isEmpty {
      latencyTarget = values.latencyTarget
    }
  }

  mutating func storeConnection(
    hostAlias: String,
    sshPort: String,
    latencyTarget: String,
    in profile: ConnectionNetworkProfile
  ) {
    switch profile {
    case .otherNetwork:
      otherNetworkHostAlias = hostAlias
      otherNetworkSSHPort = sshPort
      otherNetworkLatencyTarget = latencyTarget
    case .sameNetwork:
      sameNetworkHostAlias = hostAlias
      sameNetworkSSHPort = sshPort
      sameNetworkLatencyTarget = latencyTarget
    }
  }

  func connectionValues(for profile: ConnectionNetworkProfile) -> (
    hostAlias: String, sshPort: String, latencyTarget: String
  ) {
    switch profile {
    case .otherNetwork:
      return (otherNetworkHostAlias, otherNetworkSSHPort, otherNetworkLatencyTarget)
    case .sameNetwork:
      return (sameNetworkHostAlias, sameNetworkSSHPort, sameNetworkLatencyTarget)
    }
  }

  mutating func ensureDefaultPermissionTargets() {
    var seen = Set(permissionTargets.map { "\($0.remotePath.trimmed)|\($0.pane.rawValue)" })
    for target in RemotePermissionTarget.defaults {
      let key = "\(target.remotePath.trimmed)|\(target.pane.rawValue)"
      guard !seen.contains(key) else { continue }
      permissionTargets.append(target)
      seen.insert(key)
    }
  }

  var sshTarget: String {
    hostAlias.trimmed
  }

  var hasSSHTarget: Bool {
    !sshTarget.isEmpty
  }

  var expandedIdentityFile: String {
    sshIdentityFile.trimmed.expandingTilde
  }

  var normalizedSSHPort: String {
    sshPort.trimmed
  }

  var sshProcessOptions: [String] {
    let controlPath = "\(NSHomeDirectory())/.ssh/acontrol-%C"
    var options = [
      "-o", "BatchMode=yes",
      "-o", "LogLevel=ERROR",
      "-o", "ControlMaster=auto",
      "-o", "ControlPersist=600",
      "-o", "ControlPath=\(controlPath)",
      "-o", "ConnectTimeout=8",
      "-o", "ConnectionAttempts=1",
      "-o", "ServerAliveInterval=15",
      "-o", "ServerAliveCountMax=2",
      "-o", "TCPKeepAlive=yes",
    ]
    if !normalizedSSHPort.isEmpty {
      options += ["-p", normalizedSSHPort]
    }
    if !sshIdentityFile.trimmed.isEmpty {
      options += ["-i", expandedIdentityFile, "-o", "IdentitiesOnly=yes"]
    }
    return options
  }

  var scpShellOptions: String {
    let controlPath = "\(NSHomeDirectory())/.ssh/acontrol-%C"
    var options = [
      "-o BatchMode=yes",
      "-o LogLevel=ERROR",
      "-o ControlMaster=auto",
      "-o ControlPersist=600",
      "-o ControlPath=\(controlPath.shellQuoted)",
      "-o ConnectTimeout=8",
      "-o ConnectionAttempts=1",
      "-o ServerAliveInterval=15",
      "-o ServerAliveCountMax=2",
      "-o TCPKeepAlive=yes",
    ]
    if !normalizedSSHPort.isEmpty {
      options += ["-P", normalizedSSHPort.shellQuoted]
    }
    if !sshIdentityFile.trimmed.isEmpty {
      options += ["-i", expandedIdentityFile.shellQuoted, "-o", "IdentitiesOnly=yes"]
    }
    return options.joined(separator: " ")
  }

  var sshShellOptions: String {
    let controlPath = "\(NSHomeDirectory())/.ssh/acontrol-%C"
    var options = [
      "-o BatchMode=yes",
      "-o LogLevel=ERROR",
      "-o ControlMaster=auto",
      "-o ControlPersist=600",
      "-o ControlPath=\(controlPath.shellQuoted)",
      "-o ConnectTimeout=8",
      "-o ConnectionAttempts=1",
      "-o ServerAliveInterval=15",
      "-o ServerAliveCountMax=2",
      "-o TCPKeepAlive=yes",
    ]
    if !normalizedSSHPort.isEmpty {
      options += ["-p", normalizedSSHPort.shellQuoted]
    }
    if !sshIdentityFile.trimmed.isEmpty {
      options += ["-i", expandedIdentityFile.shellQuoted, "-o IdentitiesOnly=yes"]
    }
    return options.joined(separator: " ")
  }

  var transferSSHShellOptions: String {
    var options = [
      "-o BatchMode=yes",
      "-o LogLevel=ERROR",
      "-o ControlMaster=no",
      "-o ControlPath=none",
      "-o Compression=no",
      "-o IPQoS=throughput",
      "-o ConnectTimeout=10",
      "-o ConnectionAttempts=1",
      "-o ServerAliveInterval=15",
      "-o ServerAliveCountMax=4",
      "-o TCPKeepAlive=yes",
    ]
    if !normalizedSSHPort.isEmpty {
      options += ["-p", normalizedSSHPort.shellQuoted]
    }
    if !sshIdentityFile.trimmed.isEmpty {
      options += ["-i", expandedIdentityFile.shellQuoted, "-o IdentitiesOnly=yes"]
    }
    return options.joined(separator: " ")
  }

  var sshShellCommand: String {
    ["/usr/bin/ssh", sshShellOptions, sshTarget.shellQuoted]
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  var sshNoCompressionShellCommand: String {
    ["/usr/bin/ssh", sshShellOptions, "-o Compression=no", sshTarget.shellQuoted]
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  var transferSSHShellCommand: String {
    ["/usr/bin/ssh", transferSSHShellOptions, sshTarget.shellQuoted]
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  var transferSCPShellCommand: String {
    ["/usr/bin/scp", transferSSHShellOptions.replacingOccurrences(of: "-p ", with: "-P ")]
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  var fastTransferSCPShellCommand: String {
    [
      "/usr/bin/scp",
      "-O",
      transferSSHShellOptions.replacingOccurrences(of: "-p ", with: "-P "),
    ]
    .filter { !$0.isEmpty }
    .joined(separator: " ")
  }

  var scpShellCommand: String {
    ["/usr/bin/scp", scpShellOptions]
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  var rsyncSSHCommand: String {
    ["/usr/bin/ssh", transferSSHShellOptions]
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  var remoteToolEnvironment: String {
    var assignments: [String] = []
    let codexOverride = codexPath.trimmed
    if !codexOverride.isEmpty, !Self.isAutomaticCodexPath(codexOverride) {
      assignments.append("A_COCKPIT_CODEX_BIN=\(codexOverride.shellQuoted)")
    }
    if !claudePath.trimmed.isEmpty {
      assignments.append("A_COCKPIT_CLAUDE_BIN=\(claudePath.trimmed.shellQuoted)")
    }
    return assignments.isEmpty ? "" : assignments.joined(separator: " ") + " "
  }

  static func isAutomaticCodexPath(_ value: String) -> Bool {
    let trimmed = value.trimmed
    return trimmed == "codex"
      || trimmed == "/Applications/Codex.app/Contents/Resources/codex"
      || trimmed == "~/Applications/Codex.app/Contents/Resources/codex"
  }

  func remoteSpec(_ path: String) -> String {
    "\(sshTarget):\(path)"
  }
}

struct RemoteItem: Identifiable, Codable, Hashable, Sendable {
  var name: String
  var path: String
  var type: String
  var size: Int64
  var mtime: Int64
  var symlink: Bool?

  var id: String { path }
  var isDirectory: Bool { type == "dir" }
}

struct FileTransferProgress: Identifiable, Equatable {
  var id = UUID()
  var title: String
  var source: String
  var destination: String
  var phase: String
  var completedBytes: Int64
  var totalBytes: Int64
  var startedAt = Date()
  var updatedAt = Date()
  var isFinished = false
  var succeeded: Bool?

  var fraction: Double? {
    guard totalBytes > 0 else { return nil }
    return min(1, max(0, Double(completedBytes) / Double(totalBytes)))
  }

  var sizeDescription: String {
    if totalBytes > 0 {
      return "\(ByteCountFormatter.string(fromByteCount: completedBytes, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))"
    }
    if completedBytes > 0 {
      return ByteCountFormatter.string(fromByteCount: completedBytes, countStyle: .file)
    }
    return "Preparing"
  }

  var elapsedDescription: String {
    let seconds = max(0, Int(Date().timeIntervalSince(startedAt)))
    if seconds < 60 { return "\(seconds)s" }
    return "\(seconds / 60)m \(seconds % 60)s"
  }
}

struct PromptAttachment: Identifiable, Hashable, Codable {
  var id = UUID()
  var localURL: URL
  var remotePath: String?
  var name: String
  var size: Int64
  var kind: String
  var createdAt = Date()

  var displaySize: String {
    guard size > 0 else { return "folder" }
    return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
  }

  var uploadName: String {
    "\(createdAt.attachmentSafeStamp)-\(id.uuidString.prefix(8))-\(name.sanitizedFileName)"
  }
}

enum CodexPromptQueueKind: String, Hashable, Sendable, Codable {
  case send
  case steer

  var title: String {
    switch self {
    case .send: "Send"
    case .steer: "Steer"
    }
  }

  var symbol: String {
    switch self {
    case .send: "paperplane"
    case .steer: "arrow.triangle.turn.up.right.diamond"
    }
  }
}

enum CodexPromptQueueStatus: String, Hashable, Sendable, Codable {
  case queued
  case sending
  case waitingForCodex
  case delivered
  case failed

  var title: String {
    switch self {
    case .queued: "Queued"
    case .sending: "Sending"
    case .waitingForCodex: "On A Queue"
    case .delivered: "Delivered"
    case .failed: "Failed"
    }
  }
}

struct CodexPromptQueueItem: Identifiable, Hashable, Codable {
  var id = UUID()
  var sessionID: UUID?
  var kind: CodexPromptQueueKind
  var text: String
  var displayText: String?
  var attachments: [PromptAttachment]
  var createdAt = Date()
  var updatedAt = Date()
  var status: CodexPromptQueueStatus = .queued
  var lastError = ""
  var remoteQueueID: String?
  var researchGroupID: String?
  var researchRole: String?

  var visibleText: String {
    if let displayText = displayText?.trimmed, !displayText.isEmpty {
      return displayText
    }
    let prompt = text.trimmed
    if !prompt.isEmpty { return prompt }
    return attachments.map { "@\($0.name)" }.joined(separator: "\n")
  }

  var shortText: String {
    let value = visibleText.replacingOccurrences(
      of: #"\s+"#, with: " ", options: .regularExpression
    )
    .trimmed
    guard value.count > 120 else { return value }
    return String(value.prefix(117)) + "..."
  }

  var isVisibleInComposerQueue: Bool {
    guard status != .delivered else { return false }
    guard status != .waitingForCodex else {
      let detail = lastError.lowercased()
      return !detail.contains("processing on a")
        && !detail.contains("already processing")
        && !detail.contains("worker started")
    }
    return true
  }
}

struct CodexHistoryRecord: Identifiable, Codable, Hashable {
  var id: String
  var cwd: String
  var path: String
  var mtime: Int
  var title: String
  var source: String? = nil
  var threadSource: String? = nil
  var host: String? = nil

  var shortID: String {
    String(id.prefix(8))
  }

  var normalizedHost: String {
    let value = host?.trimmed.lowercased() ?? ""
    return value.isEmpty ? "remote" : value
  }

  var isSubagent: Bool {
    let values = [
      source?.trimmed.lowercased() ?? "",
      threadSource?.trimmed.lowercased() ?? "",
    ]
    return values.contains("subagent") || values.contains { $0.contains("\"subagent\"") }
  }

  enum CodingKeys: String, CodingKey {
    case id
    case cwd
    case path
    case mtime
    case title
    case source
    case threadSource = "thread_source"
    case host
  }
}

struct CodexArtifact: Identifiable, Hashable, Sendable {
  enum Kind: String, Hashable, Sendable {
    case image
    case report
    case video
    case package
    case archive
    case log
    case other

    var title: String {
      switch self {
      case .image: "Image"
      case .report: "Report"
      case .video: "Video"
      case .package: "Package"
      case .archive: "Archive"
      case .log: "Log"
      case .other: "File"
      }
    }

    var symbol: String {
      switch self {
      case .image: "photo"
      case .report: "doc.text"
      case .video: "play.rectangle"
      case .package: "shippingbox"
      case .archive: "archivebox"
      case .log: "text.page"
      case .other: "doc"
      }
    }

    var tint: Color {
      switch self {
      case .image: .blue
      case .report: .teal
      case .video: .purple
      case .package: .green
      case .archive: .orange
      case .log: .gray
      case .other: .purple
      }
    }
  }

  var path: String
  var kind: Kind
  var sourceLine: String

  var id: String { path }

  var name: String {
    URL(fileURLWithPath: path).lastPathComponent
  }

  var displayPath: String {
    path.replacingOccurrences(
      of: #"^/Users/[^/]+"#,
      with: "~",
      options: .regularExpression)
  }
}

struct ShellCompletion: Identifiable, Codable, Hashable {
  var label: String
  var value: String
  var isDirectory: Bool

  var id: String { value }
}

struct ShellCompletionResponse: Codable {
  var items: [ShellCompletion]
}

enum RemotePreviewKind: String {
  case none
  case text
  case image
  case pdf
  case video
  case external

  var prewarmRank: Int {
    switch self {
    case .image:
      0
    case .pdf:
      1
    case .video:
      2
    case .text:
      3
    case .external:
      4
    case .none:
      5
    }
  }
}

struct SessionCard: Identifiable, Codable, Hashable {
  var id: UUID
  var name: String
  var remoteDir: String
  var tool: AISessionTool
  var enabledTools: [AISessionTool]
  var codexSession: String
  var claudeSession: String
  var codexHistoryID: String
  var codexHistoryPath: String
  var codexHistoryTitle: String
  var codexHistoryHost: String
  var codexState: CodexSessionState
  var nameSource: SessionNameSource
  var note: String
  var updatedAt: Date

  init(name: String, remoteDir: String, tool: AISessionTool = .codex) {
    self.id = UUID()
    self.name = name
    self.remoteDir = remoteDir
    self.tool = tool
    self.enabledTools = [tool]
    self.codexSession = "codex-" + String(id.uuidString.prefix(8))
    self.claudeSession = "claude-" + String(id.uuidString.prefix(8))
    self.codexHistoryID = ""
    self.codexHistoryPath = ""
    self.codexHistoryTitle = ""
    self.codexHistoryHost = "remote"
    self.codexState = .fresh
    self.nameSource = name.trimmed.isEmpty ? .generated : .user
    self.note = ""
    self.updatedAt = Date()
  }

  var agentSummary: String {
    normalizedEnabledTools
      .map { agentSummary(for: $0) }
      .joined(separator: "\n")
  }

  var dashboardAgentSummary: String {
    normalizedEnabledTools
      .map { dashboardAgentSummary(for: $0) }
      .joined(separator: "\n")
  }

  private var normalizedEnabledTools: [AISessionTool] {
    let unique = Set(enabledTools.isEmpty ? [tool] : enabledTools)
    return AISessionTool.allCases.filter { unique.contains($0) }
  }

  private func agentSummary(for tool: AISessionTool) -> String {
    switch tool {
    case .codex:
      if !codexHistoryID.trimmed.isEmpty {
        return "Codex \(String(codexHistoryID.prefix(8)))"
      }
      if codexState == .fresh {
        return "Codex new"
      }
      return "Codex ready"
    case .claude:
      return "Claude \(claudeSession.replacingOccurrences(of: "claude-", with: ""))"
    }
  }

  private func dashboardAgentSummary(for tool: AISessionTool) -> String {
    switch tool {
    case .codex:
      if codexState == .fresh, codexHistoryID.trimmed.isEmpty {
        return "Codex new"
      }
      if !codexHistoryID.trimmed.isEmpty {
        return "Codex \(String(codexHistoryID.prefix(8)))"
      }
      return "Codex ready"
    case .claude:
      return "Claude \(claudeSession.replacingOccurrences(of: "claude-", with: ""))"
    }
  }

  mutating func enableTool(_ tool: AISessionTool) {
    if !enabledTools.contains(tool) {
      enabledTools.append(tool)
    }
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case name
    case remoteDir
    case tool
    case enabledTools
    case codexSession
    case claudeSession
    case codexHistoryID
    case codexHistoryPath
    case codexHistoryTitle
    case codexHistoryHost
    case codexState
    case nameSource
    case note
    case updatedAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
    name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Session"
    remoteDir = try container.decodeIfPresent(String.self, forKey: .remoteDir) ?? "~"
    tool = try container.decodeIfPresent(AISessionTool.self, forKey: .tool) ?? .codex
    enabledTools =
      try container.decodeIfPresent([AISessionTool].self, forKey: .enabledTools) ?? [tool]
    if enabledTools.isEmpty {
      enabledTools = [tool]
    }
    let suffix = String(id.uuidString.prefix(8))
    codexSession =
      try container.decodeIfPresent(String.self, forKey: .codexSession) ?? "codex-\(suffix)"
    claudeSession =
      try container.decodeIfPresent(String.self, forKey: .claudeSession) ?? "claude-\(suffix)"
    codexHistoryID = try container.decodeIfPresent(String.self, forKey: .codexHistoryID) ?? ""
    codexHistoryPath = try container.decodeIfPresent(String.self, forKey: .codexHistoryPath) ?? ""
    codexHistoryTitle = try container.decodeIfPresent(String.self, forKey: .codexHistoryTitle) ?? ""
    codexHistoryHost =
      try container.decodeIfPresent(String.self, forKey: .codexHistoryHost) ?? "remote"
    codexState =
      try container.decodeIfPresent(CodexSessionState.self, forKey: .codexState)
      ?? (codexHistoryID.trimmed.isEmpty ? .fresh : .linked)
    nameSource = try container.decodeIfPresent(SessionNameSource.self, forKey: .nameSource) ?? .user
    note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
  }
}

struct CommandResult: Equatable {
  var exitCode: Int32
  var output: String
  var error: String

  var combined: String {
    [output, error].filter { !$0.isEmpty }.joined(separator: "\n")
  }

  var isMissingOptionalDependency: Bool {
    guard exitCode != 0 else { return false }
    let lower = combined.lowercased()
    return lower.contains(" is not installed") || lower.contains(" app not found")
      || lower.contains("cli is not available") || lower.contains("cli was not found")
      || lower.contains("command not found")
  }
}

extension String {
  var expandingTilde: String {
    if self == "~" { return FileManager.default.homeDirectoryForCurrentUser.path }
    if hasPrefix("~/") {
      return FileManager.default.homeDirectoryForCurrentUser.path + "/" + dropFirst(2)
    }
    return self
  }

  var shellQuoted: String {
    "'" + replacingOccurrences(of: "'", with: "'\\''") + "'"
  }

  var trimmed: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var nilIfEmpty: String? {
    trimmed.isEmpty ? nil : self
  }
}

extension Date {
  var shortStamp: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter.string(from: self)
  }

  var attachmentSafeStamp: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
    return formatter.string(from: self)
  }
}

extension String {
  var sanitizedFileName: String {
    let illegal = CharacterSet(charactersIn: "/:")
      .union(.newlines)
      .union(.controlCharacters)
    let cleaned = components(separatedBy: illegal).joined(separator: "_")
    return cleaned.isEmpty ? "attachment" : cleaned
  }
}

extension DateFormatter {
  static let attachmentStamp: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return formatter
  }()
}

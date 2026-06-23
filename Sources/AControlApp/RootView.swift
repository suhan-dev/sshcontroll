import AppKit
import SwiftUI

struct RootView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.colorScheme) private var colorScheme
  @State private var renamingSession: SessionCard?
  @State private var renameText = ""
  @State private var expandedSidebarProjectIDs: Set<String> = []

  private let collapsedProjectSessionLimit = 5

  var body: some View {
    GeometryReader { proxy in
      let sidebarWidth = stableSidebarWidth
      let inset = AControlStyle.contentPadding(for: max(0, proxy.size.width - sidebarWidth))

      if model.isCodeWorkspaceInlineActive {
        ZStack {
          background
          CodeWorkspaceView(isInline: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          KeyHandlingView()
            .frame(width: 0, height: 0)
        }
        .background(background)
        .ignoresSafeArea(.container, edges: .top)
      } else {
        ZStack(alignment: .trailing) {
          HStack(spacing: 0) {
            sidebar
              .frame(width: sidebarWidth)
              .layoutPriority(1)

            Rectangle()
              .fill(AControlStyle.hairline(colorScheme))
              .frame(width: 1)

            ZStack {
              background
              surface
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, inset)
                .padding(.top, AControlStyle.pageTopPadding)
                .padding(.bottom, inset)
                .clipped()
              KeyHandlingView()
                .frame(width: 0, height: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
          .background(background)

          if model.selectedSurface == .codex && !model.isCodexFilePanelVisible {
            CodexFilesEdgeRevealButton(isVisible: $model.isCodexFilePanelVisible)
              .frame(width: 28)
              .frame(maxHeight: .infinity)
              .zIndex(20)
          }
        }
        .ignoresSafeArea(.container, edges: .top)
        .sheet(item: $renamingSession) { session in
          RenameSessionSheet(
            session: session,
            name: $renameText,
            onCancel: { renamingSession = nil },
            onSave: {
              model.renameSession(session, to: renameText)
              renamingSession = nil
            }
          )
        }
      }
    }
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(spacing: 10) {
        Image(systemName: "sparkles")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(AControlStyle.accentForeground(.cyan, colorScheme))
          .frame(width: 30, height: 30)
          .background(AControlStyle.accentFill(.cyan, colorScheme), in: Circle())
        VStack(alignment: .leading, spacing: 1) {
          Text("SSHcontroll")
            .font(.system(size: 16, weight: .bold))
          Text(model.settings.hostAlias.isEmpty ? "not configured" : model.settings.hostAlias)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
        }
        Spacer()
      }
      .padding(.horizontal, 14)
      .padding(.top, 28)

      VStack(spacing: 4) {
        CodeWorkspaceSidebarButton(
          isSelected: model.isCodeWorkspaceInlineActive,
          openInline: { openCodeWorkspaceInline() },
          openDetached: { (NSApp.delegate as? AControlAppDelegate)?.showCodeWorkspaceWindow() }
        )
        ForEach(AppSurface.allCases) { surface in
          SidebarSurfaceRow(
            surface: surface,
            isSelected: !model.isCodeWorkspaceInlineActive && model.selectedSurface == surface
          ) {
            model.selectSurface(surface)
          }
        }
      }
      .padding(.horizontal, 10)

      VStack(alignment: .leading, spacing: 8) {
        Text("Projects")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 14)

        ScrollView {
          LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(sidebarProjectGroups) { group in
              sidebarProjectSection(group)
            }
          }
          .padding(.horizontal, 10)
          .padding(.bottom, 16)
        }
      }

      Spacer(minLength: 0)
    }
    .background {
      Rectangle()
        .fill(sidebarBackground)
        .ignoresSafeArea()
    }
  }

  private var sidebarProjectGroups: [SidebarProjectGroup] {
    let selectedGroupID = model.sessions
      .first(where: { $0.id == model.activeSessionID })
      .map { sidebarProjectID(for: $0.remoteDir) }
    let grouped = Dictionary(grouping: model.sessions) { session in
      sidebarProjectID(for: session.remoteDir)
    }
    let groups = grouped.map { id, sessions in
      let sortedSessions = sessions.sorted { first, second in
        if first.id == model.activeSessionID { return true }
        if second.id == model.activeSessionID { return false }
        let firstWorking =
          model.codexWorkingSessionIDs.contains(first.id)
          || model.claudeWorkingSessionIDs.contains(first.id)
        let secondWorking =
          model.codexWorkingSessionIDs.contains(second.id)
          || model.claudeWorkingSessionIDs.contains(second.id)
        if firstWorking != secondWorking { return firstWorking }
        return first.updatedAt > second.updatedAt
      }
      let rawPath = sessions.first?.remoteDir.trimmed ?? ""
      let hasWorking = sessions.contains {
        model.codexWorkingSessionIDs.contains($0.id)
          || model.claudeWorkingSessionIDs.contains($0.id)
      }
      return SidebarProjectGroup(
        id: id,
        title: sidebarProjectTitle(for: rawPath),
        detail: sidebarProjectDetail(for: rawPath),
        sessions: sortedSessions,
        hasWorking: hasWorking,
        updatedAt: sortedSessions.map(\.updatedAt).max() ?? .distantPast
      )
    }
    return groups.sorted { first, second in
      if first.id == selectedGroupID { return true }
      if second.id == selectedGroupID { return false }
      if first.hasWorking != second.hasWorking { return first.hasWorking }
      return first.updatedAt > second.updatedAt
    }
  }

  private func sidebarProjectSection(_ group: SidebarProjectGroup) -> some View {
    let isExpanded = expandedSidebarProjectIDs.contains(group.id)
    let visibleSessions =
      isExpanded
      ? group.sessions
      : Array(group.sessions.prefix(collapsedProjectSessionLimit))
    return VStack(alignment: .leading, spacing: 4) {
      SidebarProjectHeaderRow(
        title: group.title,
        detail: group.detail,
        isWorking: group.hasWorking,
        isSelected: group.sessions.contains { $0.id == model.activeSessionID }
      ) {
        guard let first = group.sessions.first else { return }
        Task { await model.openSession(first) }
      }

      ForEach(visibleSessions) { session in
        SidebarSessionRow(
          session: session,
          isSelected: model.activeSessionID == session.id,
          isCodexWorking: model.codexWorkingSessionIDs.contains(session.id),
          isClaudeWorking: model.claudeWorkingSessionIDs.contains(session.id),
          remoteHome: model.settings.remoteHome,
          showsPath: false,
          indentation: 28
        ) {
          Task { await model.openSession(session) }
        }
        .contextMenu {
          Button("Rename") {
            renameText = session.displayTitle
            renamingSession = session
          }
          Button("Open Chat Folder") {
            model.openSessionFolder(session)
          }
          Divider()
          Button("Delete Session", role: .destructive) {
            Task { await model.deleteSession(session) }
          }
        }
      }

      if group.sessions.count > collapsedProjectSessionLimit {
        Button {
          toggleSidebarProjectExpansion(group.id)
        } label: {
          Text(isExpanded ? "Show less" : "Show more")
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.leading, 30)
            .frame(height: 28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(ImmediateFeedbackButtonStyle())
      }
    }
  }

  private func toggleSidebarProjectExpansion(_ id: String) {
    if expandedSidebarProjectIDs.contains(id) {
      expandedSidebarProjectIDs.remove(id)
    } else {
      expandedSidebarProjectIDs.insert(id)
    }
  }

  private func sidebarProjectID(for rawPath: String) -> String {
    let normalized = normalizedSidebarProjectPath(rawPath)
    return normalized.isEmpty ? "__sshcontroll_no_folder__" : normalized
  }

  private func normalizedSidebarProjectPath(_ rawPath: String) -> String {
    var value = rawPath.trimmed
    guard !value.isEmpty else { return "" }
    while value.count > 1, value.hasSuffix("/") {
      value.removeLast()
    }
    if value == "." || value == "~" || value == model.settings.remoteHome.trimmed {
      return value
    }
    return value
  }

  private func sidebarProjectTitle(for rawPath: String) -> String {
    let path = normalizedSidebarProjectPath(rawPath)
    guard !path.isEmpty else { return "No Folder" }
    if path == "~" || path == model.settings.remoteHome.trimmed {
      return "Home"
    }
    return path.split(separator: "/").last.map(String.init) ?? path
  }

  private func sidebarProjectDetail(for rawPath: String) -> String {
    let host =
      model.settings.hostAlias.trimmed.isEmpty
      ? model.settings.remoteLabel.trimmed
      : model.settings.hostAlias.trimmed
    let shortPath = shortSidebarPath(rawPath)
    if shortPath.isEmpty {
      return host.isEmpty ? "No working folder" : host
    }
    if host.isEmpty { return shortPath }
    return "\(host) · \(shortPath)"
  }

  private func shortSidebarPath(_ rawPath: String) -> String {
    let path = normalizedSidebarProjectPath(rawPath)
    guard !path.isEmpty else { return "" }
    let remoteHome = model.settings.remoteHome.trimmed
    guard !remoteHome.isEmpty else { return path }
    if path == remoteHome { return "~" }
    if path.hasPrefix(remoteHome + "/") {
      return "~/" + String(path.dropFirst(remoteHome.count + 1))
    }
    return path
  }

  private var stableSidebarWidth: CGFloat {
    236
  }

  @ViewBuilder
  private var surface: some View {
    switch model.selectedSurface {
    case .dashboard:
      DashboardView()
    case .shell:
      ShellView()
    case .codex:
      CodexView()
    case .claude:
      ClaudeView()
    case .files:
      FilesView()
    case .monitor:
      MonitorView()
    case .mirror:
      MirrorView()
    case .settings:
      SettingsView()
    }
  }

  private func openCodeWorkspaceInline() {
    model.openCodeWorkspaceInline()
    Task {
      await model.prepareCodeWorkspaceForActiveSession()
      await model.refreshCodexWorkingStates(force: true)
      await model.captureCodexIfUseful(force: true)
      await model.captureShell()
    }
  }

  private var background: some View {
    Rectangle()
      .fill(AControlStyle.appBackground(colorScheme))
      .ignoresSafeArea()
  }

  private var sidebarBackground: some ShapeStyle {
    if colorScheme == .dark {
      return AnyShapeStyle(Color(red: 0.118, green: 0.127, blue: 0.144))
    }
    return AnyShapeStyle(Color(red: 0.965, green: 0.982, blue: 0.992))
  }
}

private struct SidebarProjectGroup: Identifiable {
  var id: String
  var title: String
  var detail: String
  var sessions: [SessionCard]
  var hasWorking: Bool
  var updatedAt: Date
}

private struct SidebarProjectHeaderRow: View {
  @Environment(\.colorScheme) private var colorScheme
  var title: String
  var detail: String
  var isWorking: Bool
  var isSelected: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 9) {
        Image(systemName: "folder")
          .font(.system(size: 15, weight: .semibold))
          .frame(width: 20)
          .foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 1) {
          HStack(spacing: 7) {
            Text(title)
              .font(.system(size: 14.5, weight: .semibold))
              .foregroundStyle(.primary.opacity(0.90))
              .lineLimit(1)
            if isWorking {
              Circle()
                .fill(Color.green)
                .frame(width: 7, height: 7)
                .shadow(color: Color.green.opacity(0.40), radius: 4)
            }
          }
          if !detail.trimmed.isEmpty {
            Text(detail)
              .font(.system(size: 10.5, weight: .medium))
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .background(
      isSelected ? Color.primary.opacity(colorScheme == .dark ? 0.070 : 0.038) : Color.clear,
      in: RoundedRectangle(cornerRadius: 10, style: .continuous)
    )
  }
}

private struct CodeWorkspaceSidebarButton: View {
  @Environment(\.colorScheme) private var colorScheme
  var isSelected: Bool
  var openInline: () -> Void
  var openDetached: () -> Void

  var body: some View {
    Button(action: openInline) {
      HStack(spacing: 12) {
        Image(systemName: "rectangle.3.group.bubble.left")
          .font(.system(size: 14, weight: .semibold))
          .frame(width: 22, alignment: .center)
        Text("Code Workspace")
          .font(.system(size: 14, weight: .semibold))
          .lineLimit(1)
        Spacer(minLength: 0)
      }
      .foregroundStyle(AControlStyle.accentForeground(.blue, colorScheme))
      .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40, alignment: .leading)
      .padding(.horizontal, 12)
      .contentShape(Rectangle())
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .background {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(
          isSelected
            ? AnyShapeStyle(AControlStyle.accentFill(.blue, colorScheme))
            : AControlStyle.panelFill(colorScheme)
        )
    }
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(
          isSelected ? AControlStyle.accentStroke(.blue, colorScheme) : AControlStyle.hairline(colorScheme),
          lineWidth: 1
        )
    }
    .contextMenu {
      Button("Open in New Window") {
        openDetached()
      }
    }
  }
}

private struct CodexFilesEdgeRevealButton: View {
  @Environment(\.colorScheme) private var colorScheme
  @Binding var isVisible: Bool
  @State private var isHoveringEdge = false
  @State private var isHandleVisible = false
  @State private var hoverToken = 0

  var body: some View {
    GeometryReader { proxy in
      let handleHeight = min(max(260, proxy.size.height * 0.42), 380)

      VStack(spacing: 0) {
        Color.clear
          .frame(height: 112)
          .allowsHitTesting(false)

        ZStack(alignment: .trailing) {
          Color.clear
            .contentShape(Rectangle())

          Button {
            guard isHandleVisible else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
              isVisible = true
            }
          } label: {
            VStack(spacing: 14) {
              Image(systemName: "sidebar.left")
                .font(.system(size: 13, weight: .semibold))
              Text("Files")
                .font(.system(size: 13, weight: .bold))
                .rotationEffect(.degrees(-90))
                .fixedSize()
            }
            .foregroundStyle(AControlStyle.accentForeground(.purple, colorScheme))
            .frame(width: 30, height: handleHeight)
            .background(
              AControlStyle.panelFill(colorScheme),
              in: UnevenRoundedRectangle(
                topLeadingRadius: 22,
                bottomLeadingRadius: 22,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0,
                style: .continuous
              )
            )
            .overlay {
              UnevenRoundedRectangle(
                topLeadingRadius: 22,
                bottomLeadingRadius: 22,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0,
                style: .continuous
              )
              .strokeBorder(AControlStyle.accentStroke(.purple, colorScheme), lineWidth: 1)
            }
            .shadow(color: AControlStyle.softShadow(colorScheme), radius: 14, x: -6, y: 6)
          }
          .buttonStyle(ImmediateFeedbackButtonStyle())
          .opacity(isHandleVisible ? 1 : 0)
          .offset(x: isHandleVisible ? 0 : 32)
          .allowsHitTesting(isHandleVisible)
          .accessibilityHidden(!isHandleVisible)
          .safeHelp("Open Files panel")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .contentShape(Rectangle())
        .onHover { hovering in
          updateHover(hovering)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
    }
  }

  private func updateHover(_ hovering: Bool) {
    isHoveringEdge = hovering
    hoverToken += 1
    let token = hoverToken
    if hovering {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
        guard token == hoverToken, isHoveringEdge else { return }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
          isHandleVisible = true
        }
      }
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
        guard token == hoverToken, !isHoveringEdge else { return }
        withAnimation(.easeOut(duration: 0.16)) {
          isHandleVisible = false
        }
      }
    }
  }
}

private struct SidebarSurfaceRow: View {
  @Environment(\.colorScheme) private var colorScheme
  var surface: AppSurface
  var isSelected: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: surface.symbol)
          .font(.system(size: 14, weight: .semibold))
          .frame(width: 22, alignment: .center)
        Text(surface.title)
          .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
          .lineLimit(1)
        Spacer(minLength: 0)
      }
      .foregroundStyle(isSelected ? selectedForeground : Color.primary)
      .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40, alignment: .leading)
      .padding(.horizontal, 12)
      .contentShape(Rectangle())
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .background(rowFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(
          isSelected ? Color.accentColor.opacity(colorScheme == .dark ? 0.16 : 0.12) : .clear,
          lineWidth: 1)
    }
  }

  private var rowFill: Color {
    if isSelected {
      return Color.accentColor.opacity(colorScheme == .dark ? 0.20 : 0.13)
    }
    return Color.clear
  }

  private var selectedForeground: Color {
    colorScheme == .dark ? .primary : Color.accentColor.opacity(0.82)
  }
}

private struct SidebarSessionRow: View {
  @Environment(\.colorScheme) private var colorScheme
  var session: SessionCard
  var isSelected: Bool
  var isCodexWorking: Bool
  var isClaudeWorking: Bool
  var remoteHome: String
  var showsPath = true
  var indentation: CGFloat = 0
  var action: () -> Void

  private var isWorking: Bool {
    isCodexWorking || isClaudeWorking
  }

  private var workTint: Color {
    if isCodexWorking && isClaudeWorking {
      return .purple
    }
    if isCodexWorking {
      return .blue
    }
    return .orange
  }

  private var workLabel: String {
    if isCodexWorking && isClaudeWorking {
      return "Both"
    }
    if isCodexWorking {
      return "Codex"
    }
    return "Claude"
  }

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(compact(session.displayTitle, limit: showsPath ? 44 : 38))
            .font(.callout.weight(isSelected ? .semibold : .medium))
            .lineLimit(1)
          Spacer(minLength: 0)
          if !showsPath, !isWorking {
            Text(relativeAge)
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          if isWorking {
            sessionActivityDot
            Text(workLabel)
              .font(.system(size: 9, weight: .bold))
              .foregroundStyle(AControlStyle.accentForeground(workTint, colorScheme))
              .padding(.horizontal, 6)
              .frame(height: 18)
              .background(
                AControlStyle.accentFill(workTint, colorScheme),
                in: Capsule()
              )
          }
        }
        if showsPath {
          Text(shortPath(session.remoteDir))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        if showsPath, !sessionStatusSummary.isEmpty {
          Text(sessionStatusSummary)
            .font(.caption2)
            .foregroundStyle(Color.secondary.opacity(0.82))
            .lineLimit(2)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.leading, 12 + indentation)
      .padding(.trailing, 10)
      .padding(.vertical, showsPath ? 9 : 7)
      .contentShape(Rectangle())
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .background(
      sessionFill,
      in: RoundedRectangle(cornerRadius: showsPath ? 12 : 9, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: showsPath ? 12 : 9, style: .continuous)
        .strokeBorder(sessionStroke, lineWidth: isWorking ? 1.4 : 0.8)
    }
    .accessibilityLabel(accessibilitySummary)
  }

  private var sessionFill: Color {
    if isWorking {
      return AControlStyle.accentFill(workTint, colorScheme).opacity(isSelected ? 0.88 : 0.58)
    }
    return isSelected ? Color.primary.opacity(colorScheme == .dark ? 0.09 : 0.045) : Color.clear
  }

  private var sessionStroke: Color {
    if isWorking {
      return AControlStyle.accentStroke(workTint, colorScheme)
    }
    return isSelected ? Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08) : Color.clear
  }

  private var sessionActivityDot: some View {
    Circle()
      .fill(workTint)
      .frame(width: 7, height: 7)
      .shadow(color: workTint.opacity(0.35), radius: 5)
  }

  private var sessionStatusSummary: String {
    if isWorking {
      return ""
    }
    return compact(session.agentSummary, limit: 90)
  }

  private func shortPath(_ path: String) -> String {
    path.replacingOccurrences(of: remoteHome, with: "~")
  }

  private var relativeAge: String {
    let seconds = max(0, Date().timeIntervalSince(session.updatedAt))
    if seconds < 60 { return "now" }
    if seconds < 60 * 60 { return "\(Int(seconds / 60))m" }
    if seconds < 24 * 60 * 60 { return "\(Int(seconds / 3_600))h" }
    if seconds < 7 * 24 * 60 * 60 { return "\(Int(seconds / 86_400))d" }
    return "\(Int(seconds / 604_800))w"
  }

  private var accessibilitySummary: String {
    [
      compact(session.displayTitle, limit: 60),
      shortPath(session.remoteDir),
      compact(session.agentSummary, limit: 120),
      isWorking ? workLabel : "",
    ]
    .filter { !$0.isEmpty }
    .joined(separator: ", ")
  }

  private func compact(_ value: String, limit: Int) -> String {
    let collapsed =
      value
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmed
    guard collapsed.count > limit else { return collapsed }
    return String(collapsed.prefix(max(0, limit - 1))).trimmed + "…"
  }
}

private struct RenameSessionSheet: View {
  @Environment(\.colorScheme) private var colorScheme
  var session: SessionCard
  @Binding var name: String
  var onCancel: () -> Void
  var onSave: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 10) {
        Image(systemName: "pencil")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(AControlStyle.accentForeground(.purple, colorScheme))
        Text("Rename Session")
          .font(.headline)
        Spacer()
      }
      TextField("Session name", text: $name)
        .textFieldStyle(.roundedBorder)
      HStack {
        Text(compact(session.agentSummary, limit: 110))
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
        Spacer()
        SoftButton(title: "Cancel") {
          onCancel()
        }
        PrimaryButton(title: "Save", symbol: "checkmark", tint: .purple) {
          onSave()
        }
      }
    }
    .padding(20)
    .frame(width: 420)
    .background(AControlStyle.panelFill(colorScheme))
  }

  private func compact(_ value: String, limit: Int) -> String {
    let collapsed =
      value
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmed
    guard collapsed.count > limit else { return collapsed }
    return String(collapsed.prefix(max(0, limit - 1))).trimmed + "…"
  }
}

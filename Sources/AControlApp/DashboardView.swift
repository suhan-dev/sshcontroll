import SwiftUI

struct DashboardView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.colorScheme) private var colorScheme
  @State private var newSessionName = ""
  @State private var newSessionTool: AISessionTool = .codex
  @State private var newSessionDirectory = ""
  @State private var newSessionDirectoryPinned = false
  @State private var showingSessionDirectoryPicker = false
  @State private var showHostAddress = false
  @State private var showStatusAddresses = false
  @State private var contentWidth: CGFloat = 0

  var body: some View {
    GeometryReader { proxy in
      VStack(alignment: .leading, spacing: 18) {
        SectionHeader(title: "SSHcontroll", detail: "lightweight SSH workspace") {
          await model.refreshDashboard()
        }

        if !model.settings.hasSSHTarget {
          SetupRequiredPanel()
        }

        topCards

        actionCards

        statusPanel
          .frame(maxHeight: .infinity)
      }
      .frame(maxWidth: .infinity, maxHeight: proxy.size.height, alignment: .topLeading)
      .background {
        GeometryReader { proxy in
          Color.clear.preference(key: DashboardWidthKey.self, value: proxy.size.width)
        }
      }
    }
    .onPreferenceChange(DashboardWidthKey.self) { contentWidth = $0 }
    .sheet(isPresented: $showingSessionDirectoryPicker) {
      RemoteDirectoryPicker(title: "Session Directory") { path in
        newSessionDirectory = path
        newSessionDirectoryPinned = true
      }
      .environmentObject(model)
    }
    .task {
      if newSessionDirectory.trimmed.isEmpty {
        newSessionDirectory = model.currentRemoteDir
      }
      if model.dashboardStatusSnapshot.isEmpty {
        await model.refreshDashboard()
      }
    }
    .onChange(of: model.currentRemoteDir) { _, value in
      guard !newSessionDirectoryPinned else { return }
      newSessionDirectory = value
    }
  }

  private func short(_ path: String) -> String {
    path.replacingOccurrences(of: model.settings.remoteHome, with: "~")
  }

  private var topCards: some View {
    LazyVGrid(columns: dashboardGridColumns, spacing: 14) {
      dashboardCards
    }
    .frame(maxWidth: .infinity)
  }

  private var dashboardGridColumns: [GridItem] {
    let count: Int
    if contentWidth >= 820 {
      count = 4
    } else if contentWidth >= 520 {
      count = 2
    } else {
      count = 1
    }
    return Array(repeating: GridItem(.flexible(minimum: 0), spacing: 12), count: count)
  }

  @ViewBuilder
  private var dashboardCards: some View {
    HostPrivacyCard(
      host: model.settings.hostAlias,
      address: model.settings.latencyTarget,
      isRevealed: $showHostAddress
    )
    .frame(maxWidth: .infinity)
    MetricCard(
      title: "Remote Dir", value: short(model.currentRemoteDir), subtitle: model.currentRemoteDir,
      symbol: "folder", tint: .blue, valueSize: 17, valueLineLimit: 1, minHeight: 104, padding: 14
    )
    .frame(maxWidth: .infinity)
    MetricCard(
      title: "Session", value: model.activeSession?.displayTitle ?? "Default",
      subtitle: model.activeSession?.dashboardAgentSummary ?? "Codex ready", symbol: "rectangle.stack",
      tint: .purple, valueSize: 20, valueLineLimit: 1, minHeight: 104, padding: 14
    )
    .frame(maxWidth: .infinity)
    MetricCard(
      title: "State", value: model.isBusy ? "Working" : "Ready", subtitle: model.statusText,
      symbol: "bolt", tint: model.isBusy ? .orange : .green, valueSize: 20, valueLineLimit: 1,
      minHeight: 104, padding: 14
    )
    .frame(maxWidth: .infinity)
  }

  private var actionCards: some View {
    Group {
      if contentWidth >= 760 {
        HStack(alignment: .top, spacing: 18) {
          quickActionsPanel
            .frame(maxWidth: .infinity)
          newSessionPanel
            .frame(maxWidth: .infinity)
        }
      } else {
        VStack(spacing: 16) {
          quickActionsPanel
          newSessionPanel
        }
      }
    }
    .frame(height: 150)
    .frame(maxWidth: .infinity)
  }

  private var statusPanel: some View {
    DashboardStatusPanel(
      text: model.dashboardStatusSnapshot,
      showAddresses: $showStatusAddresses
    )
  }

  private var quickActionsPanel: some View {
    DashboardQuickActionsPanel()
  }

  private var newSessionPanel: some View {
    GlassPanel(
      title: "New Session", symbol: "plus.rectangle.on.rectangle", accent: .purple, fillHeight: true
    ) {
      HStack(spacing: 10) {
        SessionNameField(text: $newSessionName)
        CompactToolToggle(selection: $newSessionTool)
          .frame(width: 190)
      }
      HStack {
        Image(systemName: "folder")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(AControlStyle.accentForeground(.blue, colorScheme))
        Text(sessionDirectoryDisplay)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
        Spacer()
        SessionCommandButton(title: "Dir", symbol: "folder", tint: .gray) {
          newSessionDirectory = sessionDirectory
          newSessionDirectoryPinned = true
          showingSessionDirectoryPicker = true
        }
        SessionCommandButton(title: "Save", symbol: "checkmark", tint: .purple) {
          let directory = sessionDirectory
          let name =
            newSessionName.trimmed.isEmpty
            ? URL(fileURLWithPath: directory.expandingTilde).lastPathComponent
            : newSessionName.trimmed
          let tool = newSessionTool
          let session = model.addSession(name: name, path: directory, tool: tool)
          newSessionName = ""
          newSessionDirectory = directory
          newSessionDirectoryPinned = false
          Task { await model.openSession(session, initialTool: tool, syncShell: true) }
        }
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: 150)
  }

  private var sessionDirectory: String {
    let value = newSessionDirectory.trimmed
    return value.isEmpty ? model.currentRemoteDir : value
  }

  private var sessionDirectoryDisplay: String {
    short(sessionDirectory)
  }
}

private struct SessionNameField: View {
  @Environment(\.colorScheme) private var colorScheme
  @Binding var text: String

  var body: some View {
    TextField("Session name", text: $text)
      .textFieldStyle(.plain)
      .font(.system(size: 15, weight: .medium))
      .padding(.horizontal, 12)
      .frame(height: 40)
      .background(
        AControlStyle.insetFill(colorScheme),
        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
      }
  }
}

private struct CompactToolToggle: View {
  @Environment(\.colorScheme) private var colorScheme
  @Binding var selection: AISessionTool

  var body: some View {
    HStack(spacing: 3) {
      toolButton(.codex)
      toolButton(.claude)
    }
    .padding(3)
    .frame(height: 40)
    .background(
      AControlStyle.insetFill(colorScheme),
      in: RoundedRectangle(cornerRadius: 9, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
    }
  }

  private func toolButton(_ tool: AISessionTool) -> some View {
    Button {
      selection = tool
    } label: {
      Label(tool.title, systemImage: tool.symbol)
        .font(.system(size: 12.5, weight: .semibold))
        .lineLimit(1)
        .frame(maxWidth: .infinity, minHeight: 34)
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .foregroundStyle(selection == tool ? .primary : .secondary)
    .background(
      selection == tool ? Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.055) : Color.clear,
      in: RoundedRectangle(cornerRadius: 7, style: .continuous)
    )
  }
}

private struct SessionCommandButton: View {
  @Environment(\.colorScheme) private var colorScheme
  var title: String
  var symbol: String
  var tint: Color
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(title, systemImage: symbol)
        .font(.system(size: 12.5, weight: .semibold))
        .lineLimit(1)
        .padding(.horizontal, 13)
        .frame(height: 34)
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .accessibilityLabel(Text(title))
    .foregroundStyle(.primary)
    .background(AControlStyle.accentFill(tint, colorScheme), in: Capsule())
    .overlay {
      Capsule().strokeBorder(AControlStyle.accentStroke(tint, colorScheme), lineWidth: 1)
    }
  }
}

private struct SetupRequiredPanel: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    GlassPanel(title: "Setup Required", symbol: "wrench.and.screwdriver", accent: .blue) {
      HStack(alignment: .center, spacing: 12) {
        Text(
          "Add an SSH target in Settings, then install the bundled remote helper and check the connection."
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        Spacer()
        PrimaryButton(title: "Open Settings", symbol: "gearshape", tint: .blue) {
          model.selectedSurface = .settings
        }
      }
    }
  }
}

private struct DashboardStatusPanel: View {
  @Environment(\.colorScheme) private var colorScheme
  var text: String
  @Binding var showAddresses: Bool

  var body: some View {
    GlassPanel(title: nil, fillHeight: true) {
      header
      StatusSnapshotView(
        text: showAddresses ? text : redactedAddresses(in: text),
        placeholder: "Press Refresh to read A status."
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .layoutPriority(1)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var header: some View {
    Button {
      withAnimation(.easeOut(duration: 0.16)) {
        showAddresses.toggle()
      }
    } label: {
      HStack(spacing: 9) {
        Image(systemName: showAddresses ? "eye" : "eye.slash")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(AControlStyle.accentForeground(.teal, colorScheme))
        Text("A Status")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.primary)
        Text(showAddresses ? "Private visible" : "Private hidden")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
        Spacer()
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
  }

  private func redactedAddresses(in text: String) -> String {
    let redacted = text.replacingOccurrences(
      of: #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#,
      with: "...",
      options: .regularExpression
    )
    return redactedPrivateBlocks(in: redacted)
      .map(normalizedRedactedLine)
      .joined(separator: "\n")
  }

  private func redactedPrivateBlocks(in text: String) -> [String] {
    let lines = text.components(separatedBy: .newlines)
    var output: [String] = []
    var index = 0

    while index < lines.count {
      let trimmed = lines[index].trimmingCharacters(in: .whitespaces)

      if trimmed == "tmux sessions:" {
        var count = 0
        index += 1
        while index < lines.count {
          let sessionLine = lines[index].trimmingCharacters(in: .whitespaces)
          if sessionLine.isEmpty { break }
          if sessionLine != "none" { count += 1 }
          index += 1
        }
        output.append("tmux sessions: \(count == 0 ? "none" : "\(count) active (hidden)")")
        continue
      }

      if trimmed == "tailscale:" {
        var hasDetails = false
        index += 1
        while index < lines.count {
          let tailscaleLine = lines[index].trimmingCharacters(in: .whitespaces)
          if tailscaleLine.isEmpty { break }
          hasDetails = true
          index += 1
        }
        output.append("tailscale: \(hasDetails ? "details hidden" : "none")")
        continue
      }

      output.append(redactedStatusLine(lines[index]))
      index += 1
    }

    return output
  }

  private func redactedStatusLine(_ line: String) -> String {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    let sensitivePrefixes = [
      "host:",
      "user:",
      "codex_app_bin:",
      "claude_bin:",
      "path_codex:",
      "path_claude:",
    ]
    if let prefix = sensitivePrefixes.first(where: { trimmed.lowercased().hasPrefix($0) }) {
      let leading = String(line.prefix { $0 == " " || $0 == "\t" })
      return "\(leading)\(prefix) hidden"
    }
    return
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
  }

  private func normalizedRedactedLine(_ line: String) -> String {
    let leadingTrimmed = line.trimmingCharacters(in: .whitespaces)
    guard leadingTrimmed.hasPrefix("...") else { return line }
    let rest = leadingTrimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
    guard !rest.isEmpty else { return "..." }
    return "...    \(rest)"
  }
}

private struct StatusSnapshotView: View {
  @Environment(\.colorScheme) private var colorScheme
  var text: String
  var placeholder: String

  private var displayText: String {
    let value = text.trimmed.isEmpty ? placeholder : text
    return value.replacingOccurrences(of: "\r", with: "\n")
  }

  var body: some View {
    GeometryReader { proxy in
      let fontSize = statusFontSize(for: proxy.size)
      Text(displayText)
        .font(.system(size: fontSize, design: .monospaced))
        .lineSpacing(fontSize >= 12.5 ? 3 : 0.5)
        .foregroundStyle(text.trimmed.isEmpty ? .secondary : .primary)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(18)
    }
    .background(
      AControlStyle.transcriptFill(colorScheme),
      in: RoundedRectangle(cornerRadius: AControlStyle.insetRadius, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: AControlStyle.insetRadius, style: .continuous)
        .strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
    }
    .shadow(color: AControlStyle.softShadow(colorScheme), radius: 8, x: 0, y: 4)
  }

  private func statusFontSize(for size: CGSize) -> CGFloat {
    let lineCount = max(1, displayText.components(separatedBy: .newlines).count)
    let usableHeight = max(0, size.height - 42)
    let fitted = ((usableHeight / CGFloat(lineCount)) - 1.5) / 1.24
    return min(13, max(8.8, fitted))
  }
}

private struct DashboardQuickActionsPanel: View {
  @EnvironmentObject private var model: AppModel
  private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

  var body: some View {
    GlassPanel(title: "Quick Actions", symbol: "wand.and.stars", accent: .cyan, fillHeight: true) {
      LazyVGrid(columns: columns, spacing: 8) {
        DashboardActionButton(title: "Shell", symbol: "terminal", tint: .cyan) {
          model.selectedSurface = .shell
        }
        DashboardActionButton(title: "Codex", symbol: "sparkles", tint: .purple) {
          model.selectedSurface = .codex
        }
        DashboardActionButton(title: "Monitor", symbol: "waveform.path.ecg", tint: .green) {
          model.selectedSurface = .monitor
        }
        DashboardActionButton(title: "Files", symbol: "folder", tint: .blue) {
          model.selectedSurface = .files
        }
        DashboardActionButton(title: "Mirror", symbol: "arrow.triangle.2.circlepath", tint: .orange)
        { model.selectedSurface = .mirror }
        DashboardActionButton(title: "Settings", symbol: "gearshape", tint: .gray) {
          model.selectedSurface = .settings
        }
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: 150)
  }
}

private struct DashboardActionButton: View {
  @Environment(\.colorScheme) private var colorScheme
  var title: String
  var symbol: String
  var tint: Color
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(title, systemImage: symbol)
        .font(.system(size: 13, weight: .semibold))
        .lineLimit(1)
        .frame(maxWidth: .infinity, minHeight: AControlStyle.controlHeight)
        .padding(.horizontal, 8)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .accessibilityLabel(Text(title))
    .foregroundStyle(.primary)
    .background(
      AControlStyle.accentFill(tint, colorScheme),
      in: RoundedRectangle(cornerRadius: 12, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(AControlStyle.accentStroke(tint, colorScheme), lineWidth: 1)
    }
  }
}

private struct DashboardWidthKey: PreferenceKey {
  static let defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

private struct HostPrivacyCard: View {
  @Environment(\.colorScheme) private var colorScheme
  var host: String
  var address: String
  @Binding var isRevealed: Bool

  var body: some View {
    Button {
      withAnimation(.easeOut(duration: 0.18)) {
        isRevealed.toggle()
      }
    } label: {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Image(systemName: "network")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AControlStyle.accentForeground(.cyan, colorScheme))
            .frame(width: 28, height: 28)
            .background(AControlStyle.accentFill(.cyan, colorScheme), in: Circle())
          Text("Host")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Spacer()
        }
        Text(host)
          .font(.system(size: 20, weight: .bold))
          .lineLimit(1)
          .minimumScaleFactor(0.75)
        Text(address.trimmed.isEmpty ? "not set" : address)
          .font(.caption)
          .foregroundStyle(isRevealed ? .secondary : .primary)
          .blur(radius: isRevealed || address.trimmed.isEmpty ? 0 : 4.2)
          .opacity(
            isRevealed ? 1 : (address.trimmed.isEmpty ? 0.58 : (colorScheme == .dark ? 0.62 : 0.54))
          )
          .shadow(
            color: .black.opacity(isRevealed ? 0 : (colorScheme == .dark ? 0.30 : 0.20)), radius: 7,
            x: 0, y: 2
          )
          .accessibilityLabel(isRevealed ? address : "Hidden address")
      }
      .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
      .padding(14)
      .background(
        AControlStyle.panelFill(colorScheme),
        in: RoundedRectangle(cornerRadius: AControlStyle.panelRadius, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: AControlStyle.panelRadius, style: .continuous)
          .strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
      }
      .shadow(color: AControlStyle.softShadow(colorScheme), radius: 14, x: 0, y: 8)
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .safeHelp(isRevealed ? "Hide address" : "Reveal address")
  }
}

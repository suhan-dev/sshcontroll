import AppKit
import SwiftUI

struct CodeWorkspaceWindowContent: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    CodeWorkspaceView()
      .environmentObject(model)
      .preferredColorScheme(model.settings.theme.colorScheme)
      .frame(minWidth: 1180, minHeight: 760)
  }
}

struct CodeWorkspaceView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.colorScheme) private var colorScheme
  var isInline = false
  @State private var folderDraft = ""
  @State private var searchText = ""
  @State private var shellDraft = ""
  @State private var codexScrollSignal = 0
  @State private var openFilePaths: [String] = []
  @State private var liveExplorerWidth: CGFloat?
  @State private var liveCodexWidth: CGFloat?
  @State private var liveConsoleHeight: CGFloat?
  @State private var selectedResearchPreset: CodexResearchPreset?
  @AppStorage("AControl.researchPresetLoopCount") private var storedResearchLoopCount =
    CodexResearchPreset.defaultLoopCount

  private var currentFolder: String {
    model.fileBrowserDir.trimmed.isEmpty ? model.currentRemoteDir : model.fileBrowserDir
  }

  private var researchLoopCount: Int {
    CodexResearchPreset.clampedLoopCount(storedResearchLoopCount)
  }

  private var palette: CodeWorkspacePalette {
    CodeWorkspacePalette(scheme: colorScheme)
  }

  private var visibleItems: [RemoteItem] {
    let query = searchText.trimmed.lowercased()
    let items =
      query.isEmpty
      ? model.fileBrowserItems
      : model.fileBrowserItems.filter { $0.name.lowercased().contains(query) }
    return items.sorted { first, second in
      if first.isDirectory != second.isDirectory {
        return first.isDirectory && !second.isDirectory
      }
      return first.name.localizedStandardCompare(second.name) == .orderedAscending
    }
  }

  private var workspaceQueueItems: [CodexPromptQueueItem] {
    let active = model.activeSessionID
    return model.codexPromptQueue
      .filter { item in active == nil || item.sessionID == active }
      .filter(\.isVisibleInComposerQueue)
      .sorted { first, second in
        if first.status != second.status {
          return queueSortRank(first.status) < queueSortRank(second.status)
        }
        if first.kind != second.kind {
          return first.kind == .steer
        }
        return first.createdAt < second.createdAt
      }
  }

  private var canSteerCodex: Bool {
    model.activeCodexCanSteer
  }

  private var workspaceCodexTranscript: String {
    let value = model.codexTranscript
    guard value.count > 32_000 else { return value }
    return String(value.suffix(32_000))
  }

  var body: some View {
    VStack(spacing: 0) {
      titleBar

      HStack(spacing: 0) {
        if !model.isCodeWorkspaceExplorerCollapsed {
          explorerPane
            .frame(width: liveExplorerWidth ?? model.codeWorkspaceExplorerWidth)
            .transaction { $0.animation = nil }
          CodeWorkspaceResizeHandle(
            axis: .horizontal,
            value: liveExplorerWidth ?? model.codeWorkspaceExplorerWidth,
            multiplier: 1,
            clamp: { model.clampedCodeWorkspaceExplorerWidth($0) },
            onChange: { liveExplorerWidth = $0 },
            onEnd: {
              model.setCodeWorkspaceExplorerWidth($0, persist: true)
              liveExplorerWidth = nil
            }
          )
        }

        VStack(spacing: 0) {
          editorArea
          if model.isCodeWorkspaceConsoleVisible {
            CodeWorkspaceResizeHandle(
              axis: .vertical,
              value: liveConsoleHeight ?? model.codeWorkspaceConsoleHeight,
              multiplier: -1,
              clamp: { model.clampedCodeWorkspaceConsoleHeight($0) },
              onChange: { liveConsoleHeight = $0 },
              onEnd: {
                model.setCodeWorkspaceConsoleHeight($0, persist: true)
                liveConsoleHeight = nil
              }
            )
            shellPane
              .frame(height: liveConsoleHeight ?? model.codeWorkspaceConsoleHeight)
              .transaction { $0.animation = nil }
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        if !model.isCodeWorkspaceCodexCollapsed {
          CodeWorkspaceResizeHandle(
            axis: .horizontal,
            value: liveCodexWidth ?? model.codeWorkspaceCodexWidth,
            multiplier: -1,
            clamp: { model.clampedCodeWorkspaceCodexWidth($0) },
            onChange: { liveCodexWidth = $0 },
            onEnd: {
              model.setCodeWorkspaceCodexWidth($0, persist: true)
              liveCodexWidth = nil
            }
          )
          codexPane
            .frame(width: liveCodexWidth ?? model.codeWorkspaceCodexWidth)
            .transaction { $0.animation = nil }
        }
      }

    }
    .background(palette.background)
    .foregroundStyle(palette.primaryText)
    .task {
      folderDraft = model.activeSession?.remoteDir ?? currentFolder
      rememberOpenFile(model.openedRemoteFile)
      await model.prepareCodeWorkspaceForActiveSession()
      folderDraft = currentFolder
    }
    .onChange(of: model.fileBrowserDir) { _, value in
      folderDraft = value
    }
    .onChange(of: model.openedRemoteFile) { _, value in
      rememberOpenFile(value)
    }
    .sheet(isPresented: $model.isCodeWorkspaceDirectoryPickerPresented) {
      RemoteDirectoryPicker(title: "Open Workspace Folder") { path in
        folderDraft = path
        model.isCodeWorkspaceDirectoryPickerPresented = false
        Task { await model.openFileBrowserFolderFromInput(path, force: false) }
      }
      .environmentObject(model)
    }
  }

  private var titleBar: some View {
    HStack(spacing: 10) {
      if isInline {
        Button {
          model.closeCodeWorkspaceInline()
        } label: {
          Image(systemName: "chevron.left")
        }
        .buttonStyle(ImmediateFeedbackButtonStyle())
        .safeHelp("Back to previous screen (Esc or Command-[)")
      }

      Button {
        model.toggleCodeWorkspaceExplorer()
      } label: {
        Image(systemName: "sidebar.left")
      }
      .buttonStyle(ImmediateFeedbackButtonStyle())
      .safeHelp("Toggle explorer")

      Button {
        model.toggleCodeWorkspaceCodex()
      } label: {
        Image(systemName: "sidebar.right")
      }
      .buttonStyle(ImmediateFeedbackButtonStyle())
      .safeHelp("Toggle Codex panel")

      Button {
        model.toggleCodeWorkspaceConsole()
      } label: {
        Image(systemName: "terminal")
      }
      .buttonStyle(ImmediateFeedbackButtonStyle())
      .safeHelp("Toggle console")

      HStack(spacing: 8) {
        Image(systemName: "folder")
          .foregroundStyle(palette.secondaryText)
        TextField("Open folder", text: $folderDraft)
          .textFieldStyle(.plain)
          .font(.system(size: 13, weight: .medium, design: .monospaced))
          .onSubmit {
            Task { await openFolder(force: false) }
          }
        Button {
          model.isCodeWorkspaceDirectoryPickerPresented = true
        } label: {
          Image(systemName: "folder.badge.gearshape")
        }
        .buttonStyle(ImmediateFeedbackButtonStyle())
        .safeHelp("Choose workspace folder (Ctrl-O)")
        Button {
          Task { await openFolder(force: false) }
        } label: {
          Image(systemName: "arrow.right.circle")
        }
        .buttonStyle(ImmediateFeedbackButtonStyle())
        .safeHelp("Open folder")
        Button {
          Task { await openFolder(force: true) }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(ImmediateFeedbackButtonStyle())
        .safeHelp("Refresh folder")
      }
      .padding(.horizontal, 10)
      .frame(maxWidth: 720, minHeight: 30)
      .background(palette.controlFill, in: RoundedRectangle(cornerRadius: 7))

      Spacer()

      if !workspaceQueueItems.isEmpty {
        Label("\(workspaceQueueItems.count)", systemImage: "tray.full")
          .font(.caption.weight(.bold))
          .foregroundStyle(Color.orange.opacity(0.92))
          .padding(.horizontal, 8)
          .frame(height: 28)
          .background(palette.controlFill, in: RoundedRectangle(cornerRadius: 7))
          .safeHelp("Codex queue")
      }

      if let activeSession = model.activeSession {
        Text(activeSession.name)
          .font(.caption.weight(.semibold))
          .foregroundStyle(palette.secondaryText.opacity(0.85))
          .lineLimit(1)
          .truncationMode(.tail)
          .frame(maxWidth: 180, alignment: .trailing)
          .safeHelp("Active session")
      }

      themeToggle

      if model.codexWorkingSessionIDs.contains(model.activeSessionID ?? UUID()) {
        Label("Codex running", systemImage: "circle.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(Color.blue.opacity(0.95))
      }
    }
    .font(.system(size: 13, weight: .semibold))
    .padding(.horizontal, 14)
    .frame(height: 48)
    .background(palette.titleBar)
  }

  private var themeToggle: some View {
    Button {
      switch model.settings.theme {
      case .dark:
        model.settings.theme = .light
      case .light, .system:
        model.settings.theme = .dark
      }
      model.saveSettings()
    } label: {
      Image(systemName: model.settings.theme == .dark ? "sun.max" : "moon")
        .frame(width: 28, height: 28)
        .background(palette.controlFill, in: RoundedRectangle(cornerRadius: 7))
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .safeHelp("Toggle light and dark mode")
  }

  private var explorerPane: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("A EXPLORER")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(palette.secondaryText)
        Spacer()
        Button {
          Task { await openFolder(force: true) }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(ImmediateFeedbackButtonStyle())
        .safeHelp("Refresh")
      }
      .padding(.horizontal, 14)
      .frame(height: 38)

      TextField("Search files", text: $searchText)
        .textFieldStyle(.plain)
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(palette.controlFill, in: RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)

      ScrollView {
        LazyVStack(spacing: 1) {
          ForEach(visibleItems) { item in
            CodeWorkspaceFileRow(
              item: item,
              isSelected: model.selectedRemoteItemIDs.contains(item.id),
              select: {
                model.selectRemoteItem(item, visibleItems: visibleItems)
              },
              open: {
                Task { await openWorkspaceItem(item) }
              }
            )
          }
        }
        .padding(.horizontal, 8)
      }

      HStack(spacing: 8) {
        Text("\(visibleItems.count) items")
        Spacer()
        Button {
          Task { await openSelectedWorkspaceItem() }
        } label: {
          Image(systemName: "arrow.right.circle")
        }
        .buttonStyle(ImmediateFeedbackButtonStyle())
        .disabled(model.selectedRemoteItem == nil)
        .safeHelp("Open selected folder or file")
        if model.isFileBrowserLoading {
          ProgressView()
            .controlSize(.mini)
        } else if !model.fileBrowserError.trimmed.isEmpty {
          Image(systemName: "exclamationmark.triangle")
        } else {
          Image(systemName: "externaldrive.badge.checkmark")
        }
      }
      .font(.system(size: 11, weight: .medium))
      .foregroundStyle(palette.secondaryText.opacity(0.78))
      .padding(.horizontal, 14)
      .frame(height: 30)
    }
    .background(palette.sidebar)
  }

  private var editorArea: some View {
    VStack(spacing: 0) {
      editorTabStrip
      editorHeader
      editorPane
      editorStatusBar
    }
  }

  private var editorTabStrip: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 1) {
        if openFilePaths.isEmpty {
          Text("No open files")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(palette.secondaryText.opacity(0.74))
            .padding(.horizontal, 12)
            .frame(height: 30)
        } else {
          ForEach(openFilePaths, id: \.self) { path in
            CodeWorkspaceTab(
              path: path,
              isSelected: path == model.openedRemoteFile,
              isDirty: path == model.openedRemoteFile && model.isRemoteFileDirty,
              select: {
                Task { await model.readRemoteFile(path, switchToFiles: false) }
              },
              close: {
                closeOpenFile(path)
              }
            )
          }
        }
      }
      .padding(.leading, 8)
      .padding(.trailing, 12)
    }
    .frame(height: 32)
    .background(palette.tabBar)
  }

  private var editorHeader: some View {
    HStack(spacing: 10) {
      Image(systemName: "doc.text")
        .foregroundStyle(palette.secondaryText)
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(model.openedRemoteFile.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "No file open")
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
          if model.isRemoteFileDirty {
            Circle()
              .fill(Color.orange.opacity(0.92))
              .frame(width: 7, height: 7)
          }
        }
        Text(model.openedRemoteFile?.replacingOccurrences(of: NSHomeDirectory(), with: "~") ?? currentFolder)
          .font(.system(size: 10.5, weight: .medium, design: .monospaced))
          .foregroundStyle(palette.secondaryText.opacity(0.72))
          .lineLimit(1)
          .truncationMode(.middle)
      }
      Spacer()
      if model.remotePreviewKind == .text, model.openedRemoteFile != nil {
        Text(model.remoteFileIsPreviewOnly ? "Preview only" : (model.isRemoteFileDirty ? "Modified" : "Saved"))
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(
            model.remoteFileIsPreviewOnly || model.isRemoteFileDirty
              ? Color.orange.opacity(0.95) : palette.secondaryText.opacity(0.78))
      }
      Button {
        Task { await model.saveRemoteFile() }
      } label: {
        Label("Save", systemImage: "checkmark.circle")
      }
      .buttonStyle(ImmediateFeedbackButtonStyle())
      .disabled(
        model.openedRemoteFile == nil || model.remotePreviewKind != .text || model.remoteFileIsPreviewOnly
          || !model.isRemoteFileDirty)
      .safeHelp("Save current file to A")
    }
    .padding(.horizontal, 14)
    .frame(height: 46)
    .background(palette.header)
  }

  @ViewBuilder
  private var editorPane: some View {
      if model.openedRemoteFile == nil {
        VStack(spacing: 14) {
          Image(systemName: "curlybraces.square")
            .font(.system(size: 56, weight: .light))
            .foregroundStyle(palette.secondaryText.opacity(0.18))
          Text("Double-click a file to edit it.")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if model.remotePreviewKind == .text {
        if model.isRemotePreviewLoading && model.remoteFileText.isEmpty {
          CodeWorkspaceLoadingView(text: "Loading text preview...", detail: model.lastMirrorLog)
        } else if model.remoteFileIsPreviewOnly {
          ScrollView {
            Text(model.remoteFileText)
              .font(.system(size: 13.2, design: .monospaced))
              .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .topLeading)
              .padding(14)
          }
          .background(palette.panel)
        } else {
          CodeTextEditor(
            text: $model.remoteFileText,
            identity: model.openedRemoteFile ?? "",
            isDark: colorScheme == .dark,
            fontSize: 13.2
          )
        }
      } else {
        RemotePreviewPane()
      }
  }

  private var editorStatusBar: some View {
    HStack(spacing: 12) {
      if model.remotePreviewKind == .text, model.openedRemoteFile != nil {
        Text("\(lineCount) lines")
        Text("\(model.remoteFileText.count) chars")
        Text(languageLabel)
      } else {
        Text(model.openedRemoteFile == nil ? "Ready" : previewKindLabel)
      }
      Spacer()
      if model.isRemoteFileDirty {
        Text("Unsaved")
          .foregroundStyle(Color.orange.opacity(0.95))
      } else if model.remoteFileIsPreviewOnly {
        Text("Preview only")
          .foregroundStyle(Color.orange.opacity(0.95))
      } else if model.openedRemoteFile != nil {
        Text("OK")
      }
    }
    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
    .foregroundStyle(palette.secondaryText.opacity(0.78))
    .padding(.horizontal, 12)
    .frame(height: 22)
    .background(palette.statusBar)
  }

  private var codexPane: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Label("A CODEX", systemImage: "sparkles")
          .font(.system(size: 12, weight: .bold))
        Spacer()
        if let updated = model.codexTranscriptUpdatedAt {
          Text(updated.shortStamp)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(palette.secondaryText.opacity(0.72))
        }
        Button {
          codexScrollSignal += 1
        } label: {
          Image(systemName: "arrow.down.to.line")
        }
        .buttonStyle(ImmediateFeedbackButtonStyle())
        .safeHelp("Scroll Codex to bottom")
        Button {
          Task {
            await model.syncServerCodexHistoryAndRefreshVisibleSession()
            codexScrollSignal += 1
          }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(ImmediateFeedbackButtonStyle())
      }
      .foregroundStyle(palette.secondaryText)
      .padding(.horizontal, 12)
      .frame(height: 38)

      CodexActivityTranscriptView(
        text: workspaceCodexTranscript,
        placeholder: "Codex transcript appears here.",
        scrollSignal: codexScrollSignal,
        followTailSignal: codexScrollSignal,
        usesPanelChrome: false
      )
      .font(.system(size: 11.5, weight: .regular, design: .monospaced))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(.horizontal, 6)
      .padding(.bottom, 6)

      if !workspaceQueueItems.isEmpty {
        CodeWorkspaceQueueStrip(items: workspaceQueueItems)
          .environmentObject(model)
          .padding(.horizontal, 10)
          .padding(.bottom, 8)
      }

      HStack(spacing: 8) {
        PromptComposerView(
          text: $model.codexInput,
          onAttachFiles: { urls in
            model.addCodexAttachments(urls)
          },
          onAttachImage: { data, ext in
            model.addCodexImageAttachment(data: data, suggestedExtension: ext)
          },
          onSubmit: {
            Task { await sendWorkspaceCodex(steer: false) }
          },
          fontSize: 12.5,
          textInset: NSSize(width: 9, height: 7)
        )
        .frame(height: 34)
        .background(palette.controlFill, in: RoundedRectangle(cornerRadius: 7))

        if !model.codexAttachments.isEmpty {
          Button {
            model.clearCodexAttachments()
          } label: {
            Label("\(model.codexAttachments.count)", systemImage: "paperclip")
              .font(.system(size: 11, weight: .bold))
          }
          .buttonStyle(ImmediateFeedbackButtonStyle())
          .safeHelp("Clear attached files")
        }

        CodexResearchPresetMenu(
          compact: true,
          selectedPreset: selectedResearchPreset,
          onSelect: { preset in
            selectedResearchPreset = preset
          },
          onClear: {
            selectedResearchPreset = nil
          }
        )
          .environmentObject(model)
          .frame(width: 34, height: 30)
          .safeHelp(
            selectedResearchPreset.map { "Professor Lab: \($0.title) · \(researchLoopCount) stages" }
              ?? "Select Professor Lab mode"
          )

        Button {
          Task { await sendWorkspaceCodex(steer: false) }
        } label: {
          Image(systemName: "paperplane")
        }
        .buttonStyle(ImmediateFeedbackButtonStyle())
      }
      .padding(10)
    }
    .background(palette.panel)
  }

  private var shellPane: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        Label("A CONSOLE", systemImage: "terminal")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(palette.secondaryText)
        Spacer()
        Text(currentFolder)
          .font(.system(size: 11, weight: .medium, design: .monospaced))
          .foregroundStyle(palette.secondaryText.opacity(0.72))
          .lineLimit(1)
          .truncationMode(.middle)
      }
      .padding(.horizontal, 12)
      .frame(height: 30)

      TerminalTranscriptView(
        text: model.shellTranscript,
        placeholder: "Shell output appears here.",
        currentDirectory: model.currentRemoteDir,
        scrollSignal: 0
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      HStack(spacing: 8) {
        TextField("Run command", text: $shellDraft)
          .textFieldStyle(.plain)
          .font(.system(size: 12.5, design: .monospaced))
          .padding(.horizontal, 9)
          .frame(height: 30)
          .background(palette.controlFill, in: RoundedRectangle(cornerRadius: 7))
          .onSubmit {
            Task { await runShellDraft() }
          }
        Button {
          Task { await runShellDraft() }
        } label: {
          Image(systemName: "return")
        }
        .buttonStyle(ImmediateFeedbackButtonStyle())
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
    }
    .background(palette.console)
  }

  private func openFolder(force: Bool) async {
    let target = folderDraft.trimmed.isEmpty ? currentFolder : folderDraft.trimmed
    folderDraft = target
    await model.openFileBrowserFolderFromInput(target, force: force)
  }

  private func openWorkspaceItem(_ item: RemoteItem) async {
    await model.openCodeWorkspaceItem(item)
    if !item.isDirectory {
      rememberOpenFile(item.path)
    }
  }

  private func openSelectedWorkspaceItem() async {
    guard let item = model.selectedRemoteItem else { return }
    await openWorkspaceItem(item)
  }

  private func rememberOpenFile(_ path: String?) {
    guard let path, !path.trimmed.isEmpty else { return }
    openFilePaths.removeAll { $0 == path }
    openFilePaths.append(path)
    if openFilePaths.count > 10 {
      openFilePaths.removeFirst(openFilePaths.count - 10)
    }
  }

  private func closeOpenFile(_ path: String) {
    openFilePaths.removeAll { $0 == path }
    if model.openedRemoteFile == path {
      if let next = openFilePaths.last {
        Task { await model.readRemoteFile(next, switchToFiles: false) }
      } else {
        model.openedRemoteFile = nil
        model.remoteFileText = ""
        model.remoteFileSavedText = ""
        model.remotePreviewURL = nil
        model.remotePreviewKind = .none
      }
    }
  }

  private func runShellDraft() async {
    let command = shellDraft.trimmed
    guard !command.isEmpty else { return }
    model.shellInput = command
    shellDraft = ""
    await model.sendShell()
  }

  private func sendWorkspaceCodex(steer: Bool) async {
    if !steer, let selectedResearchPreset {
      guard !model.codexInput.trimmed.isEmpty || !model.codexAttachments.isEmpty else {
        model.statusText = "Write a prompt before sending Professor Lab · \(Date().shortStamp)"
        return
      }
      let accepted = await model.enqueueCodexResearchPreset(
        selectedResearchPreset,
        seedPrompt: model.codexInput,
        displayPrompt: model.codexInput,
        attachments: model.codexAttachments,
        loopCount: researchLoopCount
      )
      if accepted {
        model.codexInput = ""
        self.selectedResearchPreset = nil
      }
      return
    }
    _ = await model.sendCodex(steer: steer)
  }

  private func queueSortRank(_ status: CodexPromptQueueStatus) -> Int {
    switch status {
    case .sending: return 0
    case .waitingForCodex: return 1
    case .queued: return 2
    case .failed: return 3
    case .delivered: return 4
    }
  }

  private var lineCount: Int {
    max(1, model.remoteFileText.reduce(1) { count, character in
      character == "\n" ? count + 1 : count
    })
  }

  private var languageLabel: String {
    guard let path = model.openedRemoteFile else { return "" }
    let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
    switch ext {
    case "swift": return "Swift"
    case "py": return "Python"
    case "js", "mjs", "cjs": return "JavaScript"
    case "ts", "tsx": return "TypeScript"
    case "json": return "JSON"
    case "md", "markdown": return "Markdown"
    case "yml", "yaml": return "YAML"
    case "sh", "zsh", "bash": return "Shell"
    case "html": return "HTML"
    case "css", "scss": return "CSS"
    case "tex": return "TeX"
    default: return ext.isEmpty ? "Text" : ext.uppercased()
    }
  }

  private var previewKindLabel: String {
    switch model.remotePreviewKind {
    case .text: return "Text"
    case .image: return "Image"
    case .pdf: return "PDF"
    case .video: return "Video"
    case .external: return "External"
    case .none: return "Ready"
    }
  }
}

private struct CodeWorkspaceLoadingView: View {
  @Environment(\.colorScheme) private var colorScheme
  var text: String
  var detail: String

  var body: some View {
    VStack(spacing: 10) {
      ProgressView()
        .controlSize(.small)
      Text(text)
        .font(.system(size: 13, weight: .semibold))
      if !detail.trimmed.isEmpty {
        Text(detail)
          .font(.caption)
          .lineLimit(2)
          .truncationMode(.middle)
      }
    }
    .foregroundStyle(CodeWorkspacePalette(scheme: colorScheme).secondaryText)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CodeWorkspacePalette(scheme: colorScheme).panel)
  }
}

private struct CodeWorkspaceTab: View {
  @Environment(\.colorScheme) private var colorScheme
  var path: String
  var isSelected: Bool
  var isDirty: Bool
  var select: () -> Void
  var close: () -> Void

  private var palette: CodeWorkspacePalette {
    CodeWorkspacePalette(scheme: colorScheme)
  }

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: symbol)
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundStyle(palette.secondaryText)
      Text(URL(fileURLWithPath: path).lastPathComponent)
        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
        .lineLimit(1)
        .truncationMode(.middle)
      if isDirty {
        Circle()
          .fill(Color.orange.opacity(0.95))
          .frame(width: 6, height: 6)
      }
      Button(action: close) {
        Image(systemName: "xmark")
          .font(.system(size: 9.5, weight: .bold))
          .frame(width: 15, height: 15)
      }
      .buttonStyle(ImmediateFeedbackButtonStyle())
      .opacity(isSelected ? 0.9 : 0.45)
    }
    .foregroundStyle(isSelected ? palette.primaryText : palette.secondaryText)
    .padding(.horizontal, 9)
    .frame(width: 172, height: 30, alignment: .leading)
    .background(isSelected ? palette.background : Color.clear)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(isSelected ? Color.blue.opacity(0.85) : Color.clear)
        .frame(height: 2)
    }
    .contentShape(Rectangle())
    .onTapGesture(perform: select)
  }

  private var symbol: String {
    let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
    if ext == "swift" { return "swift" }
    if ext == "py" { return "chevron.left.forwardslash.chevron.right" }
    if ext == "json" { return "curlybraces" }
    if ext == "md" || ext == "markdown" { return "doc.plaintext" }
    return "doc.text"
  }
}

private struct CodeWorkspaceQueueStrip: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.colorScheme) private var colorScheme
  var items: [CodexPromptQueueItem]
  @State private var editingQueueItemID: UUID?
  @State private var editingQueueText = ""

  private var palette: CodeWorkspacePalette {
    CodeWorkspacePalette(scheme: colorScheme)
  }

  private var activeCodexIsWorking: Bool {
    model.activeSessionID.map { model.codexWorkingSessionIDs.contains($0) } ?? false
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 8) {
        Label("\(items.count) queued", systemImage: "tray.full")
          .font(.system(size: 11.5, weight: .bold))
        Spacer()
        if items.contains(where: {
          $0.kind == .send && ($0.status == .queued || $0.status == .waitingForCodex)
        })
        {
          Button {
            model.promoteQueuedCodexItemsToSteer()
          } label: {
            Label("Steer", systemImage: "arrow.triangle.turn.up.right.diamond")
              .font(.system(size: 11, weight: .semibold))
          }
          .buttonStyle(ImmediateFeedbackButtonStyle())
          .safeHelp("Change queued sends to steer before A delivers them")
        }
      }
      .foregroundStyle(palette.secondaryText)
      .padding(.horizontal, 10)
      .frame(height: 28)

      ForEach(items.prefix(4)) { item in
        CodeWorkspaceQueueRow(
          item: item,
          activeCodexIsWorking: activeCodexIsWorking
        ) { item in
          editingQueueText = item.visibleText
          editingQueueItemID = item.id
        }
          .environmentObject(model)
      }
    }
    .background(palette.controlFill, in: RoundedRectangle(cornerRadius: 7))
    .overlay {
      RoundedRectangle(cornerRadius: 7)
        .strokeBorder(palette.secondaryText.opacity(0.10), lineWidth: 1)
    }
    .sheet(
      isPresented: Binding(
        get: { editingQueueItemID != nil },
        set: { isPresented in
          if !isPresented {
            editingQueueItemID = nil
          }
        }
      )
    ) {
      CodeWorkspaceQueueEditSheet(
        text: $editingQueueText,
        onCancel: {
          editingQueueItemID = nil
        },
        onSave: {
          guard let id = editingQueueItemID else { return }
          let nextText = editingQueueText
          editingQueueItemID = nil
          Task { await model.editCodexQueueItem(id, text: nextText) }
        }
      )
    }
  }
}

private struct CodeWorkspaceQueueRow: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.colorScheme) private var colorScheme
  var item: CodexPromptQueueItem
  var activeCodexIsWorking: Bool
  var onEdit: (CodexPromptQueueItem) -> Void

  private var palette: CodeWorkspacePalette {
    CodeWorkspacePalette(scheme: colorScheme)
  }

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: item.kind.symbol)
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundStyle(tint.opacity(0.95))
        .frame(width: 16)
      VStack(alignment: .leading, spacing: 2) {
        Text(item.shortText.isEmpty ? "Attachment prompt" : item.shortText)
          .font(.system(size: 11.5, weight: .medium))
          .foregroundStyle(palette.primaryText.opacity(0.88))
          .lineLimit(1)
        Text(queueStatusLine)
          .font(.system(size: 10.5, weight: .semibold))
          .foregroundStyle(palette.secondaryText.opacity(0.72))
          .lineLimit(1)
      }
      Spacer(minLength: 8)
      if item.kind == .send && (item.status == .queued || item.status == .waitingForCodex) {
        queueButton("arrow.triangle.turn.up.right.diamond", help: "Convert to steer") {
          model.promoteCodexQueueItemToSteer(item.id)
        }
      }
      if item.status == .failed {
        queueButton("arrow.clockwise", help: "Retry") {
          model.retryCodexQueueItem(item.id)
        }
      }
      if item.status == .queued || item.status == .waitingForCodex || item.status == .failed {
        queueButton("pencil", help: "Edit") {
          onEdit(item)
        }
      }
      if item.status != .sending {
        queueButton("xmark", help: "Remove") {
          model.discardCodexQueueItem(item.id)
        }
      }
    }
    .padding(.horizontal, 10)
    .frame(height: 34)
  }

  private var tint: Color {
    switch item.status {
    case .queued: return .orange
    case .sending, .waitingForCodex: return .blue
    case .delivered: return .green
    case .failed: return .red
    }
  }

  private var queueStatusLine: String {
    let base = "\(item.status.title) · \(item.kind.title)"
    let receipt = queueDetail
    return receipt.isEmpty ? base : "\(base) · \(receipt)"
  }

  private var queueDetail: String {
    let explicit = item.lastError.trimmed
    if !explicit.isEmpty {
      return explicit
    }
    if item.status == .waitingForCodex, let remoteQueueID = item.remoteQueueID?.trimmed,
      !remoteQueueID.isEmpty
    {
      return "A queue \(remoteQueueID)"
    }
    return ""
  }

  private func queueButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 9.5, weight: .bold))
        .frame(width: 18, height: 18)
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .foregroundStyle(palette.secondaryText)
    .safeHelp(help)
  }
}

private struct CodeWorkspaceQueueEditSheet: View {
  @Environment(\.colorScheme) private var colorScheme
  @Binding var text: String
  var onCancel: () -> Void
  var onSave: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label("Edit Queue Item", systemImage: "pencil")
        .font(.system(size: 14, weight: .bold))
      TextEditor(text: $text)
        .font(.system(size: 13))
        .scrollContentBackground(.hidden)
        .padding(10)
        .frame(width: 560, height: 220)
        .background(
          Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.04),
          in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
      HStack {
        Spacer()
        Button("Cancel", action: onCancel)
        Button("Save", action: onSave)
          .disabled(text.trimmed.isEmpty)
      }
    }
    .padding(18)
  }
}

private struct CodeTextEditor: NSViewRepresentable {
  @Binding var text: String
  var identity: String
  var isDark: Bool
  var fontSize: CGFloat

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.drawsBackground = true
    scrollView.backgroundColor = palette.background
    scrollView.borderType = .noBorder
    scrollView.contentView.postsBoundsChangedNotifications = true

    let textStorage = NSTextStorage()
    let layoutManager = NSLayoutManager()
    textStorage.addLayoutManager(layoutManager)

    let textContainer = NSTextContainer(
      containerSize: CGSize(
        width: CGFloat.greatestFiniteMagnitude,
        height: CGFloat.greatestFiniteMagnitude
      )
    )
    textContainer.widthTracksTextView = false
    textContainer.heightTracksTextView = false
    textContainer.lineFragmentPadding = 0
    layoutManager.addTextContainer(textContainer)

    let textView = NSTextView(frame: .zero, textContainer: textContainer)
    textView.delegate = context.coordinator
    textView.string = text
    textView.isRichText = false
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticTextReplacementEnabled = false
    textView.isAutomaticSpellingCorrectionEnabled = false
    textView.allowsUndo = true
    textView.isEditable = true
    textView.isSelectable = true
    textView.importsGraphics = false
    textView.font = palette.font(size: fontSize)
    textView.textColor = palette.text
    textView.backgroundColor = palette.background
    textView.insertionPointColor = palette.caret
    textView.textContainerInset = CGSize(width: 16, height: 14)
    textView.minSize = CGSize(width: 0, height: scrollView.contentSize.height)
    textView.maxSize = CGSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude
    )
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = true
    textView.autoresizingMask = [.width]

    scrollView.documentView = textView

    let ruler = CodeLineNumberRulerView(
      scrollView: scrollView,
      textView: textView,
      isDark: isDark,
      fontSize: fontSize
    )
    scrollView.verticalRulerView = ruler
    scrollView.hasVerticalRuler = true
    scrollView.rulersVisible = true

    context.coordinator.textView = textView
    context.coordinator.rulerView = ruler
    NotificationCenter.default.addObserver(
      context.coordinator,
      selector: #selector(Coordinator.boundsDidChange(_:)),
      name: NSView.boundsDidChangeNotification,
      object: scrollView.contentView
    )
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    context.coordinator.parent = self
    scrollView.backgroundColor = palette.background
    guard let textView = context.coordinator.textView else { return }
    let identityChanged = context.coordinator.lastIdentity != identity
    context.coordinator.lastIdentity = identity
    if textView.string != text {
      let selectedRange = identityChanged ? NSRange(location: 0, length: 0) : textView.selectedRange()
      textView.string = text
      let safeLocation = min(selectedRange.location, (text as NSString).length)
      textView.setSelectedRange(NSRange(location: safeLocation, length: 0))
      if identityChanged {
        textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
      } else {
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: scrollView.contentView.bounds.origin.y))
        scrollView.reflectScrolledClipView(scrollView.contentView)
      }
    } else if identityChanged {
      textView.setSelectedRange(NSRange(location: 0, length: 0))
      textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
    }
    textView.font = palette.font(size: fontSize)
    textView.textColor = palette.text
    textView.backgroundColor = palette.background
    textView.insertionPointColor = palette.caret
    context.coordinator.rulerView?.isDark = isDark
    context.coordinator.rulerView?.fontSize = fontSize
    context.coordinator.rulerView?.needsDisplay = true
  }

  private var palette: CodeTextEditorPalette {
    CodeTextEditorPalette(isDark: isDark)
  }

  @MainActor
  final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: CodeTextEditor
    weak var textView: NSTextView?
    weak var rulerView: CodeLineNumberRulerView?
    var lastIdentity = ""

    init(_ parent: CodeTextEditor) {
      self.parent = parent
    }

    deinit {
      NotificationCenter.default.removeObserver(self)
    }

    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }
      parent.text = textView.string
      rulerView?.needsDisplay = true
    }

    @objc func boundsDidChange(_ notification: Notification) {
      rulerView?.needsDisplay = true
    }
  }
}

private struct CodeTextEditorPalette {
  var isDark: Bool

  var background: NSColor {
    isDark
      ? NSColor(calibratedRed: 0.075, green: 0.078, blue: 0.082, alpha: 1)
      : NSColor(calibratedRed: 0.970, green: 0.974, blue: 0.980, alpha: 1)
  }

  var text: NSColor {
    isDark
      ? NSColor(calibratedWhite: 0.92, alpha: 1)
      : NSColor(calibratedWhite: 0.14, alpha: 1)
  }

  var mutedText: NSColor {
    isDark
      ? NSColor(calibratedWhite: 0.52, alpha: 1)
      : NSColor(calibratedWhite: 0.48, alpha: 1)
  }

  var rulerBackground: NSColor {
    isDark
      ? NSColor(calibratedRed: 0.068, green: 0.071, blue: 0.075, alpha: 1)
      : NSColor(calibratedRed: 0.938, green: 0.946, blue: 0.958, alpha: 1)
  }

  var separator: NSColor {
    isDark
      ? NSColor(calibratedWhite: 1, alpha: 0.10)
      : NSColor(calibratedWhite: 0, alpha: 0.10)
  }

  var caret: NSColor {
    isDark ? NSColor.systemCyan : NSColor.systemBlue
  }

  func font(size: CGFloat) -> NSFont {
    NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
  }
}

private final class CodeLineNumberRulerView: NSRulerView {
  weak var textView: NSTextView?
  var isDark: Bool {
    didSet {
      needsDisplay = true
    }
  }
  var fontSize: CGFloat {
    didSet {
      needsDisplay = true
    }
  }

  private var palette: CodeTextEditorPalette {
    CodeTextEditorPalette(isDark: isDark)
  }

  init(scrollView: NSScrollView, textView: NSTextView, isDark: Bool, fontSize: CGFloat) {
    self.textView = textView
    self.isDark = isDark
    self.fontSize = fontSize
    super.init(scrollView: scrollView, orientation: .verticalRuler)
    clientView = textView
    ruleThickness = 50
  }

  required init(coder: NSCoder) {
    self.isDark = false
    self.fontSize = 13
    super.init(coder: coder)
  }

  override func drawHashMarksAndLabels(in rect: NSRect) {
    palette.rulerBackground.setFill()
    bounds.fill()

    guard
      let textView,
      let layoutManager = textView.layoutManager,
      let textContainer = textView.textContainer,
      let scrollView = scrollView
    else {
      return
    }

    let visibleRect = scrollView.contentView.bounds
    let inset = textView.textContainerInset
    let boundingRect = NSRect(
      x: visibleRect.minX,
      y: max(0, visibleRect.minY - inset.height),
      width: visibleRect.width,
      height: visibleRect.height + inset.height * 2
    )
    let glyphRange = layoutManager.glyphRange(forBoundingRect: boundingRect, in: textContainer)
    let string = textView.string as NSString
    var glyphIndex = glyphRange.location
    var lineNumber = lineNumber(at: layoutManager.characterIndexForGlyph(at: glyphIndex), in: string)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: palette.font(size: max(10, fontSize - 1)),
      .foregroundColor: palette.mutedText,
    ]

    while glyphIndex < NSMaxRange(glyphRange) {
      var lineGlyphRange = NSRange(location: 0, length: 0)
      let lineRect = layoutManager.lineFragmentRect(
        forGlyphAt: glyphIndex,
        effectiveRange: &lineGlyphRange,
        withoutAdditionalLayout: true
      )
      let label = "\(lineNumber)" as NSString
      let labelSize = label.size(withAttributes: attributes)
      let y = lineRect.minY + inset.height - visibleRect.minY + 1
      label.draw(
        at: NSPoint(x: max(4, ruleThickness - labelSize.width - 10), y: y),
        withAttributes: attributes
      )
      lineNumber += 1
      glyphIndex = max(NSMaxRange(lineGlyphRange), glyphIndex + 1)
    }

    palette.separator.setFill()
    NSRect(x: bounds.maxX - 1, y: bounds.minY, width: 1, height: bounds.height).fill()
  }

  private func lineNumber(at index: Int, in string: NSString) -> Int {
    guard index > 0 else { return 1 }
    var line = 1
    var searchRange = NSRange(location: 0, length: min(index, string.length))
    while searchRange.length > 0 {
      let range = string.range(of: "\n", options: [], range: searchRange)
      guard range.location != NSNotFound else { break }
      line += 1
      let nextLocation = range.location + range.length
      searchRange = NSRange(location: nextLocation, length: min(index, string.length) - nextLocation)
    }
    return line
  }
}

private struct CodeWorkspaceFileRow: View {
  @Environment(\.colorScheme) private var colorScheme
  var item: RemoteItem
  var isSelected: Bool
  var select: () -> Void
  var open: () -> Void

  private var palette: CodeWorkspacePalette {
    CodeWorkspacePalette(scheme: colorScheme)
  }

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: item.isDirectory ? "folder.fill" : symbol)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(item.isDirectory ? Color.blue.opacity(0.78) : palette.secondaryText)
        .frame(width: 15)
      Text(item.name)
        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer(minLength: 0)
    }
    .foregroundStyle(isSelected ? palette.primaryText : palette.secondaryText)
    .padding(.horizontal, 7)
    .frame(height: 24)
    .background(isSelected ? palette.selectionFill : Color.clear, in: RoundedRectangle(cornerRadius: 4))
    .contentShape(Rectangle())
    .gesture(
      TapGesture(count: 2)
        .onEnded { open() }
        .exclusively(before: TapGesture(count: 1).onEnded { select() })
    )
  }

  private var symbol: String {
    let ext = URL(fileURLWithPath: item.name).pathExtension.lowercased()
    if ["png", "jpg", "jpeg", "gif", "heic", "webp"].contains(ext) {
      return "photo"
    }
    if ["mp4", "mov", "m4v", "webm", "avi", "mkv"].contains(ext) {
      return "play.rectangle"
    }
    if ext == "pdf" {
      return "doc.richtext"
    }
    return "doc.text"
  }
}

private struct CodeWorkspaceResizeHandle: View {
  @Environment(\.colorScheme) private var colorScheme
  enum Axis {
    case horizontal
    case vertical
  }

  var axis: Axis
  var value: CGFloat
  var multiplier: CGFloat
  var clamp: (CGFloat) -> CGFloat
  var onChange: (CGFloat) -> Void
  var onEnd: (CGFloat) -> Void
  @State private var isHovering = false
  @State private var dragStartValue: CGFloat?

  var body: some View {
    ZStack {
      Rectangle()
        .fill(Color.clear)
      RoundedRectangle(cornerRadius: 2, style: .continuous)
        .fill(
          isHovering || dragStartValue != nil
            ? Color.blue.opacity(0.55)
            : (colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.12))
        )
        .frame(
          width: axis == .horizontal ? 2 : 46,
          height: axis == .horizontal ? 52 : 2
        )
    }
      .frame(width: axis == .horizontal ? 8 : nil, height: axis == .vertical ? 8 : nil)
      .contentShape(Rectangle())
      .onHover { isHovering = $0 }
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            let startValue = dragStartValue ?? self.value
            dragStartValue = startValue
            let translation =
              axis == .horizontal ? value.translation.width : value.translation.height
            onChange(clamp(startValue + translation * multiplier))
          }
          .onEnded { value in
            let startValue = dragStartValue ?? self.value
            let translation =
              axis == .horizontal ? value.translation.width : value.translation.height
            onEnd(clamp(startValue + translation * multiplier))
            dragStartValue = nil
          }
      )
  }
}

private struct CodeWorkspacePalette {
  var scheme: ColorScheme

  var isDark: Bool { scheme == .dark }
  var background: Color { isDark ? Color(red: 0.128, green: 0.136, blue: 0.150) : Color(red: 0.970, green: 0.974, blue: 0.980) }
  var titleBar: Color { isDark ? Color(red: 0.156, green: 0.164, blue: 0.180) : Color(red: 0.920, green: 0.930, blue: 0.944) }
  var tabBar: Color { isDark ? Color(red: 0.143, green: 0.151, blue: 0.166) : Color(red: 0.940, green: 0.948, blue: 0.960) }
  var sidebar: Color { isDark ? Color(red: 0.132, green: 0.141, blue: 0.157) : Color(red: 0.945, green: 0.952, blue: 0.963) }
  var header: Color { isDark ? Color(red: 0.150, green: 0.158, blue: 0.174) : Color(red: 0.955, green: 0.962, blue: 0.972) }
  var panel: Color { isDark ? Color(red: 0.138, green: 0.146, blue: 0.162) : Color(red: 0.955, green: 0.962, blue: 0.972) }
  var console: Color { isDark ? Color(red: 0.118, green: 0.126, blue: 0.140) : Color(red: 0.900, green: 0.910, blue: 0.925) }
  var statusBar: Color { isDark ? Color(red: 0.135, green: 0.143, blue: 0.158) : Color(red: 0.930, green: 0.940, blue: 0.953) }
  var controlFill: Color { isDark ? Color.white.opacity(0.115) : Color.black.opacity(0.065) }
  var selectionFill: Color { isDark ? Color.white.opacity(0.150) : Color.blue.opacity(0.12) }
  var primaryText: Color { isDark ? Color.white.opacity(0.90) : Color.black.opacity(0.82) }
  var secondaryText: Color { isDark ? Color.white.opacity(0.62) : Color.black.opacity(0.52) }
}

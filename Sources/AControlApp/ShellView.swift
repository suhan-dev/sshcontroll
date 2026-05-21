import SwiftUI

struct ShellView: View {
  @EnvironmentObject private var model: AppModel
  @State private var showingDirectoryPicker = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "A Shell", detail: model.currentRemoteDir) {
        await model.captureShell()
      }

      ShellToolbar(showingDirectoryPicker: $showingDirectoryPicker)

      ShellTranscriptPanel()
        .layoutPriority(1)

      ShellInputPanel()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .task {
      if model.shellTranscript.isEmpty {
        await model.captureShell()
      }
    }
    .sheet(isPresented: $showingDirectoryPicker) {
      RemoteDirectoryPicker(title: "Shell Directory") { path in
        showingDirectoryPicker = false
        Task { await model.changeShellDirectory(path) }
      }
      .environmentObject(model)
    }
  }
}

private struct ShellToolbar: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.colorScheme) private var colorScheme
  @Binding var showingDirectoryPicker: Bool

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        PrimaryButton(title: "Exit Codex", symbol: "rectangle.portrait.and.arrow.right", tint: .orange, minWidth: 118) {
          Task { await model.exitShellCodex() }
        }
        SoftButton(title: "Ctrl+C", symbol: "command", minWidth: 92) {
          Task { await model.interruptShell() }
        }
        SoftButton(title: "Esc", symbol: "escape", minWidth: 72) {
          Task { await model.escapeShell() }
        }
        SoftButton(title: "Ctrl+B", symbol: "keyboard", minWidth: 88) {
          Task { await model.shellTmuxPrefix() }
        }
        SoftButton(title: "Clear", symbol: "trash", minWidth: 88) {
          Task { await model.clearShell() }
        }
        SoftButton(title: "Dir", symbol: "folder", minWidth: 76) {
          showingDirectoryPicker = true
        }
      }
      .padding(2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct ShellTranscriptPanel: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.colorScheme) private var colorScheme
  @State private var transcriptScheme: ColorScheme?
  @State private var themeHovering = false
  @State private var transcriptAtBottom = true
  @State private var scrollSignal = 0

  private var effectiveScheme: ColorScheme {
    transcriptScheme ?? colorScheme
  }

  var body: some View {
    ZStack(alignment: .topTrailing) {
      TerminalTranscriptView(
        text: model.shellTranscript,
        placeholder: "A shell transcript will appear here.",
        currentDirectory: model.currentRemoteDir,
        scrollSignal: scrollSignal,
        onBottomStateChange: { transcriptAtBottom = $0 }
      )
      .environment(\.colorScheme, effectiveScheme)
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      themeControl

      TranscriptScrollButton {
        scrollSignal += 1
      }
      .padding(.bottom, 12)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
      .opacity(showsScrollButton ? 1 : 0)
      .allowsHitTesting(showsScrollButton)
      .animation(.easeOut(duration: 0.16), value: showsScrollButton)
    }
    .background(
      AControlStyle.transcriptFill(effectiveScheme),
      in: RoundedRectangle(cornerRadius: AControlStyle.insetRadius, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: AControlStyle.insetRadius, style: .continuous)
        .strokeBorder(AControlStyle.hairline(effectiveScheme), lineWidth: 1)
    }
    .shadow(color: AControlStyle.softShadow(colorScheme), radius: 8, x: 0, y: 4)
  }

  private var showsScrollButton: Bool {
    !transcriptAtBottom && !model.shellTranscript.trimmed.isEmpty
  }

  private var themeControl: some View {
    ZStack(alignment: .topTrailing) {
      ThemeHoverButton(isDark: effectiveScheme == .dark) {
        transcriptScheme = effectiveScheme == .dark ? .light : .dark
      }
      .environment(\.colorScheme, effectiveScheme)
      .padding(16)
      .opacity(themeHovering ? 1 : 0)
      .animation(.easeOut(duration: 0.16), value: themeHovering)
    }
    .frame(width: 92, height: 92, alignment: .topTrailing)
    .contentShape(Rectangle())
    .onHover { themeHovering = $0 }
  }
}

private struct ShellInputPanel: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.colorScheme) private var colorScheme
  @State private var draft = ""
  @State private var completionPrefetchTask: Task<Void, Never>?

  var body: some View {
    GlassPanel(title: "Input", symbol: "keyboard", accent: .cyan) {
      ShellCommandInput(
        text: $draft,
        onSubmit: { submit() },
        onTab: { complete() }
      )
      .frame(height: 86)
      .background(
        AControlStyle.transcriptFill(colorScheme),
        in: RoundedRectangle(cornerRadius: AControlStyle.insetRadius, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: AControlStyle.insetRadius, style: .continuous)
          .strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
      }
      HStack {
        Text("Enter sends once. Shift+Enter adds a new line. Tab opens completions.")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        PrimaryButton(title: "Send", symbol: "return", tint: .cyan) {
          submit()
        }
        .keyboardShortcut(.return, modifiers: [.command])
      }

      if !model.shellCompletions.isEmpty {
        FlowLayout(spacing: 8) {
          ForEach(model.shellCompletions) { completion in
            Button {
              model.useShellCompletion(completion)
            } label: {
              Label(completion.label, systemImage: completion.isDirectory ? "folder" : "doc.text")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(AControlStyle.accentFill(.cyan, colorScheme), in: Capsule())
                .overlay {
                  Capsule().strokeBorder(
                    AControlStyle.accentStroke(.cyan, colorScheme), lineWidth: 1)
                }
            }
            .buttonStyle(ImmediateFeedbackButtonStyle())
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .onAppear {
      draft = model.shellInput
    }
    .onChange(of: model.shellInput) { _, value in
      guard value != draft else { return }
      if draft.trimmed.isEmpty || value.trimmed.isEmpty || !model.shellCompletions.isEmpty {
        draft = value
      }
    }
    .onChange(of: draft) { _, value in
      scheduleCompletionPrefetch(for: value)
    }
    .onDisappear {
      completionPrefetchTask?.cancel()
    }
  }

  private func submit() {
    let submitted = draft
    model.shellInput = submitted
    draft = ""
    Task {
      await model.sendShell()
      if !model.shellInput.trimmed.isEmpty, draft.trimmed.isEmpty {
        draft = model.shellInput
      }
    }
  }

  private func complete() {
    model.shellInput = draft
    Task {
      await model.completeShell()
      draft = model.shellInput
    }
  }

  private func scheduleCompletionPrefetch(for value: String) {
    completionPrefetchTask?.cancel()
    guard !value.trimmed.isEmpty else { return }
    completionPrefetchTask = Task {
      try? await Task.sleep(nanoseconds: 220_000_000)
      guard !Task.isCancelled else { return }
      await model.prefetchShellCompletions(for: value)
    }
  }
}

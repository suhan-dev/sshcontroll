import AppKit
import SwiftUI

struct ClaudeView: View {
  @EnvironmentObject private var model: AppModel

  private static let promptSnippets: [(String, String)] = [
    ("Computer", "Use Computer Use on A if available. "),
    ("Browser", "Use Browser Use for local or web verification if available. "),
    ("GitHub", "Use GitHub connector/plugin if available. "),
    ("Plan", "Make a short plan before editing. "),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "A Claude", detail: short(model.currentRemoteDir)) {
        await model.captureClaude()
      }
      if claudeNeedsInstallGuide {
        ClaudeSetupNotice()
      }
      CodexTranscriptCard(
        text: model.claudeTranscript,
        sessionID: model.activeSessionID,
        modelName: "Claude Code",
        weekly: "",
        reset: "",
        symbol: "text.bubble",
        accent: .purple,
        placeholder: "Claude transcript will appear here.",
        showsWeeklyStatus: false
      ) {
        Task { await model.captureClaude() }
      }
      .layoutPriority(1)
      ClaudePromptPanel(promptSnippets: Self.promptSnippets)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .task(id: model.activeSessionID) {
      await model.captureClaudeIfUseful()
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 20_000_000_000)
        guard !Task.isCancelled, !model.isBusy, model.activeClaudeConversationIsEstablished else {
          continue
        }
        await model.captureClaudeIfUseful()
      }
    }
  }

  private func short(_ path: String) -> String {
    path.replacingOccurrences(of: model.settings.remoteHome, with: "~")
  }

  private var claudeNeedsInstallGuide: Bool {
    let lower = String(model.claudeTranscript.suffix(12_000)).lowercased()
    return lower.contains("claude code cli was not found")
      || lower.contains("claude cli was not found") || lower.contains("claude_bin: missing")
      || lower.contains("path_claude: missing")
  }
}

private struct ClaudeSetupNotice: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    GlassPanel(title: "Claude Setup", symbol: "text.bubble", accent: .purple) {
      HStack(alignment: .center, spacing: 12) {
        Text(
          "Claude is not available on the remote Mac. Install Claude Code or enter the `claude` path in Settings, then press Refresh."
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .lineLimit(2)
        Spacer()
        SoftButton(title: "Check", symbol: "checkmark.seal") {
          Task { await model.checkAITool("claude") }
        }
        PrimaryButton(title: "Install", symbol: "arrow.down.circle", tint: .purple) {
          Task { await model.installClaudeCLI() }
        }
      }
    }
  }
}

private struct ClaudePromptPanel: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.colorScheme) private var colorScheme
  @State private var showingDirectoryPicker = false
  @State private var draft = ""
  var promptSnippets: [(String, String)]

  var body: some View {
    GlassPanel(title: "Prompt", symbol: "text.bubble", accent: .purple) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          Menu("Snippets") {
            ForEach(promptSnippets, id: \.0) { item in
              Button(item.0) {
                draft += item.1
              }
            }
          }
          .menuStyle(.button)
          .frame(height: 36)

          SoftButton(title: "Dir", symbol: "folder.badge.gearshape") {
            showingDirectoryPicker = true
          }
        }
      }

      PromptComposerView(
        text: $draft,
        onAttachFiles: { urls in
          model.addClaudeAttachments(urls)
        },
        onAttachImage: { data, ext in
          model.addClaudeImageAttachment(data: data, suggestedExtension: ext)
        },
        onSubmit: {
          submit(steer: false)
        }
      )
      .frame(height: 142)
      .background(
        AControlStyle.transcriptFill(colorScheme),
        in: RoundedRectangle(cornerRadius: AControlStyle.insetRadius, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: AControlStyle.insetRadius, style: .continuous)
          .strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
      }

      if !model.claudeAttachments.isEmpty {
        FlowLayout(spacing: 8) {
          ForEach(model.claudeAttachments) { attachment in
            AttachmentChip(attachment: attachment) {
              model.removeClaudeAttachment(attachment)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      HStack {
        Text("Paste/drop files or images. Attach uploads from C to \(model.settings.remoteLabel).")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        Spacer()
        AgentChoiceControls(
          onUp: { Task { await model.claudeKey("up") } },
          onDown: { Task { await model.claudeKey("down") } },
          onEnter: { Task { await model.claudeKey("enter") } },
          onEscape: { Task { await model.claudeKey("esc") } }
        )
        SoftButton(title: "Attach", symbol: "paperclip") {
          model.chooseClaudeAttachments()
        }
        if !model.claudeAttachments.isEmpty {
          SoftButton(title: "Clear Files", symbol: "xmark.circle") {
            model.clearClaudeAttachments()
          }
        }
        SoftButton(title: "Steer", symbol: "arrow.triangle.turn.up.right.diamond") {
          submit(steer: true)
        }
        PrimaryButton(title: "Send", symbol: "paperplane", tint: .purple) {
          submit(steer: false)
        }
      }
    }
    .sheet(isPresented: $showingDirectoryPicker) {
      RemoteDirectoryPicker(title: "Claude Directory") { path in
        showingDirectoryPicker = false
        Task { await model.restartClaude(in: path) }
      }
      .environmentObject(model)
    }
  }

  private func submit(steer: Bool) {
    let submitted = draft
    guard !submitted.trimmed.isEmpty || !model.claudeAttachments.isEmpty else { return }
    draft = ""
    model.claudeInput = submitted
    Task {
      await model.sendClaude(steer: steer)
      let restored = model.claudeInput
      guard !restored.trimmed.isEmpty else { return }
      model.claudeInput = ""
      if draft.trimmed.isEmpty {
        draft = restored
      } else {
        draft = restored + "\n\n" + draft
      }
    }
  }
}

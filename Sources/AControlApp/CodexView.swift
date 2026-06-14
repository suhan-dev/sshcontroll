import AppKit
import SwiftUI

struct CodexView: View {
  @EnvironmentObject private var model: AppModel
  @AppStorage("AControl.codexFilePanelWidth") private var storedCodexFilePanelWidth = 360.0

  private static let codexModels = [
    CodexModelOption(
      name: "gpt-5.5",
      badge: "Frontier",
      detail: "Best for complex coding, larger refactors, and high-context work."
    ),
    CodexModelOption(
      name: "gpt-5.4",
      badge: "Daily",
      detail: "Strong everyday coding model with a balanced feel."
    ),
    CodexModelOption(
      name: "gpt-5.4-mini",
      badge: "Fast",
      detail: "Small, quick, and cost-efficient for simpler edits."
    ),
    CodexModelOption(
      name: "gpt-5.3-codex",
      badge: "Coding",
      detail: "Coding-optimized model for focused implementation work."
    ),
    CodexModelOption(
      name: "gpt-5.3-codex-spark",
      badge: "Spark",
      detail: "Ultra-fast coding model for lightweight changes."
    ),
    CodexModelOption(
      name: "gpt-5.2",
      badge: "Agent",
      detail: "Good for professional long-running agentic tasks."
    ),
  ]

  private static let reasoningEfforts: [CodexReasoningEffortOption] = [
    .init(value: "low", title: "Low", detail: "Fastest lighter reasoning."),
    .init(value: "medium", title: "Medium", detail: "Balanced depth for everyday work."),
    .init(value: "high", title: "High", detail: "Deeper reasoning for complex changes."),
    .init(value: "xhigh", title: "Extra High", detail: "Maximum depth for long, careful work."),
  ]

  private static let pluginSnippets: [CodexPluginSnippet] = [
    .init(
      title: "@Computer",
      snippet: "Use [@Computer](plugin://computer-use@openai-bundled) for local Mac UI inspection, screenshots, clicks, drags, and real-app verification when the task depends on visible behavior.",
      category: "Runtime",
      symbol: "display",
      detail: "Local Mac UI inspection and interaction"
    ),
    .init(
      title: "@Browser",
      snippet: "Use [@Browser](plugin://browser@openai-bundled) for localhost/web UI inspection, screenshots, console checks, responsive QA, and browser-side interaction when it materially verifies the work.",
      category: "Runtime",
      symbol: "safari",
      detail: "Browser and localhost QA"
    ),
    .init(
      title: "@Documents",
      snippet: "Use [@Documents](plugin://documents@openai-primary-runtime) for document editing, redlines, rendering, DOCX/PDF verification, and page-level visual QA.",
      category: "Artifacts",
      symbol: "doc.richtext",
      detail: "Document editing and verification"
    ),
    .init(
      title: "@Spreadsheets",
      snippet: "Use [@Spreadsheets](plugin://spreadsheets@openai-primary-runtime) for tables, formulas, charts, CSV/XLSX analysis, recalculation, and export validation.",
      category: "Artifacts",
      symbol: "tablecells",
      detail: "Spreadsheet analysis and exports"
    ),
    .init(
      title: "@Presentations",
      snippet: "Use [@Presentations](plugin://presentations@openai-primary-runtime) for slide decks, rendered critique, visual polish, and PPTX export verification.",
      category: "Artifacts",
      symbol: "rectangle.on.rectangle.angled",
      detail: "Slides and presentation QA"
    ),
    .init(
      title: "@GitHub",
      snippet: "Use [@GitHub](plugin://github@openai-curated) for repository review, PRs, issues, CI, release/publish workflows, and checking remote state before pushing.",
      category: "Runtime",
      symbol: "point.3.connected.trianglepath.dotted",
      detail: "Repo, PR, CI, and publish workflow"
    ),
    .init(
      title: "Professor Lab",
      snippet:
        "Run as a long-horizon research program: maintain PROGRAM.md, CLAIM_LEDGER.csv, EVIDENCE_MATRIX.md, REFEREE_GATE.md, ARTIFACT_INDEX.md, and a concrete next-action queue. Treat the visible reply as a progress note and the files as the real lab notebook.",
      category: "Research",
      symbol: "atom",
      detail: "Long-horizon research operating system"
    ),
    .init(
      title: "Theory Builder",
      snippet:
        "Invent named hypotheses or mechanisms, formalize assumptions, derive consequences, seek counterexamples, and mark each idea as RESULT, CONJECTURE, or FAILURE. Kill weak ideas explicitly.",
      category: "Research",
      symbol: "lightbulb.max",
      detail: "New theory, formalism, and counterexamples"
    ),
    .init(
      title: "Research Report",
      snippet:
        "Prepare reviewer-ready report work: outline, abstract, claim/evidence map, figure roadmap, bilingual notes when useful, artifact verification, and final report-risk checklist.",
      category: "Research",
      symbol: "doc.text.magnifyingglass",
      detail: "Paper/report structure and evidence polish"
    ),
    .init(
      title: "Literature Review",
      snippet:
        "Use Zotero, Scite, life-science, browser, or local documents when available; connect every source to a concrete claim, assumption, or gap instead of collecting citations passively.",
      category: "Research",
      symbol: "books.vertical",
      detail: "Prior art and novelty mapping"
    ),
    .init(
      title: "Design Lab",
      snippet:
        "For design work, inspect the real interface, define workflow friction, contrast, layout, resizing, empty/loading states, accessibility, screenshots, and reusable design-system changes.",
      category: "Product",
      symbol: "paintpalette",
      detail: "Design critique and polish"
    ),
    .init(
      title: "App Lab",
      snippet:
        "For app development, treat latency, state correctness, previews, queues, tests, permissions, and installed-app behavior as measurable claims with verification commands.",
      category: "Product",
      symbol: "hammer",
      detail: "App development quality gates"
    ),
    .init(
      title: "@Figma",
      snippet: "Use Figma tooling if available for design inspection, implementation, tokens, and design-system checks; otherwise continue with screenshot-based design QA.",
      category: "Product",
      symbol: "square.stack.3d.up",
      detail: "Figma and design-system work"
    ),
    .init(
      title: "A Computer",
      snippet: "For remote A Mac GUI work, use SSHcontroll's A-Cockpit bridge through ~/.local/bin/a-cockpit-remote when screenshots or UI actions are materially useful.",
      category: "Runtime",
      symbol: "desktopcomputer",
      detail: "Remote A Mac bridge"
    ),
    .init(
      title: "Mobile QA",
      snippet:
        "Run emulator/simulator QA for the target devices, save screenshot paths, and separate app failures from ADB/CoreSimulator/Xcode permission blockers.",
      category: "Product",
      symbol: "iphone",
      detail: "Mobile simulator/device verification"
    ),
    .init(
      title: "Security",
      snippet:
        "Before any git/package/release step, scan for secrets and private handoff files. Redact credentials as [REDACTED] in logs and reports.",
      category: "Runtime",
      symbol: "lock.shield",
      detail: "Secret and privacy guardrails"
    ),
    .init(
      title: "Plan",
      snippet:
        "First make a short implementation checklist, then execute it without stopping at analyzer-only verification.",
      category: "Workflow",
      symbol: "checklist",
      detail: "Compact plan plus execution"
    ),
    .init(
      title: "GitHub",
      snippet:
        "If GitHub tooling is available, inspect repo status before publishing and avoid committing private/generated local files.",
      category: "Workflow",
      symbol: "arrow.triangle.branch",
      detail: "Publish hygiene"
    ),
    .init(
      title: "Docs",
      snippet:
        "If a document/report is needed, create a concise handoff with changed files, commands, artifacts, blockers, and next commands.",
      category: "Workflow",
      symbol: "doc.plaintext",
      detail: "Readable handoff notes"
    ),
  ]

  var body: some View {
    GeometryReader { proxy in
      let panelWidth = clampedFilePanelWidth(for: proxy.size.width)
      let gap: CGFloat = model.isCodexFilePanelVisible ? 4 : 0
      let trailingInset: CGFloat = model.isCodexFilePanelVisible ? 6 : 0

      HStack(alignment: .top, spacing: gap) {
        VStack(alignment: .leading, spacing: 12) {
          HStack(alignment: .center, spacing: 10) {
            SectionHeader(title: "A Codex", detail: short(model.currentRemoteDir)) {
              await model.syncServerCodexHistoryAndRefreshVisibleSession()
            }
          }
          if codexNeedsInstallGuide {
            CodexSetupNotice()
          }
          CodexTranscriptCard(
            text: model.codexTranscript,
            sessionID: model.activeSessionID,
            scrollRequest: model.codexTranscriptAutoRefreshGeneration,
            isWorking: model.activeSessionID.map { model.codexWorkingSessionIDs.contains($0) }
              ?? false,
            workingSince: model.activeSessionID.flatMap {
              model.codexWorkingStartedAtBySession[$0]
            },
            modelName: "\(model.codexModel) \(model.codexReasoningEffort)",
            weekly: model.codexTokenWeekly,
            reset: model.codexTokenReset,
            style: .codexActivity
          ) {
            Task { await model.refreshCodexTokenStatus(force: true) }
          }
          .layoutPriority(1)
          CodexPromptPanel(
            codexModels: Self.codexModels,
            reasoningEfforts: Self.reasoningEfforts,
            pluginSnippets: Self.pluginSnippets
          )
        }
        .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        if model.isCodexFilePanelVisible {
          CodexPanelResizeHandle(
            panelWidth: panelWidth,
            resize: { setCodexFilePanelWidth($0, totalWidth: proxy.size.width) },
            reset: { storedCodexFilePanelWidth = 360 }
          )
          .frame(width: 14)
          .frame(maxHeight: .infinity)
          .zIndex(2)

          CodexSideFilePanel(isVisible: codexFilePanelBinding)
            .frame(width: panelWidth)
            .frame(maxHeight: .infinity)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
      }
      .padding(.trailing, trailingInset)
      .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
    }
    .animation(.spring(response: 0.22, dampingFraction: 0.88), value: model.isCodexFilePanelVisible)
    .task(id: model.activeSessionID) {
      await model.syncServerCodexHistoryAndRefreshVisibleSession()
      while !Task.isCancelled {
        let activeWorking =
          model.activeSessionID.map { model.codexWorkingSessionIDs.contains($0) } ?? false
        try? await Task.sleep(nanoseconds: activeWorking ? 550_000_000 : 950_000_000)
        guard !Task.isCancelled else { continue }
        await model.refreshCodexWorkingStates()
        if model.activeCodexConversationIsEstablished {
          await model.captureCodexIfUseful()
        }
      }
    }
    .task(id: model.codexTranscriptAutoRefreshGeneration) {
      guard model.codexTranscriptAutoRefreshGeneration > 0 else { return }
      while !Task.isCancelled, model.isCodexTranscriptAutoRefreshActive {
        try? await Task.sleep(nanoseconds: 700_000_000)
        guard !Task.isCancelled else { continue }
        await model.refreshCodexWorkingStates()
        if model.activeCodexConversationIsEstablished {
          await model.captureCodexIfUseful()
        }
      }
    }
    .onAppear {
      Task { await model.syncServerCodexHistoryAndRefreshVisibleSession() }
    }
  }

  private func short(_ path: String) -> String {
    path.replacingOccurrences(of: model.settings.remoteHome, with: "~")
  }

  private var codexFilePanelBinding: Binding<Bool> {
    Binding(
      get: { model.isCodexFilePanelVisible },
      set: { model.isCodexFilePanelVisible = $0 }
    )
  }

  private func clampedFilePanelWidth(for totalWidth: CGFloat) -> CGFloat {
    let minimumPanelWidth = min(320, max(260, totalWidth * 0.28))
    let maximumPanelWidth = max(
      minimumPanelWidth,
      min(totalWidth - 430, totalWidth * 0.58)
    )
    return min(max(CGFloat(storedCodexFilePanelWidth), minimumPanelWidth), maximumPanelWidth)
  }

  private func setCodexFilePanelWidth(_ width: CGFloat, totalWidth: CGFloat) {
    let minimumPanelWidth = min(320, max(260, totalWidth * 0.28))
    let maximumPanelWidth = max(
      minimumPanelWidth,
      min(totalWidth - 430, totalWidth * 0.58)
    )
    storedCodexFilePanelWidth = Double(min(max(width, minimumPanelWidth), maximumPanelWidth))
  }

  private var codexNeedsInstallGuide: Bool {
    let recentTranscript = String(model.codexTranscript.suffix(12_000)).lowercased()
    return recentTranscript.contains("codex cli was not found")
      || recentTranscript.contains("codex_app_bin: missing")
      || recentTranscript.contains("path_codex: missing")
  }

}

private struct CodexPanelResizeHandle: View {
  @State private var isHovering = false
  @State private var dragStartWidth: CGFloat?
  var panelWidth: CGFloat
  var resize: (CGFloat) -> Void
  var reset: () -> Void

  var body: some View {
    Rectangle()
      .fill(Color.clear)
      .overlay(alignment: .center) {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
          .fill(Color.primary.opacity(isHovering ? 0.24 : 0.10))
          .frame(width: isHovering ? 4 : 3, height: isHovering ? 62 : 44)
          .animation(.easeOut(duration: 0.12), value: isHovering)
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
          .onChanged { value in
            if dragStartWidth == nil {
              dragStartWidth = panelWidth
            }
            let startWidth = dragStartWidth ?? panelWidth
            resize(startWidth - value.translation.width)
          }
          .onEnded { _ in
            dragStartWidth = nil
          }
      )
      .onHover { hovering in
        isHovering = hovering
        if hovering {
          NSCursor.resizeLeftRight.set()
        } else {
          NSCursor.arrow.set()
        }
      }
      .onTapGesture(count: 2, perform: reset)
      .accessibilityLabel("Resize Files preview")
      .accessibilityHint(
        "Drag left or right to change the Codex transcript and Files preview ratio."
      )
      .safeHelp("Drag to resize Files preview. Double-click to reset.")
  }
}

private struct CodexSetupNotice: View {
  var body: some View {
    GlassPanel(title: "Codex Setup", symbol: "sparkles", accent: .purple) {
      HStack(alignment: .center, spacing: 12) {
        Text(
          "Codex is not available on the remote Mac. Install the Codex app or put the `codex` CLI on PATH, then press Refresh."
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .lineLimit(2)
        Spacer()
        SoftButton(title: "Open Guide", symbol: "safari") {
          if let url = URL(string: "https://chatgpt.com/codex") {
            NSWorkspace.shared.open(url)
          }
        }
      }
    }
  }
}

private struct CodexSideFilePanel: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.colorScheme) private var colorScheme
  @Binding var isVisible: Bool

  private var artifactKey: String {
    model.codexArtifacts.map(\.id).joined(separator: "|")
  }

  private var sortedArtifacts: [CodexArtifact] {
    model.codexArtifacts.sorted { lhs, rhs in
      let nameOrder = lhs.name.localizedStandardCompare(rhs.name)
      if nameOrder == .orderedSame {
        return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
      }
      return nameOrder == .orderedAscending
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 9) {
        Image(systemName: "folder.fill")
          .font(.system(size: 12.5, weight: .semibold))
          .foregroundStyle(AControlStyle.accentForeground(.purple, colorScheme))
          .frame(width: 28, height: 28)
          .background(AControlStyle.accentFill(.purple, colorScheme), in: Circle())
          .overlay {
            Circle().strokeBorder(AControlStyle.accentStroke(.purple, colorScheme), lineWidth: 1)
          }

        VStack(alignment: .leading, spacing: 1) {
          Text("Files")
            .font(.system(size: 16, weight: .bold))
            .lineLimit(1)
          Text("\(model.codexArtifacts.count) from transcript")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer()
        Button {
          withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
            isVisible = false
          }
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 11.5, weight: .bold))
            .frame(width: 26, height: 26)
            .contentShape(Circle())
        }
        .buttonStyle(ImmediateFeedbackButtonStyle())
        .foregroundStyle(.secondary)
        .background(AControlStyle.insetFill(colorScheme), in: Circle())
        .safeHelp("Hide Files panel")
      }

      if model.codexArtifacts.isEmpty {
        emptyText("No files mentioned yet.")
      } else {
        ArtifactStrip(
          artifacts: sortedArtifacts,
          activeID: model.codexPreviewArtifact?.id
        )
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      Divider()
        .opacity(0.45)

      CodexArtifactPreview()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(14)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(
      AControlStyle.panelFill(colorScheme),
      in: RoundedRectangle(cornerRadius: 20, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
    }
    .shadow(color: AControlStyle.softShadow(colorScheme), radius: 18, x: -4, y: 8)
    .layoutPriority(1)
    .task(id: artifactKey) {
      try? await Task.sleep(nanoseconds: 160_000_000)
      guard !Task.isCancelled else { return }
      guard model.codexPreviewArtifact == nil else { return }
      guard let first = sortedArtifacts.first else { return }
      await model.previewCodexArtifact(first)
    }
  }

  private func emptyText(_ text: String) -> some View {
    Text(text)
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 6)
  }
}

private struct CodexCollapsedFilesRail: View {
  @Environment(\.colorScheme) private var colorScheme
  @Binding var isVisible: Bool
  @State private var isHoveringEdge = false
  @State private var isHandleVisible = false
  @State private var hoverToken = 0

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Color.clear
        .frame(maxWidth: .infinity, maxHeight: .infinity)

      Button {
        guard isHandleVisible else { return }
        withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
          isVisible = true
        }
      } label: {
        VStack(spacing: 10) {
          Image(systemName: "folder.fill")
            .font(.system(size: 13, weight: .semibold))
          Text("Files")
            .font(.caption.weight(.bold))
            .rotationEffect(.degrees(-90))
            .fixedSize()
        }
        .foregroundStyle(AControlStyle.accentForeground(.purple, colorScheme))
        .frame(width: 36, height: 150)
        .background(
          AControlStyle.panelFill(colorScheme),
          in: Capsule(style: .continuous)
        )
        .overlay {
          Capsule(style: .continuous)
            .strokeBorder(AControlStyle.accentStroke(.purple, colorScheme), lineWidth: 1)
        }
        .shadow(color: AControlStyle.softShadow(colorScheme), radius: 14, x: 0, y: 7)
      }
      .buttonStyle(ImmediateFeedbackButtonStyle())
      .opacity(isHandleVisible ? 1 : 0)
      .offset(x: isHandleVisible ? -8 : 18)
      .allowsHitTesting(isHandleVisible)
      .accessibilityHidden(!isHandleVisible)
      .safeHelp("Open Files panel")
    }
    .padding(.top, 58)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    .contentShape(Rectangle())
    .onHover { hovering in
      isHoveringEdge = hovering
      hoverToken += 1
      let token = hoverToken
      if hovering {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
          guard token == hoverToken, isHoveringEdge else { return }
          withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
            isHandleVisible = true
          }
        }
      } else {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
          guard token == hoverToken, !isHoveringEdge else { return }
          withAnimation(.easeOut(duration: 0.14)) {
            isHandleVisible = false
          }
        }
      }
    }
  }
}

private struct ArtifactStrip: View {
  @EnvironmentObject private var model: AppModel
  var artifacts: [CodexArtifact]
  var activeID: String?

  private let rows = [
    GridItem(.fixed(38), spacing: 6, alignment: .leading),
    GridItem(.fixed(38), spacing: 6, alignment: .leading),
  ]

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      LazyHGrid(rows: rows, alignment: .top, spacing: 7) {
        ForEach(artifacts) { artifact in
          Button {
            Task { await model.previewCodexArtifactInPanel(artifact) }
          } label: {
            ArtifactPill(
              artifact: artifact,
              isActive: artifact.id == activeID
            )
          }
          .buttonStyle(ImmediateFeedbackButtonStyle())
          .safeHelp(artifact.sourceLine.isEmpty ? artifact.path : artifact.sourceLine)
          .simultaneousGesture(
            TapGesture(count: 2)
              .onEnded {
                Task { await model.previewCodexArtifactInPanel(artifact) }
              }
          )
        }
      }
      .padding(.vertical, 1)
      .padding(.trailing, 8)
    }
    .frame(height: 82)
  }
}

private struct ArtifactPill: View {
  @Environment(\.colorScheme) private var colorScheme
  var artifact: CodexArtifact
  var isActive: Bool

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: artifact.kind.symbol)
        .font(.system(size: 12, weight: .semibold))
        .frame(width: 14, height: 14)
      VStack(alignment: .leading, spacing: 1) {
        Text(artifact.name)
          .font(.caption2.weight(.semibold))
          .lineLimit(1)
          .truncationMode(.middle)
        Text(artifact.displayPath)
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
    }
    .foregroundStyle(
      isActive
        ? AControlStyle.accentForeground(.purple, colorScheme)
        : AControlStyle.accentForeground(artifact.kind.tint, colorScheme)
    )
    .padding(.horizontal, 8)
    .frame(width: 190, height: 36)
    .background(
      isActive
        ? AControlStyle.accentFill(.purple, colorScheme)
        : Color.primary.opacity(colorScheme == .dark ? 0.040 : 0.025),
      in: RoundedRectangle(cornerRadius: 11, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 11, style: .continuous)
        .strokeBorder(
          AControlStyle.accentStroke(isActive ? .purple : artifact.kind.tint, colorScheme),
          lineWidth: 1)
    }
  }
}

private struct CodexArtifactPreview: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if let artifact = model.codexPreviewArtifact {
        VStack(alignment: .leading, spacing: 8) {
          HStack(alignment: .top, spacing: 8) {
            Image(systemName: artifact.kind.symbol)
              .font(.system(size: 12.5, weight: .semibold))
              .foregroundStyle(AControlStyle.accentForeground(artifact.kind.tint, colorScheme))
              .frame(width: 26, height: 26)
              .background(AControlStyle.accentFill(artifact.kind.tint, colorScheme), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
              Text(artifact.name)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(2)
                .truncationMode(.middle)
                .fixedSize(horizontal: false, vertical: true)
              Text(compactPath(artifact.displayPath))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
          }

          HStack(spacing: 8) {
            Button {
              Task { await model.openCodexArtifact(artifact) }
            } label: {
              Label("Files", systemImage: "folder")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 9)
                .frame(height: 28)
            }
            .buttonStyle(ImmediateFeedbackButtonStyle())
            .foregroundStyle(.primary)
            .background(AControlStyle.insetFill(colorScheme), in: Capsule())
            .safeHelp("Open in Files")
            if model.codexArtifactPreviewURL != nil {
              Button {
                model.openCodexPreviewExternally()
              } label: {
                Label("Open", systemImage: "arrow.up.forward.square")
                  .font(.caption.weight(.semibold))
                  .padding(.horizontal, 9)
                  .frame(height: 28)
              }
              .buttonStyle(ImmediateFeedbackButtonStyle())
              .foregroundStyle(.primary)
              .background(AControlStyle.insetFill(colorScheme), in: Capsule())
              .safeHelp("Open externally")
            }
            Spacer(minLength: 0)
          }
        }
        previewBody
      } else {
        emptyPreview
      }
    }
  }

  @ViewBuilder
  private var previewBody: some View {
    switch model.codexArtifactPreviewKind {
    case .text:
      WrappingTextPreview(
        text: model.codexArtifactPreviewText.isEmpty ? "Loading..." : model.codexArtifactPreviewText
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(AControlStyle.transcriptFill(colorScheme), in: RoundedRectangle(cornerRadius: 12))
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
      }
    case .image:
      if let url = model.codexArtifactPreviewURL {
        LocalImagePreview(url: url)
          .padding(8)
          .background(
            AControlStyle.transcriptFill(colorScheme), in: RoundedRectangle(cornerRadius: 12)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 12)
              .strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
          }
      } else if model.isCodexArtifactPreviewLoading {
        previewLoading("Loading image preview...")
      } else if !model.codexArtifactPreviewError.isEmpty {
        previewLoading(model.codexArtifactPreviewError)
      } else {
        previewUnavailable("Image preview unavailable.")
      }
    case .pdf:
      if let url = model.codexArtifactPreviewURL {
        PDFPreview(url: url)
          .background(
            AControlStyle.transcriptFill(colorScheme), in: RoundedRectangle(cornerRadius: 12)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 12)
              .strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
          }
      } else if model.isCodexArtifactPreviewLoading {
        previewLoading("Loading PDF preview...")
      } else if !model.codexArtifactPreviewError.isEmpty {
        previewLoading(model.codexArtifactPreviewError)
      } else {
        previewUnavailable("PDF preview unavailable.")
      }
    case .video:
      if let url = model.codexArtifactPreviewURL {
        LocalVideoPreview(url: url)
          .background(
            AControlStyle.transcriptFill(colorScheme), in: RoundedRectangle(cornerRadius: 12)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 12)
              .strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
          }
      } else if model.isCodexArtifactPreviewLoading {
        previewLoading("Video preview skipped.")
      } else if !model.codexArtifactPreviewError.isEmpty {
        previewLoading(model.codexArtifactPreviewError)
      } else {
        previewUnavailable("Video preview skipped.")
      }
    case .external:
      VStack(spacing: 8) {
        Image(systemName: "doc")
          .font(.system(size: 28, weight: .semibold))
          .foregroundStyle(.secondary)
        Text("Preview supports PDF, images, and text files.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, minHeight: 140)
      .background(AControlStyle.insetFill(colorScheme), in: RoundedRectangle(cornerRadius: 12))
    case .none:
      emptyPreview
    }
  }

  private func compactPath(_ path: String) -> String {
    let parts = path.split(separator: "/").map(String.init)
    guard parts.count > 3 else { return path }
    let suffix = parts.suffix(3).joined(separator: "/")
    if path.hasPrefix("~/") {
      return "~/…/\(suffix)"
    }
    return "…/\(suffix)"
  }

  private var emptyPreview: some View {
    Text("Select a file to preview.")
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, minHeight: 120)
      .background(AControlStyle.insetFill(colorScheme), in: RoundedRectangle(cornerRadius: 12))
  }

  private func previewUnavailable(_ text: String) -> some View {
    VStack(spacing: 8) {
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(.secondary)
      Text(text)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text("Resolving the exact A-side path and warming the preview cache.")
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
    }
    .padding(16)
    .frame(maxWidth: .infinity, minHeight: 140)
    .background(AControlStyle.insetFill(colorScheme), in: RoundedRectangle(cornerRadius: 12))
  }

  private func previewLoading(_ text: String) -> some View {
    VStack(spacing: 10) {
      ProgressView()
        .controlSize(.regular)
      Text(text)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      Text("Fetching the file from A in the background.")
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
    .padding(16)
    .frame(maxWidth: .infinity, minHeight: 140)
    .background(AControlStyle.insetFill(colorScheme), in: RoundedRectangle(cornerRadius: 12))
  }
}

private struct LocalImagePreview: View {
  var url: URL

  var body: some View {
    Group {
      if let image = NSImage(contentsOf: url) {
        Image(nsImage: image)
          .resizable()
          .scaledToFit()
      } else {
        Text("Image preview unavailable.")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private struct WrappingTextPreview: NSViewRepresentable {
  var text: String

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true

    let textView = NSTextView()
    textView.isEditable = false
    textView.isSelectable = true
    textView.isRichText = false
    textView.drawsBackground = false
    textView.textContainerInset = NSSize(width: 10, height: 10)
    textView.textContainer?.lineFragmentPadding = 0
    textView.textContainer?.widthTracksTextView = true
    textView.textContainer?.heightTracksTextView = false
    textView.textContainer?.containerSize = NSSize(
      width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
    textView.isHorizontallyResizable = false
    textView.isVerticallyResizable = true
    textView.minSize = NSSize(width: 0, height: 0)
    textView.maxSize = NSSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude
    )
    textView.autoresizingMask = [.width]
    textView.font = NSFont.monospacedSystemFont(ofSize: 11.2, weight: .regular)
    textView.textColor = .labelColor
    textView.string = text

    scrollView.documentView = textView
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let textView = scrollView.documentView as? NSTextView else { return }
    textView.textContainer?.containerSize = NSSize(
      width: scrollView.contentView.bounds.width, height: .greatestFiniteMagnitude)
    if textView.string != text {
      textView.string = text
    }
  }
}

private struct CodexModelOption: Identifiable, Hashable {
  var id: String { name }
  var name: String
  var badge: String
  var detail: String
}

private struct CodexReasoningEffortOption: Identifiable, Hashable {
  var id: String { value }
  var value: String
  var title: String
  var detail: String
}

private struct CodexPromptPanel: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.colorScheme) private var colorScheme
  @State private var draft = ""
  @State private var showingDirectoryPicker = false
  @State private var selectedPluginSnippets: [CodexPluginSnippet] = []
  @State private var selectedResearchPreset: CodexResearchPreset?
  @State private var activeControlPanel: CodexPromptControlPanel?
  @State private var selectedResearchGroupID: String?
  @State private var draftSaveTask: Task<Void, Never>?
  @AppStorage("AControl.researchPresetLoopCount") private var storedResearchLoopCount =
    CodexResearchPreset.defaultLoopCount
  var codexModels: [CodexModelOption]
  var reasoningEfforts: [CodexReasoningEffortOption]
  var pluginSnippets: [CodexPluginSnippet]

  private var activeCodexIsWorking: Bool {
    model.activeSessionID.map { model.codexWorkingSessionIDs.contains($0) } ?? false
  }

  private var canSteerCodex: Bool {
    model.activeCodexCanSteer
  }

  private var hasQueueItemsForActiveSession: Bool {
    let active = model.activeSessionID
    return model.codexPromptQueue.contains { item in
      (active == nil || item.sessionID == active) && item.isVisibleInComposerQueue
    }
  }

  private var composerPlaceholder: String {
    activeCodexIsWorking ? "Ask for follow-up changes" : "Ask Codex to work on this session"
  }

  private var researchLoopCount: Int {
    CodexResearchPreset.clampedLoopCount(storedResearchLoopCount)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 12) {
        if hasQueueItemsForActiveSession {
          CodexQueueStrip()
        }

        VStack(alignment: .leading, spacing: 0) {
          ZStack(alignment: .topLeading) {
            PromptComposerView(
              text: $draft,
              onAttachFiles: { urls in
                model.addCodexAttachments(urls)
              },
              onAttachImage: { data, ext in
                model.addCodexImageAttachment(data: data, suggestedExtension: ext)
              },
              onSubmit: {
                submit(steer: false)
              }
            )
            .frame(height: 116)

            if draft.trimmed.isEmpty {
              Text(composerPlaceholder)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.secondary.opacity(0.58))
                .padding(.horizontal, 18)
                .padding(.vertical, 17)
                .allowsHitTesting(false)
            }
          }

          if !model.codexAttachments.isEmpty {
            FlowLayout(spacing: 8) {
              ForEach(model.codexAttachments) { attachment in
                AttachmentChip(attachment: attachment) {
                  model.removeCodexAttachment(attachment)
                }
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
          }

          if selectedResearchPreset != nil || !selectedPluginSnippets.isEmpty {
            FlowLayout(spacing: 8) {
              if let selectedResearchPreset {
                ComposerContextChip(
                  title: "Professor Lab: \(selectedResearchPreset.title) · \(researchLoopCount) stages",
                  symbol: selectedResearchPreset.symbol
                ) {
                  self.selectedResearchPreset = nil
                }
              }
              ForEach(selectedPluginSnippets) { snippet in
                ComposerContextChip(title: snippet.title, symbol: "puzzlepiece.extension") {
                  selectedPluginSnippets.removeAll { $0.id == snippet.id }
                }
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
          }

          Divider().opacity(0.45)

          HStack(spacing: 10) {
            composerIconButton("plus", help: "Attach files") {
              model.chooseCodexAttachments()
            }
            SoftButton(title: "Dir", symbol: "folder.badge.gearshape") {
              showingDirectoryPicker = true
            }
            if !model.codexAttachments.isEmpty {
              composerIconButton("xmark.circle", help: "Clear attachments") {
                model.clearCodexAttachments()
              }
            }

            Spacer(minLength: 8)

            if model.isProcessingCodexPromptQueue {
              ProgressView()
                .controlSize(.small)
                .safeHelp("Sending queued prompt")
            }

            CodexPromptControls(
              codexModels: codexModels,
              reasoningEfforts: reasoningEfforts,
              pluginSnippets: pluginSnippets,
              draft: $draft,
              selectedPluginSnippets: $selectedPluginSnippets,
              selectedResearchPreset: $selectedResearchPreset,
              activePanel: $activeControlPanel,
              selectedResearchGroupID: $selectedResearchGroupID
            )
            .frame(minWidth: 0, maxWidth: 1040, alignment: .trailing)
            .layoutPriority(3)

            AgentChoiceControls(
              onUp: { Task { await model.codexKey("up") } },
              onDown: { Task { await model.codexKey("down") } },
              onEnter: { Task { await model.codexKey("enter") } },
              onEscape: { Task { await model.codexKey("esc") } }
            )

            steerSubmitButton

            PrimaryButton(
              title: "Send",
              symbol: "paperplane",
              tint: .purple,
              minWidth: 88
            ) {
              submit(steer: false)
            }
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
        }
        .background(
          AControlStyle.transcriptFill(colorScheme),
          in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 28, style: .continuous)
            .strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
        }
        .overlay(alignment: .bottom) {
          if let activeControlPanel {
            CodexPromptControlSelectorPanel(
              panel: activeControlPanel,
              codexModels: codexModels,
              reasoningEfforts: reasoningEfforts,
              pluginSnippets: pluginSnippets,
              selectedPluginSnippets: $selectedPluginSnippets,
              selectedResearchPreset: $selectedResearchPreset,
              activePanel: $activeControlPanel,
              selectedResearchGroupID: $selectedResearchGroupID
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 58)
            .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .bottom)))
            .zIndex(20)
          }
        }
        .shadow(
          color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.08), radius: 14, x: 0, y: 7)
      }
    }
    .sheet(isPresented: $showingDirectoryPicker) {
      RemoteDirectoryPicker(title: "Codex Directory") { path in
        showingDirectoryPicker = false
        Task { await model.restartCodex(in: path) }
      }
      .environmentObject(model)
    }
    .onAppear {
      draft = model.codexDraftForActiveSession()
      if model.codexPluginLog.trimmed.isEmpty {
        Task { await model.checkCodexPlugins() }
      }
    }
    .onChange(of: model.activeSessionID) { _, _ in
      draftSaveTask?.cancel()
      draft = model.codexDraftForActiveSession()
      selectedResearchPreset = nil
      selectedResearchGroupID = nil
      selectedPluginSnippets = []
      activeControlPanel = nil
    }
    .onChange(of: draft) { _, newValue in
      model.cacheCodexDraftForActiveSession(newValue)
      draftSaveTask?.cancel()
      let valueToPersist = newValue
      draftSaveTask = Task { @MainActor in
        try? await Task.sleep(nanoseconds: 450_000_000)
        guard !Task.isCancelled else { return }
        model.updateCodexDraftForActiveSession(valueToPersist)
      }
    }
    .onDisappear {
      draftSaveTask?.cancel()
      model.updateCodexDraftForActiveSession(draft)
    }
  }

  private var steerSubmitButton: some View {
    Button {
      submit(steer: true)
    } label: {
      Label("Steer", systemImage: "arrow.triangle.turn.up.right.diamond")
        .font(.system(size: 12.5, weight: .bold))
        .lineLimit(1)
        .padding(.horizontal, 12)
        .frame(height: 34)
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .disabled(!canSteerCodex)
    .foregroundStyle(
      canSteerCodex
        ? AControlStyle.accentForeground(.blue, colorScheme)
        : Color.secondary.opacity(0.55)
    )
    .background(
      canSteerCodex
        ? AnyShapeStyle(AControlStyle.accentFill(.blue, colorScheme))
        : AnyShapeStyle(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.035)),
      in: Capsule()
    )
    .overlay {
      Capsule()
        .strokeBorder(
          canSteerCodex
            ? AControlStyle.accentStroke(.blue, colorScheme)
            : AControlStyle.hairline(colorScheme),
          lineWidth: 1
        )
    }
    .safeHelp(
      canSteerCodex
        ? "Queue this as a steer follow-up on the server Codex"
        : "Start or queue a Codex task first, then steer it"
    )
  }

  private func submit(steer: Bool) {
    let submitted = draft
    guard !submitted.trimmed.isEmpty || !model.codexAttachments.isEmpty else { return }
    let deliveryText = promptForDelivery(visiblePrompt: submitted)
    model.codexInput = deliveryText
    Task { @MainActor in
      let accepted: Bool
      if !steer, let researchPreset = selectedResearchPreset {
        accepted = await model.enqueueCodexResearchPreset(
          researchPreset,
          seedPrompt: deliveryText,
          displayPrompt: submitted,
          attachments: model.codexAttachments,
          loopCount: researchLoopCount
        )
      } else {
        accepted = await model.sendCodex(
          steer: steer,
          displayText: visiblePromptSummary(submitted)
        )
      }
      if accepted {
        draftSaveTask?.cancel()
        draft = ""
        selectedResearchPreset = nil
        selectedResearchGroupID = nil
        selectedPluginSnippets = []
        activeControlPanel = nil
        model.updateCodexDraftForActiveSession("")
        model.codexInput = ""
      } else {
        model.codexInput = deliveryText
        model.updateCodexDraftForActiveSession(submitted)
      }
    }
  }

  private func promptForDelivery(visiblePrompt: String) -> String {
    let pluginContext = selectedPluginSnippets
      .map { "- \($0.title): \($0.snippet.trimmed)" }
      .joined(separator: "\n")
      .trimmed
    guard !pluginContext.isEmpty else { return visiblePrompt }
    return """
      \(visiblePrompt.trimmed)

      SSHcontroll selected context:
      \(pluginContext)
      """
  }

  private func visiblePromptSummary(_ prompt: String) -> String? {
    let trimmedPrompt = prompt.trimmed
    guard !selectedPluginSnippets.isEmpty else { return nil }
    let pluginList = selectedPluginSnippets.map(\.title).joined(separator: ", ")
    if trimmedPrompt.isEmpty {
      return "Prompt with \(pluginList)"
    }
    return "Using \(pluginList)\n\n\(trimmedPrompt)"
  }

  private func composerIconButton(
    _ symbol: String,
    help: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 14, weight: .semibold))
        .frame(width: 34, height: 34)
        .contentShape(Circle())
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .foregroundStyle(.secondary)
    .background(AControlStyle.insetFill(colorScheme), in: Circle())
    .overlay {
      Circle().strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
    }
    .safeHelp(help)
  }
}

private struct CodexQueueStrip: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.colorScheme) private var colorScheme
  @State private var draggingQueueItemID: UUID?
  @State private var editingQueueItemID: UUID?
  @State private var editingQueueText = ""

  private var sessionItems: [CodexPromptQueueItem] {
    let active = model.activeSessionID
    return model.codexPromptQueue
      .filter { item in active == nil || item.sessionID == active }
  }

  private var activeItems: [CodexPromptQueueItem] {
    sessionItems
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

  private var visibleItems: [CodexPromptQueueItem] {
    activeItems
  }

  private var activeCount: Int {
    visibleItems.count
  }

  private var activeCodexIsWorking: Bool {
    model.activeSessionID.map { model.codexWorkingSessionIDs.contains($0) } ?? false
  }

  private var canSteerCodex: Bool {
    model.activeCodexCanSteer
  }

  private func queueSortRank(_ status: CodexPromptQueueStatus) -> Int {
    switch status {
    case .sending: 0
    case .waitingForCodex: 1
    case .queued: 2
    case .failed: 3
    case .delivered: 4
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 8) {
        Text(queueHeaderTitle)
          .font(.system(size: 10.5, weight: .semibold))
          .foregroundStyle(.secondary)
        Spacer()
        if visibleItems.contains(where: { $0.status == .failed }) {
          Button {
            model.retryFailedCodexQueueItems()
          } label: {
            Label("Retry failed", systemImage: "arrow.clockwise")
              .font(.system(size: 10.5, weight: .semibold))
          }
          .buttonStyle(ImmediateFeedbackButtonStyle())
          .foregroundStyle(AControlStyle.accentForeground(.blue, colorScheme))
        }
      }
      .padding(.horizontal, 11)
      .padding(.vertical, 5)

      Divider().opacity(0.5)

      if activeCount > 0, visibleItems.count > 3 {
        ScrollView(.vertical, showsIndicators: true) {
          queueRows
        }
        .frame(height: 118)
      } else {
        queueRows
      }
    }
    .background(
      AControlStyle.insetFill(colorScheme),
      in: RoundedRectangle(cornerRadius: 16, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
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
      CodexQueueEditSheet(
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

  private var queueHeaderTitle: String {
    if activeCount == 0 {
      return "No queued follow-ups"
    }
    if activeCount == 1 {
      return "1 queued follow-up"
    }
    return "\(activeCount) queued follow-ups"
  }

  private var queueRows: some View {
    VStack(spacing: 0) {
      ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
        queueRow(item)
        if index < visibleItems.count - 1 {
          Divider().opacity(0.4)
        }
      }
    }
  }

  @ViewBuilder
  private func queueRow(_ item: CodexPromptQueueItem) -> some View {
    let row = CodexQueueChip(
      item: item,
      activeCodexIsWorking: activeCodexIsWorking
    ) { item in
      beginEditing(item)
    }
    if item.status == .queued || item.status == .waitingForCodex {
      row
        .onDrag {
          draggingQueueItemID = item.id
          return NSItemProvider(object: item.id.uuidString as NSString)
        }
        .onDrop(
          of: ["public.text"],
          delegate: CodexQueueDropDelegate(
            targetID: item.id,
            draggingID: $draggingQueueItemID
          ) { draggedID, targetID in
            model.moveQueuedCodexPrompt(draggedID, before: targetID)
          }
        )
    } else {
      row
    }
  }

  private func beginEditing(_ item: CodexPromptQueueItem) {
    editingQueueText = item.visibleText
    editingQueueItemID = item.id
  }
}

private struct CodexQueueEditSheet: View {
  @Environment(\.colorScheme) private var colorScheme
  @Binding var text: String
  var onCancel: () -> Void
  var onSave: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Label("Edit Queue Item", systemImage: "pencil")
          .font(.system(size: 14, weight: .bold))
        Spacer()
      }
      TextEditor(text: $text)
        .font(.system(size: 13, weight: .regular))
        .scrollContentBackground(.hidden)
        .padding(10)
        .frame(width: 560, height: 220)
        .background(
          AControlStyle.transcriptFill(colorScheme),
          in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
        }
      HStack {
        Spacer()
        SoftButton(title: "Cancel", symbol: "xmark") {
          onCancel()
        }
        PrimaryButton(title: "Save", symbol: "checkmark", tint: .blue, minWidth: 92) {
          onSave()
        }
        .disabled(text.trimmed.isEmpty)
      }
    }
    .padding(18)
  }
}

private struct CodexQueueDropDelegate: DropDelegate {
  let targetID: UUID
  @Binding var draggingID: UUID?
  var onMove: (UUID, UUID) -> Void

  func validateDrop(info: DropInfo) -> Bool {
    guard let draggingID else { return false }
    return draggingID != targetID
  }

  func dropEntered(info: DropInfo) {
    guard let draggingID, draggingID != targetID else { return }
    onMove(draggingID, targetID)
  }

  func performDrop(info: DropInfo) -> Bool {
    draggingID = nil
    return true
  }

  func dropExited(info: DropInfo) {}
}

private struct CodexQueueChip: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.colorScheme) private var colorScheme
  var item: CodexPromptQueueItem
  var activeCodexIsWorking: Bool
  var onEdit: (CodexPromptQueueItem) -> Void

  private var tint: Color {
    switch item.status {
    case .queued: .orange
    case .sending, .waitingForCodex: .blue
    case .delivered: .green
    case .failed: .red
    }
  }

  var body: some View {
    HStack(alignment: .center, spacing: 7) {
      if item.status == .queued || item.status == .waitingForCodex {
        Image(systemName: "line.3.horizontal")
          .font(.system(size: 8, weight: .bold))
          .foregroundStyle(.secondary.opacity(0.55))
          .frame(width: 9)
          .safeHelp("Drag to reorder queued A prompts before they start")
      }

      Image(
        systemName: item.kind == .steer
          ? "arrow.triangle.turn.up.right.diamond" : "arrow.triangle.turn.up.right"
      )
      .font(.system(size: 10.5, weight: .semibold))
      .foregroundStyle(AControlStyle.accentForeground(tint, colorScheme))
      .frame(width: 16)

      VStack(alignment: .leading, spacing: 1) {
        Text(item.shortText.isEmpty ? "Attachment prompt" : item.shortText)
          .font(.system(size: 10.5, weight: .semibold))
          .foregroundStyle(.primary.opacity(0.82))
          .lineLimit(1)
          .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: 5) {
          Text(item.status.title)
          Text("·")
          Text(item.kind.title)
          if !queueDetail.isEmpty {
            Text("·")
            Text(queueDetail)
              .lineLimit(1)
          }
        }
        .font(.system(size: 9.5, weight: .semibold))
        .foregroundStyle(.secondary)
      }

      Spacer(minLength: 8)

      HStack(spacing: 5) {
        if item.kind == .send && (item.status == .queued || item.status == .waitingForCodex) {
          queueTextButton(
            "Steer",
            symbol: "arrow.triangle.turn.up.right.diamond",
            tint: .blue,
            isDisabled: false,
            help: item.status == .waitingForCodex
              ? "Change this A queue item to steer if it has not started yet"
              : "Send this queued item as steer"
          ) {
            model.promoteCodexQueueItemToSteer(item.id)
          }
        }
        if item.status == .failed {
          queueIconButton("arrow.clockwise", help: "Retry this prompt") {
            model.retryCodexQueueItem(item.id)
          }
        }
        if item.status == .queued || item.status == .waitingForCodex || item.status == .failed {
          queueIconButton("pencil", help: "Edit this queued prompt") {
            onEdit(item)
          }
        }
        if item.status != .sending {
          queueIconButton("trash", help: "Remove from queue") {
            model.discardCodexQueueItem(item.id)
          }
        }
      }
    }
    .padding(.horizontal, 11)
    .padding(.vertical, 4)
    .contentShape(Rectangle())
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

  private func queueIconButton(
    _ symbol: String,
    help: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 8, weight: .bold))
        .frame(width: 15, height: 15)
        .contentShape(Circle())
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .foregroundStyle(.secondary)
    .background(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.055), in: Circle())
    .safeHelp(help)
  }

  private func queueTextButton(
    _ title: String,
    symbol: String,
    tint: Color,
    isDisabled: Bool,
    help: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Label(title, systemImage: symbol)
        .font(.system(size: 10.2, weight: .semibold))
        .lineLimit(1)
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .disabled(isDisabled)
    .foregroundStyle(isDisabled ? .secondary : AControlStyle.accentForeground(tint, colorScheme))
    .safeHelp(help)
  }
}

struct AgentChoiceControls: View {
  @Environment(\.colorScheme) private var colorScheme
  var onUp: () -> Void
  var onDown: () -> Void
  var onEnter: () -> Void
  var onEscape: () -> Void

  var body: some View {
    HStack(spacing: 4) {
      choiceButton("chevron.up", help: "Move selection up", action: onUp)
      choiceButton("chevron.down", help: "Move selection down", action: onDown)
      choiceButton("return", help: "Confirm selection", action: onEnter)
      choiceButton("escape", help: "Cancel selection", action: onEscape)
    }
    .padding(4)
    .background(AControlStyle.insetFill(colorScheme), in: Capsule())
    .overlay {
      Capsule().strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
    }
  }

  private func choiceButton(_ symbol: String, help: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 12.5, weight: .semibold))
        .frame(width: 28, height: 28)
        .contentShape(Circle())
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .foregroundStyle(.primary)
    .background(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.045), in: Circle())
    .safeHelp(help)
  }
}

private enum CodexPromptControlPanel: Hashable {
  case model
  case reasoning
  case research
  case plugins

  var title: String {
    switch self {
    case .model: "Model"
    case .reasoning: "Reasoning"
    case .research: "Professor Lab"
    case .plugins: "Plugins"
    }
  }

  var symbol: String {
    switch self {
    case .model: "slider.horizontal.3"
    case .reasoning: "brain.head.profile"
    case .research: "atom"
    case .plugins: "puzzlepiece.extension"
    }
  }

  var preferredHeight: CGFloat {
    switch self {
    case .model: 168
    case .reasoning: 124
    case .research: 248
    case .plugins: 248
    }
  }
}

private struct CodexPromptControlSelectorPanel: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.colorScheme) private var colorScheme
  @AppStorage("AControl.researchPresetLoopCount") private var storedLoopCount =
    CodexResearchPreset.defaultLoopCount
  var panel: CodexPromptControlPanel
  var codexModels: [CodexModelOption]
  var reasoningEfforts: [CodexReasoningEffortOption]
  var pluginSnippets: [CodexPluginSnippet]
  @Binding var selectedPluginSnippets: [CodexPluginSnippet]
  @Binding var selectedResearchPreset: CodexResearchPreset?
  @Binding var activePanel: CodexPromptControlPanel?
  @Binding var selectedResearchGroupID: String?

  private var loopCount: Int {
    CodexResearchPreset.clampedLoopCount(storedLoopCount)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack(spacing: 8) {
        Label(panel.title, systemImage: panel.symbol)
          .font(.system(size: 12.2, weight: .bold))
          .foregroundStyle(.primary.opacity(0.86))
        Spacer()
        Button {
          withAnimation(.easeOut(duration: 0.14)) {
            activePanel = nil
          }
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 10.5, weight: .bold))
            .frame(width: 24, height: 24)
        }
        .buttonStyle(ImmediateFeedbackButtonStyle())
        .foregroundStyle(.secondary)
        .safeHelp("Close selector")
      }

      switch panel {
      case .model:
        modelPanel
      case .reasoning:
        reasoningPanel
      case .research:
        researchPanel
      case .plugins:
        pluginsPanel
      }
    }
    .padding(12)
    .frame(height: panel.preferredHeight, alignment: .topLeading)
    .background(
      AControlStyle.insetFill(colorScheme),
      in: RoundedRectangle(cornerRadius: 18, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
    }
    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.08), radius: 18, x: 0, y: 8)
  }

  private var modelPanel: some View {
    ScrollView(.vertical, showsIndicators: true) {
      FlowLayout(spacing: 8) {
        ForEach(codexModels) { option in
          panelChoiceButton(
            title: "\(option.name) \(option.badge)",
            subtitle: option.detail,
            symbol: option.name == model.codexModel ? "checkmark.circle.fill" : "circle",
            selected: option.name == model.codexModel,
            tint: .blue
          ) {
            guard option.name != model.codexModel else {
              activePanel = nil
              return
            }
            model.codexModel = option.name
            activePanel = nil
            Task { await model.selectCodexModel(option.name) }
          }
        }
      }
      .padding(.trailing, 4)
    }
    .frame(maxHeight: 124)
  }

  private var reasoningPanel: some View {
    FlowLayout(spacing: 8) {
      ForEach(reasoningEfforts) { option in
        panelChoiceButton(
          title: option.title,
          subtitle: option.detail,
          symbol: option.value == model.codexReasoningEffort ? "checkmark.circle.fill" : "circle",
          selected: option.value == model.codexReasoningEffort,
          tint: .indigo
        ) {
          guard option.value != model.codexReasoningEffort else {
            activePanel = nil
            return
          }
          model.codexReasoningEffort = option.value
          activePanel = nil
          Task { await model.selectCodexReasoningEffort(option.value) }
        }
      }
    }
  }

  private var researchPanel: some View {
    VStack(alignment: .leading, spacing: 9) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 7) {
          ForEach(CodexResearchPresetLibrary.groups) { group in
            panelPill(
              title: group.title,
              symbol: group.symbol,
              selected: selectedResearchGroup?.id == group.id
            ) {
              selectedResearchGroupID = group.id
              if let selectedResearchPreset,
                !group.presetIDs.contains(selectedResearchPreset.id)
              {
                self.selectedResearchPreset = nil
              }
            }
          }
        }
        .padding(.vertical, 1)
      }

      HStack(spacing: 7) {
        panelPill(
          title: "Normal Send",
          symbol: "paperplane",
          selected: selectedResearchPreset == nil,
          tint: .purple
        ) {
          selectedResearchPreset = nil
          selectedResearchGroupID = nil
          activePanel = nil
        }
        ForEach(CodexResearchPreset.loopCountChoices, id: \.self) { count in
          panelPill(
            title: "\(count)",
            symbol: loopCount == count ? "checkmark.circle.fill" : "circle",
            selected: loopCount == count,
            tint: .orange
          ) {
            storedLoopCount = count
          }
        }
      }

      ScrollView(.vertical, showsIndicators: true) {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 174, maximum: 260), spacing: 8)],
          alignment: .leading,
          spacing: 8
        ) {
          ForEach(CodexResearchPresetLibrary.presets(in: displayedResearchGroup)) { preset in
            panelChoiceButton(
              title: preset.title,
              subtitle: preset.subtitle,
              symbol: selectedResearchPreset?.id == preset.id ? "checkmark.circle.fill" : preset.symbol,
              selected: selectedResearchPreset?.id == preset.id,
              tint: .purple
            ) {
              selectedResearchPreset = preset
              selectedResearchGroupID = groupID(for: preset)
            }
          }
        }
        .padding(.trailing, 4)
      }
      .frame(minHeight: 126, maxHeight: 176)
    }
  }

  private var pluginsPanel: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 7) {
        panelPill(
          title: "Refresh",
          symbol: "arrow.clockwise",
          selected: false,
          tint: .teal
        ) {
          Task { await model.checkCodexPlugins() }
        }
        if !selectedPluginSnippets.isEmpty {
          panelPill(
            title: "Clear",
            symbol: "xmark.circle",
            selected: false,
            tint: .red
          ) {
            selectedPluginSnippets.removeAll()
          }
        }
      }

      ScrollView(.vertical, showsIndicators: true) {
        VStack(alignment: .leading, spacing: 10) {
          ForEach(pluginMenuCategories, id: \.self) { category in
            VStack(alignment: .leading, spacing: 6) {
              Text(category)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
              FlowLayout(spacing: 7) {
                ForEach(plugins(in: category)) { item in
                  panelChoiceButton(
                    title: item.title,
                    subtitle: item.detail.trimmed.isEmpty ? item.snippet : item.detail,
                    symbol: isPluginSelected(item) ? "checkmark.circle.fill" : item.symbol,
                    selected: isPluginSelected(item),
                    tint: .teal
                  ) {
                    togglePluginSnippet(item)
                  }
                }
              }
            }
          }
        }
        .padding(.trailing, 4)
      }
      .frame(minHeight: 150, maxHeight: 190)
    }
  }

  private var selectedResearchGroup: CodexResearchPresetGroup? {
    if let selectedResearchPreset,
      let group = CodexResearchPresetLibrary.groups.first(where: {
        $0.presetIDs.contains(selectedResearchPreset.id)
      })
    {
      return group
    }
    guard let selectedResearchGroupID else { return nil }
    return CodexResearchPresetLibrary.groups.first { $0.id == selectedResearchGroupID }
  }

  private var displayedResearchGroup: CodexResearchPresetGroup {
    selectedResearchGroup ?? CodexResearchPresetLibrary.groups.first!
  }

  private func groupID(for preset: CodexResearchPreset) -> String? {
    CodexResearchPresetLibrary.groups.first { group in
      group.presetIDs.contains(preset.id)
    }?.id
  }

  private func panelPill(
    title: String,
    symbol: String,
    selected: Bool,
    tint: Color = .blue,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Label(title, systemImage: symbol)
        .font(.system(size: 11.2, weight: .semibold))
        .lineLimit(1)
        .padding(.horizontal, 9)
        .frame(height: 28)
        .foregroundStyle(selected ? AControlStyle.accentForeground(tint, colorScheme) : .primary)
        .background(
          selected
            ? AnyShapeStyle(AControlStyle.accentFill(tint, colorScheme))
            : AControlStyle.transcriptFill(colorScheme),
          in: Capsule()
        )
        .overlay {
          Capsule()
            .strokeBorder(
              selected ? AControlStyle.accentStroke(tint, colorScheme) : AControlStyle.hairline(colorScheme),
              lineWidth: 1
            )
        }
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
  }

  private func panelChoiceButton(
    title: String,
    subtitle: String,
    symbol: String,
    selected: Bool,
    tint: Color,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(alignment: .top, spacing: 8) {
        Image(systemName: symbol)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(selected ? AControlStyle.accentForeground(tint, colorScheme) : .secondary)
          .frame(width: 16, height: 18)
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.system(size: 11.6, weight: .semibold))
            .foregroundStyle(.primary.opacity(0.88))
            .lineLimit(1)
          if !subtitle.trimmed.isEmpty {
            Text(subtitle)
              .font(.system(size: 9.6, weight: .medium))
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
      .background(
        selected
          ? AnyShapeStyle(AControlStyle.accentFill(tint, colorScheme))
          : AControlStyle.transcriptFill(colorScheme),
        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(
            selected ? AControlStyle.accentStroke(tint, colorScheme) : AControlStyle.hairline(colorScheme),
            lineWidth: 1
          )
      }
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
  }

  private var pluginCategoryOrder: [String] {
    ["Runtime", "Artifacts", "Research", "Product", "Workflow", "Installed", "Tools"]
  }

  private var pluginMenuCategories: [String] {
    let categories = Set(combinedPluginSnippets.map(\.category))
    return pluginCategoryOrder.filter { categories.contains($0) }
      + categories.filter { !pluginCategoryOrder.contains($0) }.sorted()
  }

  private func plugins(in category: String) -> [CodexPluginSnippet] {
    combinedPluginSnippets.filter { $0.category == category }
  }

  private var combinedPluginSnippets: [CodexPluginSnippet] {
    var seen = Set<String>()
    var result: [CodexPluginSnippet] = []
    for item in model.detectedCodexPluginSnippets + pluginSnippets {
      let key = item.title.lowercased()
      guard !seen.contains(key) else { continue }
      seen.insert(key)
      result.append(item)
    }
    return result
  }

  private func isPluginSelected(_ item: CodexPluginSnippet) -> Bool {
    selectedPluginSnippets.contains { $0.id == item.id }
  }

  private func togglePluginSnippet(_ item: CodexPluginSnippet) {
    if isPluginSelected(item) {
      selectedPluginSnippets.removeAll { $0.id == item.id }
    } else {
      selectedPluginSnippets.append(item)
    }
  }
}

private struct CodexPromptControls: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.colorScheme) private var colorScheme
  @AppStorage("AControl.researchPresetLoopCount") private var storedLoopCount =
    CodexResearchPreset.defaultLoopCount
  var codexModels: [CodexModelOption]
  var reasoningEfforts: [CodexReasoningEffortOption]
  var pluginSnippets: [CodexPluginSnippet]
  @Binding var draft: String
  @Binding var selectedPluginSnippets: [CodexPluginSnippet]
  @Binding var selectedResearchPreset: CodexResearchPreset?
  @Binding var activePanel: CodexPromptControlPanel?
  @Binding var selectedResearchGroupID: String?

  var body: some View {
    ViewThatFits(in: .horizontal) {
      promptControlTray(compact: false)
      promptControlTray(compact: true)
    }
    .frame(maxWidth: .infinity, alignment: .trailing)
  }

  private func promptControlTray(compact: Bool) -> some View {
    HStack(spacing: compact ? 5 : 7) {
      modelMenu(width: compact ? 42 : 240, compact: compact)
      reasoningMenu(width: compact ? 42 : 160, compact: compact)
      researchMenu(width: compact ? 42 : 160, compact: compact)
      pluginMenu(width: compact ? 42 : 118, compact: compact)
    }
    .padding(.horizontal, 4)
    .padding(.vertical, 4)
    .background(AControlStyle.insetFill(colorScheme), in: Capsule())
    .overlay {
      Capsule().strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
    }
  }

  private func modelMenu(width: CGFloat, compact: Bool) -> some View {
    Button {
      togglePanel(.model)
    } label: {
      promptMenuLabel(
        title: selectedModelTitle,
        symbol: "slider.horizontal.3",
        width: width,
        compact: compact,
        tint: .blue,
        isSelected: activePanel == .model
      )
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .safeHelp("Select Codex model")
  }

  private func reasoningMenu(width: CGFloat, compact: Bool) -> some View {
    Button {
      togglePanel(.reasoning)
    } label: {
      promptMenuLabel(
        title: selectedReasoningTitle,
        symbol: "brain.head.profile",
        width: width,
        compact: compact,
        tint: .indigo,
        isSelected: activePanel == .reasoning
      )
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .safeHelp("Select Codex reasoning depth")
  }

  private func researchMenu(width: CGFloat, compact: Bool) -> some View {
    let hasPreset = selectedResearchPreset != nil
    return Button {
      togglePanel(.research)
    } label: {
      promptMenuLabel(
        title: selectedResearchPreset?.title ?? "Normal Send",
        symbol: selectedResearchPreset?.symbol ?? "paperplane",
        width: hasPreset ? max(width, compact ? 42 : 186) : width,
        compact: compact,
        tint: hasPreset ? .orange : .purple,
        isSelected: hasPreset
      )
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .safeHelp("Normal send, or choose a one-shot Professor Lab preset")
  }

  private func pluginMenu(width: CGFloat, compact: Bool) -> some View {
    Button {
      togglePanel(.plugins)
    } label: {
      promptMenuLabel(
        title: pluginMenuTitle,
        symbol: "puzzlepiece.extension",
        width: width,
        compact: compact,
        tint: .teal,
        isSelected: activePanel == .plugins || !selectedPluginSnippets.isEmpty
      )
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .safeHelp("Attach plugin instructions to the next prompt")
  }

  private func togglePanel(_ panel: CodexPromptControlPanel) {
    withAnimation(.easeOut(duration: 0.12)) {
      activePanel = activePanel == panel ? nil : panel
    }
  }

  private func promptMenuLabel(
    title: String,
    symbol: String,
    width: CGFloat,
    compact: Bool,
    tint: Color,
    isSelected: Bool = false,
    showsChevron: Bool = true
  ) -> some View {
    HStack(spacing: compact ? 0 : 9) {
      Image(systemName: symbol)
        .font(.system(size: compact ? 12.5 : 12.3, weight: .semibold))
        .frame(width: compact ? width : 18)
      if !compact {
        Text(title)
          .font(.system(size: 12.2, weight: .semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.78)
        Spacer(minLength: 6)
        if showsChevron {
          Image(systemName: "chevron.up.chevron.down")
            .font(.system(size: 9.5, weight: .bold))
            .foregroundStyle(.secondary.opacity(0.72))
        }
      }
    }
    .foregroundStyle(isSelected ? AControlStyle.accentForeground(tint, colorScheme) : .primary)
    .padding(.horizontal, compact ? 0 : 10)
    .frame(width: width, height: 31)
    .background(
      isSelected
        ? AnyShapeStyle(AControlStyle.accentFill(tint, colorScheme))
        : AControlStyle.transcriptFill(colorScheme),
      in: Capsule()
    )
    .overlay {
      Capsule()
        .strokeBorder(
          isSelected ? AControlStyle.accentStroke(tint, colorScheme) : AControlStyle.hairline(colorScheme),
          lineWidth: 1
        )
    }
  }

  private var loopCount: Int {
    CodexResearchPreset.clampedLoopCount(storedLoopCount)
  }

  private var selectedModelTitle: String {
    if let option = codexModels.first(where: { $0.name == model.codexModel }) {
      return "\(option.name)  \(option.badge)"
    }
    return model.codexModel
  }

  private var selectedReasoningTitle: String {
    reasoningEfforts.first(where: { $0.value == model.codexReasoningEffort })?.title
      ?? model.codexReasoningEffort
  }

  private func selectModel(_ selected: String) {
    guard selected != model.codexModel else { return }
    model.codexModel = selected
    Task { await model.selectCodexModel(selected) }
  }

  private func selectReasoning(_ selected: String) {
    guard selected != model.codexReasoningEffort else { return }
    model.codexReasoningEffort = selected
    Task { await model.selectCodexReasoningEffort(selected) }
  }

  private var modelSelection: Binding<String> {
    Binding(
      get: { model.codexModel },
      set: { selected in
        selectModel(selected)
      }
    )
  }

  private var reasoningSelection: Binding<String> {
    Binding(
      get: { model.codexReasoningEffort },
      set: { selected in
        selectReasoning(selected)
      }
    )
  }

  private func legacyModelPickerButton(width: CGFloat, pickerWidth: CGFloat) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "slider.horizontal.3")
        .font(.system(size: 13, weight: .semibold))
      Picker("Model", selection: modelSelection) {
        ForEach(codexModels) { option in
          Text("\(option.name)  \(option.badge)")
            .tag(option.name)
        }
      }
      .labelsHidden()
      .pickerStyle(.menu)
      .frame(width: pickerWidth)
    }
    .padding(.leading, 12)
    .padding(.trailing, 6)
    .padding(.vertical, 5)
    .frame(width: width)
    .frame(minHeight: 36)
    .background(AControlStyle.insetFill(colorScheme), in: Capsule())
    .overlay {
      Capsule().strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
    }
  }

  private func legacyReasoningPickerButton(width: CGFloat, pickerWidth: CGFloat) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "brain.head.profile")
        .font(.system(size: 13, weight: .semibold))
      Picker("Depth", selection: reasoningSelection) {
        ForEach(reasoningEfforts) { option in
          Text(option.title)
            .tag(option.value)
        }
      }
      .labelsHidden()
      .pickerStyle(.menu)
      .frame(width: pickerWidth)
    }
    .padding(.leading, 12)
    .padding(.trailing, 6)
    .padding(.vertical, 5)
    .frame(width: width)
    .frame(minHeight: 36)
    .background(AControlStyle.insetFill(colorScheme), in: Capsule())
    .overlay {
      Capsule().strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
    }
    .safeHelp("Select Codex reasoning depth")
  }

  private func isPluginSelected(_ item: CodexPluginSnippet) -> Bool {
    selectedPluginSnippets.contains { $0.id == item.id }
  }

  private func togglePluginSnippet(_ item: CodexPluginSnippet) {
    if isPluginSelected(item) {
      selectedPluginSnippets.removeAll { $0.id == item.id }
    } else {
      selectedPluginSnippets.append(item)
    }
  }

  private var pluginMenuTitle: String {
    if selectedPluginSnippets.isEmpty {
      return "Plugins"
    }
    if selectedPluginSnippets.count == 1, let first = selectedPluginSnippets.first {
      return first.title
    }
    return "\(selectedPluginSnippets.count) tools"
  }

  private var pluginCategoryOrder: [String] {
    ["Runtime", "Artifacts", "Research", "Product", "Workflow", "Installed", "Tools"]
  }

  private var pluginMenuCategories: [String] {
    let categories = Set(combinedPluginSnippets.map(\.category))
    return pluginCategoryOrder.filter { categories.contains($0) }
      + categories.filter { !pluginCategoryOrder.contains($0) }.sorted()
  }

  private func plugins(in category: String) -> [CodexPluginSnippet] {
    combinedPluginSnippets.filter { $0.category == category }
  }

  private var combinedPluginSnippets: [CodexPluginSnippet] {
    var seen = Set<String>()
    var result: [CodexPluginSnippet] = []
    for item in model.detectedCodexPluginSnippets + pluginSnippets {
      let key = item.title.lowercased()
      guard !seen.contains(key) else { continue }
      seen.insert(key)
      result.append(item)
    }
    return result
  }
}

struct AttachmentChip: View {
  var attachment: PromptAttachment
  var remove: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: symbol)
        .foregroundStyle(AControlStyle.accentForeground(.purple, colorScheme))
      VStack(alignment: .leading, spacing: 1) {
        Text(attachment.name)
          .lineLimit(1)
        Text(attachment.displaySize)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      Button(action: remove) {
        Image(systemName: "xmark")
          .font(.caption.weight(.bold))
      }
      .buttonStyle(ImmediateFeedbackButtonStyle())
      .foregroundStyle(.secondary)
    }
    .font(.caption.weight(.semibold))
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .background(.thinMaterial, in: Capsule())
    .overlay {
      Capsule().strokeBorder(AControlStyle.accentStroke(.purple, colorScheme), lineWidth: 1)
    }
  }

  @Environment(\.colorScheme) private var colorScheme

  private var symbol: String {
    switch attachment.kind {
    case "image": "photo"
    case "folder": "folder"
    default: "doc"
    }
  }
}

struct ComposerContextChip: View {
  @Environment(\.colorScheme) private var colorScheme
  var title: String
  var symbol: String
  var remove: () -> Void

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: symbol)
        .font(.caption.weight(.semibold))
      Text(title)
        .font(.caption.weight(.semibold))
        .lineLimit(1)
      Button(action: remove) {
        Image(systemName: "xmark")
          .font(.caption2.weight(.bold))
      }
      .buttonStyle(ImmediateFeedbackButtonStyle())
    }
    .foregroundStyle(AControlStyle.accentForeground(.blue, colorScheme))
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .background(AControlStyle.accentFill(.blue, colorScheme), in: Capsule())
    .overlay {
      Capsule().strokeBorder(AControlStyle.accentStroke(.blue, colorScheme), lineWidth: 1)
    }
    .safeHelp("This context will be sent with the prompt without filling the editor.")
  }
}

struct CodexTranscriptCard: View {
  enum TranscriptStyle {
    case codexActivity
    case raw
  }

  @EnvironmentObject private var model: AppModel
  @Environment(\.colorScheme) private var colorScheme
  @State private var scrollSignal = 0
  @State private var followTailSignal = 0
  @State private var transcriptAtBottom = true
  @State private var userHasScrolledAway = false
  @State private var wheelScrollButtonFallback = false
  @State private var scrollButtonSuppressed = false
  @State private var suppressAwayReportsUntil = Date.distantPast
  @State private var recentUserScrollUntil = Date.distantPast
  @State private var transcriptScheme: ColorScheme?
  @State private var transcriptDistanceToBottom: CGFloat = 0
  var text: String
  var sessionID: UUID?
  var scrollRequest = 0
  var isWorking = false
  var workingSince: Date?
  var modelName: String
  var weekly: String
  var reset: String
  var symbol = "sparkles"
  var accent: Color = .purple
  var placeholder = "Codex transcript will appear here."
  var showsWeeklyStatus = true
  var style: TranscriptStyle = .raw
  var refreshTokens: () -> Void

  private var effectiveScheme: ColorScheme {
    transcriptScheme ?? colorScheme
  }

  private var canUseTranscriptActions: Bool {
    !text.trimmed.isEmpty
  }

  private var showScrollToBottomButton: Bool {
    !scrollButtonSuppressed && !transcriptAtBottom
      && (userHasScrolledAway || wheelScrollButtonFallback)
      && transcriptDistanceToBottom > CodexTranscriptTuning.scrollButtonDistance
      && text.trimmed.count > 600
  }

  private var isVisiblyFollowingTail: Bool {
    !showScrollToBottomButton
  }

  private var workingLabel: String {
    guard isWorking else { return "Codex idle" }
    guard let workingSince else { return "Codex running" }
    let seconds = max(0, Int(Date().timeIntervalSince(workingSince)))
    if seconds < 60 {
      return "Working for \(seconds)s"
    }
    return "Working for \(seconds / 60)m \(seconds % 60)s"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: symbol)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(AControlStyle.accentForeground(accent, colorScheme))
        Text("Transcript")
          .font(.system(size: 13, weight: .semibold))
          .lineLimit(1)
        Text(modelName)
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 9)
          .padding(.vertical, 4)
          .background(AControlStyle.insetFill(colorScheme), in: Capsule())
        if isWorking {
          HStack(spacing: 5) {
            Circle()
              .fill(Color.blue)
              .frame(width: 6, height: 6)
            TimelineView(.periodic(from: .now, by: 1)) { _ in
              Text(workingLabel)
            }
          }
          .font(.caption.weight(.bold))
          .foregroundStyle(AControlStyle.accentForeground(.blue, colorScheme))
          .padding(.horizontal, 9)
          .padding(.vertical, 4)
          .background(AControlStyle.accentFill(.blue, colorScheme), in: Capsule())
          .overlay {
            Capsule()
              .strokeBorder(AControlStyle.accentStroke(.blue, colorScheme), lineWidth: 1)
          }
        }
        Spacer(minLength: 8)
        if canUseTranscriptActions {
          TranscriptTailStatePill(
            isAtBottom: isVisiblyFollowingTail,
            isWorking: isWorking,
            colorScheme: colorScheme
          )
        }
        if let label = transcriptActivityLabel {
          Text(label)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(AControlStyle.insetFill(colorScheme), in: Capsule())
        }
        HStack(spacing: 5) {
          transcriptHeaderButton(
            symbol: "arrow.clockwise",
            help: "Refresh transcript"
          ) {
            Task { await model.syncServerCodexHistoryAndRefreshVisibleSession() }
          }
          if canUseTranscriptActions {
            transcriptHeaderButton(
              symbol: "doc.on.doc",
              help: "Copy transcript"
            ) {
              model.copyActiveCodexTranscript()
            }
            transcriptHeaderButton(
              symbol: "folder",
              help: "Open transcript folder"
            ) {
              model.openActiveTranscriptFolder()
            }
          }
        }
        if showsWeeklyStatus {
          Button(action: refreshTokens) {
            HStack(spacing: 6) {
              Image(systemName: "gauge.with.dots.needle.67percent")
              Text("Weekly \(weekly.isEmpty ? "Tap" : weekly)")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(AControlStyle.accentForeground(.cyan, colorScheme))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(AControlStyle.accentFill(.cyan, colorScheme), in: Capsule())
          }
          .buttonStyle(ImmediateFeedbackButtonStyle())
          .safeHelp(reset.isEmpty ? "Update token status" : reset)
        }
      }
      .frame(minHeight: 30)

      ZStack {
        transcriptBody
          .environment(\.colorScheme, effectiveScheme)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .layoutPriority(1)

        TranscriptScrollWheelSniffer {
          guard text.trimmed.count > 600 else { return }
          recentUserScrollUntil = Date().addingTimeInterval(2.0)
          guard Date() >= suppressAwayReportsUntil else { return }
          guard !transcriptAtBottom else {
            wheelScrollButtonFallback = false
            userHasScrolledAway = false
            return
          }
          userHasScrolledAway = true
          wheelScrollButtonFallback = true
        }
        .allowsHitTesting(false)

        CodexFloatingTranscriptControls(
          isDark: effectiveScheme == .dark,
          showScrollButton: showScrollToBottomButton,
          toggleTheme: {
            transcriptScheme = effectiveScheme == .dark ? .light : .dark
          }
        ) {
          wheelScrollButtonFallback = false
          scrollButtonSuppressed = false
          userHasScrolledAway = false
          transcriptAtBottom = true
          transcriptDistanceToBottom = 0
          scrollSignal += 1
        }
      }
      .onChange(of: text) { _, _ in
        guard transcriptAtBottom && !userHasScrolledAway else { return }
        userHasScrolledAway = false
        wheelScrollButtonFallback = false
        DispatchQueue.main.async {
          followTailSignal += 1
        }
      }
      .onChange(of: scrollRequest) { _, _ in
        guard transcriptAtBottom && !userHasScrolledAway else {
          scrollButtonSuppressed = false
          return
        }
        suppressAwayReportsUntil = Date().addingTimeInterval(0.75)
        scrollButtonSuppressed = true
        userHasScrolledAway = false
        wheelScrollButtonFallback = false
        transcriptAtBottom = true
        transcriptDistanceToBottom = 0
        DispatchQueue.main.async {
          scrollSignal += 1
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            transcriptAtBottom = true
            transcriptDistanceToBottom = 0
            scrollButtonSuppressed = false
            scrollSignal += 1
          }
        }
      }
      .onChange(of: sessionID) { _, _ in
        suppressAwayReportsUntil = Date().addingTimeInterval(1.2)
        scrollButtonSuppressed = true
        recentUserScrollUntil = .distantPast
        transcriptAtBottom = true
        transcriptDistanceToBottom = 0
        userHasScrolledAway = false
        wheelScrollButtonFallback = false
        DispatchQueue.main.async {
          scrollSignal += 1
          userHasScrolledAway = false
          wheelScrollButtonFallback = false
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            transcriptAtBottom = true
            transcriptDistanceToBottom = 0
            userHasScrolledAway = false
            wheelScrollButtonFallback = false
            scrollSignal += 1
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            transcriptAtBottom = true
            transcriptDistanceToBottom = 0
            userHasScrolledAway = false
            wheelScrollButtonFallback = false
            scrollSignal += 1
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            scrollButtonSuppressed = false
            if transcriptAtBottom {
              userHasScrolledAway = false
              wheelScrollButtonFallback = false
            }
          }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  @ViewBuilder
  private var transcriptBody: some View {
    switch style {
    case .codexActivity:
      CodexActivityTranscriptView(
        text: text,
        placeholder: placeholder,
        scrollSignal: scrollSignal,
        followTailSignal: followTailSignal,
        userIsReadingHistory: userHasScrolledAway,
        onBottomStateChange: { visible, distance in
          transcriptAtBottom = visible
          transcriptDistanceToBottom = distance
          if visible {
            userHasScrolledAway = false
            wheelScrollButtonFallback = false
          } else if Date() < suppressAwayReportsUntil {
            userHasScrolledAway = false
            wheelScrollButtonFallback = false
          } else if Date() < recentUserScrollUntil {
            userHasScrolledAway = true
          } else {
            wheelScrollButtonFallback = false
          }
        },
        usesPanelChrome: false
      )
    case .raw:
      TranscriptView(
        text: text,
        placeholder: placeholder,
        scrollSignal: scrollSignal,
        followTailSignal: followTailSignal,
        autoScrollsOnTextChange: true,
        onBottomStateChange: { visible in
          transcriptAtBottom = visible
          transcriptDistanceToBottom = visible ? 0 : max(transcriptDistanceToBottom, 320)
          if visible {
            userHasScrolledAway = false
            wheelScrollButtonFallback = false
          } else if Date() < suppressAwayReportsUntil {
            userHasScrolledAway = false
            wheelScrollButtonFallback = false
          } else if Date() < recentUserScrollUntil {
            userHasScrolledAway = true
          } else {
            wheelScrollButtonFallback = false
          }
        }
      )
    }
  }

  private var transcriptActivityLabel: String? {
    if let updated = model.codexTranscriptUpdatedAt {
      return "Updated \(updated.shortStamp)"
    }
    if let checked = model.codexTranscriptCheckedAt {
      return "Checked \(checked.shortStamp)"
    }
    return nil
  }

  private func transcriptHeaderButton(
    symbol: String,
    help: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .frame(width: 26, height: 26)
        .background(AControlStyle.insetFill(colorScheme), in: Circle())
        .overlay {
          Circle().strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
        }
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .accessibilityLabel(Text(help))
    .safeHelp(help)
  }
}

private struct TranscriptTailStatePill: View {
  var isAtBottom: Bool
  var isWorking: Bool
  var colorScheme: ColorScheme

  private var tint: Color {
    if isWorking { return .blue }
    return isAtBottom ? .green : .orange
  }

  private var label: String {
    if isWorking && isAtBottom { return "Live" }
    if isWorking { return "Paused" }
    return isAtBottom ? "Tail" : "Paused"
  }

  var body: some View {
    HStack(spacing: 5) {
      Circle()
        .fill(tint)
        .frame(width: 5, height: 5)
      Text(label)
    }
    .font(.caption2.weight(.bold))
    .foregroundStyle(AControlStyle.accentForeground(tint, colorScheme))
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(AControlStyle.accentFill(tint, colorScheme), in: Capsule())
  }
}

private struct CodexFloatingTranscriptControls: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var themeHovering = false
  var isDark: Bool
  var showScrollButton: Bool
  var toggleTheme: () -> Void
  var scrollToBottom: () -> Void

  var body: some View {
    ZStack {
      ThemeHoverButton(isDark: isDark, action: toggleTheme)
        .environment(\.colorScheme, isDark ? .dark : .light)
        .padding(16)
        .opacity(themeHovering ? 1 : 0)
        .animation(.easeOut(duration: 0.16), value: themeHovering)
        .frame(width: 92, height: 92, alignment: .topTrailing)
        .contentShape(Rectangle())
        .onHover { themeHovering = $0 }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

      TranscriptScrollButton(action: scrollToBottom)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .opacity(showScrollButton ? 1 : 0)
        .allowsHitTesting(showScrollButton)
        .animation(.easeOut(duration: 0.16), value: showScrollButton)
        .safeHelp("Scroll transcript to bottom")
    }
  }
}

private struct TranscriptScrollWheelSniffer: NSViewRepresentable {
  var onScroll: () -> Void

  func makeNSView(context: Context) -> SnifferView {
    let view = SnifferView()
    view.onScroll = onScroll
    return view
  }

  func updateNSView(_ view: SnifferView, context: Context) {
    view.onScroll = onScroll
    view.installMonitorIfNeeded()
  }

  @MainActor
  final class SnifferView: NSView {
    var onScroll: (() -> Void)?
    private var monitor: Any?

    override func hitTest(_ point: NSPoint) -> NSView? {
      nil
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      installMonitorIfNeeded()
    }

    func installMonitorIfNeeded() {
      guard monitor == nil else { return }
      monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
        guard let self, let window = self.window, event.window === window else { return event }
        let point = self.convert(event.locationInWindow, from: nil)
        guard self.bounds.insetBy(dx: -8, dy: -8).contains(point) else { return event }
        DispatchQueue.main.async { [weak self] in
          self?.onScroll?()
        }
        return event
      }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
      if newWindow == nil, let monitor {
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
      }
      super.viewWillMove(toWindow: newWindow)
    }
  }
}

struct CodexActivityTranscriptView: View {
  @Environment(\.colorScheme) private var colorScheme
  var text: String
  var placeholder: String
  var scrollSignal: Int
  var followTailSignal: Int
  var userIsReadingHistory = false
  var onBottomStateChange: ((Bool, CGFloat) -> Void)?
  var usesPanelChrome = true
  @State private var isAtBottom = true
  @State private var parsedItems: [CodexActivityItem] = []
  @State private var expandedTextIDs: Set<String> = []

  private var parseKey: String {
    let source = hasTranscriptText ? text : placeholder
    return
      "\(hasTranscriptText ? "transcript" : "placeholder"):\(source.count):\(source.prefix(160)):\(source.suffix(512))"
  }

  private var hasTranscriptText: Bool {
    !text.trimmed.isEmpty
  }

  private var accessibilitySummary: String {
    let visibleText =
      parsedItems
      .suffix(6)
      .map { item in
        [item.kind.roleLabel, item.title, item.detail]
          .map(\.trimmed)
          .filter { !$0.isEmpty }
          .joined(separator: " ")
      }
      .filter { !$0.isEmpty }
      .joined(separator: "\n")
    if visibleText.isEmpty {
      return hasTranscriptText ? String(text.suffix(900)) : placeholder
    }
    return String(visibleText.suffix(900))
  }

  private var displayItems: [CodexActivityItem] {
    if !parsedItems.isEmpty {
      return parsedItems
    }
    return [
      CodexActivityItem(
        kind: .placeholder,
        title: hasTranscriptText ? "Refreshing transcript..." : placeholder,
        detail: "",
        badge: nil
      )
    ]
  }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 9) {
          ForEach(displayItems) { item in
            CodexActivityRow(item: item, expandedTextIDs: $expandedTextIDs)
              .id(item.id)
          }
          Color.clear
            .frame(height: CodexTranscriptTuning.bottomSpacerHeight)
            .id("codex-bottom")
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
      }
      .coordinateSpace(name: "codexActivityTranscript")
      .background {
        if usesPanelChrome {
          RoundedRectangle(cornerRadius: AControlStyle.insetRadius, style: .continuous)
            .fill(AControlStyle.transcriptFill(colorScheme))
        }
      }
      .overlay {
        if usesPanelChrome {
          RoundedRectangle(cornerRadius: AControlStyle.insetRadius, style: .continuous)
            .strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text("Codex transcript"))
      .accessibilityValue(Text(accessibilitySummary))
      .overlay {
        CodexScrollPositionObserver(
          isAtBottom: $isAtBottom,
          tolerance: CodexTranscriptTuning.bottomTolerance,
          scrollSignal: scrollSignal
        ) { visible, distance in
          onBottomStateChange?(visible, distance)
        }
        .allowsHitTesting(false)
      }
      .shadow(
        color: usesPanelChrome ? AControlStyle.softShadow(colorScheme) : .clear,
        radius: usesPanelChrome ? 8 : 0,
        x: 0,
        y: usesPanelChrome ? 4 : 0
      )
      .onChange(of: scrollSignal) { _, _ in
        scrollToBottom(proxy, force: true, notify: true, extraDelays: [0.08])
      }
      .onChange(of: followTailSignal) { _, _ in
        DispatchQueue.main.async {
          scrollToBottom(proxy, force: false, extraDelays: [0.06])
        }
      }
      .onAppear {
        DispatchQueue.main.async {
          scrollToBottom(proxy, force: true, extraDelays: [0.05, 0.18])
        }
      }
      .task(id: parseKey) {
        try? await Task.sleep(nanoseconds: 20_000_000)
        guard !Task.isCancelled else { return }
        let source = hasTranscriptText ? text : placeholder
        let isPlaceholder = !hasTranscriptText
        let parsed = await Task.detached(priority: .userInitiated) {
          CodexActivityParser.items(from: source, isPlaceholder: isPlaceholder)
        }.value
        guard !Task.isCancelled else { return }
        let nextItems = parsed.enumerated().map { index, item in
          item.withStableID(index: index)
        }
        let shouldKeepPinned = canFollowTail
        parsedItems = nextItems
        if shouldKeepPinned {
          DispatchQueue.main.async {
            scrollToBottom(proxy, force: false, extraDelays: [0.06])
          }
        }
      }
    }
  }

  private var canFollowTail: Bool {
    !userIsReadingHistory && isAtBottom
  }

  private func scrollToBottom(
    _ proxy: ScrollViewProxy,
    force: Bool,
    notify: Bool = false,
    extraDelays: [TimeInterval] = []
  ) {
    guard force || canFollowTail else { return }
    proxy.scrollTo("codex-bottom", anchor: .bottom)
    if notify {
      isAtBottom = true
      onBottomStateChange?(true, 0)
    }
    for delay in extraDelays {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        guard force || canFollowTail else { return }
        proxy.scrollTo("codex-bottom", anchor: .bottom)
        if notify {
          onBottomStateChange?(true, 0)
        }
      }
    }
  }
}

private struct CodexScrollPositionObserver: NSViewRepresentable {
  @Binding var isAtBottom: Bool
  var tolerance: CGFloat
  var scrollSignal: Int
  var onBottomStateChange: (Bool, CGFloat) -> Void

  func makeNSView(context: Context) -> ObserverView {
    let view = ObserverView()
    view.tolerance = tolerance
    view.lastScrollSignal = scrollSignal
    view.onBottomStateChange = { visible, distance in
      if isAtBottom != visible {
        isAtBottom = visible
      }
      onBottomStateChange(visible, distance)
    }
    return view
  }

  func updateNSView(_ view: ObserverView, context: Context) {
    view.tolerance = tolerance
    view.onBottomStateChange = { visible, distance in
      if isAtBottom != visible {
        isAtBottom = visible
      }
      onBottomStateChange(visible, distance)
    }
    DispatchQueue.main.async {
      view.attachIfNeeded()
      if view.lastScrollSignal != scrollSignal {
        view.lastScrollSignal = scrollSignal
        view.scrollToBottom()
      }
      view.report()
    }
  }

  @MainActor
  final class ObserverView: NSView {
    var tolerance: CGFloat = 64
    var lastScrollSignal = 0
    var onBottomStateChange: ((Bool, CGFloat) -> Void)?
    private weak var scrollView: NSScrollView?
    private var lastValue: Bool?
    private var lastDistance: CGFloat = -1

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      DispatchQueue.main.async { [weak self] in
        self?.attachIfNeeded()
        self?.report(force: true)
      }
    }

    func attachIfNeeded() {
      if scrollView != nil { return }
      if let scroll = enclosingScrollView {
        attach(to: scroll)
        return
      }
      var candidate = superview
      while let view = candidate {
        if let scroll = view as? NSScrollView {
          attach(to: scroll)
          break
        }
        candidate = view.superview
      }
      if scrollView == nil, let contentView = window?.contentView,
        let scroll = overlappingScrollView(in: contentView)
      {
        attach(to: scroll)
      }
    }

    private func attach(to scroll: NSScrollView) {
      scrollView = scroll
      scroll.contentView.postsBoundsChangedNotifications = true
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(boundsDidChange),
        name: NSView.boundsDidChangeNotification,
        object: scroll.contentView
      )
    }

    private func overlappingScrollView(in root: NSView) -> NSScrollView? {
      let targetFrame = convert(bounds, to: nil)
      let targetCenter = NSPoint(x: targetFrame.midX, y: targetFrame.midY)
      var bestScrollView: NSScrollView?
      var bestScore = CGFloat.greatestFiniteMagnitude

      func visit(_ view: NSView) {
        if let scroll = view as? NSScrollView {
          let frame = scroll.convert(scroll.bounds, to: nil)
          let intersection = targetFrame.intersection(frame)
          if !intersection.isNull {
            let area = intersection.width * intersection.height
            let frameArea = max(1, frame.width * frame.height)
            let score =
              (frame.contains(targetCenter) ? 0 : 1_000_000_000)
              + frameArea - area
            if score < bestScore {
              bestScore = score
              bestScrollView = scroll
            }
          }
        }
        for subview in view.subviews {
          visit(subview)
        }
      }

      visit(root)
      return bestScrollView
    }

    func report(force: Bool = false) {
      guard let scrollView, let documentView = scrollView.documentView else { return }
      documentView.layoutSubtreeIfNeeded()
      scrollView.contentView.layoutSubtreeIfNeeded()
      let visibleRect = scrollView.contentView.documentVisibleRect
      let distance =
        documentView.isFlipped
        ? max(0, documentView.bounds.maxY - visibleRect.maxY)
        : max(0, visibleRect.minY - documentView.bounds.minY)
      let visible =
        documentView.bounds.height <= scrollView.contentView.bounds.height + tolerance
        || distance <= tolerance
      guard force || lastValue != visible || abs(lastDistance - distance) > 8 else { return }
      lastValue = visible
      lastDistance = distance
      onBottomStateChange?(visible, distance)
    }

    func scrollToBottom() {
      guard let scrollView, let documentView = scrollView.documentView else { return }
      documentView.layoutSubtreeIfNeeded()
      scrollView.contentView.layoutSubtreeIfNeeded()
      let y =
        documentView.isFlipped
        ? max(0, documentView.bounds.maxY - scrollView.contentView.bounds.height)
        : documentView.bounds.minY
      scrollView.contentView.scroll(to: NSPoint(x: 0, y: y))
      scrollView.reflectScrolledClipView(scrollView.contentView)
      report(force: true)
    }

    @objc private func boundsDidChange() {
      report()
    }
  }
}

private struct CodexActivityRow: View {
  @Environment(\.colorScheme) private var colorScheme
  @EnvironmentObject private var model: AppModel
  var item: CodexActivityItem
  @Binding var expandedTextIDs: Set<String>

  var body: some View {
    Group {
      if item.kind == .prompt {
        promptBubble
      } else if item.kind.isTimelineEvent {
        timelineEventLine
      } else {
        codexLine
      }
    }
    .textSelection(.enabled)
  }

  private var promptBubble: some View {
    HStack(alignment: .top, spacing: 0) {
      Spacer(minLength: 96)
      VStack(alignment: .leading, spacing: 7) {
        HStack(spacing: 6) {
          Image(systemName: item.kind.symbol)
            .font(.system(size: 10.5, weight: .bold))
          Text(item.kind.roleLabel)
            .font(.caption2.weight(.bold))
        }
        .foregroundStyle(AControlStyle.accentForeground(item.kind.tint, colorScheme))

        ExpandableCodexTextWithInlineFiles(
          expansionID: "\(item.id)-prompt",
          text: narrativeText,
          font: .system(size: 12.2, weight: .regular),
          color: Color.primary.opacity(0.86),
          collapsedLineLimit: 8,
          fileReferences: item.fileReferences,
          expandedTextIDs: $expandedTextIDs
        ) { reference in
          preview(reference, openingPanel: true)
        } open: { reference in
          preview(reference, openingPanel: true)
        }
      }
      .padding(.horizontal, 15)
      .padding(.vertical, 10)
      .frame(maxWidth: 920, alignment: .leading)
      .background(
        item.kind == .steer
          ? AnyShapeStyle(AControlStyle.accentFill(item.kind.tint, colorScheme).opacity(0.56))
          : AnyShapeStyle(Color.primary.opacity(colorScheme == .dark ? 0.075 : 0.055)),
        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
      )
      .overlay {
        if item.kind == .steer {
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(AControlStyle.accentStroke(item.kind.tint, colorScheme), lineWidth: 1)
        }
      }
    }
    .padding(.vertical, 8)
  }

  private var codexLine: some View {
    HStack(alignment: .top, spacing: 11) {
      Image(systemName: item.kind.symbol)
        .font(.system(size: item.kind == .result ? 12 : 13, weight: .semibold))
        .foregroundStyle(AControlStyle.accentForeground(item.kind.tint, colorScheme))
        .frame(width: 22, height: 22)
        .background {
          if item.kind != .result {
            Circle().fill(AControlStyle.accentFill(item.kind.tint, colorScheme))
          }
        }
      content
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, item.kind.isPrimaryMessage ? 10 : 0)
    .padding(.vertical, item.kind.isPrimaryMessage ? 8 : 2)
    .background {
      if item.kind.isPrimaryMessage {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(AControlStyle.accentFill(item.kind.tint, colorScheme).opacity(0.62))
      }
    }
    .overlay {
      if item.kind == .working || item.kind == .goal {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .strokeBorder(AControlStyle.accentStroke(.blue, colorScheme), lineWidth: 1)
      }
    }
  }

  private var timelineEventLine: some View {
    HStack(alignment: .top, spacing: 11) {
      Image(systemName: item.kind.symbol)
        .font(.system(size: 12.5, weight: .semibold))
        .foregroundStyle(.secondary.opacity(0.72))
        .frame(width: 22, height: 22)

      VStack(alignment: .leading, spacing: 6) {
        Text(timelineEventTitle)
          .font(.system(size: 13.2, weight: .medium))
          .foregroundStyle(.secondary.opacity(0.82))
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)

        if !timelineEventDetail.isEmpty {
          ExpandableCodexTextWithInlineFiles(
            expansionID: "\(item.id)-event-detail",
            text: timelineEventDetail,
            font: .system(size: 12.0, weight: .regular, design: item.kind.prefersMonospace ? .monospaced : .default),
            color: .secondary.opacity(0.86),
            collapsedLineLimit: item.kind.prefersMonospace ? 8 : 6,
            fileReferences: item.fileReferences,
            expandedTextIDs: $expandedTextIDs
          ) { reference in
            preview(reference, openingPanel: true)
          } open: { reference in
            preview(reference, openingPanel: true)
          }
        }

        fileReferenceSection
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, item.kind == .steer ? 7 : 4)
  }

  @ViewBuilder
  private var content: some View {
    VStack(alignment: .leading, spacing: 8) {
      roleHeader
      if item.kind.usesNarrativeStyle || item.kind == .prompt {
        ExpandableCodexTextWithInlineFiles(
          expansionID: "\(item.id)-narrative",
          text: narrativeText,
          font: .system(
            size: item.kind == .result ? 12.0 : 12.2, weight: .regular,
            design: item.kind.prefersMonospace ? .monospaced : .default),
          color: item.kind == .placeholder ? .secondary : Color.primary.opacity(0.84),
          collapsedLineLimit: item.kind == .result ? 10 : 12,
          fileReferences: item.fileReferences,
          expandedTextIDs: $expandedTextIDs
        ) { reference in
          preview(reference, openingPanel: true)
        } open: { reference in
          preview(reference, openingPanel: true)
        }
      } else {
        HStack(spacing: 7) {
          Text(item.title)
            .font(.system(size: 12.0, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
          if let badge = item.badge {
            badgeCapsule(badge)
          }
          Spacer(minLength: 0)
        }
        if !item.detail.isEmpty {
          ExpandableCodexTextWithInlineFiles(
            expansionID: "\(item.id)-detail",
            text: item.detail,
            font: .system(
              size: 11.4, weight: .regular,
              design: item.kind.prefersMonospace ? .monospaced : .default),
            color: .secondary,
            collapsedLineLimit: item.kind.prefersMonospace ? 10 : 8,
            fileReferences: item.fileReferences,
            expandedTextIDs: $expandedTextIDs
          ) { reference in
            preview(reference, openingPanel: true)
          } open: { reference in
            preview(reference, openingPanel: true)
          }
        }
      }
      if !hasInlineFileHeading {
        fileReferenceSection
      }
    }
  }

  @ViewBuilder
  private var fileReferenceSection: some View {
    if !item.fileReferences.isEmpty {
      let imageReferences = item.fileReferences.filter(\.isImage)
      if !imageReferences.isEmpty {
        VStack(alignment: .leading, spacing: 7) {
          ForEach(imageReferences.prefix(4)) { reference in
            CodexInlineImagePreview(reference: reference, context: fileReferenceContext) {
              preview(reference, openingPanel: true)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      HStack(spacing: 6) {
        Image(systemName: "paperclip")
          .font(.caption2.weight(.bold))
        Text("Files")
          .font(.caption2.weight(.bold))
      }
      .foregroundStyle(.secondary)
      FlowLayout(spacing: 7) {
        ForEach(item.fileReferences) { reference in
          Button {
            preview(reference, openingPanel: true)
          } label: {
            CodexFileReferenceChip(reference: reference)
          }
          .buttonStyle(ImmediateFeedbackButtonStyle())
          .safeHelp("Preview \(reference.path)")
          .simultaneousGesture(
            TapGesture(count: 2)
              .onEnded {
                preview(reference, openingPanel: true)
              }
          )
          .contextMenu {
            Button("Open Preview Panel") {
              preview(reference, openingPanel: true)
            }
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func preview(_ reference: CodexInlineFileReference, openingPanel: Bool) {
    let artifact = artifact(for: reference)
    Task {
      if openingPanel {
        await model.previewCodexArtifactInPanel(artifact)
      } else {
        await model.previewCodexArtifact(artifact)
      }
    }
  }

  private func artifact(for reference: CodexInlineFileReference) -> CodexArtifact {
    let sourceContext = [item.title, item.detail]
      .map(\.trimmed)
      .filter { !$0.isEmpty }
      .joined(separator: "\n")
    return CodexArtifact(path: reference.path, kind: .other, sourceLine: sourceContext)
  }

  private var roleHeader: some View {
    Group {
      if item.kind == .result && item.badge == nil {
        EmptyView()
      } else {
        HStack(spacing: 7) {
          Text(item.kind.roleLabel)
            .font(.caption2.weight(.bold))
            .foregroundStyle(AControlStyle.accentForeground(item.kind.tint, colorScheme))
          if let badge = item.badge, badge != item.kind.roleLabel {
            badgeCapsule(badge)
          }
          Spacer(minLength: 0)
        }
      }
    }
  }

  private func badgeCapsule(_ badge: String) -> some View {
    Text(badge)
      .font(.caption2.weight(.bold))
      .foregroundStyle(AControlStyle.accentForeground(item.kind.tint, colorScheme))
      .padding(.horizontal, 7)
      .padding(.vertical, 3)
      .background(AControlStyle.accentFill(item.kind.tint, colorScheme), in: Capsule())
  }

  private var narrativeText: String {
    [item.title, item.detail]
      .map(\.trimmed)
      .filter { !$0.isEmpty }
      .joined(separator: "\n")
  }

  private var fileReferenceContext: String {
    [item.title, item.detail]
      .map(\.trimmed)
      .filter { !$0.isEmpty }
      .joined(separator: "\n")
  }

  private var timelineEventTitle: String {
    let raw: String
    switch item.kind {
    case .ran:
      raw = "Ran \(strippingActivityPrefix(item.title, prefixes: ["Ran", "• Ran"]))"
    case .explored:
      raw = humanizedReadTitle(from: item.title)
    case .edited:
      raw = "Edited \(strippingActivityPrefix(item.title, prefixes: ["Edited", "• Edited"]))"
    case .called:
      raw = "Called \(strippingActivityPrefix(item.title, prefixes: ["Called", "• Called"]))"
    case .waited:
      raw = "Waited \(strippingActivityPrefix(item.title, prefixes: ["Waited", "• Waited"]))"
    case .steer:
      raw = "Steered conversation"
    default:
      raw = item.title
    }
    return raw
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmed
  }

  private var timelineEventDetail: String {
    let value = item.kind == .steer ? narrativeText : item.detail
    let trimmed = value.trimmed
    if item.kind == .steer, trimmed.localizedCaseInsensitiveCompare("Steered conversation") == .orderedSame {
      return ""
    }
    return trimmed
  }

  private func strippingActivityPrefix(_ value: String, prefixes: [String]) -> String {
    var output = value.trimmed
    for prefix in prefixes {
      if output.hasPrefix(prefix) {
        output = String(output.dropFirst(prefix.count)).trimmed
      }
    }
    return output.isEmpty ? value.trimmed : output
  }

  private func humanizedReadTitle(from value: String) -> String {
    let command = strippingActivityPrefix(value, prefixes: ["Explored", "• Explored"])
    let lower = command.lowercased()
    if lower.hasPrefix("sed ") || lower.hasPrefix("cat ") || lower.hasPrefix("tail ")
      || lower.hasPrefix("head ")
    {
      return "Read \(bestPath(in: command) ?? command)"
    }
    if lower.hasPrefix("rg ") || lower.hasPrefix("grep ") {
      return "Searched \(bestPath(in: command) ?? command)"
    }
    if lower.hasPrefix("ls ") || lower.hasPrefix("find ") {
      return "Looked at \(bestPath(in: command) ?? command)"
    }
    return "Looked at \(command)"
  }

  private func bestPath(in command: String) -> String? {
    let tokens = command
      .split(separator: " ")
      .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
      .filter { !$0.isEmpty }
    return tokens.last { token in
      token.contains("/")
        || token.range(of: #"\.[A-Za-z0-9]{1,8}$"#, options: .regularExpression) != nil
    }
  }

  private var hasInlineFileHeading: Bool {
    guard !item.fileReferences.isEmpty else { return false }
    return narrativeText.components(separatedBy: .newlines).contains {
      CodexInlineFileShortcutLine.shouldAttachFiles(to: $0)
    }
  }
}

private struct ExpandableCodexText: View {
  var expansionID: String
  var text: String
  var font: Font
  var color: Color
  var collapsedLineLimit: Int
  @Binding var expandedTextIDs: Set<String>

  private var trimmedText: String {
    text.trimmed
  }

  private var shouldOfferExpansion: Bool {
    guard !trimmedText.isEmpty else { return false }
    let newlineCount = trimmedText.reduce(0) { partial, character in
      partial + (character == "\n" ? 1 : 0)
    }
    return trimmedText.count > collapsedLineLimit * 92 || newlineCount >= collapsedLineLimit
  }

  private var isExpanded: Bool {
    expandedTextIDs.contains(expansionID)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      textBody
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.enabled)
        .contentShape(Rectangle())
        .onTapGesture {
          guard shouldOfferExpansion, !isExpanded else { return }
          withAnimation(.easeOut(duration: 0.16)) {
            _ = expandedTextIDs.insert(expansionID)
          }
        }

      if shouldOfferExpansion {
        Button {
          withAnimation(.easeOut(duration: 0.16)) {
            if isExpanded {
              _ = expandedTextIDs.remove(expansionID)
            } else {
              _ = expandedTextIDs.insert(expansionID)
            }
          }
        } label: {
          Text(isExpanded ? "Show less" : "Show more")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.secondary.opacity(0.08), in: Capsule())
        }
        .buttonStyle(ImmediateFeedbackButtonStyle())
        .safeHelp(isExpanded ? "Collapse transcript text" : "Expand transcript text")
      }
    }
  }

  @ViewBuilder
  private var textBody: some View {
    let base =
      Text(trimmedText)
      .font(font)
      .foregroundStyle(color)
      .lineSpacing(2)

    if isExpanded {
      base
        .lineLimit(nil)
        .textSelection(.enabled)
    } else {
      base
        .lineLimit(collapsedLineLimit)
        .textSelection(.enabled)
    }
  }
}

private struct ExpandableCodexTextWithInlineFiles: View {
  var expansionID: String
  var text: String
  var font: Font
  var color: Color
  var collapsedLineLimit: Int
  var fileReferences: [CodexInlineFileReference]
  @Binding var expandedTextIDs: Set<String>
  var preview: (CodexInlineFileReference) -> Void
  var open: (CodexInlineFileReference) -> Void

  private var trimmedText: String {
    text.trimmed
  }

  private var lines: [String] {
    trimmedText.components(separatedBy: .newlines)
      .map(\.trimmed)
      .filter { !$0.isEmpty }
  }

  private var shouldOfferExpansion: Bool {
    guard !trimmedText.isEmpty else { return false }
    return trimmedText.count > collapsedLineLimit * 92 || lines.count > collapsedLineLimit
  }

  private var isExpanded: Bool {
    expandedTextIDs.contains(expansionID)
  }

  private var visibleLines: [String] {
    if isExpanded || !shouldOfferExpansion {
      return lines
    }
    return Array(lines.prefix(collapsedLineLimit))
  }

  private var hasInlineFileHeading: Bool {
    lines.contains { CodexInlineFileShortcutLine.shouldAttachFiles(to: $0) }
  }

  var body: some View {
    if fileReferences.isEmpty || !hasInlineFileHeading {
      ExpandableCodexText(
        expansionID: expansionID,
        text: text,
        font: font,
        color: color,
        collapsedLineLimit: collapsedLineLimit,
        expandedTextIDs: $expandedTextIDs
      )
    } else {
      VStack(alignment: .leading, spacing: 5) {
        ForEach(Array(visibleLines.enumerated()), id: \.offset) { _, line in
          CodexInlineFileShortcutLine(
            line: line,
            font: font,
            color: color,
            references: fileReferences,
            preview: preview,
            open: open
          )
        }

        if shouldOfferExpansion {
          Button {
            withAnimation(.easeOut(duration: 0.16)) {
              if isExpanded {
                _ = expandedTextIDs.remove(expansionID)
              } else {
                _ = expandedTextIDs.insert(expansionID)
              }
            }
          } label: {
            Text(isExpanded ? "Show less" : "Show more")
              .font(.caption2.weight(.bold))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(.secondary.opacity(0.08), in: Capsule())
          }
          .buttonStyle(ImmediateFeedbackButtonStyle())
          .safeHelp(isExpanded ? "Collapse transcript text" : "Expand transcript text")
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .textSelection(.enabled)
    }
  }
}

private struct CodexInlineFileShortcutLine: View {
  var line: String
  var font: Font
  var color: Color
  var references: [CodexInlineFileReference]
  var preview: (CodexInlineFileReference) -> Void
  var open: (CodexInlineFileReference) -> Void

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 7) {
      Text(line)
        .font(font)
        .foregroundStyle(color)
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.enabled)

      if Self.shouldAttachFiles(to: line) {
        FlowLayout(spacing: 5) {
          ForEach(references.prefix(12)) { reference in
            Button {
              preview(reference)
            } label: {
              CodexInlineFileMiniChip(reference: reference)
            }
            .buttonStyle(ImmediateFeedbackButtonStyle())
            .safeHelp("Preview \(reference.path)")
            .simultaneousGesture(
              TapGesture(count: 2)
                .onEnded {
                  preview(reference)
                }
            )
          }
        }
        .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  static func shouldAttachFiles(to value: String) -> Bool {
    let line = value.trimmed.lowercased()
    guard line.hasSuffix(":") || line.hasSuffix("：") else { return false }
    let signals = [
      "file", "files", "artifact", "artifacts", "output", "outputs", "code", "report",
      "figure", "figures", "generated", "modified", "created", "updated", "verification",
      "validation", "검증", "파일", "산출", "코드", "보고서", "그림", "생성", "수정", "갱신",
    ]
    return signals.contains { line.contains($0) }
  }
}

private struct CodexInlineFileMiniChip: View {
  @Environment(\.colorScheme) private var colorScheme
  var reference: CodexInlineFileReference

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: symbol)
        .font(.system(size: 9.5, weight: .bold))
      Text(reference.displayName)
        .font(.caption2.weight(.bold))
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .foregroundStyle(AControlStyle.accentForeground(.teal, colorScheme))
    .padding(.horizontal, 6)
    .frame(width: 118, height: 20)
    .background(AControlStyle.accentFill(.teal, colorScheme), in: Capsule())
    .overlay {
      Capsule()
        .strokeBorder(AControlStyle.accentStroke(.teal, colorScheme), lineWidth: 1)
    }
  }

  private var symbol: String {
    let lower = reference.path.lowercased()
    if lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg")
      || lower.hasSuffix(".webp") || lower.hasSuffix(".gif") || lower.hasSuffix(".heic")
    {
      return "photo"
    }
    if lower.hasSuffix(".pdf") {
      return "doc.richtext"
    }
    return "doc.text"
  }
}

private struct CodexActivityItem: Identifiable, Sendable {
  var id = ""
  var kind: CodexActivityKind
  var title: String
  var detail: String
  var badge: String?
  var fileReferences: [CodexInlineFileReference] = []

  func withStableID(index: Int) -> CodexActivityItem {
    var copy = self
    let fileKey = fileReferences.map(\.path).joined(separator: "|")
    let contentKey = "\(kind.roleLabel)|\(title)|\(detail)|\(badge ?? "")|\(fileKey)"
    copy.id = "\(index)-\(contentKey.hashValue)"
    return copy
  }
}

private struct CodexInlineFileReference: Identifiable, Hashable, Sendable {
  var path: String
  var label: String

  var id: String { path }

  var displayName: String {
    let trimmedLabel = label.trimmed
    if !trimmedLabel.isEmpty, trimmedLabel.count <= 34 {
      return trimmedLabel
    }
    let name = URL(fileURLWithPath: path).lastPathComponent
    return name.isEmpty ? path : name
  }

  var displayPath: String {
    path.replacingOccurrences(
      of: #"^/Users/[^/]+"#,
      with: "~",
      options: .regularExpression)
  }

  var isImage: Bool {
    let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
    return ["png", "jpg", "jpeg", "webp", "gif", "heic", "tif", "tiff", "bmp"].contains(ext)
  }
}

private struct CodexInlineImagePreview: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.colorScheme) private var colorScheme
  var reference: CodexInlineFileReference
  var context: String
  var open: () -> Void
  @State private var requested = false

  private var previewURL: URL? {
    model.codexInlineImagePreviewURLs[reference.path]
  }

  var body: some View {
    Button(action: open) {
      ZStack {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.045))
        if let previewURL, let image = NSImage(contentsOf: previewURL) {
          Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
          VStack(spacing: 7) {
            ProgressView()
              .controlSize(.small)
            Text(reference.displayName)
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }
          .padding(.horizontal, 12)
        }
      }
      .frame(maxWidth: 430)
      .frame(minHeight: 128, idealHeight: 180, maxHeight: 220)
      .overlay {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
      }
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .safeHelp("Open \(reference.path)")
    .task(id: reference.path) {
      guard !requested else { return }
      requested = true
      await model.ensureCodexInlineImagePreview(for: reference.path, context: context)
    }
  }
}

private struct CodexFileReferenceChip: View {
  @Environment(\.colorScheme) private var colorScheme
  var reference: CodexInlineFileReference

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: symbol)
        .font(.system(size: 11.5, weight: .semibold))
      Text(reference.displayName)
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .foregroundStyle(AControlStyle.accentForeground(.teal, colorScheme))
    .padding(.horizontal, 9)
    .padding(.vertical, 6)
    .frame(maxWidth: 182, alignment: .leading)
    .background(AControlStyle.accentFill(.teal, colorScheme), in: Capsule())
    .overlay {
      Capsule()
        .strokeBorder(AControlStyle.accentStroke(.teal, colorScheme), lineWidth: 1)
    }
  }

  private var symbol: String {
    let lower = reference.path.lowercased()
    if lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg")
      || lower.hasSuffix(".webp") || lower.hasSuffix(".gif") || lower.hasSuffix(".heic")
    {
      return "photo"
    }
    if lower.hasSuffix(".pdf") {
      return "doc.richtext"
    }
    return "doc.text"
  }
}

private enum CodexActivityKind: Sendable, Equatable {
  case prompt
  case ran
  case explored
  case edited
  case called
  case waited
  case steer
  case queued
  case goal
  case working
  case result
  case placeholder

  var symbol: String {
    switch self {
    case .prompt: "chevron.right"
    case .ran: "terminal"
    case .explored: "magnifyingglass"
    case .edited: "pencil"
    case .called: "cursorarrow.click"
    case .waited: "clock"
    case .steer: "arrow.triangle.turn.up.right.diamond"
    case .queued: "tray.and.arrow.down"
    case .goal: "target"
    case .working: "progress.indicator"
    case .result: "sparkles"
    case .placeholder: "text.bubble"
    }
  }

  var tint: Color {
    switch self {
    case .prompt: .purple
    case .ran: .cyan
    case .explored: .blue
    case .edited: .green
    case .called: .orange
    case .waited: .gray
    case .steer: .purple
    case .queued: .orange
    case .goal: .blue
    case .working: .blue
    case .result: .blue
    case .placeholder: .gray
    }
  }

  var roleLabel: String {
    switch self {
    case .prompt: "Prompt"
    case .ran: "Run"
    case .explored: "Read"
    case .edited: "Edit"
    case .called: "Tool"
    case .waited: "Wait"
    case .steer: "Steer"
    case .queued: "Queued"
    case .goal: "Goal"
    case .working: "Working"
    case .result: "Codex"
    case .placeholder: "Transcript"
    }
  }

  var isPrimaryMessage: Bool {
    switch self {
    case .prompt, .queued, .working, .goal:
      true
    default:
      false
    }
  }

  var prefersMonospace: Bool {
    switch self {
    case .ran, .called, .waited:
      true
    default:
      false
    }
  }

  var usesNarrativeStyle: Bool {
    switch self {
    case .result, .placeholder, .steer, .goal:
      true
    default:
      false
    }
  }

  var isTimelineEvent: Bool {
    switch self {
    case .ran, .explored, .edited, .called, .waited, .steer:
      true
    default:
      false
    }
  }
}

private enum CodexActivityParser {
  static func items(from rawText: String, isPlaceholder: Bool) -> [CodexActivityItem] {
    if isPlaceholder {
      return [CodexActivityItem(kind: .placeholder, title: rawText, detail: "", badge: nil)]
    }
    let cleaned = clean(recentSlice(rawText))
    var groups: [[String]] = []
    var current: [String] = []
    for line in cleaned.components(separatedBy: .newlines) {
      let trimmed = normalizedLine(line)
      guard !trimmed.isEmpty, !isBoilerplateLine(trimmed) else { continue }
      if startsNewGroup(trimmed), !current.isEmpty {
        groups.append(current)
        current = [trimmed]
      } else {
        current.append(trimmed)
      }
    }
    if !current.isEmpty {
      groups.append(current)
    }
    let parsed = compactNoisyRepeats(
      removePromptEchoes(
        from: groups.compactMap(parseGroup).filter { !isGeneratedResearchActivity($0) }
      )
    )
    if !parsed.isEmpty {
      return Array(parsed.suffix(120))
    }
    let fallback = fallbackItems(from: cleaned)
    if !fallback.isEmpty {
      return fallback
    }
    return rawFallbackItems(from: cleaned)
  }

  private static func recentSlice(_ value: String) -> String {
    guard value.count > 180_000 else { return value }
    return String(value.suffix(180_000))
  }

  private static func normalizedLine(_ line: String) -> String {
    var output =
      line
      .trimmingCharacters(in: .whitespaces)
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    while let first = output.first, "│┃║".contains(first) {
      output.removeFirst()
      output = output.trimmingCharacters(in: .whitespaces)
    }
    while let last = output.last, "│┃║".contains(last) {
      output.removeLast()
      output = output.trimmingCharacters(in: .whitespaces)
    }
    return output
  }

  private static func isBoilerplateLine(_ line: String) -> Bool {
    let boxCharacters = CharacterSet(charactersIn: "╭╮╰╯─━═│┃║┌┐└┘┬┴┤├┼┄┈╌╍╎╏ ")
    if !line.isEmpty, line.unicodeScalars.allSatisfy({ boxCharacters.contains($0) }) {
      return true
    }
    let lower = line.lowercased()
    let content =
      line
      .replacingOccurrences(of: #"^[›>•]\s*"#, with: "", options: .regularExpression)
      .trimmed
      .lowercased()
    return lower.contains("openai codex") || lower.contains("development features are incomplete")
      || lower.hasPrefix("model:") || lower.hasPrefix("directory:") || lower.hasPrefix("tip:")
      || lower == "/status" || lower.hasPrefix("visit https://chatgpt.com/codex/settings/usage")
      || lower.hasPrefix("information on rate limits") || lower.hasPrefix("permissions:")
      || lower.hasPrefix("agents.md:") || lower.hasPrefix("account:")
      || lower.hasPrefix("collaboration mode:") || lower.hasPrefix("context window:")
      || lower.hasPrefix("5h limit:") || lower.hasPrefix("weekly limit:")
      || lower.hasPrefix("gpt-5.3-codex-spark limit:") || lower.contains("/.codex/config.toml")
      || lower == "prompt"
      || lower.hasPrefix("warning:") || lower.hasPrefix("⚠")
      || lower.hasPrefix("under-development features")
      || lower.contains("under-development features enabled")
      || lower.contains("suppress_unstable_features_warning")
      || lower.hasPrefix("codex_history_id:") || lower.contains("resumed codex history")
      || lower.hasPrefix("chunk id:") || lower.hasPrefix("wall time:")
      || lower.hasPrefix("process exited with code") || lower.hasPrefix("original token count:")
      || lower.hasPrefix("process running with session id")
      || lower.range(of: #"^\d+\s+\d+\s+[a-z+]+\s+/"#, options: .regularExpression) != nil
      || lower == "output:" || lower.hasPrefix("output: ")
      || content.hasPrefix("find and fix a bug in @filename")
      || content.hasPrefix("explain this codebase")
      || (content.hasPrefix("gpt-") && content.contains(" · ") && content.contains("~"))
      || isPatchDetailLine(line)
      || isJsonDiagnosticLine(line)
      || isLowSignalDiagnosticLine(line)
      || isPromptPluginExpansionLine(line)
      || isToolSafetyNoiseLine(line)
      || isHiddenPromptMetadataLine(line)
      || isInternalContextLine(line)
      || isNoisyRuntimeLine(lower)
  }

  private static func metadataComparableLine(_ line: String) -> String {
    line
      .replacingOccurrences(of: #"^[›>•]\s*"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"^\d+\s*:\s*"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"^[-–—]\s*"#, with: "", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
  }

  private static func isHiddenPromptMetadataLine(_ line: String) -> Bool {
    let comparable = metadataComparableLine(line)
    return comparable == "breakdown" || comparable == "breakdown."
      || comparable == "analysis" || comparable == "analysis."
      || comparable == "reasoning" || comparable == "reasoning."
      || comparable == "thinking" || comparable == "thinking."
  }

  private static func isInternalContextLine(_ line: String) -> Bool {
    let comparable = metadataComparableLine(line)
    return comparable.hasPrefix("# task group:")
      || comparable.hasPrefix("task group:")
      || comparable.hasPrefix("filesystem sandboxing defines ")
      || comparable.hasPrefix("approval policy is currently ")
      || comparable.hasPrefix("decision boundary: should you use memory")
      || comparable.hasPrefix("you have access to a memory folder")
      || comparable.hasPrefix("## memory")
      || comparable.hasPrefix("scope:")
      || comparable.hasPrefix("applies_to:")
      || comparable.hasPrefix("desc:")
      || comparable.hasPrefix("- desc:")
      || comparable.hasPrefix("learnings:")
      || comparable.hasPrefix("- learnings:")
      || comparable.hasPrefix("## user profile")
      || comparable.hasPrefix("## user preferences")
      || comparable.hasPrefix("## general tips")
      || comparable.hasPrefix("## what's in memory")
      || comparable.hasPrefix("### /users/")
      || comparable.hasPrefix("### chronicle")
      || comparable.hasPrefix("### a control")
      || comparable.hasPrefix("### cm1 workspace")
      || comparable.hasPrefix("### older memory topics")
      || comparable.hasPrefix("#### 20")
      || comparable.hasPrefix("reuse_rule=")
      || comparable.contains("rollout_path=")
      || comparable.contains("thread_id=")
      || comparable.contains("[chronicle memory]")
      || comparable.contains("chronicle synthetic")
      || comparable.contains("memory-summary.md")
      || comparable.contains("memory_summary.md")
      || comparable.contains("quick memory pass")
      || comparable.contains("memory citation")
      || comparable.contains("<oai-mem-citation")
      || comparable.contains("<citation_entries>")
      || comparable.contains("<rollout_ids>")
      || comparable.hasPrefix("</citation_entries>")
      || comparable.hasPrefix("</rollout_ids>")
  }

  private static func isNoisyRuntimeLine(_ lowercasedLine: String) -> Bool {
    lowercasedLine.hasPrefix("codex/tcc relevant processes:")
      || lowercasedLine.range(
        of: #"^\d+\s+\d+\s+[a-z+]+\s+/"#, options: .regularExpression) != nil
      || lowercasedLine.contains("/contents/macos/skycomputeruse")
      || lowercasedLine.contains("/contents/resources/codex")
      || lowercasedLine.contains("/python.framework/versions/")
      || lowercasedLine.contains("apple event error -1743")
      || lowercasedLine.hasPrefix("open-exit=")
      || lowercasedLine.contains("ktccserviceappleevents")
      || lowercasedLine.contains("png image data,")
      || lowercasedLine.contains("host_bundle_capture.png")
      || lowercasedLine.contains("codex cli permission host.app:")
      || lowercasedLine.contains("local.codex.cli-permission-host")
      || lowercasedLine.contains(#"{"output":"#)
      || lowercasedLine.contains(#"\"metadata\":"#)
      || lowercasedLine.contains(#"\"exit_code\":"#)
      || lowercasedLine.contains("[{\"type\":\"text\",\"text\":")
      || lowercasedLine.contains("could not create image from display")
      || lowercasedLine.contains("/bin/java --add-opens")
      || lowercasedLine.contains("gradledaemon")
      || lowercasedLine.contains("kotlincompiledaemon")
      || lowercasedLine.contains("flutter_tester")
      || lowercasedLine.contains("ps -axo pid,command")
      || lowercasedLine.contains("grep -e [f]lutter")
      || lowercasedLine.contains("/.gradle/caches/")
      || lowercasedLine.contains("/.dart_tool/")
      || lowercasedLine.contains("--packages=")
      || lowercasedLine.contains("/bin/cache/")
      || lowercasedLine.contains("/.pub-cache/")
  }

  private static func startsNewGroup(_ line: String) -> Bool {
    line.hasPrefix("• ") || line.hasPrefix("› ")
      || line.hasPrefix("Queued") || line.hasPrefix("• Queued")
      || line.hasPrefix("─ Worked") || line.hasPrefix("Steered conversation")
      || line.hasPrefix("Working (") || line.hasPrefix("Thinking")
      || line.hasPrefix("Pursuing goal") || line.hasPrefix("Goal:")
      || isPatchHeaderLine(line)
      || looksLikeToolOutputLine(line)
  }

  private static func parseGroup(_ lines: [String]) -> CodexActivityItem? {
    guard !lines.isEmpty else { return nil }
    let sanitizedLines = sanitizeHiddenContextLines(lines)
    guard !sanitizedLines.isEmpty else { return nil }
    guard !isInternalContextGroup(sanitizedLines) else { return nil }
    let effectiveLines = sanitizedLines
    let effectiveFirst = effectiveLines[0]
    let groupFileReferences = fileReferences(from: effectiveLines)
    if isDiagnosticDump(effectiveLines) {
      guard !groupFileReferences.isEmpty else { return nil }
      return CodexActivityItem(
        kind: .result,
        title: "Diagnostic output hidden",
        detail: "Raw checks and media/file listings are hidden to keep the transcript readable. Open the file chips to inspect the produced artifacts.",
        badge: "Files",
        fileReferences: groupFileReferences)
    }
    if isLooseCodeDump(effectiveLines) {
      guard !groupFileReferences.isEmpty else { return nil }
      return CodexActivityItem(
        kind: .edited,
        title: "Code details hidden",
        detail: "Raw code/tool output is hidden to keep the transcript readable. Open the attached files to inspect the exact contents.",
        badge: "Files",
        fileReferences: groupFileReferences)
    }
    let rawDetailLines = Array(effectiveLines.dropFirst())
    if isDocumentReadDump(effectiveLines) || isDocumentReadDump([effectiveFirst] + rawDetailLines) {
      return CodexActivityItem(
        kind: .result,
        title: "Read attached document",
        detail:
          "Long document contents are hidden here. Use the file chips or Files panel to preview the source.",
        badge: nil,
        fileReferences: groupFileReferences)
    }
    let displayFirst = readableLine(effectiveFirst, fileReferences: groupFileReferences)
    let titleForDuplicateCheck = normalizedContent(effectiveFirst)
    let detail =
      rawDetailLines
      .map { readableLine($0, fileReferences: groupFileReferences) }
      .filter { !$0.isEmpty }
      .filter { !shouldSuppressDetailLine($0) }
      .filter { normalizedContent($0) != titleForDuplicateCheck }
      .prefix(14)
      .joined(separator: "\n")
    if effectiveFirst.hasPrefix("› ") {
      let promptText = sanitizePromptText(
        [String(effectiveFirst.dropFirst(2))] + Array(effectiveLines.dropFirst())
      )
      guard !promptText.isEmpty else { return nil }
      let promptReferences = fileReferences(
        from: promptText.components(separatedBy: .newlines).map(normalizedLine)
      )
      if let steerText = steerInstruction(from: promptText) {
        return CodexActivityItem(
          kind: .steer,
          title: steerText,
          detail: "",
          badge: nil,
          fileReferences: promptReferences)
      }
      let promptLines = promptText.components(separatedBy: .newlines)
        .map(normalizedLine)
        .filter { !$0.isEmpty }
      guard let promptTitle = promptLines.first else { return nil }
      return CodexActivityItem(
        kind: .prompt,
        title: readableLine(promptTitle, fileReferences: promptReferences),
        detail: promptLines.dropFirst()
          .map { readableLine($0, fileReferences: promptReferences) }
          .filter { !$0.isEmpty }
          .joined(separator: "\n"),
        badge: nil,
        fileReferences: promptReferences)
    }
    if effectiveFirst == "Prompt" || effectiveFirst.hasPrefix("Prompt ") {
      let inlineTitle = effectiveFirst.replacingOccurrences(
        of: #"^Prompt\s*"#, with: "", options: .regularExpression
      )
      .trimmed
      let promptText = sanitizePromptText(
        inlineTitle.isEmpty
          ? Array(effectiveLines.dropFirst())
          : [inlineTitle] + Array(effectiveLines.dropFirst())
      )
      let promptLines = promptText.components(separatedBy: .newlines)
        .map(normalizedLine)
        .filter { !$0.isEmpty }
      if let steerText = steerInstruction(from: promptText) {
        return CodexActivityItem(
          kind: .steer,
          title: steerText,
          detail: "",
          badge: nil,
          fileReferences: groupFileReferences)
      }
      let title =
        promptLines.first
        ?? (inlineTitle.isEmpty
          ? detail.components(separatedBy: .newlines).first ?? "Prompt" : inlineTitle)
      let remainingDetail =
        promptLines.isEmpty
        ? (inlineTitle.isEmpty
          ? detail.components(separatedBy: .newlines).dropFirst().joined(separator: "\n")
          : detail)
        : promptLines.dropFirst().joined(separator: "\n")
      if looksLikeToolOutputLine(title) {
        return CodexActivityItem(
          kind: .result,
          title: readableLine(title, fileReferences: groupFileReferences),
          detail: remainingDetail,
          badge: nil,
          fileReferences: groupFileReferences)
      }
      return CodexActivityItem(
        kind: .prompt,
        title: readableLine(title, fileReferences: groupFileReferences),
        detail: remainingDetail,
        badge: nil,
        fileReferences: groupFileReferences)
    }
    if effectiveFirst.contains("Steered conversation") || detail.contains("Steer the current") {
      let steerText =
        steerInstruction(from: [effectiveFirst, detail].joined(separator: "\n"))
        ?? steerInstruction(from: detail)
        ?? detail
      return CodexActivityItem(
        kind: .steer,
        title: steerText,
        detail: "",
        badge: nil,
        fileReferences: groupFileReferences)
    }
    if effectiveFirst.hasPrefix("• Queued") || effectiveFirst.hasPrefix("Queued") {
      let title =
        effectiveFirst
        .replacingOccurrences(of: "• ", with: "")
        .replacingOccurrences(of: "Queued", with: "Queued for Codex")
      return CodexActivityItem(
        kind: .queued, title: title, detail: detail, badge: "Queue",
        fileReferences: groupFileReferences)
    }
    if effectiveFirst.hasPrefix("Pursuing goal") || effectiveFirst.hasPrefix("Goal:") {
      let title =
        effectiveFirst
        .replacingOccurrences(of: "Pursuing goal", with: "Pursuing goal")
        .replacingOccurrences(of: #"^Goal:\s*"#, with: "Pursuing goal ", options: .regularExpression)
        .trimmed
      return CodexActivityItem(
        kind: .goal,
        title: title.isEmpty ? "Pursuing goal" : title,
        detail: detail,
        badge: "Goal",
        fileReferences: groupFileReferences)
    }
    if effectiveFirst.hasPrefix("• Working") || effectiveFirst.hasPrefix("Working (")
      || effectiveFirst.hasPrefix("Thinking")
    {
      return CodexActivityItem(
        kind: .working, title: effectiveFirst.replacingOccurrences(of: "• ", with: ""),
        detail: detail,
        badge: "Live", fileReferences: groupFileReferences)
    }
    if effectiveFirst.hasPrefix("• Ran ") {
      return CodexActivityItem(
        kind: .ran, title: compactTitle(effectiveFirst, prefix: "• Ran "), detail: detail,
        badge: "Run",
        fileReferences: groupFileReferences)
    }
    if effectiveFirst.hasPrefix("• Explored") {
      return CodexActivityItem(
        kind: .explored, title: effectiveFirst.replacingOccurrences(of: "• ", with: ""),
        detail: detail,
        badge: "Read", fileReferences: groupFileReferences)
    }
    if effectiveFirst.hasPrefix("• Edited") {
      return CodexActivityItem(
        kind: .edited, title: effectiveFirst.replacingOccurrences(of: "• ", with: ""),
        detail: detail,
        badge: "Edit", fileReferences: groupFileReferences)
    }
    if effectiveFirst.hasPrefix("• Called") {
      return CodexActivityItem(
        kind: .called, title: effectiveFirst.replacingOccurrences(of: "• ", with: ""),
        detail: detail,
        badge: "Tool", fileReferences: groupFileReferences)
    }
    if effectiveFirst.hasPrefix("• Waited") {
      return CodexActivityItem(
        kind: .waited, title: effectiveFirst.replacingOccurrences(of: "• ", with: ""),
        detail: detail,
        badge: "Wait", fileReferences: groupFileReferences)
    }
    if isPatchHeaderLine(effectiveFirst) {
      return CodexActivityItem(
        kind: .edited,
        title: groupFileReferences.isEmpty ? "Patch applied" : "Patch applied",
        detail: "",
        badge: "Edit",
        fileReferences: groupFileReferences)
    }
    if effectiveFirst.hasPrefix("─ Worked") {
      return CodexActivityItem(
        kind: .result,
        title: effectiveFirst.trimmingCharacters(in: CharacterSet(charactersIn: "─ ")),
        detail: detail, badge: "Done", fileReferences: groupFileReferences)
    }
    if effectiveFirst.hasPrefix("• ") {
      return CodexActivityItem(
        kind: .result,
        title: nonEmpty(
          displayFirst.replacingOccurrences(of: "• ", with: ""), fallback: "Codex update"),
        detail: detail,
        badge: nil, fileReferences: groupFileReferences)
    }
    if looksLikeCodeLine(effectiveFirst) {
      return nil
    }
    return CodexActivityItem(
      kind: .result,
      title: nonEmpty(displayFirst, fallback: groupFileReferences.isEmpty ? "" : "Files attached"),
      detail: detail,
      badge: nil,
      fileReferences: groupFileReferences)
  }

  private static func looksLikeCodeLine(_ value: String) -> Bool {
    let line = value.trimmed
    guard !line.isEmpty else { return false }
    if line.hasPrefix("#!") { return true }
    if ["{", "}", "},", "];", ");", "});"].contains(line) { return true }
    let codePrefixes = [
      "def ", "class ", "struct ", "enum ", "func ", "let ", "var ", "final ", "return ",
      "if ", "elif ", "else:", "for ", "while ", "import ", "from ", "try ", "try:",
      "except ", "except:", "except Exception:", "catch ", "guard ", "@override",
      "private ", "public ", "static ", "const ", "void ", "self.", "this.", "continue",
      "break", "pass", "export ", "module.exports", "case ", "default:",
    ]
    if codePrefixes.contains(where: { line.hasPrefix($0) }) { return true }
    if line.hasPrefix("} from ") || line.contains(#"} from ""#) || line.contains("} from '") {
      return true
    }
    if line.range(of: #"^[A-Za-z_$][A-Za-z0-9_$]*,$"#, options: .regularExpression) != nil {
      return true
    }
    if line.range(of: #"^[A-Za-z_][A-Za-z0-9_]*\s*="#, options: .regularExpression) != nil {
      return true
    }
    if line.range(
      of: #"^[A-Za-z_$][A-Za-z0-9_$-]*\s*:\s*(?:[\{\["']|[-+]?\d|true\b|false\b|null\b)"#,
      options: .regularExpression) != nil
    {
      return true
    }
    if line.contains(" = ") && (line.contains("(") || line.contains("[") || line.contains(".")) {
      return true
    }
    if line.contains(" -> ") && line.contains(":") {
      return true
    }
    if line.range(of: #"^[A-Za-z0-9_./-]+:\d+:"#, options: .regularExpression) != nil {
      return true
    }
    if line.range(
      of: #"^[A-Za-z_][A-Za-z0-9_.]*\([^)]*\)(?:\s*->\s*.*)?$"#,
      options: .regularExpression) != nil
    {
      return true
    }
    if line.range(
      of: #"^[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z0-9_.]+\([^)]*\)"#,
      options: .regularExpression) != nil
    {
      return true
    }
    return false
  }

  private static func isLooseCodeDump(_ lines: [String]) -> Bool {
    let normalized = lines
      .map(\.trimmed)
      .filter { !$0.isEmpty }
    guard normalized.count >= 2 else { return false }
    let codeLike = normalized.filter { line in
      looksLikeCodeFragmentLine(line)
    }.count
    guard codeLike >= 2 else { return false }
    let naturalLanguage = normalized.filter { line in
      let lower = line.lowercased()
      return line.contains(" ") && !looksLikeCodeLine(line)
        && !lower.hasPrefix("status")
        && !lower.hasPrefix("failure_mode")
        && !lower.hasPrefix("result")
    }.count
    return codeLike >= max(2, normalized.count / 2) && naturalLanguage <= 1
  }

  private static func looksLikeCodeFragmentLine(_ line: String) -> Bool {
    looksLikeCodeLine(line)
      || isJsonDiagnosticLine(line)
      || isLowSignalDiagnosticLine(line)
      || line == "("
      || line == ")"
      || line.hasSuffix(",") && (
        line.contains("=") || line.contains("(") || line.contains(")") || line.contains("[")
          || line.contains("{") || line.contains(":")
      )
      || line.range(of: #"^[A-Za-z_$][A-Za-z0-9_$]*,$"#, options: .regularExpression) != nil
      || line.range(of: #"^[A-Za-z_$][A-Za-z0-9_$-]*\s*:\s*.+,$"#, options: .regularExpression) != nil
      || line.range(of: #"^\s*[\}\]]\s*(?:,|;)?$"#, options: .regularExpression) != nil
  }

  private static func looksLikeToolOutputLine(_ value: String) -> Bool {
    let lower = value.trimmed.lowercased()
    guard !lower.isEmpty else { return false }
    let prefixes = [
      "could not ", "failed ", "error:", "java.", "run with ", "* try:",
      "exception", "formatted ", "analyzing ", "no issues found", "privacy scan",
      "static checks", "build ", "running ", "resolving dependencies", "downloading packages",
      "what went wrong:", "where:", "a problem occurred", "execution failed",
      "caused by:", "unable to ", "encountered error", "command failed",
    ]
    if prefixes.contains(where: { lower.hasPrefix($0) }) { return true }
    return lower.contains("operation not permitted")
      || lower.contains("socketexception")
      || lower.contains("filelock")
      || lower.contains("gradle")
      || lower.contains("flutter test")
      || lower.contains("flutter build")
  }

  private static func isInternalContextGroup(_ lines: [String]) -> Bool {
    let comparable = lines.map(metadataComparableLine)
    let hasUserTurn =
      comparable.contains { line in
        line.hasPrefix("› ") || line.hasPrefix("prompt ")
          || line.hasPrefix("transcript_smoke_")
          || line.hasPrefix("sshcontroll_")
      }
    guard !hasUserTurn else { return false }

    let memorySignals =
      comparable.filter { line in
        line.hasPrefix("filesystem sandboxing defines ")
          || line.hasPrefix("approval policy is currently ")
          || line.hasPrefix("decision boundary: should you use memory")
          || line.hasPrefix("you have access to a memory folder")
          || line.hasPrefix("## memory")
          || line.contains("[chronicle memory]")
          || line.hasPrefix("#### 20")
          || line.hasPrefix("### /users/")
          || line.hasPrefix("### chronicle")
          || line.hasPrefix("### a control")
          || line.hasPrefix("### cm1 workspace")
          || line.hasPrefix("- desc:")
          || line.hasPrefix("- learnings:")
          || line.contains("rollout_path=")
          || line.contains("memory-summary.md")
          || line.contains("memory_summary.md")
      }
    let guidanceSignals =
      comparable.filter { line in
        line.hasPrefix("when the user ")
          || line.hasPrefix("- when the user ")
          || line.contains("user explicitly")
      }
    return memorySignals.count >= 2
      || guidanceSignals.count >= 3
      || comparable.first == "a compact change + verification recap."
      || comparable.contains(where: { $0.hasPrefix("### /users/") || $0.hasPrefix("### chronicle") }
      )
  }

  private static func isDocumentReadDump(_ lines: [String]) -> Bool {
    let joined = lines.prefix(80).joined(separator: "\n").lowercased()
    guard joined.count > 120 else { return false }
    if joined.contains("submit a single .zip file")
      && (joined.contains("readme.txt") || joined.contains("source code and notebook")
        || joined.contains("delayed submissions"))
    {
      return true
    }
    if joined.contains("submit a single .zip file") && joined.contains("page 1 of") {
      return true
    }
    if joined.contains("delayed submissions are not accepted") && joined.contains("page 1 of") {
      return true
    }
    if joined.contains("computation, learning, and physics") && joined.contains("page 1 of") {
      return true
    }
    if joined.contains("page 1 of") && joined.contains("individual project") {
      return true
    }
    if joined.contains("using dmrg for periodic boundary conditions")
      && joined.contains("ground state")
    {
      return true
    }
    let signals = [
      "page 1 of", "page 2 of", "submit a single .zip", "delayed submissions",
      "computation, learning, and physics", "individual project",
      "periodic boundary conditions", "hamiltonian", "ground state",
      "mps", "dmrg method", "pdf", "report format", "readme.txt",
      "source code and notebook", "no predefined report format",
    ]
    let count = signals.filter { joined.contains($0) }.count
    return count >= 3 || (count >= 2 && joined.count > 260)
  }

  private static func normalizedContent(_ value: String) -> String {
    stripHiddenPromptContext(value)
      .replacingOccurrences(of: #"^(?:Prompt\s*)?[›•]?\s*"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmed
      .lowercased()
  }

  private static func steerInstruction(from value: String) -> String? {
    let text = stripHiddenPromptContext(value)
      .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
      .trimmed
    guard !text.isEmpty else { return nil }

    if text.localizedCaseInsensitiveContains("Steer the current Codex work with this instruction")
      || text.localizedCaseInsensitiveContains(
        "Treat it as a correction or priority for the active task")
    {
      let pattern =
        #"(?is)^\s*(?:Steered conversation\s*)?(?:Steer the current Codex work with this instruction\.\s*)?Treat it as a correction or priority for the active task,\s*not as an unrelated new task:\s*"#
      let cleaned =
        text
        .replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        .trimmed
      return cleaned.isEmpty ? "Steered conversation" : cleaned
    }

    if text.localizedCaseInsensitiveContains("Steered conversation") {
      let cleaned =
        text
        .components(separatedBy: .newlines)
        .drop { $0.trimmed.localizedCaseInsensitiveContains("Steered conversation") }
        .joined(separator: "\n")
        .trimmed
      return cleaned.isEmpty ? "Steered conversation" : cleaned
    }

    return nil
  }

  private static func removePromptEchoes(from items: [CodexActivityItem]) -> [CodexActivityItem] {
    var output: [CodexActivityItem] = []
    var recentUserTurns: [String] = []
    for item in items {
      let titleRole = normalizedContent(item.title)
      let contentSource =
        item.kind == .result && !item.detail.trimmed.isEmpty
          && ["codex", "assistant", "claude"].contains(titleRole)
        ? item.detail
        : [item.title, item.detail]
          .map(\.trimmed)
          .filter { !$0.isEmpty }
          .joined(separator: " ")
      let content = normalizedContent(contentSource)
      if item.kind == .prompt || item.kind == .steer {
        if recentUserTurns.contains(where: { previous in isPromptEcho(content, of: previous) }) {
          continue
        }
        if !content.isEmpty {
          recentUserTurns.append(content)
          recentUserTurns = Array(recentUserTurns.suffix(8))
        }
        output.append(item)
        continue
      }
      if item.kind == .result,
        recentUserTurns.contains(where: { prompt in isPromptEcho(content, of: prompt) })
      {
        continue
      }
      output.append(item)
    }
    return output
  }

  private static func compactNoisyRepeats(_ items: [CodexActivityItem]) -> [CodexActivityItem] {
    var output: [CodexActivityItem] = []
    for item in items {
      if let previous = output.last, shouldCollapseActivity(item, after: previous) {
        continue
      }
      output.append(item)
    }
    return output
  }

  private static func shouldCollapseActivity(
    _ item: CodexActivityItem,
    after previous: CodexActivityItem
  ) -> Bool {
    guard item.kind == previous.kind else { return false }
    let currentText = normalizedContent([item.title, item.detail].joined(separator: " "))
    let previousText = normalizedContent([previous.title, previous.detail].joined(separator: " "))
    guard !currentText.isEmpty, currentText == previousText else { return false }
    switch item.kind {
    case .waited, .working, .ran, .explored, .edited, .called, .goal, .result:
      return true
    case .prompt, .steer, .queued, .placeholder:
      return false
    }
  }

  private static func isPromptEcho(_ content: String, of prompt: String) -> Bool {
    guard !content.isEmpty, !prompt.isEmpty else { return false }
    if content == prompt || content.hasPrefix(prompt) || prompt.hasPrefix(content) {
      return true
    }
    if min(content.count, prompt.count) >= 48,
      content.contains(prompt) || prompt.contains(content)
    {
      return true
    }
    let promptWords = prompt.split(separator: " ")
    let contentWords = content.split(separator: " ")
    guard promptWords.count >= 8, contentWords.count >= 8 else { return false }
    let promptPrefix = promptWords.prefix(min(promptWords.count, 24)).joined(separator: " ")
    let contentPrefix = contentWords.prefix(min(contentWords.count, 24)).joined(separator: " ")
    if promptPrefix == contentPrefix {
      return true
    }
    let promptShortPrefix = String(prompt.prefix(min(prompt.count, 96)))
    let contentShortPrefix = String(content.prefix(min(content.count, 96)))
    return promptShortPrefix.count >= 48 && promptShortPrefix == contentShortPrefix
  }

  private static func sanitizeHiddenContextLines(_ lines: [String]) -> [String] {
    let hasPromptPrefix = lines.first?.hasPrefix("› ") == true
    var text = lines.joined(separator: "\n")
    if hasPromptPrefix {
      text = text.replacingOccurrences(of: #"^›\s*"#, with: "", options: .regularExpression)
    }
    text = stripHiddenPromptContext(text)
    let output = text.components(separatedBy: .newlines)
      .map(normalizedLine)
      .filter { !$0.isEmpty }
    guard hasPromptPrefix, let first = output.first else { return output }
    return ["› \(first)"] + Array(output.dropFirst())
  }

  private static func sanitizePromptText(_ lines: [String]) -> String {
    stripHiddenPromptContext(lines.joined(separator: "\n"))
      .components(separatedBy: .newlines)
      .map(normalizedLine)
      .compactMap(promptDisplayLine)
      .filter {
        !$0.isEmpty && !isBoilerplateLine($0) && !isHiddenPromptMetadataLine($0)
          && !isInternalContextLine($0)
      }
      .joined(separator: "\n")
      .trimmed
  }

  private static func promptDisplayLine(_ line: String) -> String? {
    let trimmed = line.trimmed
    guard !trimmed.isEmpty else { return nil }
    let lower = trimmed.lowercased()
    if lower.hasPrefix("attached files are in this a-side sshcontroll buffer directory")
      || lower.hasPrefix("files:")
      || lower.hasPrefix("inspect the buffer directory directly")
      || lower.hasPrefix("do not quote or paste raw file contents")
      || lower.hasPrefix("<sshcontroll_attachments")
      || lower.hasPrefix("</sshcontroll_attachments")
      || lower.hasPrefix("<turn_aborted")
      || lower.hasPrefix("</turn_aborted")
      || lower.hasPrefix("buffer_dir:")
      || lower.hasPrefix("rules:")
      || lower.hasPrefix("remote_path:")
      || lower.hasPrefix("shell_quoted_path:")
      || lower.hasPrefix("kind: file")
      || lower.hasPrefix("research run: research_loops/")
      || lower.contains("autonomous research stages are staged on a queue")
      || lower.contains("/.acontrol_attachments/")
      || lower.contains("/.sshcontroll_buffer/")
    {
      return nil
    }
    if lower.range(
      of: #"^-\s+[^/]+\.(?:pdf|png|jpe?g|md|txt|csv|json|py|swift|dart|zip|log)$"#,
      options: [.regularExpression, .caseInsensitive]) != nil
    {
      return nil
    }
    if let plugin = matches(
      in: trimmed,
      pattern: #"^\[@([A-Za-z0-9 _-]+)\]\(plugin://[^)]+\)$"#
    ).first?.first {
      return "@\(plugin.replacingOccurrences(of: " ", with: ""))"
    }
    if isPromptPluginExpansionLine(trimmed) {
      return nil
    }
    if isToolSafetyNoiseLine(trimmed) {
      return nil
    }
    if isCodexSuggestionPlaceholder(trimmed) {
      return nil
    }
    if isGeneratedResearchQueueDisplayLine(trimmed) {
      return nil
    }
    return trimmed
  }

  private static func isGeneratedResearchActivity(_ item: CodexActivityItem) -> Bool {
    guard item.kind == .prompt || item.kind == .steer || item.kind == .queued else {
      return false
    }
    let text = [item.title, item.detail]
      .map(\.trimmed)
      .filter { !$0.isEmpty }
      .joined(separator: "\n")
    return isGeneratedResearchQueueDisplayLine(text)
      || text.localizedCaseInsensitiveContains("Queued Professor Lab:")
      || text.localizedCaseInsensitiveContains("Research run: research_loops/")
      || text.localizedCaseInsensitiveContains("autonomous research stages are staged on A queue")
      || text.range(
        of: #"\bprofessor-(?:stage|loop)-\d+(?:-of-\d+)?\b"#,
        options: [.regularExpression, .caseInsensitive]
      ) != nil
  }

  private static func isGeneratedResearchQueueDisplayLine(_ line: String) -> Bool {
    let normalized =
      line
      .replacingOccurrences(of: #"^[›>\s]*"#, with: "", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if normalized.range(
      of: #"\bprofessor-(?:stage|loop)-\d+(?:-of-\d+)?\b"#,
      options: [.regularExpression, .caseInsensitive]
    ) != nil {
      return true
    }
    if normalized.localizedCaseInsensitiveContains("Queued Professor Lab:") {
      return true
    }
    return normalized.range(
      of: #"^[A-Za-z0-9 &/+.-]+ · [A-Za-z0-9 &/+.-]+ · \d+/\d+(?: · .*)?$"#,
      options: .regularExpression
    ) != nil
  }

  private static func isCodexSuggestionPlaceholder(_ line: String) -> Bool {
    let normalized =
      line
      .replacingOccurrences(of: #"^[›>\s]*"#, with: "", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    let placeholders: Set<String> = [
      "implement {feature}",
      "find and fix a bug in @filename",
      "improve documentation in @filename",
      "explain this codebase",
      "use /skills to list available skills",
    ]
    return placeholders.contains(normalized)
  }

  private static func isPromptPluginExpansionLine(_ line: String) -> Bool {
    let lower = line.lowercased()
    return lower.hasPrefix("use computer use on a ")
      || lower.hasPrefix("use browser on a ")
      || lower.hasPrefix("for a-side gui screenshots or clicks")
      || lower.hasPrefix("capabilities from the ")
      || lower.hasPrefix("- skills from this plugin")
      || lower.hasPrefix("- mcp servers from this plugin")
      || lower.hasPrefix("use these plugin-associated capabilities")
  }

  private static func isToolSafetyNoiseLine(_ line: String) -> Bool {
    let lower = line.lowercased()
    return lower.contains("computer use is not allowed to use the app")
      || lower.contains("com.openai.codex")
      || lower.contains("apple event error -1743")
      || lower.contains("could not create image from display")
      || lower.hasPrefix("chunk id:")
      || lower.hasPrefix("wall time:")
      || lower.hasPrefix("process exited with code")
      || lower.hasPrefix("process running with session id")
      || lower.hasPrefix("original token count:")
      || lower == "output:"
      || (lower.hasPrefix("[{\"type\":\"text\"") && lower.contains("safety reasons"))
      || (lower.hasPrefix("[{\"type\":\"text\"") && lower.contains("apple event error"))
      || lower.hasPrefix("{\"type\":\"text\"")
  }

  private static func stripHiddenPromptContext(_ value: String) -> String {
    value
      .replacingOccurrences(
        of: #"(?is)<environment_context\b[^>]*>.*?</environment_context>"#,
        with: "\n",
        options: .regularExpression
      )
      .replacingOccurrences(
        of: #"(?is)<(?:subagent_notification|agent_notification|turn_aborted)\b[^>]*>.*?</(?:subagent_notification|agent_notification|turn_aborted)>"#,
        with: "\n",
        options: .regularExpression
      )
      .replacingOccurrences(
        of:
          #"(?is)<(?:permissions instructions|app-context|collaboration_mode|apps_instructions|skills_instructions|plugins_instructions)\b[^>]*>.*?</(?:permissions instructions|app-context|collaboration_mode|apps_instructions|skills_instructions|plugins_instructions)>"#,
        with: "\n",
        options: .regularExpression
      )
      .replacingOccurrences(
        of: #"(?ims)^## Memory\s*$.*?^========= MEMORY_SUMMARY ENDS =========\s*$"#,
        with: "\n",
        options: .regularExpression
      )
      .replacingOccurrences(
        of: #"(?is)#\s*AGENTS\.md instructions[^\n]*\n\s*<INSTRUCTIONS>.*?</INSTRUCTIONS>"#,
        with: "\n",
        options: .regularExpression
      )
      .replacingOccurrences(
        of: #"(?is)<INSTRUCTIONS>.*?</INSTRUCTIONS>"#,
        with: "\n",
        options: .regularExpression
      )
      .replacingOccurrences(
        of:
          #"(?is)SSHcontroll transferred the user's attached file\(s\).*?(?:Before answering, inspect any needed attachment.*?(?:clipboard write path for these attachments\.|$))"#,
        with: "\n",
        options: .regularExpression
      )
      .replacingOccurrences(
        of:
          #"(?is)Attached files are in this A-side SSHcontroll buffer directory:.*?(?:Do not use clipboard APIs for these attachments\.|$)"#,
        with: "\n",
        options: .regularExpression
      )
      .replacingOccurrences(
        of: #"(?is)<sshcontroll_attachments>.*?</sshcontroll_attachments>"#,
        with: "\n",
        options: .regularExpression
      )
      .replacingOccurrences(
        of:
          #"(?im)^\s*</?(?:current_date|timezone|shell|cwd|approval_policy|sandbox_mode|environment_context)[^>]*>.*$"#,
        with: "",
        options: .regularExpression
      )
      .replacingOccurrences(
        of: #"\n{3,}"#,
        with: "\n\n",
        options: .regularExpression
      )
      .trimmed
  }

  private static func coalesceAdjacentPrompts(_ items: [CodexActivityItem]) -> [CodexActivityItem] {
    var output: [CodexActivityItem] = []
    for item in items {
      if item.kind == .prompt, var previous = output.last, previous.kind == .prompt {
        let mergedLines = [
          previous.title, previous.detail, item.title, item.detail,
        ]
        .map(\.trimmed)
        .filter { !$0.isEmpty }
        .flatMap { $0.components(separatedBy: .newlines) }
        .map(\.trimmed)
        .filter { !$0.isEmpty }

        if let firstLine = mergedLines.first {
          previous.title = firstLine
          previous.detail = mergedLines.dropFirst().joined(separator: "\n")
        }

        var seen = Set(previous.fileReferences.map(\.id))
        for reference in item.fileReferences where !seen.contains(reference.id) {
          previous.fileReferences.append(reference)
          seen.insert(reference.id)
        }
        output[output.count - 1] = previous
      } else {
        output.append(item)
      }
    }
    return output
  }

  private static func fallbackItems(from value: String) -> [CodexActivityItem] {
    value.components(separatedBy: .newlines)
      .map(normalizedLine)
      .filter { !$0.isEmpty && !isBoilerplateLine($0) }
      .filter { !looksLikeCodeFragmentLine($0) }
      .filter { !isLowSignalDiagnosticLine($0) }
      .filter { !looksLikeBareFileLine($0) }
      .suffix(120)
      .map { CodexActivityItem(kind: .result, title: $0, detail: "", badge: nil) }
  }

  private static func rawFallbackItems(from value: String) -> [CodexActivityItem] {
    let lines = value.components(separatedBy: .newlines)
      .map(normalizedLine)
      .filter { !$0.isEmpty && !isBoilerplateLine($0) }
      .filter { !looksLikeCodeFragmentLine($0) }
      .filter { !isLowSignalDiagnosticLine($0) }
      .filter { !looksLikeBareFileLine($0) }
      .suffix(36)
    let text = lines.joined(separator: "\n").trimmed
    guard !text.isEmpty else {
      return [
        CodexActivityItem(
          kind: .placeholder,
          title: "No readable transcript text yet.",
          detail: "",
          badge: nil,
          fileReferences: []
        )
      ]
    }
    return [
      CodexActivityItem(
        kind: .result,
        title: text,
        detail: "",
        badge: nil,
        fileReferences: fileReferences(from: Array(lines))
      )
    ]
  }

  private static func compactTitle(_ value: String, prefix: String) -> String {
    let raw = value.replacingOccurrences(of: prefix, with: "")
    let compacted = compactVisibleFileReferences(raw)
    return compacted.count > 120 ? String(compacted.prefix(117)) + "..." : compacted
  }

  private static func nonEmpty(_ value: String, fallback: String) -> String {
    value.trimmed.isEmpty ? fallback : value
  }

  private static func readableLine(
    _ value: String,
    fileReferences: [CodexInlineFileReference]
  ) -> String {
    guard !isFileReferenceOnlyLine(value, fileReferences: fileReferences) else { return "" }
    return compactDetailLine(value)
  }

  private static func shouldSuppressDetailLine(_ value: String) -> Bool {
    let line = value.trimmed
    guard !line.isEmpty else { return true }
    if isHiddenPromptMetadataLine(line) { return true }
    if isInternalContextLine(line) { return true }
    if isPromptPluginExpansionLine(line) { return true }
    if isToolSafetyNoiseLine(line) { return true }
    if isPatchDetailLine(line) { return true }
    if isJsonDiagnosticLine(line) { return true }
    if isLowSignalDiagnosticLine(line) { return true }
    if looksLikeCodeLine(line) { return true }
    if looksLikeBareFileLine(line) { return true }
    let lower = line.lowercased()
    if lower.hasPrefix("page 1 of") || lower.hasPrefix("page 2 of")
      || lower.contains("delayed submissions are not accepted")
      || lower.contains("computation, learning, and physics")
      || lower.contains("in this individual project")
    {
      return true
    }
    return false
  }

  private static func isJsonDiagnosticLine(_ value: String) -> Bool {
    let line = value.trimmed
    guard !line.isEmpty else { return false }
    if line == "{" || line == "}" || line == "[" || line == "]" || line == "}," || line == "]," {
      return true
    }
    if line.range(
      of: #"^\"[A-Za-z0-9_./ -]+\"\s*:\s*(?:.+)?[,]?$"#,
      options: .regularExpression) != nil
    {
      return true
    }
    if line.range(of: #"^\"[^\"]+\"[,]?$"#, options: .regularExpression) != nil {
      return true
    }
    return false
  }

  private static func isDiagnosticDump(_ lines: [String]) -> Bool {
    let normalized = lines.map(\.trimmed).filter { !$0.isEmpty }
    guard normalized.count >= 4 else { return false }
    let diagnostics = normalized.filter {
      isLowSignalDiagnosticLine($0) || isJsonDiagnosticLine($0) || looksLikeCodeFragmentLine($0)
    }.count
    return diagnostics >= max(3, normalized.count / 2)
  }

  private static func isLowSignalDiagnosticLine(_ value: String) -> Bool {
    let line = value.trimmed
    guard !line.isEmpty else { return false }
    let lower = line.lowercased()
    if lower.range(
      of: #"^(total\s+\d+|[-dlrwxs@+]{6,}\s+\d+\s+\S+\s+\S+\s+\d+)"#,
      options: .regularExpression) != nil
    {
      return true
    }
    if lower.range(
      of: #"^(width|height|duration|r_frame_rate|avg_frame_rate|codec_name|codec_type|pix_fmt|bit_rate|nb_frames|sample_rate|channels|format_name|format_long_name)="#,
      options: .regularExpression) != nil
    {
      return true
    }
    if lower.range(
      of: #"^==\s+/users/.+\.(?:mp4|mov|m4v|png|jpe?g|gif|webp|pdf|pptx|key|csv|tsv|md|py|json|log|txt|zip)$"#,
      options: .regularExpression) != nil
    {
      return true
    }
    if lower.range(
      of: #"^/users/.+\.(?:mp4|mov|m4v|png|jpe?g|gif|webp|pdf|pptx|key|csv|tsv|md|py|json|log|txt|zip)$"#,
      options: .regularExpression) != nil
    {
      return true
    }
    if lower.range(of: #"^/users/.+/$"#, options: .regularExpression) != nil {
      return true
    }
    if lower.range(of: #"^test of /users/.+ ok$"#, options: .regularExpression) != nil {
      return true
    }
    if lower.range(of: #"^slide(?:_size|\s+\d+\s+media\b)"#, options: .regularExpression) != nil {
      return true
    }
    if lower.range(of: #"^slide\s+\d+\s+shape_count\b"#, options: .regularExpression) != nil {
      return true
    }
    if lower.range(of: #"^changed\s+\["#, options: .regularExpression) != nil {
      return true
    }
    if lower.range(of: #"^\(\d+,\s*'[^']+',\s*\d+"#, options: .regularExpression) != nil {
      return true
    }
    if lower.range(of: #"^\(\d+,\s*\"[^\"]+\",\s*\d+"#, options: .regularExpression) != nil {
      return true
    }
    if lower.range(of: #"^\(\d+,\s*[a-z0-9_ -]+,\s*\d+"#, options: .regularExpression) != nil {
      return true
    }
    if lower.range(of: #"^stream #\d+:\d+"#, options: .regularExpression) != nil {
      return true
    }
    if lower.range(of: #"^(frame|fps|q|size|time|bitrate|speed)="#, options: .regularExpression) != nil {
      return true
    }
    if lower.range(of: #"^\[?[\d.,\s()/-]+\]?$"#, options: .regularExpression) != nil
      && line.count > 8
    {
      return true
    }
    return false
  }

  private static func isPatchHeaderLine(_ value: String) -> Bool {
    let line = value.trimmed
    return line == "Patch" || line == "Begin Patch" || line == "End Patch"
      || line == "*** Begin Patch" || line == "*** End Patch"
      || line.hasPrefix("*** Update File:") || line.hasPrefix("*** Add File:")
      || line.hasPrefix("*** Delete File:") || line.hasPrefix("* Update File:")
      || line.hasPrefix("* Add File:") || line.hasPrefix("* Delete File:")
  }

  private static func isPatchDetailLine(_ value: String) -> Bool {
    let line = value.trimmed
    guard !line.isEmpty else { return true }
    if isPatchHeaderLine(line) { return true }
    if line.hasPrefix("@@") || line.hasPrefix("+++") || line.hasPrefix("--- ") {
      return true
    }
    if let first = line.first, first == "+" || first == "-" {
      let body = String(line.dropFirst()).trimmed
      if first == "+" {
        return true
      }
      if body.isEmpty || looksLikeCodeLine(body) || looksLikePatchCodeBody(body)
        || body.hasPrefix("#")
        || body.hasPrefix("{") || body.hasPrefix("}") || body.hasPrefix("[")
        || body.hasPrefix("]") || body.hasPrefix("(") || body.hasPrefix(")")
        || body.hasPrefix("\"") || body.hasPrefix("'")
        || body.range(of: #"^[A-Za-z_][A-Za-z0-9_]*\("#, options: .regularExpression) != nil
      {
        return true
      }
    }
    return false
  }

  private static func looksLikePatchCodeBody(_ value: String) -> Bool {
    let line = value.trimmed
    guard !line.isEmpty else { return true }
    if line.hasPrefix("from ") || line.hasPrefix("import ") || line.hasPrefix("def ")
      || line.hasPrefix("class ") || line.hasPrefix("return ") || line.hasPrefix("if ")
      || line.hasPrefix("for ") || line.hasPrefix("while ") || line.hasPrefix("@")
    {
      return true
    }
    if line.contains(" = ") || line.hasSuffix(",") {
      return true
    }
    return false
  }

  private static func looksLikeBareFileLine(_ value: String) -> Bool {
    value.trimmed.range(
      of:
        #"^[A-Za-z0-9._@+-]+\.(?:swift|dart|kt|java|gradle|properties|plist|xcconfig|xcodeproj|xcworkspace|py|js|ts|tsx|jsx|css|scss|html|xml|json|ya?ml|toml|md|txt|csv|log|sh|zsh|ps1|rs|go|c|cc|cpp|h|hpp|png|jpe?g|gif|heic|tiff?|bmp|webp|pdf|apk|ipa|pkg|dmg|zip|tar|tgz|gz)$"#,
      options: [.regularExpression, .caseInsensitive]
    ) != nil
  }

  private static func isFileReferenceOnlyLine(
    _ value: String,
    fileReferences: [CodexInlineFileReference]
  ) -> Bool {
    var scrubbed = value.trimmed
      .replacingOccurrences(of: "└ ", with: "")
      .replacingOccurrences(of: "│ ", with: "")
      .replacingOccurrences(of: #"^[-•]\s*"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"^>\s+"#, with: "", options: .regularExpression)
      .trimmed
    guard !scrubbed.isEmpty, !fileReferences.isEmpty else { return false }

    for reference in fileReferences {
      let candidates = [
        reference.path,
        "`\(reference.path)`",
        "[\(reference.label)](\(reference.path))",
        reference.label,
        reference.displayName,
      ].filter { !$0.isEmpty }
      for candidate in candidates {
        scrubbed = scrubbed.replacingOccurrences(of: candidate, with: "")
      }
    }
    scrubbed =
      scrubbed
      .replacingOccurrences(of: #"\[[^\]]+\]\([^)]+\)"#, with: "", options: .regularExpression)
      .trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n`'\"[](){}:;,."))
    return scrubbed.isEmpty
  }

  private static func compactDetailLine(_ value: String) -> String {
    compactVisibleFileReferences(
      value
        .replacingOccurrences(
          of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression
        )
        .replacingOccurrences(of: "**", with: "")
        .replacingOccurrences(of: "└ ", with: "")
        .replacingOccurrences(of: "│ ", with: "")
        .replacingOccurrences(of: #"^>\s+"#, with: "", options: .regularExpression)
        .replacingOccurrences(of: "… +", with: "... +")
        .trimmed)
  }

  private static func compactVisibleFileReferences(_ value: String) -> String {
    let extensions =
      #"swift|dart|kt|java|gradle|properties|plist|xcconfig|xcodeproj|xcworkspace|py|js|ts|tsx|jsx|css|scss|html|xml|json|ya?ml|toml|md|txt|csv|log|sh|zsh|ps1|rs|go|c|cc|cpp|h|hpp|png|jpe?g|gif|heic|tiff?|bmp|webp|mp4|mov|m4v|webm|avi|mkv|pdf|apk|ipa|pkg|dmg|zip|tar|tgz|gz"#
    let absolutePattern =
      #"(?:(?:~)|(?:/Users/[A-Za-z0-9._-]+)|(?:/private/tmp)|(?:/tmp))[^ \t\r\n"'<>|()\[\]]*\.(?:\#(extensions))"#
    let relativePattern =
      #"(?:(?:[A-Za-z0-9._-]+/)+)[A-Za-z0-9._@+-]+\.(?:\#(extensions))"#
    return replacePaths(
      in: replacePaths(in: value, pattern: absolutePattern), pattern: relativePattern)
  }

  private static func replacePaths(in value: String, pattern: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
      return value
    }
    let output = NSMutableString(string: value)
    let matches = regex.matches(in: value, range: NSRange(value.startIndex..., in: value))
    for match in matches.reversed() {
      let path = (value as NSString).substring(with: match.range)
      let name = URL(fileURLWithPath: path).lastPathComponent
      output.replaceCharacters(in: match.range, with: name.isEmpty ? path : name)
    }
    return output as String
  }

  private static func fileReferences(from lines: [String]) -> [CodexInlineFileReference] {
    let value = lines.joined(separator: "\n")
    let extensions =
      #"swift|dart|kt|java|gradle|properties|plist|xcconfig|xcodeproj|xcworkspace|py|js|ts|tsx|jsx|css|scss|html|xml|json|ya?ml|toml|md|txt|csv|log|sh|zsh|ps1|rs|go|c|cc|cpp|h|hpp|png|jpe?g|gif|heic|tiff?|bmp|webp|pdf|apk|ipa|pkg|dmg|zip|tar|tgz|gz"#
    var references: [CodexInlineFileReference] = []
    var seen: Set<String> = []

    func add(path rawPath: String, label rawLabel: String = "") {
      let path = normalizeReferencePath(rawPath)
      guard looksLikeReferencePath(path, extensions: extensions), !seen.contains(path) else {
        return
      }
      seen.insert(path)
      references.append(CodexInlineFileReference(path: path, label: rawLabel.trimmed))
    }

    for match in matches(
      in: value,
      pattern: #"\[([^\]\n]{1,90})\]\(([^)\s]+)\)"#
    ) {
      if match.count >= 2 {
        add(path: match[1], label: match[0])
      }
    }

    for match in matches(
      in: value,
      pattern: #"`([^`\n]*\.(?:\#(extensions))[^`\n]*)`"#
    ) {
      if let path = match.first {
        add(path: path)
      }
    }

    for match in matches(
      in: value,
      pattern:
        #"((?:(?:~)|(?:/Users/[A-Za-z0-9._-]+)|(?:/private/tmp)|(?:/tmp))[^ \t\r\n"'<>|)]*\.(?:\#(extensions))[^ \t\r\n"'<>|)]*)"#
    ) {
      if let path = match.first {
        add(path: path)
      }
    }

    for match in matches(
      in: value,
      pattern:
        #"((?:[A-Za-z0-9._-]+/)+[A-Za-z0-9._@+-]+\.(?:\#(extensions))[^ \t\r\n"'<>|)]*)"#
    ) {
      if let path = match.first {
        add(path: path)
      }
    }

    for match in matches(
      in: value,
      pattern:
        #"(^|[\s:：,;()\[\]<>`"'•*\-])([A-Za-z0-9][A-Za-z0-9._@+\-]{0,140}\.(?:\#(extensions)))(?=$|[\s,;:：)\]}>`"'])"#
    ) {
      if match.count >= 2 {
        add(path: match[1])
      }
    }

    for line in value.components(separatedBy: .newlines) {
      let candidate = fileReferenceCandidateLine(line)
      guard looksLikeBareFileLine(candidate) else { continue }
      add(path: candidate)
    }

    return Array(references.prefix(12))
  }

  private static func fileReferenceCandidateLine(_ value: String) -> String {
    normalizedLine(value)
      .replacingOccurrences(of: #"^[-•*]\s+"#, with: "", options: .regularExpression)
      .replacingOccurrences(
        of:
          #"^(?:코드\s*반영\s*파일|변경\s*파일|생성\s*파일|갱신\s*파일|검증|파일|산출물|files?|outputs?|artifacts?|reports?)\s*[:：]\s*"#,
        with: "",
        options: [.regularExpression, .caseInsensitive]
      )
      .trimmed
  }

  private static func normalizeReferencePath(_ value: String) -> String {
    var path = value.trimmingCharacters(
      in: CharacterSet(charactersIn: " \t\r\n\"'`<>[]{}(),;:"))
    if !path.hasPrefix("/") && !path.hasPrefix("~/"),
      path.rangeOfCharacter(from: .whitespacesAndNewlines) != nil
    {
      let tokens =
        path
        .components(separatedBy: .whitespacesAndNewlines)
        .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`<>[]{}(),;:")) }
        .filter { !$0.isEmpty && !$0.hasPrefix("-") }
      if let candidate = tokens.last(where: { $0.contains(".") && !$0.hasPrefix("$") }) {
        path = candidate
      }
    }
    if path.hasPrefix("Users/") {
      path = "/" + path
    }
    if let anchor = path.firstIndex(of: "#") {
      path = String(path[..<anchor])
    }
    while path.hasSuffix(".") {
      path.removeLast()
    }
    let name = URL(fileURLWithPath: path).lastPathComponent
    guard !name.hasPrefix(".") else { return "" }
    return path
  }

  private static func looksLikeReferencePath(_ path: String, extensions: String) -> Bool {
    guard !path.isEmpty, !path.contains("://") else { return false }
    guard !path.contains("*"), !path.contains("$("), !path.contains("${") else { return false }
    let lower = path.lowercased()
    let firstToken =
      lower.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init) ?? ""
    guard
      !["python", "python3", "dart", "flutter", "bash", "zsh", "swift", "node", "npm", "npx"]
        .contains(firstToken)
    else { return false }
    guard !lower.contains("/.gradle/caches/"), !lower.contains("gradledaemon"),
      !lower.contains("kotlincompiledaemon"), !lower.contains("/.tools/"),
      !lower.contains("/.dart_tool/"), !lower.contains("/build/unit_test_assets/"),
      !lower.contains("/bin/cache/"), !lower.contains("/.pub-cache/"),
      !lower.contains("flutter_tester"), !lower.contains("--packages="),
      !lower.contains("dartaotruntime"), !lower.contains("frontend_server"),
      !lower.contains("/.codex/"), !lower.contains("extensions/chronicle/resources/"),
      !lower.contains("/tmp/a-control"), !lower.contains("/private/tmp/a-control")
    else { return false }
    let name = URL(fileURLWithPath: path).lastPathComponent.lowercased()
    guard !(name.hasPrefix("rollout-") && (name.hasSuffix(".json") || name.hasSuffix(".jsonl")))
    else { return false }
    let pattern = #"\.(?:\#(extensions))$"#
    guard path.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil else {
      return false
    }
    if !path.hasPrefix("/") && !path.hasPrefix("~/") {
      let firstComponent = path.split(separator: "/").first.map(String.init) ?? ""
      if path.contains("/"), firstComponent.contains(".") {
        return false
      }
    }
    return path.hasPrefix("/")
      || path.hasPrefix("~/")
      || path.contains("/")
      || path.contains(".")
  }

  private static func matches(in value: String, pattern: String) -> [[String]] {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
      return []
    }
    let range = NSRange(value.startIndex..., in: value)
    return regex.matches(in: value, range: range).map { match in
      (1..<match.numberOfRanges).compactMap { index in
        let range = match.range(at: index)
        guard let swiftRange = Range(range, in: value) else { return nil }
        return String(value[swiftRange])
      }
    }
  }

  private static func clean(_ value: String) -> String {
    value
      .replacingOccurrences(
        of: #"(?is)<oai-mem-citation>.*?</oai-mem-citation>"#,
        with: "\n",
        options: .regularExpression
      )
      .replacingOccurrences(
        of: "\u{001B}\\][^\u{0007}]*(\u{0007}|\u{001B}\\\\)", with: "", options: .regularExpression
      )
      .replacingOccurrences(
        of: "\u{001B}\\[[0-9;?]*[ -/]*[@-~]", with: "", options: .regularExpression
      )
      .replacingOccurrences(of: "\r", with: "\n")
      .replacingOccurrences(of: "  ", with: " ")
  }
}

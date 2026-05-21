import AppKit
import SwiftUI

enum AControlStyle {
  static let panelRadius: CGFloat = 18
  static let insetRadius: CGFloat = 16
  static let controlHeight: CGFloat = 38
  static let headerTitleSize: CGFloat = 24
  static let headerDetailSize: CGFloat = 13
  static let pageTopPadding: CGFloat = 34

  static func appBackground(_ scheme: ColorScheme) -> AnyShapeStyle {
    if scheme == .dark {
      return AnyShapeStyle(
        LinearGradient(
          colors: [
            Color(red: 0.055, green: 0.060, blue: 0.070),
            Color(red: 0.035, green: 0.038, blue: 0.048),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      )
    }
    return AnyShapeStyle(
      LinearGradient(
        colors: [
          Color(red: 0.996, green: 0.997, blue: 0.999),
          Color(red: 0.974, green: 0.982, blue: 0.990),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    )
  }

  static func panelFill(_ scheme: ColorScheme) -> AnyShapeStyle {
    if scheme == .dark {
      return AnyShapeStyle(Color.white.opacity(0.055))
    }
    return AnyShapeStyle(Color.white.opacity(0.94))
  }

  static func insetFill(_ scheme: ColorScheme) -> AnyShapeStyle {
    if scheme == .dark {
      return AnyShapeStyle(Color.black.opacity(0.18))
    }
    return AnyShapeStyle(Color.white.opacity(0.88))
  }

  static func transcriptFill(_ scheme: ColorScheme) -> AnyShapeStyle {
    if scheme == .dark {
      return AnyShapeStyle(Color(red: 0.040, green: 0.043, blue: 0.047))
    }
    return AnyShapeStyle(Color.white.opacity(0.98))
  }

  static func hairline(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.075)
  }

  static func softShadow(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color.black.opacity(0.28) : Color.black.opacity(0.045)
  }

  static func accentFill(_ color: Color, _ scheme: ColorScheme) -> Color {
    color.opacity(scheme == .dark ? 0.11 : 0.048)
  }

  static func accentStroke(_ color: Color, _ scheme: ColorScheme) -> Color {
    color.opacity(scheme == .dark ? 0.16 : 0.095)
  }

  static func accentForeground(_ color: Color, _ scheme: ColorScheme) -> Color {
    color.opacity(scheme == .dark ? 0.80 : 0.58)
  }

  static func contentPadding(for width: CGFloat) -> CGFloat {
    if width < 900 { return 14 }
    if width < 1250 { return 18 }
    return 22
  }
}

struct ImmediateFeedbackButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.975 : 1)
      .opacity(configuration.isPressed ? 0.82 : 1)
      .brightness(configuration.isPressed ? -0.035 : 0)
      .animation(.linear(duration: 0.035), value: configuration.isPressed)
  }
}

extension View {
  func safeHelp(_ text: String) -> some View {
    accessibilityHint(Text(text))
  }
}

struct GlassPanel<Content: View>: View {
  @Environment(\.colorScheme) private var colorScheme
  var title: String?
  var symbol: String?
  var accent: Color = .cyan
  var fillHeight = false
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      if let title {
        HStack(spacing: 9) {
          if let symbol {
            Image(systemName: symbol)
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(AControlStyle.accentForeground(accent, colorScheme))
          }
          Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
          Spacer()
        }
      }
      content
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: fillHeight ? .infinity : nil, alignment: .topLeading)
    .background(
      AControlStyle.panelFill(colorScheme),
      in: RoundedRectangle(cornerRadius: AControlStyle.panelRadius, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: AControlStyle.panelRadius, style: .continuous)
        .strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
    }
    .shadow(color: AControlStyle.softShadow(colorScheme), radius: 16, x: 0, y: 8)
  }
}

struct MetricCard: View {
  @Environment(\.colorScheme) private var colorScheme
  var title: String
  var value: String
  var subtitle: String = ""
  var symbol: String
  var tint: Color
  var valueSize: CGFloat = 21
  var valueLineLimit: Int = 2
  var subtitleLineLimit: Int = 2
  var minHeight: CGFloat = 112
  var fixedHeight: CGFloat?
  var padding: CGFloat = 16

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Image(systemName: symbol)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(AControlStyle.accentForeground(tint, colorScheme))
          .frame(width: 28, height: 28)
          .background(AControlStyle.accentFill(tint, colorScheme), in: Circle())
        Text(title)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Spacer()
      }
      Text(value.isEmpty ? "—" : value)
        .font(.system(size: valueSize, weight: .bold))
        .lineLimit(valueLineLimit)
        .minimumScaleFactor(0.55)
      if !subtitle.isEmpty {
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(subtitleLineLimit)
      }
    }
    .frame(
      maxWidth: .infinity, minHeight: fixedHeight ?? minHeight, maxHeight: fixedHeight,
      alignment: .leading
    )
    .padding(padding)
    .background(
      AControlStyle.panelFill(colorScheme),
      in: RoundedRectangle(cornerRadius: AControlStyle.panelRadius, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: AControlStyle.panelRadius, style: .continuous)
        .strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
    }
    .shadow(color: AControlStyle.softShadow(colorScheme), radius: 12, x: 0, y: 6)
  }
}

struct TranscriptView: View {
  @Environment(\.colorScheme) private var colorScheme
  var text: String
  var placeholder: String
  var scrollSignal: Int = 0
  var followTailSignal: Int = 0
  var autoScrollsOnTextChange = true
  var onBottomStateChange: ((Bool) -> Void)? = nil

  var body: some View {
    PlainTranscriptRepresentable(
      text: text,
      placeholder: placeholder,
      isPlaceholder: text.isEmpty,
      scheme: colorScheme,
      scrollSignal: scrollSignal,
      followTailSignal: followTailSignal,
      autoScrollsOnTextChange: autoScrollsOnTextChange,
      onBottomStateChange: onBottomStateChange
    )
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
}

private struct PlainTranscriptRepresentable: NSViewRepresentable {
  var text: String
  var placeholder: String
  var isPlaceholder: Bool
  var scheme: ColorScheme
  var scrollSignal: Int
  var followTailSignal: Int
  var autoScrollsOnTextChange: Bool
  var onBottomStateChange: ((Bool) -> Void)?

  func makeNSView(context: Context) -> PlainTranscriptScrollView {
    PlainTranscriptScrollView()
  }

  func updateNSView(_ scrollView: PlainTranscriptScrollView, context: Context) {
    scrollView.onBottomStateChange = onBottomStateChange
    scrollView.applyAppearance(scheme: scheme, isPlaceholder: isPlaceholder)
    let renderedText = context.coordinator.renderedText(
      rawText: text,
      placeholder: placeholder,
      isPlaceholder: isPlaceholder
    )

    let shouldRender =
      context.coordinator.lastRenderedText != renderedText
      || context.coordinator.lastIsPlaceholder != isPlaceholder
      || context.coordinator.lastScheme != scheme

    if shouldRender {
      let shouldFollow =
        autoScrollsOnTextChange
        && (context.coordinator.lastRenderedText == nil
          || scrollView.shouldFollowTailOnContentChange)
      context.coordinator.lastRenderedText = renderedText
      context.coordinator.lastIsPlaceholder = isPlaceholder
      context.coordinator.lastScheme = scheme
      scrollView.setTranscript(renderedText, scrollToBottom: shouldFollow)
    } else {
      scrollView.reportBottomState()
    }

    if context.coordinator.lastScrollSignal != scrollSignal {
      context.coordinator.lastScrollSignal = scrollSignal
      scrollView.forceFollowTail(animated: true)
    }

    if context.coordinator.lastFollowTailSignal != followTailSignal {
      context.coordinator.lastFollowTailSignal = followTailSignal
      scrollView.forceFollowTail(animated: false)
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  final class Coordinator {
    private let ansiPattern = "\u{001B}\\[[0-9;?]*[ -/]*[@-~]"
    private let ruleCharacters = CharacterSet(charactersIn: "-_─━═=╌┄┈…·. ")
    private var lastRawText: String?
    private var lastCleanedText = ""
    var lastRenderedText: String?
    var lastIsPlaceholder = false
    var lastScheme: ColorScheme?
    var lastScrollSignal = 0
    var lastFollowTailSignal = 0

    func renderedText(rawText: String, placeholder: String, isPlaceholder: Bool) -> String {
      guard !isPlaceholder else { return placeholder }
      guard lastRawText != rawText else { return lastCleanedText }
      lastRawText = rawText
      lastCleanedText = clean(rawText)
      return lastCleanedText
    }

    private func clean(_ value: String) -> String {
      value
        .replacingOccurrences(of: ansiPattern, with: "", options: .regularExpression)
        .replacingOccurrences(of: "\r", with: "\n")
        .components(separatedBy: .newlines)
        .filter { !isHorizontalRule($0.trimmingCharacters(in: .whitespaces)) }
        .joined(separator: "\n")
    }

    private func isHorizontalRule(_ line: String) -> Bool {
      guard line.count >= 18 else { return false }
      return line.unicodeScalars.allSatisfy { ruleCharacters.contains($0) }
    }
  }
}

private final class PlainTranscriptScrollView: NSScrollView {
  private let textView = NSTextView()
  private let bottomTolerance: CGFloat = 28
  private var isProgrammaticScroll = false
  private var followsTail = true
  private var lastReportedBottomState: Bool?
  var onBottomStateChange: ((Bool) -> Void)?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    drawsBackground = false
    borderType = .noBorder
    hasVerticalScroller = true
    autohidesScrollers = true
    horizontalScrollElasticity = .none
    verticalScrollElasticity = .automatic
    contentView.postsBoundsChangedNotifications = true
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(boundsDidChange),
      name: NSView.boundsDidChangeNotification,
      object: contentView
    )

    textView.drawsBackground = false
    textView.isEditable = false
    textView.isSelectable = true
    textView.isRichText = false
    textView.importsGraphics = false
    textView.allowsUndo = false
    textView.isAutomaticSpellingCorrectionEnabled = false
    textView.isContinuousSpellCheckingEnabled = false
    textView.isGrammarCheckingEnabled = false
    textView.textContainerInset = NSSize(width: 18, height: 18)
    textView.textContainer?.lineFragmentPadding = 0
    textView.textContainer?.widthTracksTextView = true
    textView.textContainer?.containerSize = NSSize(
      width: contentView.bounds.width, height: .greatestFiniteMagnitude)
    textView.layoutManager?.allowsNonContiguousLayout = true
    textView.isHorizontallyResizable = false
    textView.isVerticallyResizable = true
    textView.minSize = NSSize(width: 0, height: 0)
    textView.maxSize = NSSize(
      width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    textView.autoresizingMask = [.width]
    documentView = textView
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  var shouldFollowTailOnContentChange: Bool {
    followsTail || isAtBottom
  }

  func applyAppearance(scheme: ColorScheme, isPlaceholder: Bool) {
    textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    textView.textColor = isPlaceholder ? placeholderColor(scheme) : foregroundColor(scheme)
    textView.insertionPointColor = foregroundColor(scheme)
  }

  func setTranscript(_ value: String, scrollToBottom shouldScrollToBottom: Bool) {
    isProgrammaticScroll = shouldScrollToBottom
    let oldSelectedRanges = textView.selectedRanges
    textView.string = value
    let length = (value as NSString).length
    textView.selectedRanges = oldSelectedRanges.filter { rangeValue in
      rangeValue.rangeValue.upperBound <= length
    }
    if let textContainer = textView.textContainer {
      textView.layoutManager?.ensureLayout(for: textContainer)
    }
    if shouldScrollToBottom {
      followsTail = true
      scheduleBottomPin()
    } else {
      isProgrammaticScroll = false
      reportBottomState()
    }
  }

  func forceFollowTail(animated: Bool) {
    followsTail = true
    isProgrammaticScroll = true
    if animated {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.16
        scrollToBottom()
      } completionHandler: {
        DispatchQueue.main.async {
          self.scheduleBottomPin()
        }
      }
    } else {
      scheduleBottomPin()
    }
  }

  fileprivate func reportBottomState(force: Bool = false) {
    let atBottom = isAtBottom
    guard force || lastReportedBottomState != atBottom else { return }
    lastReportedBottomState = atBottom
    onBottomStateChange?(atBottom)
  }

  private var isAtBottom: Bool {
    distanceToBottom <= bottomTolerance
  }

  private var distanceToBottom: CGFloat {
    guard let documentView else { return 0 }
    documentView.layoutSubtreeIfNeeded()
    contentView.layoutSubtreeIfNeeded()
    guard documentView.bounds.height > contentView.bounds.height + bottomTolerance else { return 0 }
    return max(0, documentView.bounds.maxY - contentView.documentVisibleRect.maxY)
  }

  private func scheduleBottomPin() {
    scrollToBottom()
    DispatchQueue.main.async { [weak self] in
      self?.scrollToBottom()
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
        self?.scrollToBottom()
        self?.isProgrammaticScroll = false
      }
    }
  }

  private func scrollToBottom() {
    guard let documentView else { return }
    documentView.layoutSubtreeIfNeeded()
    contentView.layoutSubtreeIfNeeded()
    let y = max(0, documentView.bounds.height - contentView.bounds.height)
    contentView.scroll(to: NSPoint(x: 0, y: y))
    reflectScrolledClipView(contentView)
    reportBottomState(force: true)
  }

  @objc private func boundsDidChange() {
    if isProgrammaticScroll {
      reportBottomState()
      return
    }
    if isAtBottom {
      followsTail = true
    } else if distanceToBottom > bottomTolerance {
      followsTail = false
    }
    reportBottomState()
  }

  private func foregroundColor(_ scheme: ColorScheme) -> NSColor {
    scheme == .dark ? NSColor(calibratedWhite: 0.92, alpha: 1) : NSColor.labelColor
  }

  private func placeholderColor(_ scheme: ColorScheme) -> NSColor {
    scheme == .dark ? NSColor(calibratedWhite: 0.68, alpha: 1) : NSColor.secondaryLabelColor
  }
}

struct PrimaryButton: View {
  var title: String
  var symbol: String
  var tint: Color = .cyan
  var minWidth: CGFloat?
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(title, systemImage: symbol)
        .font(.system(size: 13, weight: .semibold))
        .lineLimit(1)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(minWidth: minWidth, minHeight: AControlStyle.controlHeight)
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .accessibilityLabel(Text(title))
    .foregroundStyle(.primary)
    .background(AControlStyle.accentFill(tint, colorScheme), in: Capsule())
    .overlay {
      Capsule().strokeBorder(AControlStyle.accentStroke(tint, colorScheme), lineWidth: 1)
    }
  }

  @Environment(\.colorScheme) private var colorScheme
}

struct RefreshIconButton: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var isRefreshing = false
  @State private var rotation = 0.0
  var action: () async -> Void

  var body: some View {
    Button {
      guard !isRefreshing else { return }
      Task { @MainActor in
        isRefreshing = true
        await action()
        try? await Task.sleep(nanoseconds: 180_000_000)
        isRefreshing = false
      }
    } label: {
      Image(systemName: "arrow.clockwise")
        .font(.system(size: 12.5, weight: .bold))
        .rotationEffect(.degrees(rotation))
        .frame(width: 28, height: 28)
        .contentShape(Circle())
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .foregroundStyle(AControlStyle.accentForeground(.gray, colorScheme))
    .background(AControlStyle.accentFill(.gray, colorScheme), in: Circle())
    .overlay {
      Circle().strokeBorder(AControlStyle.accentStroke(.gray, colorScheme), lineWidth: 1)
    }
    .onChange(of: isRefreshing) { _, refreshing in
      if refreshing {
        rotation = 0
        withAnimation(.linear(duration: 0.72).repeatForever(autoreverses: false)) {
          rotation = 360
        }
      } else {
        withAnimation(.easeOut(duration: 0.16)) {
          rotation = 0
        }
      }
    }
    .safeHelp("Refresh")
  }
}

struct SoftButton: View {
  var title: String
  var symbol: String?
  var minWidth: CGFloat?
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 7) {
        if let symbol {
          Image(systemName: symbol)
        }
        Text(title)
          .lineLimit(1)
      }
      .font(.system(size: 13, weight: .semibold))
      .padding(.horizontal, 14)
      .padding(.vertical, 9)
      .frame(minWidth: minWidth, minHeight: AControlStyle.controlHeight)
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .accessibilityLabel(Text(title))
    .background(AControlStyle.insetFill(colorScheme), in: Capsule())
    .overlay {
      Capsule().strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
    }
  }

  @Environment(\.colorScheme) private var colorScheme
}

struct SectionHeader: View {
  var title: String
  var detail: String?
  var refreshAction: (() async -> Void)? = nil

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .center, spacing: 10) {
          headerTitle
          if let detail {
            headerDetail(detail)
          }
        }
        VStack(alignment: .leading, spacing: 4) {
          headerTitle
          if let detail {
            headerDetail(detail)
          }
        }
      }

      Spacer(minLength: 12)

      if let refreshAction {
        RefreshIconButton(action: refreshAction)
          .padding(.top, 1)
      }
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
  }

  private var headerTitle: some View {
    Text(title)
      .font(.system(size: AControlStyle.headerTitleSize, weight: .bold))
      .lineLimit(1)
      .minimumScaleFactor(0.86)
  }

  private func headerDetail(_ value: String) -> some View {
    Text(value)
      .font(.system(size: AControlStyle.headerDetailSize, weight: .medium))
      .foregroundStyle(.secondary)
      .lineLimit(1)
      .truncationMode(.middle)
  }
}

struct ThemeHoverButton: View {
  @Environment(\.colorScheme) private var colorScheme
  var isDark: Bool
  var action: () -> Void

  var body: some View {
    Button {
      action()
    } label: {
      Image(systemName: isDark ? "sun.max" : "moon")
        .font(.system(size: 13, weight: .bold))
        .frame(width: 30, height: 30)
        .contentShape(Circle())
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .foregroundStyle(AControlStyle.accentForeground(.indigo, colorScheme))
    .background(AControlStyle.accentFill(.indigo, colorScheme), in: Circle())
    .overlay {
      Circle().strokeBorder(AControlStyle.accentStroke(.indigo, colorScheme), lineWidth: 1)
    }
    .safeHelp(isDark ? "Switch this transcript to light" : "Switch this transcript to dark")
  }
}

struct TranscriptScrollButton: View {
  @Environment(\.colorScheme) private var colorScheme
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "arrow.down.to.line.compact")
        .font(.system(size: 12.5, weight: .semibold))
        .foregroundStyle(AControlStyle.accentForeground(.purple, colorScheme))
        .frame(width: 34, height: 34)
        .contentShape(Circle())
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .background(AControlStyle.insetFill(colorScheme), in: Circle())
    .overlay {
      Circle().strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
    }
    .shadow(color: AControlStyle.softShadow(colorScheme), radius: 10, x: 0, y: 5)
    .safeHelp("Scroll to bottom")
  }
}

struct RemoteDirectoryPicker: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme
  var title: String
  var useDirectory: (String) -> Void
  @State private var newDirectoryName = ""
  @State private var isCreatingDirectory = false
  @State private var browsingPath = ""
  @State private var browsingItems: [RemoteItem] = []
  @State private var isLoadingBrowsingItems = false
  @State private var browseRequestID = 0
  @State private var initialBrowsingPath = ""
  @State private var didInitializeBrowser = false

  private var directories: [RemoteItem] {
    browsingItems
      .filter(\.isDirectory)
      .sorted { first, second in
        let firstHidden = first.name.hasPrefix(".")
        let secondHidden = second.name.hasPrefix(".")
        if firstHidden != secondHidden {
          return !firstHidden
        }
        return first.name.localizedStandardCompare(second.name) == .orderedAscending
      }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.system(size: 22, weight: .bold))
          Text(activeBrowsingPath)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
        }
        Spacer()
        SoftButton(title: "Cancel", symbol: "xmark") {
          dismiss()
        }
      }

      VStack(spacing: 6) {
        DirectoryPickerRow(name: "..", subtitle: "Parent directory", symbol: "arrow.up.folder") {
          Task {
            let parent = URL(fileURLWithPath: activeBrowsingPath).deletingLastPathComponent().path
            await openDirectory(parent == "/" ? "/" : parent)
          }
        }

        ScrollView {
          LazyVStack(spacing: 6) {
            ForEach(directories) { item in
              DirectoryPickerRow(name: item.name, subtitle: item.path, symbol: "folder.fill") {
                Task { await openDirectory(item.path) }
              }
            }
            if isLoadingBrowsingItems && directories.isEmpty {
              VStack(spacing: 10) {
                ProgressView()
                  .controlSize(.small)
                Text("Loading folders...")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.secondary)
              }
              .frame(maxWidth: .infinity, minHeight: 180)
            } else if !isLoadingBrowsingItems && directories.isEmpty {
              Text("No child folders")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 180)
            }
          }
          .padding(8)
        }
        .background(
          AControlStyle.insetFill(colorScheme),
          in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
        }
      }
      .layoutPriority(1)

      HStack {
        Text("\(directories.count) folder(s)")
          .font(.caption)
          .foregroundStyle(.secondary)
        if isLoadingBrowsingItems {
          ProgressView()
            .controlSize(.small)
        }
        Spacer()
        TextField("New directory", text: $newDirectoryName)
          .textFieldStyle(.plain)
          .font(.caption.weight(.semibold))
          .padding(.horizontal, 10)
          .frame(width: 150, height: 34)
          .background(AControlStyle.insetFill(colorScheme), in: Capsule())
          .overlay {
            Capsule().strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
          }
          .onSubmit {
            createDirectory()
          }
        SoftButton(title: "New Dir", symbol: "folder.badge.plus") {
          createDirectory()
        }
        .disabled(newDirectoryName.trimmed.isEmpty || isCreatingDirectory)
        PrimaryButton(title: "Use Current", symbol: "checkmark.circle", tint: .blue) {
          useDirectory(activeBrowsingPath)
          dismiss()
        }
      }
    }
    .padding(20)
    .frame(width: 560, height: 520)
    .background(AControlStyle.appBackground(colorScheme))
    .task {
      guard !didInitializeBrowser else { return }
      didInitializeBrowser = true
      let preferredPath =
        browsingPath.trimmed.isEmpty
        ? (model.fileBrowserDir.trimmed.isEmpty ? model.currentRemoteDir : model.fileBrowserDir)
        : browsingPath
      let initialPath = model.normalizedRemotePath(preferredPath)
      initialBrowsingPath = initialPath
      await openDirectory(initialPath)
      Task(priority: .userInitiated) {
        await model.preloadDirectoryTree(around: initialPath, depth: 3)
      }
    }
  }

  private var activeBrowsingPath: String {
    if !browsingPath.trimmed.isEmpty {
      return browsingPath
    }
    if !initialBrowsingPath.trimmed.isEmpty {
      return initialBrowsingPath
    }
    return model.normalizedRemotePath(
      model.fileBrowserDir.trimmed.isEmpty ? model.currentRemoteDir : model.fileBrowserDir)
  }

  private func openDirectory(_ path: String) async {
    let normalizedPath = model.normalizedRemotePath(path)
    browseRequestID += 1
    let requestID = browseRequestID
    browsingPath = normalizedPath
    if let cached = model.cachedDirectoryItems(for: normalizedPath) {
      browsingItems = cached
      isLoadingBrowsingItems = false
      Task(priority: .userInitiated) {
        await model.preloadDirectoryTree(around: normalizedPath, depth: 2)
      }
      return
    }
    isLoadingBrowsingItems = true
    let items = await model.directoryItems(for: normalizedPath, force: false)
    guard requestID == browseRequestID, browsingPath == normalizedPath else { return }
    if !items.isEmpty || browsingItems.isEmpty {
      browsingItems = items
    }
    isLoadingBrowsingItems = false
    Task(priority: .userInitiated) {
      await model.preloadDirectoryTree(around: normalizedPath, depth: 2)
    }
  }

  private func createDirectory() {
    let name = newDirectoryName.trimmed
    guard !name.isEmpty, !isCreatingDirectory else { return }
    isCreatingDirectory = true
    Task {
      if let path = await model.createRemoteDirectory(named: name, in: activeBrowsingPath) {
        newDirectoryName = ""
        await openDirectory(path)
      }
      isCreatingDirectory = false
    }
  }
}

private struct DirectoryPickerRow: View {
  @Environment(\.colorScheme) private var colorScheme
  var name: String
  var subtitle: String
  var symbol: String
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: symbol)
          .foregroundStyle(AControlStyle.accentForeground(.blue, colorScheme))
          .frame(width: 22)
        VStack(alignment: .leading, spacing: 2) {
          Text(name)
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
          Text(subtitle)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
        }
        Spacer()
      }
      .padding(.horizontal, 12)
      .frame(height: 42)
      .background(
        Color.primary.opacity(colorScheme == .dark ? 0.055 : 0.035),
        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
  }
}

struct FlowLayout: Layout {
  var spacing: CGFloat = 10

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let width = proposal.width ?? 640
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    for view in subviews {
      let size = view.sizeThatFits(.unspecified)
      if x + size.width > width, x > 0 {
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
      }
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
    return CGSize(width: width, height: y + rowHeight)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    var x = bounds.minX
    var y = bounds.minY
    var rowHeight: CGFloat = 0
    for view in subviews {
      let size = view.sizeThatFits(.unspecified)
      if x + size.width > bounds.maxX, x > bounds.minX {
        x = bounds.minX
        y += rowHeight + spacing
        rowHeight = 0
      }
      view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
  }
}

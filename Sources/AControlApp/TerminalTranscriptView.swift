import AppKit
import SwiftUI

struct TerminalTranscriptView: NSViewRepresentable {
  @Environment(\.colorScheme) private var colorScheme
  var text: String
  var placeholder: String
  var currentDirectory: String = ""
  var scrollSignal: Int = 0
  var onBottomStateChange: ((Bool) -> Void)? = nil

  func makeNSView(context: Context) -> TerminalTranscriptScrollView {
    TerminalTranscriptScrollView()
  }

  func updateNSView(_ scrollView: TerminalTranscriptScrollView, context: Context) {
    let source = text.isEmpty ? placeholder : text
    let isPlaceholder = text.isEmpty
    scrollView.onBottomStateChange = onBottomStateChange

    let shouldRender =
      context.coordinator.lastSource != source
      || context.coordinator.lastIsPlaceholder != isPlaceholder
      || context.coordinator.lastCurrentDirectory != currentDirectory
      || context.coordinator.lastScheme != colorScheme

    if shouldRender {
      let shouldStayPinned = context.coordinator.lastSource == nil || scrollView.isAtBottom
      let renderer = TerminalTranscriptRenderer(currentDirectory: currentDirectory)
      let rows = renderer.rows(from: source, isPlaceholder: isPlaceholder, scheme: colorScheme)
      context.coordinator.lastSource = source
      context.coordinator.lastIsPlaceholder = isPlaceholder
      context.coordinator.lastCurrentDirectory = currentDirectory
      context.coordinator.lastScheme = colorScheme
      scrollView.setRows(rows, scrollToBottom: shouldStayPinned)
    } else {
      scrollView.reportBottomState()
    }

    if context.coordinator.lastScrollSignal != scrollSignal {
      context.coordinator.lastScrollSignal = scrollSignal
      scrollView.scrollToBottom()
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  final class Coordinator {
    var lastScrollSignal = 0
    var lastSource: String?
    var lastIsPlaceholder = false
    var lastCurrentDirectory = ""
    var lastScheme: ColorScheme?
  }
}

final class TerminalTranscriptScrollView: NSScrollView {
  private let stackView = NSStackView()
  private let horizontalInset: CGFloat = 34
  private let trailingInset: CGFloat = 40
  private let bottomTolerance: CGFloat = 72
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

    stackView.orientation = .vertical
    stackView.alignment = .width
    stackView.spacing = 2
    stackView.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    stackView.translatesAutoresizingMaskIntoConstraints = false

    let document = FlippedTranscriptDocumentView()
    document.translatesAutoresizingMaskIntoConstraints = false
    document.addSubview(stackView)
    documentView = document

    NSLayoutConstraint.activate([
      stackView.leadingAnchor.constraint(
        equalTo: document.leadingAnchor, constant: horizontalInset),
      stackView.trailingAnchor.constraint(
        equalTo: document.trailingAnchor, constant: -trailingInset),
      stackView.topAnchor.constraint(equalTo: document.topAnchor, constant: 20),
      stackView.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -20),
      document.widthAnchor.constraint(equalTo: contentView.widthAnchor),
    ])
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  fileprivate var isAtBottom: Bool {
    guard let documentView else { return true }
    documentView.layoutSubtreeIfNeeded()
    contentView.layoutSubtreeIfNeeded()
    let documentHeight = documentView.bounds.height
    let viewportHeight = contentView.bounds.height
    guard viewportHeight > 0 else { return true }
    guard documentHeight > viewportHeight + bottomTolerance else { return true }

    let distanceToBottom = documentView.bounds.maxY - contentView.documentVisibleRect.maxY
    return distanceToBottom <= bottomTolerance
  }

  fileprivate func setRows(
    _ rows: [TerminalTranscriptRow], scrollToBottom shouldScrollToBottom: Bool
  ) {
    stackView.arrangedSubviews.forEach {
      stackView.removeArrangedSubview($0)
      $0.removeFromSuperview()
    }

    for row in rows {
      let rowView = TerminalTranscriptRowView(row: row)
      stackView.addArrangedSubview(rowView)
      rowView.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
    }

    if shouldScrollToBottom {
      DispatchQueue.main.async { [weak self] in
        self?.scrollToBottom()
        DispatchQueue.main.async { [weak self] in
          self?.scrollToBottom()
        }
      }
    } else {
      reportBottomState()
    }
  }

  fileprivate func scrollToBottom() {
    guard let documentView else { return }
    documentView.layoutSubtreeIfNeeded()
    contentView.layoutSubtreeIfNeeded()
    let y = max(0, documentView.bounds.height - contentView.bounds.height)
    contentView.scroll(to: NSPoint(x: 0, y: y))
    reflectScrolledClipView(contentView)
    reportBottomState(force: true)
    DispatchQueue.main.async { [weak self] in
      self?.reportBottomState(force: true)
    }
  }

  @objc private func boundsDidChange() {
    reportBottomState()
  }

  fileprivate func reportBottomState(force: Bool = false) {
    guard documentView != nil else {
      onBottomStateChange?(true)
      return
    }
    let isAtBottom = self.isAtBottom
    guard force || lastReportedBottomState != isAtBottom else { return }
    lastReportedBottomState = isAtBottom
    onBottomStateChange?(isAtBottom)
  }
}

private final class FlippedTranscriptDocumentView: NSView {
  override var isFlipped: Bool { true }
}

private final class TerminalTranscriptRowView: NSView {
  init(row: TerminalTranscriptRow) {
    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = false

    let line = NSTextField(labelWithAttributedString: row.content)
    line.drawsBackground = false
    line.isBordered = false
    line.isEditable = false
    line.isSelectable = true
    line.alignment = .left
    line.lineBreakMode = .byTruncatingTail
    line.maximumNumberOfLines = 1
    line.allowsExpansionToolTips = true
    line.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    line.translatesAutoresizingMaskIntoConstraints = false

    let time = NSTextField(labelWithString: row.timestamp)
    time.font = NSFont.monospacedDigitSystemFont(ofSize: 11.2, weight: .semibold)
    time.textColor = row.timestampColor
    time.alignment = .right
    time.drawsBackground = false
    time.isBordered = false
    time.isEditable = false
    time.translatesAutoresizingMaskIntoConstraints = false

    addSubview(line)
    addSubview(time)

    NSLayoutConstraint.activate([
      line.leadingAnchor.constraint(equalTo: leadingAnchor),
      line.topAnchor.constraint(equalTo: topAnchor),
      line.bottomAnchor.constraint(equalTo: bottomAnchor),
      time.leadingAnchor.constraint(equalTo: line.trailingAnchor, constant: 14),
      time.trailingAnchor.constraint(equalTo: trailingAnchor),
      time.firstBaselineAnchor.constraint(equalTo: line.firstBaselineAnchor),
      time.widthAnchor.constraint(equalToConstant: 58),
      heightAnchor.constraint(greaterThanOrEqualToConstant: 17),
    ])
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private struct TerminalTranscriptRow {
  var content: NSAttributedString
  var timestamp: String
  var timestampColor: NSColor
}

private struct TerminalTranscriptRenderer {
  var currentDirectory: String = ""

  func rows(from value: String, isPlaceholder: Bool, scheme: ColorScheme) -> [TerminalTranscriptRow]
  {
    let source = compactPromptLines(value.replacingOccurrences(of: "\r", with: "\n"))
    return compactDisplayLines(source).map { rawLine in
      let parsed = extractInlineTimestamp(rawLine)
      return TerminalTranscriptRow(
        content: ansiAttributedString(parsed.line, isPlaceholder: isPlaceholder, scheme: scheme),
        timestamp: parsed.timestamp ?? "",
        timestampColor: timestampColor(scheme)
      )
    }
  }

  private func compactDisplayLines(_ value: String) -> [String] {
    var rows: [String] = []
    var previousWasBlank = false
    for rawLine in value.components(separatedBy: .newlines) {
      let line = rawLine.trimmingCharacters(in: .whitespaces)
      let plain = stripANSI(line).trimmed
      if isHorizontalRule(plain) {
        if !rows.isEmpty, !previousWasBlank {
          rows.append("")
          previousWasBlank = true
        }
        continue
      }
      if plain.isEmpty {
        if !rows.isEmpty, !previousWasBlank {
          rows.append("")
          previousWasBlank = true
        }
        continue
      }
      rows.append(line)
      previousWasBlank = false
    }
    while rows.last?.trimmed.isEmpty == true {
      rows.removeLast()
    }
    return rows.isEmpty ? [value.trimmed.isEmpty ? "" : value.trimmed] : rows
  }

  private func isHorizontalRule(_ line: String) -> Bool {
    guard line.count >= 18 else { return false }
    let ruleCharacters = CharacterSet(charactersIn: "-_─━═=╌┄┈…·. ")
    return line.unicodeScalars.allSatisfy { ruleCharacters.contains($0) }
  }

  private func compactPromptLines(_ value: String) -> String {
    value
      .components(separatedBy: .newlines)
      .map { compactPromptLine($0) ?? $0 }
      .joined(separator: "\n")
  }

  private func compactPromptLine(_ line: String) -> String? {
    let plain = stripANSI(line)
      .replacingOccurrences(of: "**", with: "")
      .replacingOccurrences(of: "\u{00a0}", with: " ")
    let compactPlain =
      plain
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmed
    let hasPromptCue =
      compactPlain.contains("❯") || compactPlain.contains("➜") || compactPlain.contains("MacBook")
      || compactPlain.contains("") || compactPlain.contains("") || plain.contains("")
      || plain.contains("") || plain.contains("")
    let hasWideSpacer = plain.contains("    ")
    guard hasPromptCue || hasWideSpacer else { return nil }
    guard
      let rawPath = firstMatch(
        in: compactPlain, pattern: #"(~(?:/[^\s]+)*|/Users/[^\s]+(?:/[^\s]+)*)"#)
    else { return nil }
    let path = readablePromptPath(replacing: rawPath)
    let time = firstMatch(
      in: compactPlain, pattern: #"\b[0-9]{1,2}:[0-9]{2}(?::[0-9]{2})?\s*(?:AM|PM)?\b"#
    )
    .map { compactTime($0) }
    let marker = time.map { "\u{001B}]1337;AControlTime=\($0)\u{0007}" } ?? ""
    return "\u{001B}[38;5;76m❯\u{001B}[0m \u{001B}[38;5;39m\(path)\u{001B}[0m\(marker)"
  }

  private func readablePromptPath(replacing rawPath: String) -> String {
    let readableDirectory = readableCurrentDirectory()
    guard !readableDirectory.isEmpty else { return rawPath }
    if rawPath == readableDirectory {
      return rawPath
    }
    if compactPathVariants(for: readableDirectory).contains(rawPath) {
      return readableDirectory
    }
    return rawPath
  }

  private func readableCurrentDirectory() -> String {
    var readable = currentDirectory.trimmed
    guard !readable.isEmpty else { return "" }
    if readable.hasPrefix("/Users/") {
      let parts = readable.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
      if parts.count >= 3 {
        readable = "~/" + parts.dropFirst(2).joined(separator: "/")
      }
    }
    return readable
  }

  private func compactPathVariants(for readablePath: String) -> Set<String> {
    guard readablePath.hasPrefix("~/") else { return [] }
    let homeRelative = String(readablePath.dropFirst(2))
    let parts = homeRelative.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    guard parts.count >= 3, let first = parts.first, let last = parts.last else { return [] }
    let middle = parts.dropFirst().dropLast()
    var variants = Set<String>()
    for firstWidth in 1...min(4, first.count) {
      var compactParts = ["~", String(first.prefix(firstWidth))]
      compactParts.append(contentsOf: middle.map { String($0.prefix(1)) })
      compactParts.append(last)
      variants.insert(compactParts.joined(separator: "/"))
    }
    return variants
  }

  private func compactTime(_ value: String) -> String {
    let raw =
      value
      .replacingOccurrences(
        of: #":([0-9]{2})\s*(AM|PM)$"#, with: " $2", options: .regularExpression
      )
      .replacingOccurrences(of: "  ", with: " ")
      .trimmed
    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.dateFormat = raw.split(separator: ":").count == 3 ? "h:mm:ss a" : "h:mm a"
    let output = DateFormatter()
    output.locale = Locale(identifier: "en_US_POSIX")
    output.dateFormat = "HH:mm"
    if let date = parser.date(from: raw) {
      return output.string(from: date)
    }
    if raw.split(separator: ":").count == 3 {
      return raw.components(separatedBy: ":").prefix(2).joined(separator: ":")
    }
    return raw.replacingOccurrences(of: " AM", with: "").replacingOccurrences(of: " PM", with: "")
  }

  private func extractInlineTimestamp(_ line: String) -> (line: String, timestamp: String?) {
    let marker = "\u{001B}]1337;AControlTime="
    guard let start = line.range(of: marker),
      let end = line[start.upperBound...].range(of: "\u{0007}")
    else {
      return (line, nil)
    }
    let timestamp = String(line[start.upperBound..<end.lowerBound])
    var cleaned = line
    cleaned.removeSubrange(start.lowerBound..<end.upperBound)
    return (cleaned, timestamp)
  }

  private func stripANSI(_ value: String) -> String {
    value
      .replacingOccurrences(
        of: "\u{001B}\\][^\u{0007}]*(\u{0007}|\u{001B}\\\\)", with: "", options: .regularExpression
      )
      .replacingOccurrences(
        of: "\u{001B}\\[[0-9;?]*[ -/]*[@-~]", with: "", options: .regularExpression)
  }

  private func firstMatch(in value: String, pattern: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(value.startIndex..., in: value)
    guard let match = regex.firstMatch(in: value, range: range),
      let swiftRange = Range(match.range, in: value)
    else { return nil }
    return String(value[swiftRange]).trimmingCharacters(in: .whitespaces)
  }

  private func ansiAttributedString(_ value: String, isPlaceholder: Bool, scheme: ColorScheme)
    -> NSAttributedString
  {
    let output = NSMutableAttributedString()
    let baseFont = terminalFont()
    var foreground = baseForeground(isPlaceholder: isPlaceholder, scheme: scheme)
    var background: NSColor?
    var isBold = false
    var isDim = false
    var buffer = ""

    func currentAttributes() -> [NSAttributedString.Key: Any] {
      var attrs: [NSAttributedString.Key: Any] = [
        .font: isBold
          ? NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask) : baseFont,
        .foregroundColor: isDim ? foreground.withAlphaComponent(0.68) : foreground,
      ]
      if let background {
        attrs[.backgroundColor] = background
      }
      return attrs
    }

    func flush() {
      guard !buffer.isEmpty else { return }
      output.append(NSAttributedString(string: buffer, attributes: currentAttributes()))
      buffer.removeAll(keepingCapacity: true)
    }

    func reset() {
      foreground = baseForeground(isPlaceholder: isPlaceholder, scheme: scheme)
      background = nil
      isBold = false
      isDim = false
    }

    func applySGR(_ parameters: String) {
      let values =
        parameters.isEmpty
        ? [0]
        : parameters.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
      var index = 0
      while index < values.count {
        let code = values[index]
        switch code {
        case 0: reset()
        case 1: isBold = true
        case 2: isDim = true
        case 22:
          isBold = false
          isDim = false
        case 30...37: foreground = ansiColor(code - 30, bright: false, scheme: scheme)
        case 90...97: foreground = ansiColor(code - 90, bright: true, scheme: scheme)
        case 40...47: background = ansiColor(code - 40, bright: false, scheme: scheme)
        case 100...107: background = ansiColor(code - 100, bright: true, scheme: scheme)
        case 38 where index + 2 < values.count && values[index + 1] == 5:
          foreground = ansi256Color(values[index + 2], scheme: scheme)
          index += 2
        case 48 where index + 2 < values.count && values[index + 1] == 5:
          background = ansi256Color(values[index + 2], scheme: scheme)
          index += 2
        case 39: foreground = baseForeground(isPlaceholder: isPlaceholder, scheme: scheme)
        case 49: background = nil
        default: break
        }
        index += 1
      }
    }

    var cursor = value.startIndex
    while cursor < value.endIndex {
      if value[cursor] == "\u{001B}" {
        flush()
        let next = value.index(after: cursor)
        guard next < value.endIndex else { break }
        if value[next] == "[" {
          var end = value.index(after: next)
          while end < value.endIndex,
            let scalar = value[end].unicodeScalars.first,
            !(scalar.value >= 0x40 && scalar.value <= 0x7E)
          {
            end = value.index(after: end)
          }
          if end < value.endIndex {
            if value[end] == "m" {
              applySGR(String(value[value.index(after: next)..<end]))
            }
            cursor = value.index(after: end)
            continue
          }
        } else if value[next] == "]" {
          var end = value.index(after: next)
          while end < value.endIndex, value[end] != "\u{0007}" {
            end = value.index(after: end)
          }
          cursor = end < value.endIndex ? value.index(after: end) : value.endIndex
          continue
        }
        cursor = value.index(after: next)
        continue
      }
      buffer.append(value[cursor])
      cursor = value.index(after: cursor)
    }
    flush()
    return output
  }

  private func terminalFont() -> NSFont {
    NSFont(name: "MesloLGS NF", size: 12.5)
      ?? NSFont(name: "MesloLGS NF Regular", size: 12.5)
      ?? NSFont.monospacedSystemFont(ofSize: 12.5, weight: .medium)
  }

  private func baseForeground(isPlaceholder: Bool, scheme: ColorScheme) -> NSColor {
    if isPlaceholder { return NSColor.secondaryLabelColor }
    return scheme == .dark
      ? NSColor(calibratedRed: 0.79, green: 0.80, blue: 0.77, alpha: 1)
      : NSColor.labelColor
  }

  private func timestampColor(_ scheme: ColorScheme) -> NSColor {
    scheme == .dark
      ? NSColor(calibratedRed: 0.70, green: 0.72, blue: 0.70, alpha: 0.76)
      : NSColor.secondaryLabelColor
  }

  private func ansiColor(_ index: Int, bright: Bool, scheme: ColorScheme) -> NSColor {
    let darkNormal: [NSColor] = [
      NSColor(calibratedWhite: 0.16, alpha: 1),
      NSColor(calibratedRed: 0.74, green: 0.36, blue: 0.36, alpha: 1),
      NSColor(calibratedRed: 0.42, green: 0.62, blue: 0.34, alpha: 1),
      NSColor(calibratedRed: 0.72, green: 0.62, blue: 0.38, alpha: 1),
      NSColor(calibratedRed: 0.42, green: 0.57, blue: 0.76, alpha: 1),
      NSColor(calibratedRed: 0.62, green: 0.49, blue: 0.70, alpha: 1),
      NSColor(calibratedRed: 0.32, green: 0.56, blue: 0.60, alpha: 1),
      NSColor(calibratedWhite: 0.76, alpha: 1),
    ]
    let darkBright: [NSColor] = [
      NSColor(calibratedWhite: 0.42, alpha: 1),
      NSColor(calibratedRed: 0.82, green: 0.43, blue: 0.43, alpha: 1),
      NSColor(calibratedRed: 0.50, green: 0.68, blue: 0.38, alpha: 1),
      NSColor(calibratedRed: 0.80, green: 0.68, blue: 0.42, alpha: 1),
      NSColor(calibratedRed: 0.50, green: 0.64, blue: 0.82, alpha: 1),
      NSColor(calibratedRed: 0.69, green: 0.55, blue: 0.77, alpha: 1),
      NSColor(calibratedRed: 0.38, green: 0.62, blue: 0.66, alpha: 1),
      NSColor(calibratedRed: 0.79, green: 0.80, blue: 0.77, alpha: 1),
    ]
    let lightNormal: [NSColor] = [
      NSColor(calibratedWhite: 0.05, alpha: 1),
      NSColor(calibratedRed: 0.86, green: 0.20, blue: 0.26, alpha: 1),
      NSColor(calibratedRed: 0.18, green: 0.72, blue: 0.36, alpha: 1),
      NSColor(calibratedRed: 0.84, green: 0.66, blue: 0.25, alpha: 1),
      NSColor(calibratedRed: 0.22, green: 0.52, blue: 0.92, alpha: 1),
      NSColor(calibratedRed: 0.68, green: 0.42, blue: 0.88, alpha: 1),
      NSColor(calibratedRed: 0.18, green: 0.72, blue: 0.82, alpha: 1),
      NSColor(calibratedWhite: 0.22, alpha: 1),
    ]
    let lightBright: [NSColor] = [
      NSColor(calibratedWhite: 0.34, alpha: 1),
      NSColor(calibratedRed: 1.00, green: 0.42, blue: 0.45, alpha: 1),
      NSColor(calibratedRed: 0.35, green: 0.86, blue: 0.50, alpha: 1),
      NSColor(calibratedRed: 0.98, green: 0.80, blue: 0.36, alpha: 1),
      NSColor(calibratedRed: 0.38, green: 0.64, blue: 1.00, alpha: 1),
      NSColor(calibratedRed: 0.82, green: 0.55, blue: 1.00, alpha: 1),
      NSColor(calibratedRed: 0.36, green: 0.88, blue: 0.95, alpha: 1),
      NSColor(calibratedWhite: 0.10, alpha: 1),
    ]
    let palette: [NSColor]
    if scheme == .dark {
      palette = bright ? darkBright : darkNormal
    } else {
      palette = bright ? lightBright : lightNormal
    }
    return palette[max(0, min(index, palette.count - 1))]
  }

  private func ansi256Color(_ code: Int, scheme: ColorScheme) -> NSColor {
    if code < 16 {
      return ansiColor(code % 8, bright: code >= 8, scheme: scheme)
    }
    if code >= 16 && code <= 231 {
      let value = code - 16
      let red = value / 36
      let green = (value / 6) % 6
      let blue = value % 6
      let renderedRed = CGFloat(red == 0 ? 0 : 55 + red * 40) / 255
      let renderedGreen = CGFloat(green == 0 ? 0 : 55 + green * 40) / 255
      let renderedBlue = CGFloat(blue == 0 ? 0 : 55 + blue * 40) / 255
      return softenedANSIColor(
        red: renderedRed,
        green: renderedGreen,
        blue: renderedBlue,
        scheme: scheme
      )
    }
    let gray = CGFloat(8 + max(0, min(code - 232, 23)) * 10) / 255
    if scheme == .dark {
      let softenedGray = 0.16 + (gray * 0.66)
      return NSColor(calibratedWhite: min(0.84, softenedGray), alpha: 1)
    }
    return NSColor(calibratedWhite: min(0.46, max(0.10, gray * 0.72)), alpha: 1)
  }

  private func softenedANSIColor(red: CGFloat, green: CGFloat, blue: CGFloat, scheme: ColorScheme)
    -> NSColor
  {
    guard scheme == .dark else {
      return NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
    }
    let luma = (red * 0.299) + (green * 0.587) + (blue * 0.114)
    let saturation: CGFloat = 0.45
    let brightness: CGFloat = 0.72
    return NSColor(
      calibratedRed: min(0.76, ((luma + (red - luma) * saturation) * brightness) + 0.08),
      green: min(0.76, ((luma + (green - luma) * saturation) * brightness) + 0.08),
      blue: min(0.76, ((luma + (blue - luma) * saturation) * brightness) + 0.08),
      alpha: 1
    )
  }
}

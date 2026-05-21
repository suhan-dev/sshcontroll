import AppKit
import SwiftUI

struct ShellCommandInput: NSViewRepresentable {
  @Binding var text: String
  var onSubmit: () -> Void
  var onTab: () -> Void

  func makeNSView(context: Context) -> NSScrollView {
    let textView = ShellCommandTextView()
    textView.delegate = context.coordinator
    textView.onSubmit = onSubmit
    textView.onTab = onTab
    textView.onExternalTextChange = context.coordinator.updateTextFromExternalChange
    context.coordinator.attach(textView)
    textView.font =
      NSFont(name: "MesloLGS NF", size: 13.5)
      ?? NSFont.monospacedSystemFont(ofSize: 13.5, weight: .medium)
    textView.textColor = .labelColor
    textView.insertionPointColor = .controlAccentColor
    textView.drawsBackground = false
    textView.isRichText = false
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticTextReplacementEnabled = false
    textView.textContainerInset = NSSize(width: 14, height: 12)
    textView.textContainer?.widthTracksTextView = true
    textView.textContainer?.containerSize = NSSize(
      width: 0, height: CGFloat.greatestFiniteMagnitude)

    let scrollView = NSScrollView()
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.documentView = textView
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let textView = scrollView.documentView as? ShellCommandTextView else { return }
    textView.onSubmit = onSubmit
    textView.onTab = onTab
    textView.onExternalTextChange = context.coordinator.updateTextFromExternalChange
    if textView.string != text {
      textView.string = text
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text)
  }

  final class Coordinator: NSObject, NSTextViewDelegate {
    @Binding var text: String

    init(text: Binding<String>) {
      _text = text
    }

    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }
      text = textView.string
    }

    @MainActor
    func updateTextFromExternalChange(_ value: String) {
      text = value
    }

    func attach(_ textView: NSTextView) {
      pollTimer?.invalidate()
      polledTextView = textView
      let timer = Timer(
        timeInterval: 0.15,
        target: self,
        selector: #selector(pollTextView),
        userInfo: nil,
        repeats: true)
      pollTimer = timer
      RunLoop.main.add(timer, forMode: .common)
    }

    @MainActor @objc private func pollTextView() {
      guard let textView = polledTextView else { return }
      let value = textView.string
      if value != text {
        text = value
      }
    }

    private weak var polledTextView: NSTextView?
    private var pollTimer: Timer?

    deinit {
      pollTimer?.invalidate()
    }
  }
}

final class ShellCommandTextView: NSTextView {
  var onSubmit: (() -> Void)?
  var onTab: (() -> Void)?
  var onExternalTextChange: ((String) -> Void)?

  override func setAccessibilityValue(_ accessibilityValue: Any?) {
    if applyExternalAccessibilityText(accessibilityValue) { return }
    super.setAccessibilityValue(accessibilityValue)
  }

  override func accessibilityValue() -> String? {
    string
  }

  override func keyDown(with event: NSEvent) {
    let isReturn = event.keyCode == 36 || event.keyCode == 76
    if isReturn, !event.modifierFlags.contains(.shift) {
      onSubmit?()
      return
    }
    if event.keyCode == 48, !event.modifierFlags.contains(.shift) {
      onTab?()
      return
    }
    super.keyDown(with: event)
  }

  private func applyExternalAccessibilityText(_ accessibilityValue: Any?) -> Bool {
    guard let value = accessibilityValue as? String else { return false }
    if string != value {
      string = value
      selectedRange = NSRange(location: value.utf16.count, length: 0)
    }
    Task { @MainActor in
      onExternalTextChange?(string)
      NSAccessibility.post(element: self, notification: .valueChanged)
    }
    return true
  }
}

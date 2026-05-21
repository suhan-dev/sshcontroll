import AppKit
import SwiftUI

struct PromptComposerView: NSViewRepresentable {
  @Binding var text: String
  var onAttachFiles: ([URL]) -> Void
  var onAttachImage: (Data, String) -> Void
  var onSubmit: (() -> Void)? = nil
  var onTab: (() -> Void)? = nil
  var fontSize: CGFloat = 15
  var textInset = NSSize(width: 16, height: 16)

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.drawsBackground = false
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.borderType = .noBorder

    let textView = PasteAwareTextView()
    textView.minSize = NSSize(width: 0, height: 0)
    textView.maxSize = NSSize(
      width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.autoresizingMask = [.width]
    textView.textContainer?.containerSize = NSSize(
      width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
    textView.textContainer?.widthTracksTextView = true
    textView.textContainer?.lineFragmentPadding = 0
    textView.textContainerInset = textInset
    textView.font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
    textView.textColor = .labelColor
    textView.insertionPointColor = .labelColor
    textView.backgroundColor = .clear
    textView.drawsBackground = false
    textView.isRichText = false
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticTextReplacementEnabled = false
    textView.isAutomaticSpellingCorrectionEnabled = false
    textView.isContinuousSpellCheckingEnabled = false
    textView.isGrammarCheckingEnabled = false
    textView.delegate = context.coordinator
    textView.string = text
    textView.onPasteFiles = onAttachFiles
    textView.onPasteImage = onAttachImage
    textView.onSubmit = onSubmit
    textView.onTab = onTab
    textView.onExternalTextChange = context.coordinator.updateTextFromExternalChange
    textView.textContainerInset = textInset
    textView.font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
    textView.registerForDraggedTypes(PasteboardAttachmentReader.supportedTypes)
    context.coordinator.attach(textView)

    scrollView.documentView = textView
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let textView = scrollView.documentView as? PasteAwareTextView else { return }
    context.coordinator.parent = self
    textView.onPasteFiles = onAttachFiles
    textView.onPasteImage = onAttachImage
    textView.onSubmit = onSubmit
    textView.onTab = onTab
    textView.onExternalTextChange = context.coordinator.updateTextFromExternalChange
    if textView.string != text {
      textView.string = text
    }
  }

  final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: PromptComposerView

    init(_ parent: PromptComposerView) {
      self.parent = parent
    }

    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }
      parent.text = textView.string
    }

    @MainActor
    func updateTextFromExternalChange(_ value: String) {
      parent.text = value
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
      if value != parent.text {
        parent.text = value
      }
    }

    private weak var polledTextView: NSTextView?
    private var pollTimer: Timer?

    deinit {
      pollTimer?.invalidate()
    }
  }
}

final class PasteAwareTextView: NSTextView {
  var onPasteFiles: (([URL]) -> Void)?
  var onPasteImage: ((Data, String) -> Void)?
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
    if event.keyCode == 9,
      event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control)
    {
      paste(nil)
      return
    }
    let isReturn = event.keyCode == 36 || event.keyCode == 76
    if isReturn, let onSubmit, !event.modifierFlags.contains(.shift) {
      onSubmit()
      return
    }
    if event.keyCode == 48, let onTab, !event.modifierFlags.contains(.shift) {
      onTab()
      return
    }
    super.keyDown(with: event)
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if event.keyCode == 9,
      event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control)
    {
      paste(nil)
      return true
    }
    return super.performKeyEquivalent(with: event)
  }

  override func paste(_ sender: Any?) {
    if attach(from: .general) {
      return
    }
    super.paste(sender)
  }

  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    PasteboardAttachmentReader.hasAttachment(in: sender.draggingPasteboard)
      ? .copy : super.draggingEntered(sender)
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    attach(from: sender.draggingPasteboard) || super.performDragOperation(sender)
  }

  private func attach(from pasteboard: NSPasteboard) -> Bool {
    if let urls = PasteboardAttachmentReader.fileURLs(from: pasteboard), !urls.isEmpty {
      onPasteFiles?(urls)
      return true
    }
    if let image = PasteboardAttachmentReader.imageData(from: pasteboard) {
      onPasteImage?(image.data, image.ext)
      return true
    }
    return false
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

enum PasteboardAttachmentReader {
  static let jpeg = NSPasteboard.PasteboardType("public.jpeg")
  static let heic = NSPasteboard.PasteboardType("public.heic")
  static let fileURL = NSPasteboard.PasteboardType.fileURL
  static let filename = NSPasteboard.PasteboardType("NSFilenamesPboardType")

  static var supportedTypes: [NSPasteboard.PasteboardType] {
    [.fileURL, filename, .png, .tiff, jpeg, heic]
  }

  static func hasAttachment(in pasteboard: NSPasteboard) -> Bool {
    fileURLs(from: pasteboard)?.isEmpty == false || imageData(from: pasteboard) != nil
  }

  static func fileURLs(from pasteboard: NSPasteboard) -> [URL]? {
    if let urls = pasteboard.readObjects(
      forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
      !urls.isEmpty
    {
      return urls
    }
    if let values = pasteboard.propertyList(forType: filename) as? [String] {
      let urls = values.map { URL(fileURLWithPath: $0) }
      return urls.isEmpty ? nil : urls
    }
    if let fileURLString = pasteboard.string(forType: fileURL),
      let url = URL(string: fileURLString),
      url.isFileURL
    {
      return [url]
    }
    return nil
  }

  static func imageData(from pasteboard: NSPasteboard) -> (data: Data, ext: String)? {
    if let png = pasteboard.data(forType: .png) {
      return (png, "png")
    }
    if let jpeg = pasteboard.data(forType: jpeg) {
      return (jpeg, "jpg")
    }
    if let heic = pasteboard.data(forType: heic) {
      return (heic, "heic")
    }
    if let tiff = pasteboard.data(forType: .tiff),
      let image = NSImage(data: tiff),
      let png = image.pngData
    {
      return (png, "png")
    }
    if let image = NSImage(pasteboard: pasteboard),
      let png = image.pngData
    {
      return (png, "png")
    }
    return nil
  }
}

extension NSImage {
  fileprivate var pngData: Data? {
    guard let tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffRepresentation)
    else {
      return nil
    }
    return bitmap.representation(using: .png, properties: [:])
  }
}

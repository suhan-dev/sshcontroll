import AppKit
import AVKit
import PDFKit
import SwiftUI

struct FilesView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.colorScheme) private var colorScheme
  @State private var parentDirectoryIsSelected = false

  var filteredItems: [RemoteItem] {
    let query = model.searchText.trimmed.lowercased()
    let sourceItems = model.fileBrowserItems
    let items =
      query.isEmpty
      ? sourceItems
      : sourceItems.filter { $0.name.lowercased().contains(query) }
    return sortedFileItems(items)
  }

  private func sortedFileItems(_ items: [RemoteItem]) -> [RemoteItem] {
    items.sorted { first, second in
      let firstHidden = first.name.hasPrefix(".")
      let secondHidden = second.name.hasPrefix(".")
      if firstHidden != secondHidden {
        return !firstHidden
      }
      if first.isDirectory != second.isDirectory {
        return first.isDirectory && !second.isDirectory
      }
      return first.name.localizedStandardCompare(second.name) == .orderedAscending
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "A Files", detail: activeFileDirectory) {
        await model.loadFileBrowserDirectory(activeFileDirectory, force: true)
      }

      GlassPanel(title: nil) {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 10) {
            PrimaryButton(title: "Upload", symbol: "square.and.arrow.up", tint: .blue) {
              Task { await model.uploadFilesToA() }
            }
            PrimaryButton(title: "Save", symbol: "square.and.arrow.down", tint: .teal) {
              Task { await model.saveASelectionToC() }
            }
            .disabled(model.selectedRemoteItemIDs.isEmpty)
            PrimaryButton(title: "Delete", symbol: "trash", tint: .red) {
              Task { await model.deleteRemoteSelection() }
            }
            .disabled(model.selectedRemoteItemIDs.isEmpty)
            TextField("Search A files", text: $model.searchText)
              .textFieldStyle(.plain)
              .font(.system(size: 13, weight: .medium))
              .padding(.horizontal, 12)
              .frame(width: 230, height: 36)
              .background(AControlStyle.insetFill(colorScheme), in: Capsule())
              .overlay {
                Capsule().strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
              }
            TextField("Open remote path", text: $model.remoteOpenPath)
              .textFieldStyle(.plain)
              .font(.system(size: 13, weight: .medium, design: .monospaced))
              .padding(.horizontal, 12)
              .frame(width: 340, height: 36)
              .background(AControlStyle.insetFill(colorScheme), in: Capsule())
              .overlay {
                Capsule().strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
              }
              .onSubmit {
                Task { await model.openRemotePathFromInput() }
              }
            PrimaryButton(title: "Open Path", symbol: "arrow.up.right.square", tint: .teal) {
              Task { await model.openRemotePathFromInput() }
            }
            .disabled(model.remoteOpenPath.trimmed.isEmpty)
          }
        }
      }

      HStack(spacing: 16) {
        explorerPanel
        editorPanel
      }
      .layoutPriority(1)

      if !model.lastMirrorLog.isEmpty {
        GlassPanel(title: "Last File Operation", symbol: "text.alignleft", accent: .orange) {
          TranscriptView(
            text: model.lastMirrorLog,
            placeholder: "File transfer and save results will appear here."
          )
          .frame(minHeight: 160, idealHeight: 190, maxHeight: 260)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .task {
      if model.fileBrowserDir.trimmed.isEmpty || model.fileBrowserItems.isEmpty {
        await model.ensureFileBrowserLoaded()
      }
    }
    .onChange(of: model.fileBrowserDir) { _, _ in
      parentDirectoryIsSelected = false
    }
  }

  private var activeFileDirectory: String {
    model.fileBrowserDir.trimmed.isEmpty ? model.currentRemoteDir : model.fileBrowserDir
  }

  private var explorerPanel: some View {
    GlassPanel(title: "A Explorer", symbol: "folder", accent: .blue) {
      VStack(spacing: 0) {
        HStack {
          Text("Name")
            .font(.caption.weight(.semibold))
          Spacer()
          Text("Size")
            .font(.caption.weight(.semibold))
            .frame(width: 90, alignment: .trailing)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)

        VStack(spacing: 4) {
          ParentDirectoryFileRow(isSelected: parentDirectoryIsSelected) {
            parentDirectoryIsSelected = true
            model.selectedRemoteItem = nil
          } open: {
            parentDirectoryIsSelected = false
            Task { await model.goUpFileBrowserDirectory() }
          }
          .padding(.horizontal, 8)
          .padding(.top, 6)

          ScrollView {
            LazyVStack(spacing: 2) {
              ForEach(filteredItems) { item in
                RemoteFileRow(item: item, isSelected: model.selectedRemoteItemIDs.contains(item.id))
                {
                  parentDirectoryIsSelected = false
                  model.selectRemoteItem(item, visibleItems: filteredItems)
                } open: {
                  parentDirectoryIsSelected = false
                  model.selectedRemoteItem = item
                  Task { await model.openFileBrowserItem(item) }
                }
              }

              if model.isFileBrowserLoading && filteredItems.isEmpty {
                VStack(spacing: 8) {
                  ProgressView()
                    .controlSize(.small)
                  Text("Loading \(activeFileDirectory)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, minHeight: 140)
              } else if filteredItems.isEmpty {
                VStack(spacing: 6) {
                  Text("Empty folder")
                    .font(.caption.weight(.semibold))
                  if !model.fileBrowserError.isEmpty {
                    Text(model.fileBrowserError)
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                      .lineLimit(2)
                  }
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 140)
              }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
          }
        }
        .frame(maxHeight: .infinity)
        .background(listFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .layoutPriority(1)
      }
      HStack {
        Text("\(filteredItems.count) item(s)")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        SoftButton(title: "Open", symbol: "arrow.right.circle") {
          if let item = model.selectedRemoteItem {
            Task { await model.openFileBrowserItem(item) }
          }
        }
        .disabled(model.selectedRemoteItem == nil)
        SoftButton(title: "Shell Dir", symbol: "terminal") {
          Task { await model.changeShellDirectory(model.selectedDirectoryOrCurrent) }
        }
        SoftButton(title: "Codex Dir", symbol: "sparkles") {
          Task { await model.restartCodex(in: model.selectedDirectoryOrCurrent) }
        }
        SoftButton(title: "Session Dir", symbol: "folder.badge.gearshape") {
          Task { await model.resetSessionDirectory(model.selectedDirectoryOrCurrent) }
        }
        .safeHelp("Set the active session, Shell, and Codex to the selected folder")
      }
    }
    .frame(maxWidth: .infinity)
    .layoutPriority(1)
  }

  private var editorPanel: some View {
    GlassPanel(
      title: model.openedRemoteFile.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Editor",
      symbol: "doc.text", accent: .teal
    ) {
      RemotePreviewPane()
        .frame(maxHeight: .infinity)
        .layoutPriority(1)
      HStack {
        Text(model.openedRemoteFile ?? "Double-click a file to open it.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
        Spacer()
        if model.remotePreviewURL != nil {
          SoftButton(title: "Open External", symbol: "arrow.up.right.square") {
            model.openPreviewExternally()
          }
        }
        PrimaryButton(title: "Save A", symbol: "checkmark.circle", tint: .teal) {
          Task { await model.saveRemoteFile() }
        }
        .disabled(
          model.openedRemoteFile == nil || model.remotePreviewKind != .text
            || model.remoteFileIsPreviewOnly)
      }
    }
    .frame(maxWidth: .infinity)
    .layoutPriority(1)
  }

  private func fileSymbol(_ name: String) -> String {
    let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
    if ["png", "jpg", "jpeg", "gif", "heic", "tif", "tiff", "bmp", "webp"].contains(ext) {
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

  private var listFill: some ShapeStyle {
    colorScheme == .dark
      ? AnyShapeStyle(Color.white.opacity(0.045)) : AnyShapeStyle(Color.white.opacity(0.62))
  }
}

struct ParentDirectoryFileRow: View {
  @Environment(\.colorScheme) private var colorScheme
  var isSelected: Bool
  var select: () -> Void
  var open: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "arrow.up.folder.fill")
        .foregroundStyle(
          isSelected ? .primary : AControlStyle.accentForeground(.blue, colorScheme))
        .frame(width: 20)
      Text("..")
        .lineLimit(1)
      Spacer()
      Text("parent")
        .foregroundStyle(.secondary)
        .frame(width: 90, alignment: .trailing)
    }
    .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
    .padding(.horizontal, 10)
    .frame(height: 34)
    .background(rowFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .contentShape(Rectangle())
    .gesture(
      TapGesture(count: 2)
        .onEnded { open() }
        .exclusively(before: TapGesture(count: 1).onEnded { select() })
    )
  }

  private var rowFill: Color {
    if isSelected {
      return Color.accentColor.opacity(colorScheme == .dark ? 0.20 : 0.12)
    }
    return AControlStyle.accentFill(.blue, colorScheme)
  }
}

struct RemoteFileRow: View {
  @Environment(\.colorScheme) private var colorScheme
  var item: RemoteItem
  var isSelected: Bool
  var select: () -> Void
  var open: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: item.isDirectory ? "folder.fill" : fileSymbol(item.name))
        .foregroundStyle(
          isSelected
            ? .primary
            : (item.isDirectory ? AControlStyle.accentForeground(.blue, colorScheme) : .secondary)
        )
        .frame(width: 20)
      Text(item.name)
        .lineLimit(1)
        .foregroundStyle(.primary)
      Spacer()
      Text(
        item.isDirectory
          ? "folder" : ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file)
      )
      .foregroundStyle(.secondary)
      .frame(width: 90, alignment: .trailing)
    }
    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
    .padding(.horizontal, 10)
    .frame(height: 34)
    .background(rowFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .contentShape(Rectangle())
    .gesture(
      TapGesture(count: 2)
        .onEnded { open() }
        .exclusively(before: TapGesture(count: 1).onEnded { select() })
    )
  }

  private var rowFill: Color {
    if isSelected {
      return Color.accentColor.opacity(colorScheme == .dark ? 0.20 : 0.12)
    }
    return Color.primary.opacity(colorScheme == .dark ? 0.055 : 0.035)
  }

  private func fileSymbol(_ name: String) -> String {
    let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
    if ["png", "jpg", "jpeg", "gif", "heic", "tif", "tiff", "bmp", "webp"].contains(ext) {
      return "photo"
    }
    if ext == "pdf" {
      return "doc.richtext"
    }
    return "doc.text"
  }
}

struct RemotePreviewPane: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Group {
      switch model.remotePreviewKind {
      case .text:
        if model.isRemotePreviewLoading && model.remoteFileText.isEmpty {
          placeholder("Loading text preview...")
        } else if model.remoteFileIsPreviewOnly {
          ScrollView {
            Text(model.remoteFileText)
              .font(.system(.body, design: .monospaced))
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .topLeading)
              .padding(12)
          }
          .background(previewFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
          TextEditor(text: $model.remoteFileText)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .background(previewFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
      case .image:
        if let url = model.remotePreviewURL, let image = NSImage(contentsOf: url) {
          Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(previewFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
          placeholder("Loading image preview...")
        }
      case .pdf:
        if let url = model.remotePreviewURL {
          PDFPreview(url: url)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
          placeholder("Loading PDF preview...")
        }
      case .video:
        if let url = model.remotePreviewURL {
          LocalVideoPreview(url: url)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .background(previewFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
          placeholder("Video preview skipped. Use Save to view it locally.")
        }
      case .external:
        VStack(spacing: 12) {
          Image(systemName: "doc")
            .font(.system(size: 42))
            .foregroundStyle(.secondary)
          Text("Preview opened with the default macOS app.")
            .foregroundStyle(.secondary)
          if let url = model.remotePreviewURL {
            Text(url.path)
              .font(.caption)
              .foregroundStyle(.tertiary)
              .lineLimit(2)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(previewFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      case .none:
        placeholder("Select a file to preview it.")
      }
    }
  }

  private func placeholder(_ text: String) -> some View {
    VStack(spacing: 10) {
      if model.isRemotePreviewLoading {
        ProgressView()
          .controlSize(.small)
      }
      Text(text)
        .font(.system(size: 13, weight: .semibold))
      if model.isRemotePreviewLoading, !model.lastMirrorLog.trimmed.isEmpty {
        Text(model.lastMirrorLog)
          .font(.caption)
          .lineLimit(2)
          .truncationMode(.middle)
      }
    }
    .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(previewFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private var previewFill: some ShapeStyle {
    colorScheme == .dark ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(Color.white.opacity(0.64))
  }
}

struct PDFPreview: NSViewRepresentable {
  var url: URL

  func makeNSView(context: Context) -> PDFView {
    let view = PDFView()
    view.autoScales = true
    view.displayMode = .singlePageContinuous
    view.backgroundColor = .clear
    view.document = PDFDocument(url: url)
    return view
  }

  func updateNSView(_ view: PDFView, context: Context) {
    view.document = PDFDocument(url: url)
    view.autoScales = true
  }
}

struct LocalVideoPreview: View {
  var url: URL
  @State private var player: AVPlayer?

  var body: some View {
    VideoPlayer(player: player)
      .onAppear {
        player = AVPlayer(url: url)
      }
      .onDisappear {
        player?.pause()
        player = nil
      }
      .onChange(of: url) { _, newURL in
        player?.pause()
        player = AVPlayer(url: newURL)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

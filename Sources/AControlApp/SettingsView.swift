import AppKit
import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.colorScheme) private var colorScheme
  @State private var revealedSensitiveFields: Set<SensitiveSettingsField> = []
  @State private var newPermissionTargetName = ""
  @State private var newPermissionTargetPath = ""
  @State private var newPermissionTargetPane: MacPrivacyPane = .fullDiskAccess

  private enum SensitiveSettingsField: Hashable {
    case sshTarget
    case sshKeyPath
    case latencyTarget
    case appleTeamID
  }

  var body: some View {
    ScrollView(.vertical, showsIndicators: true) {
      VStack(alignment: .leading, spacing: 16) {
        SectionHeader(title: "A Settings", detail: "local app config")

        GlassPanel(title: "Connection", symbol: "network", accent: .cyan) {
          settingsField("Remote Label", text: $model.settings.remoteLabel, showsSavedState: true)
          protectedSettingsField(
            "SSH Target",
            text: $model.settings.hostAlias,
            prompt: "alias or user@host",
            id: .sshTarget,
            shouldProtect: containsNetworkAddress(model.settings.hostAlias),
            showsSavedState: true
          )
          sshKeyPathField()
          settingsField(
            "SSH Port", text: $model.settings.sshPort, prompt: "22", showsSavedState: true)
          settingsField("Remote Home", text: $model.settings.remoteHome, showsSavedState: true)
          settingsField(
            "Remote Helper", text: $model.settings.remoteScript,
            prompt: "~/.local/bin/a-cockpit-remote", showsSavedState: true)
          settingsField("Explorer Root", text: $model.settings.explorerRoot, showsSavedState: true)
          settingsField("Mirror Base on C", text: $model.settings.mirrorBase, showsSavedState: true)
          protectedSettingsField(
            "Latency Target",
            text: $model.settings.latencyTarget,
            prompt: "optional",
            id: .latencyTarget,
            shouldProtect: containsNetworkAddress(model.settings.latencyTarget),
            showsSavedState: true
          )
          Toggle(
            "Start Tailscale on C when SSHcontroll opens",
            isOn: $model.settings.startTailscaleOnLaunch
          )
          .toggleStyle(.switch)
          Toggle(
            "Open main window full screen on launch",
            isOn: $model.settings.openFullScreenOnLaunch
          )
          .toggleStyle(.switch)
          FlowLayout(spacing: 10) {
            SoftButton(title: "Full Screen Now", symbol: "arrow.up.left.and.arrow.down.right") {
              model.settings.openFullScreenOnLaunch = true
              model.saveSettings()
              applyFullScreenToCurrentWindow()
            }
            .safeHelp("Apply the launch full-screen preference to the current SSHcontroll window.")
          }
          HStack {
            Text("Theme")
              .frame(width: 140, alignment: .leading)
              .foregroundStyle(.secondary)
            Picker("Theme", selection: $model.settings.theme) {
              ForEach(AppTheme.allCases) { theme in
                Text(theme.title).tag(theme)
              }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
            Spacer()
          }
        }

        GlassPanel(title: "AI Tools", symbol: "sparkles", accent: .purple) {
          settingsField(
            "Codex Path", text: $model.settings.codexPath,
            prompt: "Blank = use A's current codex on PATH", showsSavedState: true)
          settingsField(
            "Claude Path", text: $model.settings.claudePath, prompt: "/opt/homebrew/bin/claude",
            showsSavedState: true)
          FlowLayout(spacing: 10) {
            SoftButton(title: "Check Codex", symbol: "checkmark.seal") {
              Task { await model.checkAITool("codex") }
            }
            SoftButton(title: "Check Claude", symbol: "checkmark.seal") {
              Task { await model.checkAITool("claude") }
            }
            PrimaryButton(title: "Install Claude", symbol: "arrow.down.circle", tint: .purple) {
              Task { await model.installClaudeCLI() }
            }
          }
          if !model.toolCheckLog.trimmed.isEmpty {
            Text(model.toolCheckLog)
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(12)
              .background(
                AControlStyle.insetFill(colorScheme),
                in: RoundedRectangle(cornerRadius: AControlStyle.insetRadius, style: .continuous))
          }
          Text(
            "Leave paths empty for automatic discovery. Fill them only when the remote shell cannot find the CLI."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }

        GlassPanel(title: "Apple Signing", symbol: "apple.logo", accent: .gray) {
          Text(
            "Use this for your local iOS development signing on A. SSHcontroll stores the Team ID only in local settings and passes it to xcodebuild; it is not written into the repository."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

          protectedSettingsField(
            "Team ID",
            text: $model.settings.appleDevelopmentTeamID,
            prompt: "Apple Developer Team ID",
            id: .appleTeamID,
            shouldProtect: !model.settings.appleDevelopmentTeamID.trimmed.isEmpty,
            showsSavedState: true
          )
          settingsField(
            "Bundle ID", text: $model.settings.appleBundleID, prompt: "com.example.app",
            showsSavedState: true)

          FlowLayout(spacing: 10) {
            PrimaryButton(title: "Open Xcode Signing", symbol: "apple.terminal", tint: .gray) {
              Task { await model.prepareAppleSigning() }
            }
            .safeHelp("Open Xcode and the relevant signing/privacy panes on A.")
            SoftButton(title: "Check Signing", symbol: "checkmark.seal") {
              Task { await model.checkAppleSigning() }
            }
            SoftButton(title: "Test iOS Signing", symbol: "hammer") {
              Task { await model.testAppleSigning() }
            }
            .safeHelp(
              "Run xcodebuild with the saved Team ID and Bundle ID to see whether Apple Development signing is usable."
            )
          }

          if !model.appleSigningLog.trimmed.isEmpty {
            Text(model.appleSigningLog)
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(12)
              .background(
                AControlStyle.insetFill(colorScheme),
                in: RoundedRectangle(cornerRadius: AControlStyle.insetRadius, style: .continuous))
          }
        }

        GlassPanel(title: "Permissions", symbol: "lock.shield", accent: .orange) {
          Text(
            "macOS does not allow any app to grant Full Disk Access automatically. SSHcontroll can open the exact privacy panes, keep a stable permission host on A, and launch emulator/simulator QA from A's logged-in GUI session instead of the Codex SSH sandbox."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

          VStack(alignment: .leading, spacing: 8) {
            Text("A Mac")
              .font(.caption.weight(.bold))
              .foregroundStyle(.secondary)
            FlowLayout(spacing: 10) {
              PrimaryButton(
                title: "Developer Mode Setup", symbol: "laptopcomputer.and.arrow.down",
                tint: .blue
              ) {
                Task { await model.prepareDeveloperPermissions() }
              }
              .safeHelp(
                "Install the stable host, open every A-side development permission target, run a screenshot smoke test, and check Codex plugins."
              )
              PrimaryButton(
                title: "Open All A Permissions", symbol: "lock.open.rotation", tint: .orange
              ) {
                Task { await model.prepareAllRemotePermissions() }
              }
              .safeHelp(
                "Open all relevant permission panes on A and launch the stable Permission Host and Codex.app once."
              )
              PrimaryButton(
                title: "Prepare A Permissions", symbol: "lock.open.display", tint: .orange
              ) {
                Task { await model.prepareRemotePermissions() }
              }
              .safeHelp(
                "Install the permission host on A and open the Screen Recording, Accessibility, Full Disk Access, Automation, and Input Monitoring panes on A."
              )
              PrimaryButton(title: "Prepare Codex.app", symbol: "sparkles", tint: .purple) {
                Task { await model.prepareCodexAppPermissions() }
              }
              .safeHelp(
                "Open Codex.app and its permission panes on A, then set SSHcontroll to the stable Codex.app bundled binary if it is found."
              )
              if model.remotePermissionCheckPassed {
                PrimaryButton(title: "A Permissions OK", symbol: "checkmark.shield", tint: .blue) {
                  Task { await model.checkRemotePermissions() }
                }
                .safeHelp("Last A permission check completed successfully. Click again to re-check.")
              } else {
                SoftButton(title: "Check A Permissions", symbol: "checkmark.shield") {
                  Task { await model.checkRemotePermissions() }
                }
                .safeHelp(
                  "Check whether the A-side permission helper and required targets are reachable.")
              }
              PrimaryButton(title: "Check A Computer", symbol: "cursorarrow.click.2", tint: .blue) {
                Task { await model.checkRemoteComputerBridge() }
              }
              .safeHelp(
                "Verify the A-side Computer bridge: screen capture, Accessibility/System Events, simulator, and ADB probes through the stable Permission Host."
              )
              SoftButton(title: "Install Stable Host", symbol: "shippingbox") {
                Task { await model.installRemotePermissionHost() }
              }
              PrimaryButton(title: "Run Mobile QA on A", symbol: "play.display", tint: .green) {
                Task { await model.runMobileQAGuiOnA() }
              }
              .safeHelp(
                "Run mobile emulator/simulator QA from A's logged-in GUI session through the stable Permission Host, not through Codex/tmux/SSH."
              )
              SoftButton(title: "Check GUI Log", symbol: "text.page") {
                Task { await model.checkGuiRunLog() }
              }
              PrimaryButton(title: "Codex Dev Settings", symbol: "hammer", tint: .purple) {
                Task { await model.prepareCodexDeveloperSettings() }
              }
              .safeHelp(
                "Set A Codex defaults for personal development: gpt-5.5, xhigh reasoning, full local sandbox, no approval prompts, and plugin entries for Computer, Browser, GitHub, Figma, Documents, Spreadsheets, and Presentations."
              )
              PrimaryButton(
                title: "CLI Permission Host", symbol: "camera.badge.ellipsis", tint: .blue
              ) {
                Task { await model.prepareCodexCLIPermissionHost() }
              }
              .safeHelp(
                "Use the project macOS permission bridge and Codex CLI Permission Host bundle for CLI-side screenshots and Apple Events. This is separate from Codex.app and Computer Use."
              )
              SoftButton(title: "Check Plugins", symbol: "puzzlepiece.extension") {
                Task { await model.checkCodexPlugins() }
              }
            }
          }

          VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
              Text("Saved A Permission Targets")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
              Spacer()
              SoftButton(title: "Open Saved Targets", symbol: "lock.open.laptopcomputer") {
                Task { await model.openSavedPermissionTargets() }
              }
              .safeHelp("Open each saved target on A beside its matching Privacy & Security pane.")
            }

            HStack(spacing: 8) {
              TextField("Name", text: $newPermissionTargetName)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 140)
              TextField("~/Applications/App.app or /usr/sbin/sshd", text: $newPermissionTargetPath)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
              Picker("Pane", selection: $newPermissionTargetPane) {
                ForEach(MacPrivacyPane.allCases) { pane in
                  Text(pane.title).tag(pane)
                }
              }
              .labelsHidden()
              .frame(width: 160)
              PrimaryButton(title: "Add", symbol: "plus", tint: .orange) {
                model.addPermissionTarget(
                  name: newPermissionTargetName,
                  remotePath: newPermissionTargetPath,
                  pane: newPermissionTargetPane
                )
                if !newPermissionTargetPath.trimmed.isEmpty {
                  newPermissionTargetName = ""
                  newPermissionTargetPath = ""
                  newPermissionTargetPane = .fullDiskAccess
                }
              }
            }

            if model.settings.permissionTargets.isEmpty {
              Text(
                "Add the app, binary, or folder identity you want to approve on A. SSHcontroll will open the target and the matching pane; macOS still requires the final approval click."
              )
              .font(.caption)
              .foregroundStyle(.secondary)
            } else {
              VStack(spacing: 8) {
                ForEach(model.settings.permissionTargets) { target in
                  permissionTargetRow(target)
                }
              }
            }
          }

          VStack(alignment: .leading, spacing: 8) {
            Text("This Mac")
              .font(.caption.weight(.bold))
              .foregroundStyle(.secondary)
            FlowLayout(spacing: 10) {
              ForEach(MacPrivacyPane.allCases) { pane in
                SoftButton(title: pane.title, symbol: pane.systemImage) {
                  model.openLocalPrivacyPane(pane)
                }
              }
            }
          }

          if !model.permissionLog.trimmed.isEmpty {
            Text(model.permissionLog)
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(12)
              .background(
                AControlStyle.insetFill(colorScheme),
                in: RoundedRectangle(cornerRadius: AControlStyle.insetRadius, style: .continuous))
          }

          if !model.codexPluginLog.trimmed.isEmpty {
            Text(model.codexPluginLog)
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(12)
              .background(
                AControlStyle.insetFill(colorScheme),
                in: RoundedRectangle(cornerRadius: AControlStyle.insetRadius, style: .continuous))
          }
        }

        GlassPanel(title: "Actions", symbol: "checkmark.seal", accent: .green) {
          FlowLayout(spacing: 10) {
            PrimaryButton(title: "Save Settings", symbol: "checkmark", tint: .green) {
              model.applyExplorerRootAsActiveDirectory()
              Task { await model.loadDirectory(model.settings.explorerRoot) }
            }
            SoftButton(title: "Check Connection", symbol: "antenna.radiowaves.left.and.right") {
              Task { await model.refreshDashboard() }
            }
            .safeHelp("Check whether SSHcontroll can reach A through SSH.")
            SoftButton(title: "Install Helper", symbol: "shippingbox") {
              Task { await model.installRemoteHelper() }
            }
            .safeHelp("Copy the bundled remote helper to the configured remote helper path.")
            SoftButton(title: "Start C Tailscale", symbol: "network") {
              Task { await model.prepareNetworkOnLaunch() }
            }
            SoftButton(title: "Open Remote Folder", symbol: "folder") {
              model.openLocalFolder(model.settings.mirrorBase)
            }
          }
        }

        GlassPanel(title: "Notes", symbol: "info.circle", accent: .blue) {
          Text(
            """
            SSHcontroll stores reusable settings in:
            ~/Library/Application Support/SSHcontroll/settings.json

            The remote helper is bundled inside the app and copied by Install Helper.
            Optional apps such as Macs Fan Control, Codex, Claude, or Tailscale should report as missing instead of crashing the app.

            Local folders live under:
            ~/remote/mirror
            ~/remote/save
            ~/remote/report

            First setup:
            1. Enter an SSH Target, for example an SSH config alias or user@host.
            2. Use Choose to select an SSH key path if the target needs one.
            3. Press Install Helper, then Check Connection.

            If Codex or monitor permissions are missing on the remote Mac, ask the remote LLM agent to read LLM.md and docs/INSTALL_AND_OPERATIONS.md for setup steps.
            Full Disk Access, Accessibility, Screen Recording, Automation, and Input Monitoring can be opened from Permissions. macOS still requires you to approve the toggles manually.
            If Claude Code is missing, install it from Settings or set Claude Path to the remote `claude` binary.
            """
          )
          .font(.callout)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
        }
      }
      .frame(maxWidth: .infinity, alignment: .topLeading)
      .padding(.trailing, 2)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .onChange(of: model.settings) { _, _ in
      model.saveSettings()
    }
    .onDisappear {
      model.saveSettings()
    }
  }

  private func settingsField(
    _ label: String, text: Binding<String>, prompt: String? = nil, showsSavedState: Bool = false
  ) -> some View {
    HStack {
      fieldLabel(label)
      TextField(prompt ?? label, text: text)
        .textFieldStyle(.roundedBorder)
        .font(.system(.body, design: .monospaced))
      savedBadge(for: text.wrappedValue, showsSavedState: showsSavedState)
    }
  }

  private func applyFullScreenToCurrentWindow() {
    guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
    guard !window.styleMask.contains(.fullScreen) else { return }
    window.toggleFullScreen(nil)
  }

  private func protectedSettingsField(
    _ label: String,
    text: Binding<String>,
    prompt: String? = nil,
    id: SensitiveSettingsField,
    shouldProtect: Bool,
    showsSavedState: Bool = false
  ) -> some View {
    let shouldBlur =
      shouldProtect && !text.wrappedValue.trimmed.isEmpty && !revealedSensitiveFields.contains(id)

    return HStack {
      fieldLabel(label)
      if shouldBlur {
        sensitiveValueButton(
          value: text.wrappedValue, prompt: prompt ?? label, id: id, forceBlur: true)
      } else {
        TextField(prompt ?? label, text: text)
          .textFieldStyle(.roundedBorder)
          .font(.system(.body, design: .monospaced))
      }
      savedBadge(for: text.wrappedValue, showsSavedState: showsSavedState)
    }
  }

  private func sshKeyPathField() -> some View {
    HStack(spacing: 8) {
      fieldLabel("SSH Key Path")
      sensitiveValueButton(
        value: model.settings.sshIdentityFile,
        prompt: "optional",
        id: .sshKeyPath,
        forceBlur: !model.settings.sshIdentityFile.trimmed.isEmpty
      )
      savedBadge(for: model.settings.sshIdentityFile, showsSavedState: true)
      SoftButton(title: "Choose", symbol: "key") {
        model.chooseSSHKeyFile()
        revealedSensitiveFields.remove(.sshKeyPath)
      }
    }
  }

  private func fieldLabel(_ label: String) -> some View {
    Text(label)
      .frame(width: 140, alignment: .leading)
      .foregroundStyle(.secondary)
  }

  private func permissionTargetRow(_ target: RemotePermissionTarget) -> some View {
    HStack(spacing: 10) {
      Image(systemName: target.pane.systemImage)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(AControlStyle.accentForeground(.orange, colorScheme))
        .frame(width: 24, height: 24)
        .background(AControlStyle.accentFill(.orange, colorScheme), in: Circle())
      VStack(alignment: .leading, spacing: 2) {
        Text(target.displayName)
          .font(.callout.weight(.semibold))
          .lineLimit(1)
        Text("\(target.pane.title) · \(target.remotePath)")
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      Spacer(minLength: 12)
      SoftButton(title: "Open", symbol: "arrow.up.forward.app") {
        Task { await model.openRemotePermissionTarget(target) }
      }
      .safeHelp("Open this target and its Privacy & Security pane on A.")
      SoftButton(title: "Remove", symbol: "minus.circle") {
        model.removePermissionTarget(target)
      }
    }
    .padding(10)
    .background(
      AControlStyle.insetFill(colorScheme),
      in: RoundedRectangle(cornerRadius: AControlStyle.insetRadius, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: AControlStyle.insetRadius, style: .continuous)
        .strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
    }
  }

  private func sensitiveValueButton(
    value: String,
    prompt: String,
    id: SensitiveSettingsField,
    forceBlur: Bool = false
  ) -> some View {
    let trimmed = value.trimmed
    let isEmpty = trimmed.isEmpty
    let shouldBlur = forceBlur && !revealedSensitiveFields.contains(id)
    return Button {
      if !isEmpty {
        if revealedSensitiveFields.contains(id) {
          revealedSensitiveFields.remove(id)
        } else {
          revealedSensitiveFields.insert(id)
        }
      }
    } label: {
      HStack(spacing: 8) {
        Text(isEmpty ? prompt : trimmed)
          .font(.system(.body, design: .monospaced))
          .foregroundStyle(isEmpty ? .secondary : .primary)
          .lineLimit(1)
          .truncationMode(.middle)
          .blur(radius: shouldBlur ? 4.2 : 0)
        Spacer(minLength: 0)
        if !isEmpty {
          Image(systemName: revealedSensitiveFields.contains(id) ? "eye" : "eye.slash")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
        }
      }
      .padding(.horizontal, 9)
      .frame(minHeight: 27)
      .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    .buttonStyle(ImmediateFeedbackButtonStyle())
    .background(
      AControlStyle.insetFill(colorScheme),
      in: RoundedRectangle(cornerRadius: 6, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .strokeBorder(AControlStyle.hairline(colorScheme), lineWidth: 1)
    }
    .safeHelp(isEmpty ? "No value saved." : "Click to reveal or hide this saved value.")
  }

  @ViewBuilder
  private func savedBadge(for value: String, showsSavedState: Bool) -> some View {
    if showsSavedState, !value.trimmed.isEmpty {
      Text("Saved")
        .font(.caption.weight(.bold))
        .foregroundStyle(AControlStyle.accentForeground(.green, colorScheme))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(AControlStyle.accentFill(.green, colorScheme), in: Capsule())
        .safeHelp("This value is saved in local SSHcontroll settings.")
    }
  }

  private func containsNetworkAddress(_ value: String) -> Bool {
    let ipv4Pattern =
      #"(?<![0-9])(?:25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])(?:\.(?:25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])){3}(?![0-9])"#
    if value.range(of: ipv4Pattern, options: .regularExpression) != nil {
      return true
    }
    let ipv6Pattern = #"(?i)\b(?:[0-9a-f]{1,4}:){2,}[0-9a-f:]*\b"#
    return value.range(of: ipv6Pattern, options: .regularExpression) != nil
  }
}

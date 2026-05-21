import SwiftUI

struct MonitorView: View {
    @EnvironmentObject private var model: AppModel

    var snapshot: MonitorSnapshot {
        MonitorSnapshot(raw: model.combinedMonitorSnapshot)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "A Monitor", detail: "A hardware snapshot") {
                await model.refreshMonitor()
            }

            if monitorNeedsPermissionGuide {
                MonitorSetupNotice()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                MonitorMetricButton(title: "CPU", value: displayValue("cpu", snapshot.cpu), subtitle: displaySubtitle("cpu", snapshot.cpuDetail), symbol: "cpu", tint: .cyan) {
                    Task { await model.refreshMonitorMetric("cpu") }
                }
                MonitorMetricButton(title: "GPU", value: displayValue("gpu", snapshot.gpu), subtitle: displaySubtitle("gpu", snapshot.gpuMemory), symbol: "display", tint: .purple) {
                    Task { await model.refreshMonitorMetric("gpu") }
                }
                MonitorMetricButton(title: "Memory", value: displayValue("memory", snapshot.memory), subtitle: displaySubtitle("memory", snapshot.memoryDetail), symbol: "memorychip", tint: .blue) {
                    Task { await model.refreshMonitorMetric("memory") }
                }
                MonitorMetricButton(title: "Network", value: displayValue("network", snapshot.network), subtitle: displaySubtitle("network", snapshot.networkDetail), symbol: "antenna.radiowaves.left.and.right", tint: .orange) {
                    Task { await model.refreshMonitorMetric("network") }
                }
                MonitorMetricButton(title: "Battery", value: displayValue("battery", snapshot.battery), subtitle: displaySubtitle("battery", snapshot.batteryDetail), symbol: "battery.100percent", tint: .green) {
                    Task { await model.refreshMonitorMetric("battery") }
                }
                MonitorMetricButton(title: "Fan", value: displayValue("fan", snapshot.fan.isEmpty ? "Not measured" : snapshot.fan), subtitle: displaySubtitle("fan", snapshot.fanDetail), symbol: "fan", tint: .teal, valueSize: fanValueSize, valueLineLimit: 2, subtitleLineLimit: 2) {
                    Task { await model.refreshMonitorMetric("fan") }
                }
                .contextMenu {
                    if snapshot.fanControlMissing {
                        Label("Macs Fan Control not installed", systemImage: "exclamationmark.triangle")
                    } else {
                        fanPresetMenu
                    }
                }
            }

            TranscriptView(text: model.combinedMonitorSnapshot, placeholder: "Press Refresh to read A hardware snapshot.")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await model.refreshMonitor()
        }
    }

    private func label(_ preset: String) -> String {
        switch preset {
        case "auto": "Auto"
        case "fullblast": "Full"
        default: preset
        }
    }

    private func displayValue(_ metric: String, _ value: String) -> String {
        if model.isRefreshingMonitor || model.monitorMetricInFlight == metric {
            return "Measuring..."
        }
        return value
    }

    private func displaySubtitle(_ metric: String, _ value: String) -> String {
        if model.isRefreshingMonitor {
            return metric == "fan" ? "5 sec sample" : "Reading A"
        }
        if model.monitorMetricInFlight == metric {
            return metric == "fan" ? "5 sec sample" : "Reading A"
        }
        return value
    }

    private var fanValueSize: CGFloat {
        if model.isRefreshingMonitor || model.monitorMetricInFlight == "fan" {
            return 23
        }
        return 17
    }

    @ViewBuilder
    private var fanPresetMenu: some View {
        ForEach(["auto", "fullblast", "3000", "4000", "5000"], id: \.self) { preset in
            Button {
                Task { await model.applyFan(preset) }
            } label: {
                Label(label(preset), systemImage: snapshot.fanPresetKey == preset ? "checkmark.circle" : fanPresetSymbol(preset))
            }
        }
    }

    private func fanPresetSymbol(_ preset: String) -> String {
        preset == "auto" ? "fan" : "speedometer"
    }

    private var monitorNeedsPermissionGuide: Bool {
        let lower = model.combinedMonitorSnapshot.lowercased()
        return lower.contains("grant accessibility") ||
            lower.contains("full disk access") ||
            lower.contains("fan rpm unavailable") ||
            lower.contains("permission")
    }

}

private struct MonitorSetupNotice: View {
    var body: some View {
        GlassPanel(title: "Monitor Setup", symbol: "info.circle", accent: .orange) {
            Text("Some monitor or fan readings may need remote macOS permissions. Ask your remote LLM agent to read `LLM_README.md` and run the helper's permission checks, then grant the requested macOS Privacy permissions on the remote Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MonitorMetricButton: View {
    var title: String
    var value: String
    var subtitle: String
    var symbol: String
    var tint: Color
    var valueSize: CGFloat = 23
    var valueLineLimit: Int = 2
    var subtitleLineLimit: Int = 2
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            MetricCard(title: title, value: value, subtitle: subtitle, symbol: symbol, tint: tint, valueSize: valueSize, valueLineLimit: valueLineLimit, subtitleLineLimit: subtitleLineLimit, minHeight: 126, fixedHeight: 126, padding: 15)
        }
        .buttonStyle(ImmediateFeedbackButtonStyle())
    }
}

struct MonitorSnapshot {
    var raw: String

    var lines: [String] {
        raw.components(separatedBy: .newlines)
    }

    var load: String {
        guard let line = find(prefix: "Load:") else { return "" }
        let parts = line.split(separator: " ").map(String.init)
        guard parts.count >= 3 else { return "Load \(line)" }
        return "Load 1m \(parts[0]) · 5m \(parts[1]) · 15m \(parts[2])"
    }

    var cpu: String {
        if let line = lines.first(where: { $0.lowercased().contains("cpu") && $0.contains("%") }) {
            return extractPercent(line) ?? line
        }
        return ""
    }

    var cpuDetail: String {
        if let line = lines.first(where: { $0.lowercased().hasPrefix("cpu:") }) {
            let detail = line
                .replacingOccurrences(of: "CPU:", with: "")
                .replacingOccurrences(of: ",", with: " ·")
                .trimmed
            return detail.isEmpty ? load : detail
        }
        return load
    }

    var gpu: String {
        if let line = lines.first(where: { $0.lowercased().hasPrefix("gpu") || $0.lowercased().contains("gpu:") }) {
            return extractPercent(line) ?? line
        }
        return ""
    }

    var gpuMemory: String {
        if let line = lines.first(where: { $0.lowercased().contains("gpu") && $0.lowercased().contains("memory") }) {
            return "memory " + (lastPercent(line) ?? line)
        }
        return ""
    }

    var memory: String {
        if let line = lines.first(where: { $0.lowercased().hasPrefix("memory") || $0.contains("PhysMem") }) {
            return extractPercent(line) ?? line.replacingOccurrences(of: "Memory:", with: "").replacingOccurrences(of: "PhysMem:", with: "").trimmed
        }
        return ""
    }

    var memoryDetail: String {
        guard let line = lines.first(where: { $0.lowercased().contains("pressure") || $0.lowercased().contains("wired") }) else {
            return ""
        }
        return line
            .replacingOccurrences(of: "Memory:", with: "")
            .replacingOccurrences(of: #"pressure\s+[0-9.]+%,\s*"#, with: "", options: .regularExpression)
            .trimmed
    }

    var network: String {
        guard let line = find(prefix: "Network:") else { return "" }
        return line
            .replacingOccurrences(of: ", down", with: "\ndown")
            .replacingOccurrences(of: ",  down", with: "\ndown")
    }

    var networkDetail: String {
        network.isEmpty ? "" : "Upload / Download"
    }

    var battery: String {
        if let line = lines.first(where: { $0.contains("InternalBattery") || $0.lowercased().hasPrefix("battery:") }) {
            return firstPercent(line) ?? line.replacingOccurrences(of: "Battery:", with: "").trimmed
        }
        return ""
    }

    var batteryDetail: String {
        var wanted = lines.filter {
            let lower = $0.lowercased()
            guard !lower.trimmingCharacters(in: .whitespaces).hasPrefix("battery:") else { return false }
            return lower.contains("adapter") ||
                lower.contains("battery temp") ||
                lower.contains("cycle")
        }
        if let battery = lines.first(where: { $0.lowercased().hasPrefix("battery:") }) {
            let detail = battery
                .replacingOccurrences(of: "Battery:", with: "")
                .replacingOccurrences(of: #"[0-9]+%"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: " ·,;"))
                .trimmed
            if !detail.isEmpty {
                wanted.insert(detail, at: 0)
            }
        }
        return wanted.joined(separator: " · ")
    }

    var fan: String {
        let measured = measuredFanLines
        if !measured.isEmpty {
            return measured.map { "\($0.name) \($0.rpm) rpm" }.joined(separator: "\n")
        }
        if fanControlMissing {
            return "Not installed"
        }
        if raw.lowercased().contains("measuring fan") {
            return "Measuring..."
        }
        if let line = lines.first(where: { $0.lowercased().hasPrefix("fan rpm:") }) {
            return line.replacingOccurrences(of: "Fan RPM:", with: "").trimmed
        }
        return ""
    }

    var fanDetail: String {
        var parts: [String] = []
        if fanControlMissing {
            parts.append("Preset app missing")
        }
        if let setting = lines.first(where: { $0.lowercased().contains("macs fan control setting:") }) {
            let value = setting
                .replacingOccurrences(of: "Macs Fan Control setting:", with: "")
                .trimmed
            if !value.isEmpty {
                parts.append("Setting \(value)")
            }
        }
        if let measuredAt = lines.last(where: { $0.lowercased().hasPrefix("measured at:") }) {
            if let time = compactMeasuredTime(measuredAt) {
                parts.append("Measured \(time)")
            }
        }
        if measuredFanLines.isEmpty,
           let sample = lines.first(where: { $0.lowercased().hasPrefix("sample window:") }) {
            parts.append(sample.trimmed)
        }
        return parts.joined(separator: "\n")
    }

    var fanPresetKey: String {
        guard !fanControlMissing else { return "" }
        for line in lines.reversed() {
            let lower = line.lowercased()
            if lower.contains("macs fan control setting:") || lower.trimmingCharacters(in: .whitespaces).hasPrefix("mode:") {
                if let key = fanPresetKey(from: lower) {
                    return key
                }
            }
        }
        return fanPresetKey(from: raw.lowercased()) ?? ""
    }

    var fanControlMissing: Bool {
        let lower = raw.lowercased()
        return lower.contains("macs fan control") && lower.contains("not installed")
    }

    private func fanPresetKey(from lower: String) -> String? {
        for rpm in ["3000", "4000", "5000"] {
            if lower.contains("mode: \(rpm)") || lower.contains("setting: \(rpm)") {
                return rpm
            }
        }
        if lower.contains("mode: fullblast") || lower.contains("full blast") {
            return "fullblast"
        }
        if lower.contains("mode: auto") || lower.contains("automatic") {
            return "auto"
        }
        if lower.contains("setting: auto") {
            return "auto"
        }
        return nil
    }

    private var measuredFanLines: [(name: String, rpm: String)] {
        let regex = try? NSRegularExpression(pattern: #"Fan\s+([0-9]+)\s+measured:\s+avg\s+([0-9]+)\s+rpm"#, options: [.caseInsensitive])
        var latest: [Int: String] = [:]
        for line in lines {
            guard let regex,
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let fanRange = Range(match.range(at: 1), in: line),
                  let rpmRange = Range(match.range(at: 2), in: line) else {
                continue
            }
            if let fan = Int(line[fanRange]) {
                latest[fan] = String(line[rpmRange])
            }
        }
        return latest.keys.sorted().map { fan in
            ("Fan \(fan)", latest[fan] ?? "")
        }
    }

    private func find(prefix: String) -> String? {
        lines.first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix(prefix) })?
            .replacingOccurrences(of: prefix, with: "")
            .trimmed
    }

    private func extractPercent(_ line: String) -> String? {
        firstPercent(line)
    }

    private func firstPercent(_ line: String) -> String? {
        let regex = try? NSRegularExpression(pattern: #"([0-9]+(?:\.[0-9]+)?)%"#)
        guard let match = regex?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range, in: line) else { return nil }
        return String(line[range])
    }

    private func lastPercent(_ line: String) -> String? {
        let regex = try? NSRegularExpression(pattern: #"([0-9]+(?:\.[0-9]+)?)%"#)
        guard let match = regex?.matches(in: line, range: NSRange(line.startIndex..., in: line)).last,
              let range = Range(match.range, in: line) else { return nil }
        return String(line[range])
    }

    private func compactMeasuredTime(_ line: String) -> String? {
        let raw = line
            .replacingOccurrences(of: "Measured at:", with: "")
            .trimmed
        if let match = firstMatch(in: raw, pattern: #"\b[0-9]{1,2}:[0-9]{2}(?::[0-9]{2})?\b"#) {
            return String(match.prefix(5))
        }
        return raw.isEmpty ? nil : raw
    }

    private func firstMatch(in value: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let range = Range(match.range, in: value) else { return nil }
        return String(value[range])
    }
}

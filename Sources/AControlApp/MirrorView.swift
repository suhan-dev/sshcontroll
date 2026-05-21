import SwiftUI

struct MirrorView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "A Mirror", detail: "\(model.currentRemoteDir) -> \(model.settings.mirrorBase)/mirror") {
                await model.latencyCheck()
            }

            GlassPanel(title: nil) {
                FlowLayout(spacing: 10) {
                    PrimaryButton(title: "Mirror Full", symbol: "arrow.down.doc", tint: .orange) {
                        Task { await model.mirrorFull() }
                    }
                    PrimaryButton(title: "Mirror Delta", symbol: "arrow.triangle.2.circlepath", tint: .blue) {
                        Task { await model.mirrorDelta() }
                    }
                    SoftButton(title: "Latency", symbol: "timer") {
                        Task { await model.latencyCheck() }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GlassPanel(title: "Mirror Log", symbol: "text.alignleft", accent: .orange, fillHeight: true) {
                TranscriptView(text: model.lastMirrorLog, placeholder: "Mirror and latency results will appear here.")
                    .frame(maxWidth: .infinity, minHeight: 260, maxHeight: .infinity)
                    .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

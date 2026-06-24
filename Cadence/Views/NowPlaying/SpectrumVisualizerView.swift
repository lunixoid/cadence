import SwiftUI

struct SpectrumVisualizerView: View {
    let analyzer: SpectrumAnalyzer
    let isPlaying: Bool

    @Environment(\.colorScheme) private var colorScheme

    private let labels = ["32", "64", "125", "250", "500", "1K", "2K", "4K", "8K", "16K"]
    private let labelHeight: CGFloat = 14
    private let barSpacing: CGFloat = 3

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: false)) { _ in
            Canvas { context, size in
                let plotH = size.height - labelHeight - 4
                let n = analyzer.bands.count
                guard n > 0, plotH > 0 else { return }

                let barW = (size.width - barSpacing * CGFloat(n - 1)) / CGFloat(n)
                let accent = CadenceTheme.accent(for: colorScheme)
                let labelColor = CadenceTheme.mutedText(for: colorScheme)

                for (i, band) in analyzer.bands.enumerated() {
                    let x = CGFloat(i) * (barW + barSpacing)

                    // Bar
                    let mag = CGFloat(max(band.magnitude, isPlaying ? 0 : 0))
                    let barH = max(2, mag * plotH)
                    let barY = plotH - barH + 2
                    let barRect = CGRect(x: x, y: barY, width: barW, height: barH)

                    let gradient = Gradient(colors: [
                        accent.opacity(0.94),
                        accent.opacity(0.25),
                    ])
                    context.fill(
                        Path(roundedRect: barRect, cornerSize: CGSize(width: 2, height: 2)),
                        with: .linearGradient(
                            gradient,
                            startPoint: CGPoint(x: x + barW / 2, y: barY),
                            endPoint: CGPoint(x: x + barW / 2, y: plotH + 2)
                        )
                    )

                    // Peak line
                    let peak = CGFloat(band.peak)
                    if peak > 0.08 {
                        let peakY = plotH - peak * plotH + 2
                        let peakRect = CGRect(x: x, y: peakY - 1, width: barW, height: 1.5)
                        context.fill(Path(peakRect), with: .color(accent.opacity(0.80)))
                    }

                    // Frequency label
                    context.draw(
                        Text(labels[i])
                            .font(.system(size: 9))
                            .foregroundStyle(labelColor),
                        at: CGPoint(x: x + barW / 2, y: size.height - labelHeight / 2),
                        anchor: .center
                    )
                }
            }
        }
        .frame(height: 110)
    }
}

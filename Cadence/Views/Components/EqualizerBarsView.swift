import SwiftUI

struct EqualizerBarsView: View {
    @Environment(\.colorScheme) private var colorScheme

    var color: Color?
    var size: CGFloat = 13

    @State private var animate = false

    private var barColor: Color {
        color ?? CadenceTheme.accent(for: colorScheme)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            bar(heightFactor: 0.35, delay: 0)
            bar(heightFactor: 0.75, delay: 0.2)
            bar(heightFactor: 0.55, delay: 0.4)
        }
        .frame(width: size, height: size)
        .onAppear {
            animate = true
        }
    }

    private func bar(heightFactor: CGFloat, delay: Double) -> some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(barColor)
            .frame(width: 2.5, height: animate ? size * heightFactor : size * 0.2)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(delay),
                value: animate
            )
    }
}

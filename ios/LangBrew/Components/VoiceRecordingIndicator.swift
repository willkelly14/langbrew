import SwiftUI

/// A compact recording indicator shown above the input bar during voice capture.
/// Displays a pulsing red circle, elapsed time, and simple amplitude bars.
struct VoiceRecordingIndicator: View {
    let duration: TimeInterval
    let amplitude: Float

    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 12) {
            // Pulsing red dot
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .scaleEffect(isPulsing ? 1.3 : 1.0)
                .opacity(isPulsing ? 0.7 : 1.0)
                .animation(
                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: isPulsing
                )
                .onAppear { isPulsing = true }

            // Duration timer
            Text(formattedDuration)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.lbBlack)

            // Amplitude bars
            amplitudeBars

            Spacer()

            Text("Recording")
                .font(.system(size: 12))
                .foregroundStyle(Color.lbG400)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.lbG50)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Duration Formatting

    private var formattedDuration: String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    // MARK: - Amplitude Bars

    private var amplitudeBars: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                let barAmplitude = barHeight(for: index)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.red.opacity(0.7))
                    .frame(width: 3, height: barAmplitude)
                    .animation(.easeInOut(duration: 0.15), value: amplitude)
            }
        }
        .frame(height: 20)
    }

    /// Calculates the height for each amplitude bar.
    /// Center bars are taller, edge bars shorter, all scaled by amplitude.
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeights: [CGFloat] = [0.4, 0.7, 1.0, 0.7, 0.4]
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = 20
        let base = baseHeights[index]
        let scaled = minHeight + (maxHeight - minHeight) * CGFloat(amplitude) * base
        return max(minHeight, scaled)
    }
}

#Preview {
    VStack(spacing: 20) {
        VoiceRecordingIndicator(duration: 3.5, amplitude: 0.3)
        VoiceRecordingIndicator(duration: 12.0, amplitude: 0.8)
        VoiceRecordingIndicator(duration: 0.0, amplitude: 0.0)
    }
    .padding()
    .background(Color.lbLinen)
}

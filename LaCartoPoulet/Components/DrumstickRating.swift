import SwiftUI

/// Five drumsticks for a 1–5 value, filled to the nearest half.
struct DrumstickRating: View {
    let value: Double
    var size: CGFloat = 20
    var color = Color("Crispy")
    var emptyColor = Color("Bone")
    @ScaledMetric private var scale = 1.0

    /// 4.3 → 4.5, 4.2 → 4.
    static func rounded(_ value: Double) -> Double {
        (value * 2).rounded() / 2
    }

    /// "4,3" whatever the device language: the app is French only.
    static func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "fr_FR")))
    }

    var body: some View {
        let filled = Self.rounded(value)
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                let fill = min(max(filled - Double(index - 1), 0), 1)
                stick(emptyColor)
                    .overlay(alignment: .leading) {
                        stick(color).mask(alignment: .leading) {
                            Rectangle().frame(width: scaledSize * fill)
                        }
                    }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(Self.formatted(value)) sur 5")
    }

    /// Grows with Dynamic Type, capped so five sticks still fit one line at the largest size.
    private var scaledSize: CGFloat { size * min(scale, 1.5) }

    private func stick(_ color: Color) -> some View {
        Image("drumstick").resizable().frame(width: scaledSize, height: scaledSize).foregroundStyle(color)
    }
}

#Preview {
    VStack(alignment: .leading) {
        DrumstickRating(value: 4.3, size: 32)
        DrumstickRating(value: 4.2)
        DrumstickRating(value: 1)
    }
}

import SwiftUI

/// The filled comb-red button for a screen's main action; shows a spinner while working.
struct PrimaryButtonStyle: ButtonStyle {
    var isWorking = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            configuration.label.opacity(isWorking ? 0 : 1)
            if isWorking { ProgressView().tint(Color("Feather")) }
        }
        .font(.body.weight(.semibold))
        .foregroundStyle(Color("Feather"))
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.vertical, 4)
        .background(Color("Comb"), in: RoundedRectangle(cornerRadius: 12))
        .opacity(configuration.isPressed || !isEnabled ? 0.6 : 1)
    }
}

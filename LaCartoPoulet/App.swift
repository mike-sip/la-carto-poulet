import SwiftUI

@main
struct LaCartoPouletApp: App {
    @State private var account = AccountViewModel()

    var body: some Scene {
        WindowGroup {
            MapView()
                .environment(account)
                .task { await account.restore() }
        }
    }
}

extension Font {
    /// Shrikhand, for restaurant names, screen titles and the big rating number only. Scales with Dynamic Type.
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom("Shrikhand-Regular", size: size, relativeTo: style)
    }
}

#Preview("Display font") {
    VStack(alignment: .leading, spacing: 8) {
        Text("Le Poulet Doré").font(.display(28, relativeTo: .title2))
        Text("Fast food à Lyon 7e").font(.subheadline).foregroundStyle(.secondary)
    }
    .padding(16)
}

import SwiftUI

/// Cluster marker: a basket with two eggs and the count in white on the basket.
struct NestMarker: View {
    let count: Int

    var body: some View {
        Image("nest")
            .resizable()
            .frame(width: 64, height: 44)
            .overlay {
                Text("\(count)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 1)
                    .padding(.top, 24)
            }
            .accessibilityElement()
            .accessibilityLabel("\(count) restos poulet")
            .accessibilityHint("Zoome sur ce nid")
            .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    HStack { NestMarker(count: 4); NestMarker(count: 128) }
}

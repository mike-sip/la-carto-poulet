import MapKit
import SwiftUI

/// Bottom sheet for one restaurant: the yolk header shows at once from map data, ratings load below it.
struct RestaurantSheet: View {
    let restaurant: Restaurant
    var repository: RatingRepository = SupabaseRatingRepository()
    /// Called after I publish my rating, so the map can make the marker hop.
    var onPublished: () -> Void = {}

    @Environment(AccountViewModel.self) private var account
    @State private var ratings: [Rating]?
    @State private var stats: RatingStats?
    @State private var failed = false
    @State private var showsForm = false
    @State private var reporting: Rating?
    @State private var blocking: Rating?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                VStack(spacing: 8) {
                    Button("Donner mon avis") { showsForm = true }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Itinéraire", action: openDirections)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color("Feet"))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("Feet"), lineWidth: 2))
                }
                .padding(16)
                list.padding(.horizontal, 16)
            }
        }
        .background(Color("Feather"))
        .task { await load() }
        .sheet(isPresented: $showsForm) {
            // Signed out, the same sheet signs in first, then turns into the form.
            if account.isSignedIn {
                RatingForm(restaurant: restaurant,
                           model: RatingFormModel(restaurantID: restaurant.id, repository: repository)) { published in
                    if published { onPublished() }
                    Task { await load() }
                }
            } else {
                AccountView(model: account)
            }
        }
        .sheet(item: $reporting, onDismiss: { Task { await load() } }) { rating in
            if account.isSignedIn {
                ReportSheet(rating: rating, repository: repository).presentationDetents([.medium, .large])
            } else {
                AccountView(model: account)
            }
        }
        .confirmationDialog("Bloquer \(blocking?.nickname ?? "") ?", isPresented: Binding(
            get: { blocking != nil }, set: { if !$0 { blocking = nil } }), titleVisibility: .visible, presenting: blocking) { rating in
            Button("Bloquer", role: .destructive) {
                Task { if await account.block(rating.userID) { await load() } }
            }
        } message: { _ in
            Text("Tu ne verras plus ses avis. Tu pourras le débloquer dans Mon compte.")
        }
        // "is_mine" depends on who is signed in.
        .onChange(of: account.isSignedIn) { Task { await load() } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(restaurant.name)
                .font(.display(26, relativeTo: .title2))
                .accessibilityAddTraits(.isHeader)
            Text(subtitle).font(.subheadline)
            if let address = restaurant.address {
                Text(address).font(.subheadline)
            }
            if let stats {
                let average = stats.avgStars
                let score = HStack(spacing: 8) {
                    Text(DrumstickRating.formatted(average)).font(.display(28, relativeTo: .title2)).fixedSize()
                    DrumstickRating(value: average, size: 24, emptyColor: Color("Crispy").opacity(0.28))
                }
                let count = Text("\(stats.ratingCount) avis").font(.subheadline)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { score; count }
                    VStack(alignment: .leading, spacing: 4) { score; count }
                }
                .accessibilityElement()
                .accessibilityLabel("\(DrumstickRating.formatted(average)) sur 5, \(stats.ratingCount) avis")
            }
        }
        .foregroundStyle(Color("Ink"))
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("Yolk"))
        .environment(\.colorScheme, .light)  // yolk stays yellow in dark mode, so its text stays navy
    }

    private var subtitle: String {
        let kind = restaurant.kind == "fast_food" ? "Fast food" : "Restaurant"
        return restaurant.city.map { "\(kind) à \($0)" } ?? kind
    }

    @ViewBuilder private var list: some View {
        if failed {
            HStack {
                Text("Impossible de charger les avis").font(.subheadline)
                Spacer()
                Button("Réessayer") { Task { await load() } }.foregroundStyle(Color("Feet"))
            }
            .padding(.vertical, 12)
        } else if let ratings, ratings.isEmpty {
            Text("Pas encore d'avis. Sois le premier !")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 12)
        } else {
            let placeholders = (1...3).map { Rating(id: -$0, stars: 4, comment: "Les tenders sont croustillants, la sauce vaut le détour.", createdAt: .now, nickname: "Poulette", userID: UUID(), isMine: true) }
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(ratings ?? placeholders) { rating in
                    RatingRow(rating: rating, onReport: rating.isMine ? nil : { reporting = rating },
                              onBlock: rating.isMine || !account.isSignedIn ? nil : { blocking = rating })
                }
            }
            .redacted(reason: ratings == nil ? .placeholder : [])
        }
    }

    private func load() async {
        failed = false
        do {
            async let list = repository.ratings(for: restaurant.id)
            async let totals = repository.stats(for: restaurant.id)
            (ratings, stats) = try await (list, totals)
        } catch is CancellationError {
        } catch {
            failed = true
        }
    }

    private func openDirections() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: restaurant.coordinate))
        item.name = restaurant.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault])
    }
}

/// One comment: nickname, drumsticks, "il y a 2 jours", text.
struct RatingRow: View {
    let rating: Rating
    /// Nil on my own rating.
    var onReport: (() -> Void)?
    /// Nil on my own rating and when signed out.
    var onBlock: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            HStack(alignment: .top) {
                ViewThatFits {
                    HStack { nickname; Spacer(); DrumstickRating(value: Double(rating.stars)) }
                    VStack(alignment: .leading) { nickname; DrumstickRating(value: Double(rating.stars)) }
                }
                if let onReport {
                    Menu {
                        Button("Signaler", systemImage: "flag", action: onReport)
                        if let onBlock {
                            Button("Bloquer cet utilisateur", systemImage: "hand.raised", role: .destructive, action: onBlock)
                        }
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 44, height: 44)
                    }
                    .accessibilityHidden(true)  // reachable through the row's own action below
                    .padding(.vertical, -12)
                }
            }
            .padding(.top, 8)
            Text(rating.createdAt.formatted(Date.RelativeFormatStyle(presentation: .named, locale: Locale(identifier: "fr_FR"))))
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let comment = rating.comment {
                Text(comment).font(.subheadline)
            }
        }
        .foregroundStyle(Color("Ink"))
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityActions {
            if let onReport { Button("Signaler", action: onReport) }
            if let onBlock { Button("Bloquer cet utilisateur", action: onBlock) }
        }
    }

    private var nickname: some View {
        Text(rating.nickname).font(.subheadline.weight(.bold))
    }
}

#Preview {
    Text("Carte").sheet(isPresented: .constant(true)) {
        RestaurantSheet(restaurant: Restaurant(id: 1, name: "Le Poulet Doré", kind: "fast_food", address: nil,
                                               city: "Lyon 7e", lat: 45.75, lng: 4.84))
            .presentationDetents([.medium, .large])
            .environment(AccountViewModel())
    }
}

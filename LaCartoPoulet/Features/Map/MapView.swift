import CoreLocation
import MapKit
import SwiftUI

struct MapView: View {
    static let paris = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08))

    // Follows the user once allowed; stays on Paris if location is refused.
    @State private var position: MapCameraPosition = .userLocation(fallback: .region(MapView.paris))
    @State private var locationManager = CLLocationManager()
    @State private var model = MapViewModel()
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var loadTask: Task<Void, Never>?
    @State private var selected: Restaurant?
    @State private var showsAccount = false
    @State private var query = ""
    /// The name to prefill when suggesting a missing restaurant; nil when the sheet is closed.
    @State private var suggestedName: String?
    @FocusState private var searching: Bool
    /// Hops per restaurant id; bumping one makes that marker hop twice.
    @State private var hops: [Int: Int] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AccountViewModel.self) private var account

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
            if let visibleRegion, !model.isTooFar {
                ForEach(MapViewModel.clusters(model.shown, in: visibleRegion)) { cluster in
                    if cluster.restaurants.count == 1 {
                        Annotation(cluster.restaurants[0].name, coordinate: cluster.coordinate, anchor: .bottom) {
                            Image("chicken-pin")
                                .resizable()
                                .frame(width: 56, height: 56)
                                .accessibilityLabel(cluster.restaurants[0].name)
                                .accessibilityAddTraits(.isButton)
                                .onTapGesture { selected = cluster.restaurants[0] }
                                .keyframeAnimator(initialValue: 0.0, trigger: hops[cluster.restaurants[0].id, default: 0]) { pin, lift in
                                    pin.offset(y: lift)
                                } keyframes: { _ in
                                    KeyframeTrack {
                                        SpringKeyframe(-18, duration: 0.2)
                                        SpringKeyframe(0, duration: 0.25)
                                        SpringKeyframe(-18, duration: 0.2)
                                        SpringKeyframe(0, duration: 0.25)
                                    }
                                }
                        }
                        .annotationTitles(.hidden)
                    } else {
                        Annotation("", coordinate: cluster.coordinate) {
                            NestMarker(count: cluster.restaurants.count)
                                .onTapGesture { zoom(into: cluster, from: visibleRegion) }
                        }
                        .annotationTitles(.hidden)
                    }
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    searchField
                    Button { showsAccount = true } label: {
                        Image(systemName: account.isSignedIn ? "person.fill" : "person")
                            .font(.title3)
                            .foregroundStyle(Color("Ink"))
                            .frame(width: 44, height: 44)
                            .background(Color("Feather"), in: Circle())
                            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                    }
                    .accessibilityLabel("Mon compte")
                }
                if searching && query.trimmingCharacters(in: .whitespaces).count >= 2 {
                    searchResults
                } else if !searching {
                    filterChips
                }
            }
            .padding(.horizontal, 16)
        }
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(300))  // waits for a pause in typing
            guard !Task.isCancelled else { return }
            await model.search(query)
        }
        .sheet(isPresented: $showsAccount) {
            AccountView(model: account)
        }
        .sheet(isPresented: Binding { suggestedName != nil } set: { if !$0 { suggestedName = nil } }) {
            SuggestSheet(account: account, name: suggestedName ?? "")
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            reload(context.region)
        }
        .overlay(alignment: .top) {
            if model.failed {
                Text("Pas de connexion. Les poulets déjà affichés restent là.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("Feather"))
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color("Comb"))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            OSMCredit()
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color("Feather").opacity(0.85), in: Capsule())
                .padding(8)
        }
        .overlay(alignment: .bottom) {
            if model.isTooFar {
                pill("Zoome pour voir les restos")
            } else if model.shown.isEmpty && !model.restaurants.isEmpty {
                pill("Aucun resto « \(model.filter.rawValue) » ici")
            } else if model.isEmptyArea && !model.failed {
                pill("Aucun resto poulet ici. Déplace la carte !")
            } else if model.isLoading {
                ProgressView()
                    .padding(10)
                    .background(Color("Feather"), in: Circle())
                    .padding(.bottom, 32)
            }
        }
        .sheet(item: $selected) { restaurant in
            RestaurantSheet(restaurant: restaurant) {
                if !reduceMotion { hops[restaurant.id, default: 0] += 1 }
            }
                .presentationDetents([.medium, .large])
        }
        .task {
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            }
            // .userLocation(fallback:) stays on the fallback when the first fix arrives after launch.
            do {
                for try await update in CLLocationUpdate.liveUpdates() {
                    guard let location = update.location else { continue }
                    position = .region(MKCoordinateRegion(center: location.coordinate, span: MapView.paris.span))
                    break
                }
            } catch {}
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color("Feet"))
                .accessibilityHidden(true)
            TextField("Ville ou resto", text: $query)
                .focused($searching)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onSubmit {
                    if let first = model.foundRestaurants.first { show(first) }
                    else if let first = model.foundPlaces.first { go(to: first) }
                }
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color("Feet"))
                }
                .accessibilityLabel("Effacer la recherche")
            }
        }
        .foregroundStyle(Color("Ink"))
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Color("Feather"), in: Capsule())
        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MapViewModel.Filter.allCases) { filter in
                    let isOn = model.filter == filter
                    Button { model.filter = filter } label: {
                        Text(filter.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(isOn ? "Feather" : "Ink"))
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(Color(isOn ? "Ink" : "Feather"), in: Capsule())
                            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                    }
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)  // room for the shadows
        }
        .scrollClipDisabled()
    }

    private var searchResults: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(model.foundRestaurants) { restaurant in
                    resultRow(restaurant.name, detail: detail(for: restaurant)) {
                        Image("chicken-pin").resizable().frame(width: 28, height: 28)
                    } action: { show(restaurant) }
                }
                ForEach(model.foundPlaces) { place in
                    resultRow(place.name, detail: place.detail) {
                        Image(systemName: "mappin.circle.fill").font(.title2).foregroundStyle(Color("Comb"))
                    } action: { go(to: place) }
                }
                if model.foundRestaurants.isEmpty && model.foundPlaces.isEmpty
                    && model.searchedQuery == query.trimmingCharacters(in: .whitespaces) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aucun resto ni ville à ce nom.")
                            .font(.subheadline)
                            .foregroundStyle(Color("Feet"))
                        Button("Il manque un resto ? Suggère-le") {
                            suggestedName = query.trimmingCharacters(in: .whitespaces)
                            endSearch()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("Comb"))
                        .frame(minHeight: 44)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                }
            }
        }
        .frame(maxHeight: 360)
        .fixedSize(horizontal: false, vertical: true)  // as tall as the results, up to 360
        .background(Color("Feather"), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
    }

    /// Most restaurants have no city in OSM, so the distance is what tells same-named ones apart.
    private func detail(for restaurant: Restaurant) -> String? {
        guard let center = visibleRegion?.center else { return restaurant.city }
        let meters = CLLocation(latitude: center.latitude, longitude: center.longitude)
            .distance(from: CLLocation(latitude: restaurant.lat, longitude: restaurant.lng))
        let distance = "à " + Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
        return [restaurant.city, distance].compactMap { $0 }.joined(separator: ", ")
    }

    private func resultRow(_ title: String, detail: String?, @ViewBuilder icon: () -> some View,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                icon().frame(width: 32).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold)).foregroundStyle(Color("Ink"))
                    if let detail { Text(detail).font(.caption).foregroundStyle(Color("Feet")) }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
    }

    /// Flies to the restaurant and opens its sheet.
    private func show(_ restaurant: Restaurant) {
        endSearch()
        withAnimation {
            position = .region(MKCoordinateRegion(center: restaurant.coordinate,
                                                  span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
        }
        selected = restaurant
    }

    private func go(to place: MapViewModel.Place) {
        endSearch()
        withAnimation { position = .region(MKCoordinateRegion(center: place.coordinate, span: MapView.paris.span)) }
    }

    private func endSearch() {
        searching = false
        query = ""
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color("Ink"))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color("Feather"), in: Capsule())
            .padding(.bottom, 32)
    }

    /// Loads the area once the map stops moving; on a network error retries every 5 s until the map moves again.
    private func reload(_ region: MKCoordinateRegion) {
        visibleRegion = region
        loadTask?.cancel()
        loadTask = Task {
            while await !model.load(region) {
                try? await Task.sleep(for: .seconds(5))
                if Task.isCancelled { return }
            }
        }
    }

    private func zoom(into cluster: MapViewModel.Cluster, from region: MKCoordinateRegion) {
        let span = MKCoordinateSpan(latitudeDelta: region.span.latitudeDelta / 3,
                                    longitudeDelta: region.span.longitudeDelta / 3)
        withAnimation { position = .region(MKCoordinateRegion(center: cluster.coordinate, span: span)) }
    }
}

/// Restaurant data comes from OpenStreetMap (ODbL): the credit must stay visible.
struct OSMCredit: View {
    var body: some View {
        Link("© OpenStreetMap contributors", destination: URL(string: "https://www.openstreetmap.org/copyright")!)
            .foregroundStyle(Color("Feet"))
    }
}

#Preview {
    MapView().environment(AccountViewModel())
}

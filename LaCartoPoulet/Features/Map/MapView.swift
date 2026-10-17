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

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
            if let visibleRegion, !model.isTooFar {
                ForEach(MapViewModel.clusters(model.restaurants, in: visibleRegion)) { cluster in
                    if cluster.restaurants.count == 1 {
                        Annotation(cluster.restaurants[0].name, coordinate: cluster.coordinate, anchor: .bottom) {
                            Image("chicken-pin")
                                .resizable()
                                .frame(width: 56, height: 56)
                                .accessibilityLabel(cluster.restaurants[0].name)
                                .accessibilityAddTraits(.isButton)
                                .onTapGesture { selected = cluster.restaurants[0] }
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
        .overlay(alignment: .bottom) {
            if model.isTooFar {
                pill("Zoome pour voir les restos")
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
            RestaurantSheet(restaurant: restaurant)
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

#Preview {
    MapView()
}

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

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
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
}

#Preview {
    MapView()
}

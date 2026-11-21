import CoreLocation
import Foundation

/// Distance of a cinema before the app knows where the user is.
nonisolated let unknownDistance: CLLocationDistance = -1

nonisolated let noCinemaSelected = ""
nonisolated let cinemaNotFound = -1

// Rynek, gdy położenie jest nieznane
nonisolated let fallbackCoordinate = CLLocationCoordinate2D(
    latitude: 51.1100,
    longitude: 17.0320
)
nonisolated let fallbackUserLocation = UserLocation(
    latitude: fallbackCoordinate.latitude,
    longitude: fallbackCoordinate.longitude,
    isKnown: false
)

private let metersPerKilometer: CLLocationDistance = 1000

/// A cinema in Wrocław, a plain struct,
/// so the views and tests do not depend on `MKMapItem`.
nonisolated struct Cinema: Identifiable, Hashable {
    let id: String
    let name: String
    let address: String  // empty when unknown
    let phoneNumber: String  // empty when unknown
    let website: String  // empty when unknown
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    var distanceInMeters = unknownDistance
}

/// Where the user is. `isKnown` is false when the app does not know it.
nonisolated struct UserLocation: Equatable {
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    let isKnown: Bool
}

func cinemaCoordinate(_ cinema: Cinema) -> CLLocationCoordinate2D {
    return CLLocationCoordinate2D(latitude: cinema.latitude, longitude: cinema.longitude)
}

func userCoordinate(_ location: UserLocation) -> CLLocationCoordinate2D {
    return CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
}

func distanceInMeters(from userLocation: UserLocation, to cinema: Cinema) -> CLLocationDistance {
    let start = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
    let end = CLLocation(latitude: cinema.latitude, longitude: cinema.longitude)
    return start.distance(from: end)
}

func isCloser(_ first: Cinema, _ second: Cinema) -> Bool {
    if first.distanceInMeters != second.distanceInMeters {
        if first.distanceInMeters == unknownDistance {
            return false
        }
        if second.distanceInMeters == unknownDistance {
            return true
        }
        return first.distanceInMeters < second.distanceInMeters
    }
    return first.name.localizedStandardCompare(second.name) == .orderedAscending
}

func cinemasSortedByDistance(_ cinemas: [Cinema], from userLocation: UserLocation) -> [Cinema] {
    var updated: [Cinema] = []
    for var cinema in cinemas {
        if userLocation.isKnown {
            cinema.distanceInMeters = distanceInMeters(from: userLocation, to: cinema)
        }
        updated.append(cinema)
    }
    return updated.sorted(by: isCloser)
}

func positionOfCinema(_ cinemas: [Cinema], cinemaId: String) -> Int {
    for index in cinemas.indices {
        if cinemas[index].id == cinemaId {
            return index
        }
    }
    return cinemaNotFound
}

func containsCinema(_ cinemas: [Cinema], cinemaId: String) -> Bool {
    return positionOfCinema(cinemas, cinemaId: cinemaId) != cinemaNotFound
}

func formattedDistance(_ distanceInMeters: CLLocationDistance) -> String {
    guard distanceInMeters >= 0 else {
        return ""
    }
    if distanceInMeters < metersPerKilometer {
        return "\(Int(distanceInMeters.rounded())) m"
    }
    let kilometers = distanceInMeters / metersPerKilometer
    return String(format: "%.1f km", locale: Locale(identifier: "en_US_POSIX"), kilometers)
}

func hasPhoneNumber(_ cinema: Cinema) -> Bool {
    return phoneURL(cinema) != nil
}

func phoneURL(_ cinema: Cinema) -> URL? {
    let allowedCharacters = Set("+0123456789")
    let cleaned = cinema.phoneNumber.filter { allowedCharacters.contains($0) }
    guard !cleaned.isEmpty else {
        return nil
    }
    return URL(string: "tel:\(cleaned)")
}

func hasWebsite(_ cinema: Cinema) -> Bool {
    return websiteURL(cinema) != nil
}

func websiteURL(_ cinema: Cinema) -> URL? {
    let trimmed = cinema.website.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let url = URL(string: trimmed), url.scheme != nil else {
        return nil
    }
    return url
}

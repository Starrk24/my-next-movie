//
//  Maps.swift
//  MyNextMovie
//
//  Created by Miłosz Siałkowski on 14/11/2026.
//

import CoreLocation
import Foundation
import MapKit

typealias UserLocationFinder = () async -> UserLocation
typealias LastKnownLocationReader = () -> UserLocation

enum TravelMode: Hashable {
    case walking
    case driving
}

struct CinemaRoute {
    let line: MKPolyline
    let distanceInMeters: CLLocationDistance
    let travelTime: TimeInterval
}

let noRoute = CinemaRoute(
    line: MKPolyline(),
    distanceInMeters: 0,
    travelTime: 0
)

struct NoRouteFound: LocalizedError {
    var errorDescription: String? {
        return "Maps found no way to this cinema."
    }
}

typealias CinemaRouteFinder = (UserLocation, Cinema, TravelMode) async throws -> CinemaRoute

func mapItemForCinema(_ cinema: Cinema) -> MKMapItem {
    let location = CLLocation(latitude: cinema.latitude, longitude: cinema.longitude)
    let address = cinema.address.isEmpty
        ? nil
        : MKAddress(fullAddress: cinema.address, shortAddress: nil)
    let item = MKMapItem(location: location, address: address)
    item.name = cinema.name
    return item
}

func transportTypeForMapKit(_ travelMode: TravelMode) -> MKDirectionsTransportType {
    switch travelMode {
    case .walking:
        return .walking
    case .driving:
        return .automobile
    }
}

func findMapKitRoute(
    userLocation: UserLocation,
    cinema: Cinema,
    travelMode: TravelMode
) async throws -> CinemaRoute {
    let userPoint = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
    let sourceItem = MKMapItem(location: userPoint, address: nil)
    let destinationItem = mapItemForCinema(cinema)

    let request = MKDirections.Request()
    request.source = sourceItem
    request.destination = destinationItem
    request.transportType = transportTypeForMapKit(travelMode)

    let response = try await MKDirections(request: request).calculate()
    guard let firstRoute = response.routes.first else {
        throw NoRouteFound()
    }
    return CinemaRoute(
        line: firstRoute.polyline,
        distanceInMeters: firstRoute.distance,
        travelTime: firstRoute.expectedTravelTime
    )
}

func openCinemaInMaps(_ cinema: Cinema, travelMode: TravelMode) {
    let item = mapItemForCinema(cinema)
    let directionMode = travelMode == .walking
        ? MKLaunchOptionsDirectionsModeWalking
        : MKLaunchOptionsDirectionsModeDriving
    item.openInMaps(launchOptions: [
        MKLaunchOptionsDirectionsModeKey: directionMode
    ])
}

func findLookAroundScene(_ cinema: Cinema) async -> MKLookAroundScene? {
    let request = MKLookAroundSceneRequest(coordinate: cinemaCoordinate(cinema))
    return try? await request.scene
}

//
//  CinemaDetailViewModel.swift
//  MyNextMovie
//
//  Created by Miłosz Siałkowski on 14/11/2026.
//

import Foundation
import Observation

private let secondsPerMinute: TimeInterval = 60
private let routeSummarySeparator = " \u{00B7} "

@MainActor
@Observable
final class CinemaDetailViewModel {
    let cinema: Cinema
    let userLocation: UserLocation
    var travelMode: TravelMode = .walking
    private(set) var routeState: LoadState = .idle
    private(set) var route: CinemaRoute = noRoute
    private(set) var errorMessage: String = ""

    private let findRoute: CinemaRouteFinder

    init(
        cinema: Cinema,
        userLocation: UserLocation,
        findRoute: @escaping CinemaRouteFinder
    ) {
        self.cinema = cinema
        self.userLocation = userLocation
        self.findRoute = findRoute
    }

    var canFindRoute: Bool {
        return userLocation.isKnown
    }

    func loadRoute() async {
        guard canFindRoute else {
            return
        }
        routeState = .loading
        errorMessage = ""

        do {
            route = try await findRoute(userLocation, cinema, travelMode)
            routeState = .loaded
        } catch {
            route = noRoute
            routeState = .failed
            errorMessage = error.localizedDescription
        }
    }
}

func formattedTravelTime(_ travelTime: TimeInterval) -> String {
    guard travelTime > 0 else {
        return ""
    }
    let minutes = max(1, Int((travelTime / secondsPerMinute).rounded()))
    return "\(minutes) min"
}

func routeSummary(_ route: CinemaRoute) -> String {
    let timeText = formattedTravelTime(route.travelTime)
    let distanceText = formattedDistance(route.distanceInMeters)
    if !timeText.isEmpty && !distanceText.isEmpty {
        return "\(timeText)\(routeSummarySeparator)\(distanceText)"
    }
    return timeText.isEmpty ? distanceText : timeText
}

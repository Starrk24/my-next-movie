//
//  CinemaMapViewModel.swift
//  MyNextMovie
//
//  Created by Miłosz Siałkowski on 14/11/2026.
//

import Foundation
import MapKit
import Observation

@MainActor
@Observable
final class CinemaMapViewModel {
    private(set) var cinemas: [Cinema]
    private(set) var userLocation: UserLocation = fallbackUserLocation
    var selectedCinemaId: String = noCinemaSelected
    private(set) var isLocating: Bool = false
    var visibleRegion: MKCoordinateRegion = wroclawMapRegion

    private let findUserLocation: UserLocationFinder
    private let lastKnownLocation: LastKnownLocationReader
    private var hasAskedForLocation: Bool = false

    init(
        cinemas: [Cinema],
        findUserLocation: @escaping UserLocationFinder,
        lastKnownLocation: @escaping LastKnownLocationReader = { fallbackUserLocation }
    ) {
        self.cinemas = cinemasSortedByDistance(cinemas, from: fallbackUserLocation)
        self.findUserLocation = findUserLocation
        self.lastKnownLocation = lastKnownLocation
    }

    var isLocationUnavailable: Bool {
        return hasAskedForLocation && !isLocating && !userLocation.isKnown
    }

    func locateUserIfNeeded() async {
        guard !hasAskedForLocation else {
            return
        }
        await locateUser()
    }

    func locateUser() async {
        hasAskedForLocation = true
        isLocating = true

        let lastKnown = lastKnownLocation()
        if lastKnown.isKnown {
            applyLocation(lastKnown)
        }

        let freshLocation = await findUserLocation()
        if freshLocation.isKnown {
            applyLocation(freshLocation)
        }

        isLocating = false
    }

    func toggleCinema(_ cinemaId: String) {
        if selectedCinemaId == cinemaId {
            selectedCinemaId = noCinemaSelected
        } else {
            selectedCinemaId = cinemaId
            let index = positionOfCinema(cinemas, cinemaId: cinemaId)
            if index != cinemaNotFound {
                visibleRegion = regionMoved(
                    visibleRegion,
                    to: cinemaCoordinate(cinemas[index])
                )
            }
        }
    }

    private func applyLocation(_ location: UserLocation) {
        userLocation = location
        cinemas = cinemasSortedByDistance(cinemas, from: location)
    }
}

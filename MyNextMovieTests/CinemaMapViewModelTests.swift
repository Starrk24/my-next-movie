//
//  CinemaMapViewModelTests.swift
//  MyNextMovieTests
//
//  Created by Miłosz Siałkowski on 14/11/2026.
//

import Foundation
import Testing
@testable import MyNextMovie

@MainActor
struct CinemaMapViewModelTests {
    @Test
    func showsCinemasAtOnceByName() {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas,
            findUserLocation: { fallbackUserLocation }
        )

        #expect(
            namesOf(viewModel.cinemas) == [
                "DCF",
                "Helios Magnolia",
                "Kino Nowe Horyzonty",
                "Multikino Pasaż Grunwaldzki"
            ]
        )
    }

    @Test
    func sortsByDistanceOnceUserIsFound() async {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas,
            findUserLocation: { testUserLocation }
        )

        await viewModel.locateUser()

        #expect(viewModel.userLocation == testUserLocation)
        #expect(viewModel.cinemas.first?.id == "dcf")
    }

    @Test
    func lastKnownLocationIsUsedWhenNoFreshOneComes() async {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas,
            findUserLocation: { fallbackUserLocation },
            lastKnownLocation: { testUserLocation }
        )

        await viewModel.locateUser()

        #expect(viewModel.userLocation == testUserLocation)
        #expect(viewModel.cinemas.first?.id == "dcf")
    }

    @Test
    func freshLocationReplacesLastKnownOne() async {
        let otherLocation = UserLocation(
            latitude: testCinemaHelios.latitude,
            longitude: testCinemaHelios.longitude,
            isKnown: true
        )
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas,
            findUserLocation: { testUserLocation },
            lastKnownLocation: { otherLocation }
        )

        await viewModel.locateUser()

        #expect(viewModel.userLocation == testUserLocation)
        #expect(viewModel.cinemas.first?.id == "dcf")
    }

    @Test
    func saysWhenLocationIsUnavailable() async {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas,
            findUserLocation: { fallbackUserLocation }
        )

        #expect(viewModel.isLocationUnavailable == false)

        await viewModel.locateUser()

        #expect(viewModel.isLocationUnavailable == true)
    }

    @Test
    func asksForLocationOnlyOnce() async {
        var calls = 0
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas,
            findUserLocation: {
                calls += 1
                return testUserLocation
            }
        )

        await viewModel.locateUserIfNeeded()
        await viewModel.locateUserIfNeeded()

        #expect(calls == 1)
    }

    @Test
    func togglesSelection() {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas,
            findUserLocation: { fallbackUserLocation }
        )

        viewModel.toggleCinema("dcf")
        #expect(viewModel.selectedCinemaId == "dcf")

        viewModel.toggleCinema("dcf")
        #expect(viewModel.selectedCinemaId == noCinemaSelected)
    }
    
    
}
@MainActor
struct CinemaDetailViewModelTests {
    @Test
    func findsNoRouteWithoutLocation() async {
        var routeCalls = 0
        let viewModel = CinemaDetailViewModel(
            cinema: testCinemaDCF,
            userLocation: fallbackUserLocation,
            findRoute: { _, _, _ in
                routeCalls += 1
                return noRoute
            }
        )

        #expect(viewModel.canFindRoute == false)
        await viewModel.loadRoute()
        #expect(routeCalls == 0)
        #expect(viewModel.routeState == .idle)
    }

    @Test
    func findsRouteForSelectedTravelMode() async {
        var receivedMode: TravelMode?
        let expectedRoute = CinemaRoute(
            line: noRoute.line,
            distanceInMeters: 950,
            travelTime: 720
        )
        let viewModel = CinemaDetailViewModel(
            cinema: testCinemaDCF,
            userLocation: testUserLocation,
            findRoute: { _, _, mode in
                receivedMode = mode
                return expectedRoute
            }
        )

        viewModel.travelMode = .driving
        await viewModel.loadRoute()

        #expect(receivedMode == .driving)
        #expect(viewModel.routeState == .loaded)
        #expect(viewModel.route.distanceInMeters == 950)
        #expect(viewModel.route.travelTime == 720)
    }

    @Test
    func showsErrorWhenRouteFails() async {
        let viewModel = CinemaDetailViewModel(
            cinema: testCinemaDCF,
            userLocation: testUserLocation,
            findRoute: { _, _, _ in
                throw NoRouteFound()
            }
        )

        await viewModel.loadRoute()

        #expect(viewModel.routeState == .failed)
        #expect(viewModel.errorMessage.contains("Maps found no way"))
    }

    @Test
    func routeSummaryHasTimeAndDistance() {
        let route = CinemaRoute(
            line: noRoute.line,
            distanceInMeters: 950,
            travelTime: 720
        )
        #expect(formattedTravelTime(720) == "12 min")
        #expect(routeSummary(route) == "12 min \u{00B7} 950 m")
    }
}

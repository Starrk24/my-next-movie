//
//  CinemaTests.swift
//  MyNextMovieTests
//
//  Created by Miłosz Siałkowski on 14/11/2026.
//

import CoreLocation
import Foundation
import MapKit
import Testing
@testable import MyNextMovie

@MainActor
struct CinemaTests {
    @Test
    func sortsCinemasClosestFirst() {
        let sorted = cinemasSortedByDistance(testCinemas, from: testUserLocation)
        #expect(
            namesOf(sorted) == [
                "DCF",
                "Kino Nowe Horyzonty",
                "Multikino Pasaż Grunwaldzki",
                "Helios Magnolia"
            ]
        )
    }

    @Test
    func measuresDistanceOfEveryCinema() {
        let sorted = cinemasSortedByDistance(testCinemas, from: testUserLocation)
        for cinema in sorted {
            #expect(cinema.distanceInMeters > 0)
            #expect(cinema.distanceInMeters != unknownDistance)
        }
    }

    @Test
    func sortsCinemasAtTheSameDistanceByName() {
        let sorted = cinemasSortedByDistance(testCinemas, from: fallbackUserLocation)
        #expect(
            namesOf(sorted) == [
                "DCF",
                "Helios Magnolia",
                "Kino Nowe Horyzonty",
                "Multikino Pasaż Grunwaldzki"
            ]
        )
    }

    @Test
    func findsPositionOfCinema() {
        #expect(positionOfCinema(testCinemas, cinemaId: "dcf") == 2)
        #expect(positionOfCinema(testCinemas, cinemaId: "missing") == cinemaNotFound)
        #expect(containsCinema(testCinemas, cinemaId: "dcf") == true)
        #expect(containsCinema(testCinemas, cinemaId: "missing") == false)
    }

    @Test
    func unknownDistanceIsEmptyText() {
        #expect(formattedDistance(unknownDistance) == "")
        #expect(formattedDistance(850) == "850 m")
        #expect(formattedDistance(2400) == "2.4 km")
    }

    @Test
    func phoneLinkHasOnlyDigits() {
        #expect(hasPhoneNumber(testCinemaNoweHoryzonty) == true)
        #expect(phoneURL(testCinemaNoweHoryzonty)?.absoluteString == "tel:+48717864566")
    }

    @Test
    func noPhoneOrWebsiteMeansNoLink() {
        #expect(hasPhoneNumber(testCinemaHelios) == false)
        #expect(phoneURL(testCinemaHelios) == nil)
        #expect(hasWebsite(testCinemaHelios) == false)
        #expect(websiteURL(testCinemaHelios) == nil)
        #expect(hasWebsite(testCinemaNoweHoryzonty) == true)
        #expect(websiteURL(testCinemaNoweHoryzonty)?.absoluteString == "https://kinonh.pl")
    }
}

@MainActor
struct WroclawCinemasTests {
    @Test
    func everyCinemaIsOnTheStartMap() {
        for cinema in wroclawCinemas {
            #expect(isInRegion(cinemaCoordinate(cinema), wroclawMapRegion) == true)
        }
    }

    @Test
    func idsAreUnique() {
        let uniqueIds = Set(wroclawCinemas.map { $0.id })
        #expect(uniqueIds.count == wroclawCinemas.count)
    }

    @Test
    func everyCinemaHasAddressAndWebsite() {
        for cinema in wroclawCinemas {
            #expect(!cinema.address.isEmpty)
            #expect(hasWebsite(cinema) == true)
        }
    }

    @Test
    func pointOutsideRegionIsNotOnTheMap() {
        let warsaw = CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122)
        #expect(isInRegion(warsaw, wroclawMapRegion) == false)
    }
}

@MainActor
struct MapKitConversionTests {
    @Test
    func mapItemForCinemaKeepsNameAndPosition() {
        let item = mapItemForCinema(testCinemaNoweHoryzonty)
        let coordinate = item.location.coordinate

        #expect(item.name == testCinemaNoweHoryzonty.name)
        #expect(abs(coordinate.latitude - testCinemaNoweHoryzonty.latitude) < 0.0001)
        #expect(abs(coordinate.longitude - testCinemaNoweHoryzonty.longitude) < 0.0001)
    }

    @Test
    func travelModeBecomesMapKitTransportType() {
        #expect(transportTypeForMapKit(.walking) == .walking)
        #expect(transportTypeForMapKit(.driving) == .automobile)
    }
}

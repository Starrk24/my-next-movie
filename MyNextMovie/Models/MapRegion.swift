//
//  MapRegion.swift
//  MyNextMovie
//
//  Created by Miłosz Siałkowski on 14/11/2026.
//

import CoreLocation
import MapKit

let wroclawMapRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(
        latitude: 51.0956,
        longitude: 17.0230
    ),
    latitudinalMeters: 15500,
    longitudinalMeters: 14000
)

func regionMoved(
    _ region: MKCoordinateRegion,
    to center: CLLocationCoordinate2D
) -> MKCoordinateRegion {
    return MKCoordinateRegion(center: center, span: region.span)
}

func isInRegion(
    _ coordinate: CLLocationCoordinate2D,
    _ region: MKCoordinateRegion
) -> Bool {
    let halfLat = region.span.latitudeDelta / 2.0
    let halfLon = region.span.longitudeDelta / 2.0
    let latDiff = abs(coordinate.latitude - region.center.latitude)
    let lonDiff = abs(coordinate.longitude - region.center.longitude)
    return latDiff <= halfLat && lonDiff <= halfLon
}

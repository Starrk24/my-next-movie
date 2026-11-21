//
//  Location.swift
//  MyNextMovie
//
//  Created by Miłosz Siałkowski on 14/11/2026.
//

import CoreLocation
import Foundation

nonisolated private let locationTimeout = Duration.seconds(10)

func lastKnownUserLocation() -> UserLocation {
    guard let location = CLLocationManager().location else {
        return fallbackUserLocation
    }
    return UserLocation(
        latitude: location.coordinate.latitude,
        longitude: location.coordinate.longitude,
        isKnown: true
    )
}

func findUserLocation() async -> UserLocation {
    return await withTaskGroup(of: UserLocation.self) { group in
        group.addTask {
            return await waitForLiveLocation()
        }
        group.addTask {
            try? await Task.sleep(for: locationTimeout)
            return fallbackUserLocation
        }
        let firstResult = await group.next() ?? fallbackUserLocation
        group.cancelAll()
        return firstResult
    }
}

nonisolated private func waitForLiveLocation() async -> UserLocation {
    let session = CLServiceSession(authorization: .whenInUse)
    defer { session.invalidate() }
    do {
        for try await update in CLLocationUpdate.liveUpdates() {
            if Task.isCancelled || update.authorizationDenied {
                return fallbackUserLocation
            }
            if let location = update.location {
                return UserLocation(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    isKnown: true
                )
            }
        }
    } catch {
        return fallbackUserLocation
    }
    return fallbackUserLocation
}

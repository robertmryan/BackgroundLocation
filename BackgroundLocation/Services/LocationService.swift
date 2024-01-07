//
//  LocationService.swift
//  BackgroundLocation
//
//  Created by Robert Ryan on 1/7/24.
//

import Foundation
import CoreLocation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "LocationService")

class LocationService: NSObject {
    private let manager = CLLocationManager()

    var didUpdateLocations: (([CLLocation]) -> Void)?

    func start() {
        manager.delegate = self
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        switch manager.authorizationStatus {
        case .notDetermined:       manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse: manager.requestAlwaysAuthorization()
        default:                   break
        }
        manager.startMonitoringSignificantLocationChanges()
    }

    var significantChangeServiceAvailable: Bool { CLLocationManager.significantLocationChangeMonitoringAvailable() }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("\(#function): \(error)")
    }

    func locationManager( _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        logger.debug("\(#function): \(locations)")
        didUpdateLocations?(locations)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        logger.debug("\(#function): \(manager.authorizationStatus)")

        // warning: You really should not ask for “always” immediately after granting “when in use”,
        // but rather defer this to a place in your app where the utility of “always” is really needed.
        // I'm doing it here just to illustrate the “first ask for ‘when in use’, ask for ‘always’ later”.

        if manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        }
    }
}

extension CLAuthorizationStatus: CustomStringConvertible {
    public var description: String {
        return switch self {
        case .notDetermined: "notDetermined"
        case .restricted: "restricted"
        case .denied: "denied"
        case .authorizedAlways: "authorizedAlways"
        case .authorizedWhenInUse: "authorizedWhenInUse"
        @unknown default: "default"
        }
    }
}

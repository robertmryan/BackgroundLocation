//
//  ViewController.swift
//  BackgroundLocation
//
//  Created by Robert Ryan on 1/7/24.
//

import UIKit
import os.log
import MapKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ViewController")

class ViewController: UIViewController {
    let locationService = LocationService()
    var locations: [Location] = []
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        logger.debug(#function)
        super.viewDidLoad()

        configure()
    }

    override func viewDidAppear(_ animated: Bool) {
        logger.debug(#function)
        super.viewDidAppear(animated)

        configureLocationService()
    }
}

// MARK: - Private implementation methods

private extension ViewController {
    func configure() {
        fetchLocations()
        updateMapView()
        mapView.userTrackingMode = .follow
    }

    func configureLocationService() {
        if !locationService.significantChangeServiceAvailable {
            showAlert("Significant change not available")
        }

        locationService.didUpdateLocations = { [weak self] locations in
            guard let self else { return }

            let lastTimestamp = self.locations.first?.locationTimestamp

            for location in locations where location.timestamp != lastTimestamp {
                let newLocation = Location(context: LocationStore.shared.persistentContainer.viewContext)
                newLocation.latitude = location.coordinate.latitude
                newLocation.longitude = location.coordinate.longitude
                newLocation.locationTimestamp = location.timestamp
                newLocation.insertedTimestamp = Date()
                self.locations.append(newLocation)
            }

            LocationStore.shared.saveContext()
            self.tableView.reloadData()
            self.updateMapView()
        }

        locationService.start()
    }

    func fetchLocations() {
        do {
            locations = try LocationStore.shared.locations()
        } catch {
            logger.error("\(#function) \(error)")
        }
    }

    func updateMapView() {
        let annotations = locations.map { location in
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
            return annotation
        }
        mapView.removeAnnotations(mapView.annotations.filter { $0 is MKPointAnnotation })
        mapView.addAnnotations(annotations)

        mapView.removeOverlays(mapView.overlays)
        let path = MKPolyline(coordinates: annotations.map { $0.coordinate }, count: annotations.count)
        mapView.addOverlay(path)
    }

    func showAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        locations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let location = locations[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "LocationCell", for: indexPath) as! LocationCell
        cell.coordinateLabel.text = "\(location.longitude), \(location.latitude)"
        cell.timestampLabel.text = [location.locationTimestamp, location.insertedTimestamp]
            .compactMap { $0 }
            .compactMap { dateFormatter.string(from: $0) }
            .joined(separator: " @ ")
        return cell
    }
}

// MARK: - MKMapViewDelegate

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polyline = overlay as? MKPolyline else {
            return MKOverlayRenderer(overlay: overlay)
        }

        let renderer = MKPolylineRenderer(polyline: polyline)
        renderer.strokeColor = .blue
        renderer.lineWidth = 4
        return renderer
    }
}

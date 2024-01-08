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
    private var dataSource: UITableViewDiffableDataSource<Int, Location>!

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
        configureTableView()
        fetchLocations()
        updateMapView()
        mapView.userTrackingMode = .follow
    }

    func configureTableView() {
        dataSource = .init(tableView: tableView) { [weak self] tableView, indexPath, location in
            guard let self else { return nil }
            let cell = tableView.dequeueReusableCell(withIdentifier: "LocationCell", for: indexPath) as! LocationCell
            cell.coordinateLabel.text = "\(location.longitude), \(location.latitude)"
            cell.timestampLabel.text = [location.locationTimestamp, location.insertedTimestamp]
                .compactMap { $0 }
                .compactMap { self.dateFormatter.string(from: $0) }
                .joined(separator: " @ ")
            return cell
        }
        tableView.dataSource = dataSource
    }

    func configureLocationService() {
        if !locationService.significantChangeServiceAvailable {
            showAlert("Significant change not available")
        }

        locationService.didUpdateLocations = { [weak self] locations in
            guard let self else { return }

            let lastTimestamp = self.locations.first?.locationTimestamp

            for location in locations where location.timestamp != lastTimestamp {
                let newLocation = LocationStore.shared.addLocation(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    timestamp: location.timestamp
                )
                self.locations.append(newLocation)
            }

            LocationStore.shared.saveContext()
            self.applySnapshot()
            self.updateMapView()
        }

        locationService.start()
    }

    func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Int, Location>()
        snapshot.appendSections([0])
        snapshot.appendItems(locations)
        dataSource.apply(snapshot)
    }

    func fetchLocations() {
        do {
            locations = try LocationStore.shared.locations()
            applySnapshot()
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

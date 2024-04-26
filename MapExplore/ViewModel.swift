//
//  ViewModel.swift
//  MapExplore
//
//  Created by Huy Ong on 4/22/24.
//

import Foundation
import GoogleMaps
import CoreLocation
import WeatherKit
import MapKit
import Combine

struct LocationMarker: Identifiable {
    let id = UUID()
    var marker: GMSMarker
    var weather: Weather
    var address: String?
}

class ViewModel: ObservableObject {
    @Published var locations: [LocationMarker] = []
    @Published var currentMarker: LocationMarker?
    @Published var searchText: String = ""
    @Published var places: [MKMapItem] = []
    @Published var selectedPlace: CLLocationCoordinate2D?
    
    private var lastReload: Date = .init()
    private var service = WeatherService.shared
    private var cancellables: Set<AnyCancellable> = .init()
    
    init() {
        $searchText
            .removeDuplicates()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] text in
                self?.searchForPlaces()
            }
            .store(in: &cancellables)
    }
    
    func reloadMarkers() {
        let now = Date()
        if now.timeIntervalSince(lastReload) > 3600 {
            Task {
                for i in 0..<locations.count {
                    let marker = locations[i].marker.position
                    let location = CLLocation(latitude: marker.latitude, longitude: marker.longitude)
                    let weather = try await service.weather(for: location)
                    locations[i].weather = weather
                }
                self.lastReload = Date()
            }
            self.lastReload = now
        } else {
            print("Already reload within an hour, no need to do extra")
        }
    }
    
    private func searchForPlaces() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.resultTypes = .address
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response else {
                print("Search error: \(String(describing: error?.localizedDescription))")
                return
            }
            
            self.places = response.mapItems
            
            print(self.places)
        }
    }
}

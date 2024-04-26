//
//  GoogleMapView.swift
//  MapExplore
//
//  Created by Huy Ong on 4/22/24.
//

import SwiftUI
import GoogleMaps
import WeatherKit
import CoreLocation
import Combine

struct GoogleMapView: View {
    @EnvironmentObject var viewModel: ViewModel
    
    var body: some View {
        GoogleMapViewRepresentable(styleJSON: Self.jsonString, viewModel: viewModel)
    }
}

struct GoogleMapViewRepresentable: UIViewRepresentable {
    let styleJSON: String
    var viewModel: ViewModel

    func makeUIView(context: Self.Context) -> GMSMapView {
        
        
        let options = GMSMapViewOptions()
        options.camera = GMSCameraPosition.camera(withLatitude: 37.33, longitude: -121.88, zoom: 9.0)
        
        let mapView = GMSMapView(options: options)
        

        // Applying the custom style
        do {
            mapView.mapStyle = try GMSMapStyle(jsonString: styleJSON)
        } catch {
            print("One or more of the map styles failed to load. \(error)")
        }
        
        mapView.delegate = context.coordinator
        context.coordinator.mapView = mapView
        
        return mapView
    }

    func updateUIView(_ uiView: GMSMapView, context: Context) {
        // Update the map view during SwiftUI updates
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, viewModel: viewModel)
    }
    
    class Coordinator: NSObject, GMSMapViewDelegate, UITextFieldDelegate {
        var parent: GoogleMapViewRepresentable
        var mapView: GMSMapView?
        var markers: [GMSMarker] = []
        var viewModel: ViewModel
        private let radiusInMiles = 10.0
        private var cancellables: Set<AnyCancellable> = .init()
        
        init(parent: GoogleMapViewRepresentable, viewModel: ViewModel) {
            self.parent = parent
            self.viewModel = viewModel
            
            super.init()
            
            viewModel.$currentMarker.sink { [weak self] marker in
                guard let self else { return }
                guard let marker else { return }
                self.zoomToMarker(at: marker.marker)
            }
            .store(in: &cancellables)
            
            viewModel.$selectedPlace.sink { [weak self] coordinate in
                if let coordinate {
                    self?.addNewMarker(at: coordinate)
                }
            }
            .store(in: &cancellables)
        }
        
        private func addNewMarker(at coordinate: CLLocationCoordinate2D) {
            if shouldPlaceMarker(at: coordinate), let mapView {
                let marker = GMSMarker(position: coordinate)
                markers.append(marker)
                
                Task {
                    
                    if let weather = try? await fetchCurrentWeather(at: coordinate) {
                        DispatchQueue.main.async {
                            let f = Int((weather.currentWeather.temperature.value * 9/5) + 32)
                            marker.iconView = MarkerView(frame: .init(x: 0, y: 0, width: 30, height: 30), text: "\(f)")
                            marker.map = mapView
                            
                            
                        }
                        
                        var locationMarker = LocationMarker(marker: marker, weather: weather)
                        
                        if let address = try? await getCurrentAddress(at: coordinate) {
                            locationMarker.address = address
                        }
                        
                        viewModel.locations.append(locationMarker)
                        viewModel.currentMarker = locationMarker
                    }
                }
                
                let camera = GMSCameraPosition.camera(withTarget: coordinate, zoom: 9.0)
                mapView.animate(to: camera)
                
            } else {
                print("Marker not added due to promixity to another marker.")
            }
        }
        
        private func zoomToMarker(at marker: GMSMarker) {
            
        }

        
        func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
            
        }
        
        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            viewModel.currentMarker = viewModel.locations.first(where: { $0.marker == marker })
            let position = GMSCameraPosition(target: marker.position, zoom: 9.0)
            mapView.animate(to: position)
            return true
        }
        
        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            print(coordinate)
            
            if shouldPlaceMarker(at: coordinate) {
                let marker = GMSMarker(position: coordinate)
                markers.append(marker)
                
                Task {
                    
                    if let weather = try? await fetchCurrentWeather(at: coordinate) {
                        DispatchQueue.main.async {
                            let f = Int((weather.currentWeather.temperature.value * 9/5) + 32)
                            marker.iconView = MarkerView(frame: .init(x: 0, y: 0, width: 30, height: 30), text: "\(f)")
                            marker.map = mapView
                            
                            
                        }
                        
                        var locationMarker = LocationMarker(marker: marker, weather: weather)
                        
                        if let address = try? await getCurrentAddress(at: coordinate) {
                            locationMarker.address = address
                        }
                        
                        viewModel.locations.append(locationMarker)
                        viewModel.currentMarker = locationMarker
                    }
                }
                
                let camera = GMSCameraPosition.camera(withTarget: coordinate, zoom: 9.0)
                mapView.animate(to: camera)
                
            } else {
                print("Marker not added due to promixity to another marker.")
            }
        }
        
        private func shouldPlaceMarker(at newCoordinate: CLLocationCoordinate2D) -> Bool {
            for marker in markers {
                let distance = GMSGeometryDistance(marker.position, newCoordinate)
                if distance / 1609.34 <= radiusInMiles {
                    return false
                }
            }
            return true
        }
        
        private func fetchCurrentWeather(at location: CLLocationCoordinate2D) async throws -> Weather {
            let service = WeatherService.shared
            let weather = try await service.weather(for: .init(latitude: location.latitude, longitude: location.longitude))
            return weather
        }
        
        private func getCurrentAddress(at coordinate: CLLocationCoordinate2D) async throws -> String? {
            let geocoder = GMSGeocoder()
            let response = try? await geocoder.reverseGeocodeCoordinate(coordinate)
            guard let response, let result = response.firstResult() else { return nil }
            var address = ""
            if let city = result.locality {
                address += city
            }
            if let prefixState = result.administrativeArea?.prefix(2) {
                let state = prefixState.uppercased()
                address = address == "" ? state : address + ", " + state
            }
            print("Address: \(address)")
            return address == "" ? nil : address
        }
    }
}

class MarkerView: UIView {
    private var label: UILabel!
    
    init(frame: CGRect, text: String) {
        super.init(frame: frame)
        setupView(text: text)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView(text: String) {
        
        self.backgroundColor = UIColor.white
        self.layer.cornerRadius = self.frame.width / 2
        self.clipsToBounds = true
        
        // Label setup
        label = UILabel(frame: self.bounds)
        label.text = text
        label.textColor = .black
        label.textAlignment = .center
        label.font = .boldSystemFont(ofSize: 12)
        
        self.addSubview(label)
    }
}


extension GoogleMapView {
    static let jsonString = """
    [
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#242f3e"
          }
        ]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#746855"
          }
        ]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [
          {
            "color": "#242f3e"
          }
        ]
      },
      {
        "featureType": "administrative.land_parcel",
        "elementType": "labels",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "administrative.locality",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#d59563"
          }
        ]
      },
      {
        "featureType": "poi",
        "elementType": "labels.text",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#d59563"
          }
        ]
      },
      {
        "featureType": "poi.business",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#263c3f"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#6b9a76"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#38414e"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry.stroke",
        "stylers": [
          {
            "color": "#212a37"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "labels.icon",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#9ca5b3"
          }
        ]
      },
      {
        "featureType": "road.arterial",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#746855"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry.stroke",
        "stylers": [
          {
            "color": "#1f2835"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "labels",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#f3d19c"
          }
        ]
      },
      {
        "featureType": "road.local",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "road.local",
        "elementType": "labels",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "transit",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "featureType": "transit",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#2f3948"
          }
        ]
      },
      {
        "featureType": "transit.station",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#d59563"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#17263c"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#515c6d"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "labels.text.stroke",
        "stylers": [
          {
            "color": "#17263c"
          }
        ]
      }
    ]
    """
}


#Preview {
    GoogleMapView()
}



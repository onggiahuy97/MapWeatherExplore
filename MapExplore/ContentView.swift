//
//  ContentView.swift
//  MapExplore
//
//  Created by Huy Ong on 4/22/24.
//

import SwiftUI
import CoreLocation
import MapKit
import SwiftUIIntrospect

struct ContentView: View {
    @EnvironmentObject var viewModel: ViewModel
    
    @State private var showSearch = false
    
    var body: some View {
        ZStack {
            GoogleMapView()
            QuickCardView()
        }
        .ignoresSafeArea(edges: .all)
        .overlay(alignment: .bottomTrailing) {
            Button {
                showSearch.toggle()
            } label: {
                Image(systemName: "magnifyingglass")
                    .tint(.white)
                    .imageScale(.large)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(.circle)
            }
            .padding()
        }
        .overlay(alignment: .topTrailing) {
            Button {
                viewModel.reloadMarkers()
            } label: {
                Image(systemName: "arrow.circlepath")
                    .tint(.white)
                    .imageScale(.large)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(.circle)
            }
            .padding()
            .opacity(viewModel.locations.isEmpty ? 0 : 1.0)
        }
        .sheet(isPresented: $showSearch) {
            SearchPlaceView()
                .presentationDetents([.medium])
        }
    }
}

struct SearchPlaceView: View {
    @EnvironmentObject var viewModel: ViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                HStack {
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                }
                
                TextField("Search", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .introspect(.textField, on: .iOS(.v15, .v16, .v17)) { textField in
                        DispatchQueue.main.async {
                            textField.becomeFirstResponder()
                        }
                    }
                
                ForEach(viewModel.places, id: \.self) { place in
                    Button(place.toName) {
                        let coordinate = place.placemark.coordinate
                        viewModel.selectedPlace = coordinate
                        viewModel.searchText = ""
                        viewModel.places = []
                        dismiss()
                    }
                    Divider()
                }
            }
            
        }
        .padding()
    }
}

extension MKMapItem {
    var toName: String {
        var address = ""
        
        if let city = self.placemark.locality {
            address += city
        }
        
        if let state = self.placemark.administrativeArea {
            address += address.isEmpty ? state : ", \(state)"
        }
        
        return address
    }
}

struct QuickCardView: View {
    @EnvironmentObject var viewModel: ViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            GeometryReader { proxy in
                let width = proxy.size.width
                
                if let currentWeather = viewModel.currentMarker?.weather.currentWeather {
                    HStack {
                        VStack(alignment: .leading) {
                            if let address = viewModel.currentMarker?.address {
                                Label(address, systemImage: "location")
                                Divider()
                            }
                            let f = Int(currentWeather.temperature.converted(to: .fahrenheit).value)
                            Label("\(f)", systemImage: "thermometer.medium")
                            Divider()
                            Label("\(currentWeather.condition.description)", systemImage: "\(currentWeather.symbolName)")
                            Divider()
                            Label("\(currentWeather.uvIndex.value)", systemImage: "sun.max.trianglebadge.exclamationmark")
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding()
                        .frame(width: width * 2/3)
                        
                        Spacer()
                    }
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 30)
        .padding(5)
    }
}

#Preview {
    ContentView()
}

//
//  MapExploreApp.swift
//  MapExplore
//
//  Created by Huy Ong on 4/22/24.
//

import SwiftUI
import GoogleMaps

@main
struct MapExploreApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject var viewModel = ViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        let googleApi = "Your_Google_Map_API_Key"
        GMSServices.provideAPIKey(googleApi)
        return true
    }
}



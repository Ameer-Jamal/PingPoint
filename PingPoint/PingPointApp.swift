//
//  PingPointApp.swift
//  PingPoint
//
//  Created by Ameer Jamal on 11/2/23.
//

import Cocoa
import SwiftUI

@main
struct PingPointApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            // Your settings view if needed.
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var locationManager: LocationManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        locationManager = LocationManager()
        locationManager?.checkLocationAuthorization { [weak self] authorized in
            guard let strongSelf = self else { return }
            if authorized {
                DispatchQueue.main.async {
                    // Proceed with creating the StatusBarController now that we have location authorization
                    strongSelf.statusBarController = StatusBarController(locationManager: strongSelf.locationManager)
                }
            } else {
                // Handle the case where location authorization was not granted
                DispatchQueue.main.async {
                    strongSelf.locationManager?.showLocationServicesDeniedAlert()
                    strongSelf.statusBarController = StatusBarController(locationManager: strongSelf.locationManager)
                }
            }
        }
    }
}

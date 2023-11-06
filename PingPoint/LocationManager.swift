//
//  LocationManager.swift
//  PingPoint
//
//  Created by Ameer Jamal on 11/3/23.
//

import Foundation
import CoreLocation
import AppKit
class LocationManager: NSObject, CLLocationManagerDelegate {
    var locationManager: CLLocationManager
    private var authorizationCompletion: ((Bool) -> Void)?

    override init() {
        
        self.locationManager = CLLocationManager()
        super.init()
        self.locationManager.delegate = self
    }
    
    func checkLocationAuthorization(completion: @escaping (Bool) -> Void) {
        self.authorizationCompletion = completion
        
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
            
        case .restricted, .denied:
            DispatchQueue.main.async {
                self.showLocationServicesDeniedAlert()
            }
            completion(false)
            
        case .authorizedAlways, .authorizedWhenInUse:
            completion(true)
            
        @unknown default:
            print("Received unknown CLAuthorizationStatus: \(locationManager.authorizationStatus)")
            completion(false)
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            authorizationCompletion?(true)
            
        case .restricted, .denied, .notDetermined:
            authorizationCompletion?(false)
            
        @unknown default:
            print("Received unknown CLAuthorizationStatus: \(status)")
            authorizationCompletion?(false)
        }
        
        // After handling, clear the completion to avoid retain cycles or unintended repeated calls
        self.authorizationCompletion = nil
    }
    
    func showLocationServicesDeniedAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Location Services Not Authorized"
            alert.informativeText = "This app requires detection of your current Wi-Fi network which now requires Location services \n (thanks apple). Please open System Preferences > Security & Privacy > Privacy > Location Services and grant location access for this app and then restart the app."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

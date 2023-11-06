//
//  NetworkMonitor.swift
//  PingPoint
//
//  Created by Ameer Jamal on 11/2/23.
//

import Foundation
import Network
import CoreWLAN
import SystemConfiguration
import CoreLocation
import AppKit

class NetworkMonitor {
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var statusChangeHandler: ((Bool) -> Void)?
    
    private let userDefaults = UserDefaults.standard
    
    // Keys to store SSIDs in UserDefaults
    private let primarySSIDKey = "PrimarySSID"
    private let alternateSSIDKey = "AlternateSSID"
    
    // This flag will help in preventing the alert from appearing when already switching networks.
    private var isSwitchingNetwork = false
    private var lastSwitchAttemptDate: Date?
    private var switchThrottleInSeconds: Int = 20
    private var pollingTimer: Timer?

    init(statusChangeHandler: @escaping (Bool) -> Void) {
           self.monitor = NWPathMonitor()
           self.statusChangeHandler = statusChangeHandler
           monitor.pathUpdateHandler = { [weak self] path in
               DispatchQueue.main.async {
                   if path.status == .satisfied {
                       // Network is connected, so we'll start polling
                       self?.startPollingInternetRequests()
                   } else {
                       // Not connected to a network
                       self?.stopPollingInternetRequests()
                       self?.statusChangeHandler?(false)
                   }
               }
           }
           monitor.start(queue: queue)
       }

       deinit {
           monitor.cancel()
           stopPollingInternetRequests()
       }

       func checkInternetConnectivityViaPing() {
           let url = URL(string: "https://www.apple.com/library/test/success.html")!
           var request = URLRequest(url: url)
           request.httpMethod = "HEAD"
           request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
           let config = URLSessionConfiguration.ephemeral
           let session = URLSession(configuration: config)

           session.dataTask(with: request) { _, response, error in
               let isConnected = (response as? HTTPURLResponse)?.statusCode == 200
               DispatchQueue.main.async {
                   if isConnected {
                       print("HTTP responded with 200")
                   } else { // TODO: FIND best place to put this and when to switch note that currentWiFiSSID seems fast
                       print("Failed to connect. Error: \(String(describing: error))")
                       // Check if enough time has elapsed since the last switch attempt
                       if let lastAttempt = self.lastSwitchAttemptDate, Date().timeIntervalSince(lastAttempt) < 60 {
                           // If it's been less than 60 seconds since the last attempt, do nothing
                           print("Switch attempt recently made. Waiting before trying again.")
                       } else {
                           // If it's been more than 20 seconds, attempt to switch networks
                           self.switchToAlternateNetwork()
                           self.lastSwitchAttemptDate = Date() // Update the last attempt date
                       }
                   }
                   self.statusChangeHandler?(isConnected)
               }
           }.resume()
       }

       private func startPollingInternetRequests() {
           stopPollingInternetRequests() // Stop any existing timer to avoid multiple timers running
           pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
               self?.checkInternetConnectivityViaPing()
           }
           RunLoop.current.add(pollingTimer!, forMode: .common)
       }

       private func stopPollingInternetRequests() {
           pollingTimer?.invalidate()
           pollingTimer = nil
       }
}

extension NetworkMonitor {
    
    // MARK: - Wi-Fi SSID Retrieval
    func currentWiFiSSID(locationManager: CLLocationManager) -> String? {
        _ = locationManager.authorizationStatus
        
        // Check for Wi-Fi interfaces
        guard let interfaces = CWWiFiClient.shared().interfaces(), !interfaces.isEmpty else {
            print("No Wi-Fi interfaces found.")
            return nil
        }
        
        // Iterate through Wi-Fi interfaces looking for an SSID
        for interface in interfaces {
            if let ssid = interface.ssid() {
                // Reset the switch attempt flag if connected to a valid SSID
                isSwitchingNetwork = false
                return ssid
            } else {
                
                print("SSID is nil for interface: \(interface.interfaceName ?? "Unknown")")
            }
        }

        
        return nil
    }
    

    func getAlternateNetworkName() -> String? {
        return UserDefaults.standard.string(forKey: alternateSSIDKey)
    }

    func getPrimaryNetworkName() -> String? {
        return UserDefaults.standard.string(forKey: primarySSIDKey)
    }

    func switchToAlternateNetwork() {
        // Prevent showing alert if already trying to switch networks.
        guard !isSwitchingNetwork else { return }
        
        isSwitchingNetwork = true
        
        guard let alternateSSID = getAlternateNetworkName(), !alternateSSID.isEmpty else {
            DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Oh no! Internet is down."
            alert.informativeText = "Do you want to select another network in your Wi-Fi settings?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Network Preferences")
            alert.addButton(withTitle: "Cancel")
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.network?Wi-Fi") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            print("No alternate SSID found in preferences.")
            return
        }
        
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Oh no! Internet is down."
            alert.informativeText = "Please select the following network in your Wi-Fi settings: \(alternateSSID)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Network Preferences")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.network?Wi-Fi") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    func updateNetworkPreferences(primarySSID: String, alternateSSID: String, completion: @escaping (Bool) -> Void) {
         UserDefaults.standard.set(primarySSID, forKey: primarySSIDKey)
         UserDefaults.standard.set(alternateSSID, forKey: alternateSSIDKey)

         // After saving, verify if the SSIDs were saved correctly
         let savedPrimarySSID = UserDefaults.standard.string(forKey: primarySSIDKey)
         let savedAlternateSSID = UserDefaults.standard.string(forKey: alternateSSIDKey)

         let success = (savedPrimarySSID == primarySSID) && (savedAlternateSSID == alternateSSID)
         completion(success)
     }
    
    
    func clearNetworkPreferences(completion: @escaping (Bool) -> Void) {
        // Clear the values for both keys
        UserDefaults.standard.removeObject(forKey: primarySSIDKey)
        UserDefaults.standard.removeObject(forKey: alternateSSIDKey)

        // Verify if the SSIDs were cleared correctly
        let clearedPrimarySSID = UserDefaults.standard.string(forKey: primarySSIDKey)
        let clearedAlternateSSID = UserDefaults.standard.string(forKey: alternateSSIDKey)

        let success = (clearedPrimarySSID == nil) && (clearedAlternateSSID == nil)
        completion(success)
    }
    

    // TODO: - future auto switching
    func goBackToMainNetwork() -> String {
        // TODO: Implement logic to basically listen to the primary network name or ssid and see
        // if it is no longer offline it stopped being offline then just switch back to it
        return "AlternateNetworkSSID"
    }
    
}

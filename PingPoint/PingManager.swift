//
//  PingManager.swift
//  PingPoint
//
//  Created by Ameer Jamal on 11/2/23.
//

import Foundation

class PingManager {
    var successCallback: (() -> Void)?
    var failureCallback: (() -> Void)?
    
    func startPinging() {
        // Here you could use URLSession to ping a server, but for simplicity, we'll just use a timer.
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            self.pingServer()
        }
    }
    
    private func pingServer() {
        // Replace this with actual network ping logic
        URLSession.shared.dataTask(with: URL(string: "http://www.google.com")!) { data, response, error in
            if let error = error {
                print("Ping failed: \(error)")
                DispatchQueue.main.async {
                    self.failureCallback?()
                }
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("Ping successful")
                DispatchQueue.main.async {
                    self.successCallback?()
                }
            } else {
                print("Ping failed with response: \(String(describing: response))")
                DispatchQueue.main.async {
                    self.failureCallback?()
                }
            }
        }.resume()
    }
}

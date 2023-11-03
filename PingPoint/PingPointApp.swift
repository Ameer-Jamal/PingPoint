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

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            self.statusBarController = StatusBarController()
        }
    }
}

//
//  StatusBarController.swift
//  PingPoint
//
//  Created by Ameer Jamal on 11/2/23.
//
import AppKit
import CoreLocation
import Cocoa

// MARK: - NSImage Extension for Tinting

extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        guard isTemplate, let tinted = self.copy() as? NSImage else { return self }
        
        tinted.lockFocus()
        color.set()
        
        let imageRect = NSRect(origin: .zero, size: self.size)
        imageRect.fill(using: .sourceAtop)
        
        tinted.unlockFocus()
        tinted.isTemplate = false
        
        return tinted
    }
}

// MARK: - Status Menu Item Configuration

struct StatusMenuItemConfigurator {
    static func createStatusMenuItem(title: String, isEnabled: Bool = false) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        menuItem.isEnabled = isEnabled
        return menuItem
    }
    
    static func updateStatusMenuItem(_ menuItem: NSMenuItem?, with title: String, color: NSColor) {
        DispatchQueue.main.async {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.menuFont(ofSize: 12), // Set your desired font size
                .foregroundColor: color
            ]
            menuItem?.attributedTitle = NSAttributedString(string: title, attributes: attributes)
        }
    }
}

// MARK: - Status Bar Icon Updater

class StatusBarIconUpdater {
    private var statusBarItem: NSStatusItem
    
    init(statusBarItem: NSStatusItem) {
        self.statusBarItem = statusBarItem
    }
    
    func updateStatusBarIcon(with image: NSImage) {
        DispatchQueue.main.async {
            self.statusBarItem.button?.image = image
        }
    }
}

// MARK: - StatusBarController

class StatusBarController: ObservableObject {
    // VARS:
    private var statusBarItem: NSStatusItem
    private var statusMenuItem: NSMenuItem
    private var locationManager: LocationManager?
    private var primaryNetworkTextField: NSTextField?
    private var alternateNetworkTextField: NSTextField?
    
    var preferencesWindowController: NSWindowController?
    
    private lazy var networkMonitor: NetworkMonitor = {
        return NetworkMonitor(statusChangeHandler: self.updateStatusIcon)
    }()
    
    private let iconUpdater: StatusBarIconUpdater
    private var wifiNetworkMenuItem: NSMenuItem?

    /// ---------------------------------------------------

    // MARK: - Init

    init(locationManager: LocationManager?) {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusMenuItem = StatusMenuItemConfigurator.createStatusMenuItem(title: "Status: Checking...")
        iconUpdater = StatusBarIconUpdater(statusBarItem: statusBarItem)
        
        // Attempt to get the CLLocationManager from the optional LocationManager
        self.locationManager = locationManager
        
        networkMonitor = NetworkMonitor(statusChangeHandler: { [weak self] isConnected in
            self?.updateStatusIcon(isConnected: isConnected)
            self?.updateWiFiNetworkMenuItem() // This call will refresh the network SSID name
        })
        
        if let actualLocationManager = locationManager?.locationManager {
            let ssid = networkMonitor.currentWiFiSSID(locationManager: actualLocationManager) ?? "Unknown"
            wifiNetworkMenuItem = NSMenuItem(title: " Network : \(ssid)", action: nil, keyEquivalent: "")
        } else {
            wifiNetworkMenuItem = NSMenuItem(title: " Network : Unknown", action: nil, keyEquivalent: "")
        }
        
        setupMenu()
    }
    
    private func setupMenu() {
        
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "dot.radiowaves.left.and.right", accessibilityDescription: "Network Status")
        }
        
        let menu = NSMenu()
        
        // Online/Offline
        menu.addItem(statusMenuItem)
        if let wifiNetworkMenuItem = self.wifiNetworkMenuItem {
            let copyableMenuItem = makeCopyableMenuItem(with: wifiNetworkMenuItem.title)
            menu.insertItem(copyableMenuItem, at: 1)
        }
        
        let preferencesItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(AppInfoMenuItems.createQuitItem())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(AppInfoMenuItems.createAppNameItem())
        menu.addItem(AppInfoMenuItems.createDeveloperNameItem())
        statusBarItem.menu = menu
    }
    
    private func updateStatusIcon(isConnected: Bool) {
        let color: NSColor = isConnected ? .green : .red
        if let image = NSImage(systemSymbolName: "dot.radiowaves.left.and.right", accessibilityDescription: "Network Status") {
            let tintedImage = image.tinted(with: color)
            iconUpdater.updateStatusBarIcon(with: tintedImage)
        }
        
        let statusTitle = isConnected ? "Status: ONLINE" : "Status: OFFLINE"
        StatusMenuItemConfigurator.updateStatusMenuItem(statusMenuItem, with: statusTitle, color: color)
    }
    
    private func refreshNetworkInfo(isConnected: Bool) {
        updateStatusIcon(isConnected: isConnected)
        updateWiFiNetworkMenuItem()
    }
    
    private func updateWiFiNetworkMenuItem() {
        // Ensure we have the actual CLLocationManager instance
        if let actualLocationManager = self.locationManager?.locationManager { // assuming 'locationManager' is a property on your LocationManager class
            let wifiName = networkMonitor.currentWiFiSSID(locationManager: actualLocationManager) ?? "Unknown"
            DispatchQueue.main.async {
                self.wifiNetworkMenuItem?.title = "\(wifiName)"
            }
        } else {
            DispatchQueue.main.async {
                self.wifiNetworkMenuItem?.title = "Unknown"
            }
        }
    }
    
    // MARK: - Prefrence window
    
    @objc func openPreferences() {
        // Close the existing preferences window if it's open.
        preferencesWindowController?.close()
        preferencesWindowController = nil // Dereference the existing window controller
        
            let preferencesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 250),
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false)
            preferencesWindow.center()
            preferencesWindow.title = "Preferences"
            preferencesWindow.isReleasedWhenClosed = false
            preferencesWindowController = NSWindowController(window: preferencesWindow)
            
            let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 250))
            
            let primaryNetworkLabel = NSTextField(labelWithString: "Primary Network:")
            primaryNetworkLabel.frame = NSRect(x: 20, y: 170, width: 440, height: 20)
            contentView.addSubview(primaryNetworkLabel)
            
            primaryNetworkTextField = NSTextField(frame: NSRect(x: 20, y: 140, width: 440, height: 24))
            // Retrieve and set the primary SSID if it exists
            let primarySSID = UserDefaults.standard.string(forKey: "PrimarySSID")
            primaryNetworkTextField?.stringValue = primarySSID ?? ""
            primaryNetworkTextField?.placeholderString = "Enter Primary Network Name"
            contentView.addSubview(primaryNetworkTextField!)
            
            let alternateNetworkLabel = NSTextField(labelWithString: "Alternate Network:")
            alternateNetworkLabel.frame = NSRect(x: 20, y: 100, width: 440, height: 20)
            contentView.addSubview(alternateNetworkLabel)
            
            alternateNetworkTextField = NSTextField(frame: NSRect(x: 20, y: 70, width: 440, height: 24))
            // Retrieve and set the alternate SSID if it exists
            let alternateSSID = UserDefaults.standard.string(forKey: "AlternateSSID")
            alternateNetworkTextField?.stringValue = alternateSSID ?? ""
            alternateNetworkTextField?.placeholderString = "Enter Alternate Network Name"
            contentView.addSubview(alternateNetworkTextField!)
            

            let gap: CGFloat = 10 // Gap between elements

            // Ensure that alternateNetworkTextField is unwrapped properly
            if let alternateNetworkTextField = alternateNetworkTextField {
                // Calculate the y-position for the applyButton to be below the alternateNetworkTextField
                let applyButtonYPosition = alternateNetworkTextField.frame.origin.y - alternateNetworkTextField.frame.size.height - gap

                let applyButton = NSButton(frame: NSRect(x: 20, y: applyButtonYPosition, width: 440, height: 30))
                applyButton.title = "Apply"
                applyButton.bezelStyle = NSButton.BezelStyle.rounded // Corrected
                applyButton.target = self
                applyButton.action = #selector(applyPreferences)
                contentView.addSubview(applyButton)

                // Calculate the y-position for the clearButton to be below the applyButton
                let clearButtonYPosition = applyButton.frame.origin.y - applyButton.frame.size.height - gap

                let clearButton = NSButton(frame: NSRect(x: 20, y: clearButtonYPosition, width: 440, height: 30))
                clearButton.title = "Clear"
                clearButton.bezelStyle = NSButton.BezelStyle.rounded // Corrected
                clearButton.target = self
                clearButton.action = #selector(clearPreferences)
                contentView.addSubview(clearButton)
            } else {
                // Handle the case where alternateNetworkTextField is nil if needed
            }

            
            preferencesWindow.contentView = contentView
        
        
          NSApp.activate(ignoringOtherApps: true) // Activate the app
          preferencesWindowController?.window?.orderFrontRegardless() // Bring the window to the front
    }
    
    @objc func applyPreferences() {
        let primarySSID = primaryNetworkTextField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let alternateSSID = alternateNetworkTextField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if let primary = primarySSID, !primary.isEmpty,
           let alternate = alternateSSID, !alternate.isEmpty {

            networkMonitor.updateNetworkPreferences(primarySSID: primary, alternateSSID: alternate) { success in
                DispatchQueue.main.async {
                    if success {
                        self.showAlert(withTitle: "Success", message: "Networks Applied")
                    } else {
                        self.showAlert(withTitle: "Error", message: "Failed to apply network preferences.")
                    }
                }
            }

        } else {
            showAlert(withTitle: "Error", message: "Please enter both the primary and alternate SSID names.")
        }
    }
    
    @objc func clearPreferences() {
        networkMonitor.clearNetworkPreferences { success in
            DispatchQueue.main.async {
                if success {
                    // Clear the primary network text field
                    self.primaryNetworkTextField?.stringValue = ""
                    
                    // Clear the alternate network text field
                    self.alternateNetworkTextField?.stringValue = ""
                    
                    self.showAlert(withTitle: "Success", message: "Network preferences cleared.")
                } else {
                    // Handle the error case
                    self.showAlert(withTitle: "Error", message: "Failed to clear network preferences.")
                }
            }
        }
    }
    

    private func showAlert(withTitle title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
}


// MARK: - App Info Menu Items Factory
    
    struct AppInfoMenuItems {
        static func createAppNameItem() -> NSMenuItem {
            let appName = NSMenuItem(title: "PingPoint", action: nil, keyEquivalent: "")
            appName.attributedTitle = NSAttributedString(string: appName.title, attributes: [.font: NSFont.menuBarFont(ofSize: 14), .foregroundColor: NSColor.controlTextColor])
            appName.isEnabled = false
            return appName
        }

        static func createDeveloperNameItem() -> NSMenuItem {
            let developerName = NSMenuItem(title: "By: Ameer Jamal", action: nil, keyEquivalent: "")
            developerName.attributedTitle = NSAttributedString(string: developerName.title, attributes: [.font: NSFont.menuFont(ofSize: 12), .foregroundColor: NSColor.secondaryLabelColor])
            developerName.isEnabled = false
            return developerName
        }
        
        static func createQuitItem() -> NSMenuItem {
            return NSMenuItem(title: "Quit PingPoint", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        }
    }
    
extension StatusBarController {
    func makeCopyableMenuItem(with title: String) -> NSMenuItem {
        // Create a text field with the menu item's title
        let textField = NSTextField(labelWithString: title)
        textField.isSelectable = true
        textField.isBordered = false
        textField.drawsBackground = false
        textField.sizeToFit() // Size to fit the text

        // Add 5px padding to the width on each side (total 10px)
        textField.frame.size.width += 30

        // Ensure the text field isn't too narrow or too wide
        let minWidth: CGFloat = 10 // Minimum width including padding
        let maxWidth: CGFloat = 500 // Maximum width including padding
        textField.frame.size.width = max(minWidth, min(textField.frame.size.width, maxWidth))

        // Create a custom view with a size that can contain the text field with padding
        let view = NSView(frame: NSRect(x: 0, y: 0, width: textField.frame.size.width, height: textField.frame.size.height))

        // Calculate the correct x origin for the text field
        let standardMenuItemPadding: CGFloat = 18 // This is a standard padding for menu items
        textField.frame.origin.x = standardMenuItemPadding / 2 // Set the origin x to half the padding for left alignment

        view.addSubview(textField)

        // Create the menu item with the custom view
        let menuItem = NSMenuItem()
        menuItem.view = view

        return menuItem
    }
}

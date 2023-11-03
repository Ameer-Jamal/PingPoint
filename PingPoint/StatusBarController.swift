//
//  StatusBarController.swift
//  PingPoint
//
//  Created by Ameer Jamal on 11/2/23.
//
import AppKit

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
    private var statusBarItem: NSStatusItem
    private var statusMenuItem: NSMenuItem
    private lazy var networkMonitor: NetworkMonitor = {
        return NetworkMonitor(statusChangeHandler: self.updateStatusIcon)
    }()   
    private let iconUpdater: StatusBarIconUpdater
    
    init() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusMenuItem = StatusMenuItemConfigurator.createStatusMenuItem(title: "Status: Checking...")
        iconUpdater = StatusBarIconUpdater(statusBarItem: statusBarItem)
        
        networkMonitor = NetworkMonitor(statusChangeHandler: { [weak self] isConnected in
            self?.updateStatusIcon(isConnected: isConnected)
        })
        
        setupMenu()
    }
    
    private func setupMenu() {
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "dot.radiowaves.left.and.right", accessibilityDescription: "Network Status")
        }
        
        let menu = NSMenu()
        menu.addItem(statusMenuItem)
        menu.addItem(AppInfoMenuItems.createAppNameItem())
        menu.addItem(AppInfoMenuItems.createDeveloperNameItem())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(AppInfoMenuItems.createQuitItem())
        
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

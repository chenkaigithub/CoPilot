//
//  CoPilotPlugin.swift
//
//  Created by Sven Schmidt on 11/04/2015.
//  Copyright (c) 2015 feinstruktur. All rights reserved.
//

import AppKit
import Cocoa


func publishMenuTitle(editor: Editor? = nil) -> String {
    if let editor = editor {
        let title = editor.document.displayName
        if ConnectionManager.isPublished(editor) {
            return "CoPilot Unpublish “\(title)”"
        } else {
            return "CoPilot Publish “\(title)”"
        }
    } else {
        return "CoPilot Publish"
    }
}


var sharedPlugin: CoPilotPlugin?

class CoPilotPlugin: NSObject {
    var bundle: NSBundle! = nil
    lazy var mainController: MainController = MainController(windowNibName: "MainController")
    lazy var connectedController: ConnectedController = ConnectedController(windowNibName: "ConnectedController")
    lazy var urlController: UrlController = UrlController(windowNibName: "UrlController")
    var observers = [NSObjectProtocol]()
    var publishMenuItem: NSMenuItem! = nil
    var subscribeMenuItem: NSMenuItem! = nil
    var menusAdded = false

    class func pluginDidLoad(bundle: NSBundle) {
        let appName = NSBundle.mainBundle().infoDictionary?["CFBundleName"] as? NSString
        if appName == "Xcode" {
            sharedPlugin = CoPilotPlugin(bundle: bundle)
        }
    }

    init(bundle: NSBundle) {
        super.init()

        self.bundle = bundle
        self.publishMenuItem = self.menuItem(publishMenuTitle(), action:#selector(CoPilotPlugin.publish), key:"a")
        self.subscribeMenuItem = self.menuItem("CoPilot Subscribe", action:#selector(CoPilotPlugin.subscribe), key:"z")

        observers.append(
            observe("NSApplicationDidFinishLaunchingNotification", object: nil) { _ in
                self.addMenuItems()
            }
        )
        observers.append(
            observe("NSTextViewDidChangeSelectionNotification", object: nil) { _ in
                if !self.menusAdded {
                    // sometimes the menu items would not be added, perhaps a race condition with the edit menu not being there yet?
                    self.addMenuItems()
                }
                self.publishMenuItem.title = publishMenuTitle(XcodeUtils.activeEditor)
            }
        )
        observers.append(
            observe("NSWindowWillCloseNotification", object: nil) { note in
                if let window = note.object as? NSWindow {
                    if let conn = ConnectionManager.connected({ $0.editor.window == window }) {
                        ConnectionManager.disconnect(conn.editor)
                    }
                }
            }
        )
    }

    deinit {
        for o in self.observers {
            NSNotificationCenter.defaultCenter().removeObserver(o)
        }
    }
    
    override func validateMenuItem(menuItem: NSMenuItem) -> Bool {
        let hasEditor = { XcodeUtils.activeEditor != nil }
        let isConnected = { ConnectionManager.isConnected(XcodeUtils.activeEditor!) }
        
        switch menuItem.action {
        case #selector(CoPilotPlugin.publish):
            return hasEditor()
        case #selector(CoPilotPlugin.subscribe):
            return hasEditor() && !isConnected()
        case #selector(CoPilotPlugin.showConnected):
            return hasEditor()
        default:
            return NSApplication.sharedApplication().nextResponder?.validateMenuItem(menuItem) ?? false
        }
    }

}


// MARK: - Helpers
extension CoPilotPlugin {
    
    func addMenuItems() {
        let item = NSApp.mainMenu!.itemWithTitle("Edit")
        if item != nil {
            item!.submenu!.addItem(NSMenuItem.separatorItem())
            item!.submenu!.addItem(self.publishMenuItem)
            item!.submenu!.addItem(self.subscribeMenuItem)
            item!.submenu!.addItem(self.menuItem("CoPilot Show Connections", action:#selector(CoPilotPlugin.showConnected), key:"x"))
            self.menusAdded = true
        }
    }

    
    func menuItem(title: String, action: Selector, key: String) -> NSMenuItem {
        let m = NSMenuItem(title: title, action: action, keyEquivalent: key)
        m.keyEquivalentModifierMask = Int(NSEventModifierFlags.ControlKeyMask.rawValue | NSEventModifierFlags.CommandKeyMask.rawValue)
        m.target = self
        return m
    }
    
}


// MARK: - Actions
extension CoPilotPlugin {
    
    func publish() {
        if let editor = XcodeUtils.activeEditor {
            if ConnectionManager.isPublished(editor) {
                ConnectionManager.disconnect(editor)
            } else {
                ConnectionManager.publish(editor)
            }
            self.publishMenuItem.title = publishMenuTitle(editor)
        }
    }
    

    func subscribe() {
        if let editor = XcodeUtils.activeEditor {
            self.mainController.activeEditor = editor
            if let sheetWindow = self.mainController.window {
                let windowForSheet = editor.document.windowForSheet
                self.mainController.windowForSheet = windowForSheet
                windowForSheet?.beginSheet(sheetWindow) { response in
                    if response == MainController.SheetReturnCode.Url.rawValue {
                        if let sheetWindow = self.urlController.window {
                            self.urlController.activeEditor = editor
                            self.urlController.windowForSheet = windowForSheet
                            windowForSheet?.beginSheet(sheetWindow) { _ in }
                        }
                    }
                }
            }
        }
    }
    
    
    func showConnected() {
        self.connectedController.showWindow(self)
    }
    
}


//
//  AppDelegate.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/4/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Cocoa
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initilize session var
        guard let settings = UserSettings.shared else {
            callAlert(.fatal, "Error attempting to access user data.")
            return
        }
        let session = SessionData(settings)
        
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView()
            .environmentObject(session)

        // Create the window and set the content view. 
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}


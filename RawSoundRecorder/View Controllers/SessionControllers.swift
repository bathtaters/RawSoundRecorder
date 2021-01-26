//
//  SessionControllers.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/6/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation
import struct CoreAudioTypes.CoreAudioBaseTypes.AudioStreamBasicDescription
import class SwiftUI.NSOpenPanel


extension SessionData {
    
    func pressRefresh() {
        callAlert(.prerelease, "Pressed refresh")
        updateDeviceData()
        update()
    }
    
    func pressFolder() {
        guard status == .stop else { return }
        status = .disabled // disable app
        
        Self.folderSelectorPopup.directoryURL = currentFolder
        Self.folderSelectorPopup.begin() { (result) in
            if result == .OK, let newFolder = Self.folderSelectorPopup.url {
                self.currentFolder = newFolder
                callAlert(.prerelease, "Folder changed to: \(newFolder.path)")
            }
            self.status = .stop // enable app
        }
    }
    
    func setFolder(_ folderPath: inout String) {
        guard let newFolder = URL(fromPath: folderPath, mustBeDir: true) else {
            folderPath = currentFolder.path
            return
        }
        if currentFolder != newFolder {
            currentFolder = newFolder
            callAlert(.prerelease, "Folder changed to: \(newFolder.path)")
        }
    }
    
    func setFilename(_ filename: String) {
        guard currentFilename != filename else { return }
        currentFilename = filename
        callAlert(.prerelease, "Filename changed to: \(currentFilename)")
    }
    
    func setFileType(_ index: Int) {
        guard selectedFileType != fileTypeList[index] else { return }
        selectedFileType = fileTypeList[index]
        callAlert(.prerelease, "FileType changed to: \(selectedFileType.description)")
    }
    
    var channelList: [AudioChannel] {
        if let device = selectedDevice, let data = deviceData[device] {
            return data.channels
        }
        return []
    }
    
    
    // Popup window used to select a folder
    static let folderSelectorPopup: NSOpenPanel = {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        return openPanel
    }()
}

extension UserSettings {
    static var startupFileType: AudioFileType { AudioFileType(rawValue: shared!.selectedFileTypeID) }
    static var startupFilename: String { shared!.currentFile.deletingPathExtension().lastPathComponent }
}




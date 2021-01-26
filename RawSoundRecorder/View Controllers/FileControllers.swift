//
//  FileControllers.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/14/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation
import AudioToolbox

extension Filename {
    func getNextSafe(_ folder: URL) -> Self? {
        var filename = self
        var currentFile: URL { folder.appendingPathComponent(filename.filename) }
        
        while currentFile.exists() {
            let oldFilename = filename
            filename.incCounter()
            callAlert(.prerelease, "New Filename: \(filename.filename)")
            if filename == oldFilename { return nil }
        }
        
        return filename
    }
    
    func getNext() -> Self {
        var filename = self
        filename.incCounter()
        return filename
    }
}

extension SessionData {
    
    func createFile() -> AudioFile? {
        guard let recorder = recorderInterface else { return nil }
        
        // Get next filename
        if !UserSettings.fileOverwrite {
            guard let filename = Filename(currentFile.lastPathComponent).getNextSafe(currentFolder) else {
                callAlert(.error, "File exists and cannot be auto-incremented: \(currentFile.path)")
                return nil
            }
            currentFilename = filename.extensionless
        }
        else {
            currentFilename = Filename(currentFile.lastPathComponent).getNext().extensionless
            if currentFile.exists() {
                callAlert(.warning, "\(currentFile.lastPathComponent) already exists and will be overwritten.")
            }
        }
        
        // Set channel map based off of channelList
        let map = AudioChannelMap(channels: channelList)
        var err = recorder.recorder.setChannelMap(map)
        if err != noErr {
            callAlert(.warning, "Audio enigine cannot set active inputs, recording all inputs.")
            callAlert(.debug, "Error setting Channel Map: <\(err)>")
        }
        
        // Get current format and set to compatible format
        var format = formatList[formatIndex]
        if let fmtErr = format.validFix(selectedFileType) {
            callAlert(.error, "Format \(fmtErr) is not compatible with \(selectedFileType) file. Choose another format.")
            return nil
        }
        
        // Update format to match map
        if err == noErr && map.array.count < format.channels { format.channels = map.array.count }
        err = recorder.setRecorderFormat(format)
        if err != noErr {
            callAlert(.error, "Audio enigine cannot change file format.")
            callAlert(.debug, "Error updating file format: <\(err)>")
            return nil
        }
        
        guard var file = AudioFile(new: currentFile, selectedFileType, format, overwrite: UserSettings.fileOverwrite) else {
            callAlert(.error, "Error creating file: \(currentFile.path)")
            return nil
        }
        
        file.safeWriteMode = UserSettings.fileSafewrite
        
        return file
    }
}


//
//  AudioFile.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/13/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation
import AudioToolbox

struct AudioFile {
    let path: URL
    private let file: AudioFileID
    private var access: AudioFilePermissions = .none
    private var extendedFile: ExtAudioFileRef? = nil
    
    var name: String? { path.lastPathComponent }
    private init(_ fileID: AudioFileID, path: URL, access: AudioFilePermissions) {
        self.path = path
        self.file = fileID
        self.access = access
        let err = initExtFile()
        if err != noErr { callAlert(.debug, "Error extending AudioFile <\(err)>")}
    }
    var description: String { name ?? "<File \(file.debugDescription)>" }
    //deinit { _ = close() } // if Class
}


// Basic property accessors

extension AudioFile {
    
    var fileType: AudioFileType? {
        var value = AudioFileTypeID.zero
        var size = UInt32(MemoryLayout.size(ofValue: value))
        
        let err = AudioFileGetProperty(file, kAudioFilePropertyFileFormat, &size, &value)
        if err != noErr {
            callAlert(.debug, "\(description) getFileType error code <\(err)>")
            return nil
        }
        return value == .zero ? nil : AudioFileType(rawValue: value)
    }
    
    var safeWriteMode: Bool? {
        
        get {
            var value = UInt32.max
            var size = UInt32(MemoryLayout.size(ofValue: value))
            
            let err = AudioFileGetProperty(file, kAudioFilePropertyDeferSizeUpdates, &size, &value)
            if err != noErr {
                callAlert(.debug, "\(description) getSafeWriteMode error code <\(err)>")
                return nil
            }
            return value == .max ? nil : value == 0
        }
        
        set {
            guard let safeWrite = newValue else { return }
            var value: UInt32 = safeWrite ? 0 : 1
            let size = UInt32(MemoryLayout.size(ofValue: value))
            
            let err = AudioFileSetProperty(file, kAudioFilePropertyDeferSizeUpdates, size, &value)
            if err != noErr { callAlert(.debug, "\(description) setSafeWriteMode error code <\(err)>: \(safeWrite)")}
        }
    }
    
    var isOptimized: Bool? {
        var value = UInt32.max
        var size = UInt32(MemoryLayout.size(ofValue: value))
        
        let err = AudioFileGetProperty(file, kAudioFilePropertyIsOptimized, &size, &value)
        if err != noErr {
            callAlert(.debug, "\(description) getSafeWriteMode error code <\(err)>")
            return nil
        }
        return value == .max ? nil : value != 0
    }
    
    func getFormat() -> AudioStreamBasicDescription? {
        var value = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout.size(ofValue: value))
        
        let err = AudioFileGetProperty(file, kAudioFilePropertyDataFormat, &size, &value)
        if err != noErr {
            callAlert(.debug, "\(description) getFormat error code <\(err)>")
            return nil
        }
        return value == .init() ? nil : value
    }
    
    // Check if it's ok to write file
    func writableErrors() -> FileError {
        if !access.contains(.writePermission) { return .access }
        if extendedFile == nil { return .extendedInterface }
        
        if let optimized = isOptimized {
            if !optimized { AudioFileOptimize(file) } // Try to optimize
            if !(isOptimized ?? false) { return .optimization }
        }
        else { return .optimizeValue }
        
        return .writable
    }
}


// File operations

extension AudioFile {
    
    // Create new file
    init?(new path: URL, _ type: AudioFileType, _ format: AudioStreamBasicDescription,
                      overwrite: Bool = false, pageAligned: Bool = true) {
        
        var fileID: AudioFileID?
        var fileFormat = format
        let flags = AudioFileFlags(overwrite: overwrite, pageAligned: pageAligned)
        
        let err = AudioFileCreateWithURL(path as CFURL, type.rawValue, &fileFormat, flags, &fileID)
        if err != noErr { callAlert(.debug, "Error code <\(err)> creating file \(path.lastPathComponent).") }
        
        guard let file = fileID else { return nil }
        self.init(file, path: path, access: .writePermission)
        
    }
    
    // Extend file
    mutating func initExtFile() -> OSStatus {
        guard access != .none else { return kAudioFilePermissionsError }
        return ExtAudioFileWrapAudioFileID(file, access.contains(.writePermission), &extendedFile)
    }
    
    // Write buffer handoff functino
    func writeBuffer(_ bufferList: UnsafeMutablePointer<AudioBufferList>, frameCount: inout UInt32) -> OSStatus {
        
        guard let extFile = extendedFile else {
            callAlert(.debug, "Unable to access extnded writing interface of file: \(description)")
            return kAudioFileNotOpenError
        }
        
        return ExtAudioFileWrite(extFile, frameCount, bufferList)
    }
    
    // Save and finalize file
    mutating func close(optimize: Bool = true) -> OSStatus {
        access = .none
        
        if optimize {
            let err = AudioFileOptimize(file)
            if err != noErr { callAlert(.debug, "Error optimizing file \(description)") }
        }
        
        if let extFile = extendedFile {
            let err = ExtAudioFileDispose(extFile)
            if err != noErr { callAlert(.debug, "Error disposing of file \(description)") }
            extendedFile = nil
            return err
        }
        
        let err = AudioFileClose(file)
        if err != noErr { callAlert(.debug, "Error closing file \(description)") }
        return err
    }
    
}


// File error types
extension AudioFile { enum FileError { case writable, access, extendedInterface, optimization, optimizeValue } }


// Helpers for AudioFile
extension AudioFilePermissions: CustomStringConvertible {
    // OptionSet methods since this can't ever conform due to built-in init()
    static let none = AudioFilePermissions(rawValue: 0)!
    static let names: [AudioFilePermissions: String] = [
        .readPermission : "read", .writePermission : "write"
    ]
    
    public func contains(_ element: AudioFilePermissions) -> Bool {
        rawValue & element.rawValue != 0
    }
    public var description: String {
        Self.names.keys.filter{ contains($0) }.map{ Self.names[$0]! }.joined(separator: "/")
    }
}
extension AudioFileFlags {
    // init from Bools
    init(overwrite: Bool = false, pageAligned: Bool = true) {
        self.init(rawValue: 0)
        if overwrite { insert(.eraseFile) }
        if !pageAligned { insert(.dontPageAlignAudioData) }
    }
}

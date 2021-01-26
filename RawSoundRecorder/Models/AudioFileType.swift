//
//  AudioFileType.swift
//  RawSoundRecord
//
//  Created by Nick Chirumbolo on 11/9/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation
import AudioToolbox

struct AudioFileType: RawRepresentable {
    let rawValue: AudioFileTypeID
    
    // Stored properties
    let name: String
    let extensions: [String]
    let defaultExt: String
    
    init(rawValue: AudioFileTypeID) {
        let extensions = Self.getExtensions(rawValue)
        
        self.rawValue = rawValue
        self.name = Self.getName(rawValue) ?? "'\(rawValue.decoded)'"
        self.extensions = extensions
        self.defaultExt = extensions.first ?? ""
    }
    static let wav = AudioFileType(rawValue: kAudioFileWAVEType)
}

// Fetch stored properties
extension AudioFileType {
    static func getName(_ rawValue: AudioFileTypeID) -> String? {
        var value = "" as CFString
        var valSize = UInt32(MemoryLayout<CFString>.size)
        var specifier = rawValue
        
        let err = AudioFileGetGlobalInfo(
            kAudioFileGlobalInfo_FileTypeName,
            UInt32(MemoryLayout.size(ofValue: specifier)),
            &specifier,
            &valSize,
            &value
        )
        if err != noErr {
            callAlert(.debug, "FileGlobal.Name(\(rawValue.decoded)) returned err code: <\(err)>")
            return nil
        }
        
        let name = value as String
        return name.isEmpty ? nil : name
    }
    static func getExtensions(_ rawValue: AudioFileTypeID) -> [String] {
        var value: CFArray?
        var valSize = UInt32(MemoryLayout<CFArray>.size)
        var specifier = rawValue
        
        let err = AudioFileGetGlobalInfo(
            kAudioFileGlobalInfo_ExtensionsForType,
            UInt32(MemoryLayout.size(ofValue: specifier)),
            &specifier,
            &valSize,
            &value
        )
        if err != noErr || value == nil {
            callAlert(.debug, "FileGlobal.Extensions(\(rawValue.decoded)) returned err code: <\(err)>")
            return []
        }
        return value as? [String] ?? []
    }
    func getFormats(_ formatID: AudioFormatID = kAudioFormatLinearPCM) -> [AudioStreamBasicDescription] {
        let selector = kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat
        var valSize = UInt32(0)
        
        var specifier = AudioFileTypeAndFormatID(mFileType: rawValue, mFormatID: formatID)
        let specSize = UInt32(MemoryLayout.size(ofValue: specifier))
        
        var err = AudioFileGetGlobalInfoSize(selector, specSize, &specifier, &valSize)
        if err != noErr {
            callAlert(.debug, "\(description)(\(formatID.decoded)).getSizeOfValidFormats returned err code: <\(err)>")
            return []
        }
        
        let empty = AudioStreamBasicDescription()
        var value = [AudioStreamBasicDescription](
            repeating: empty,
            count: Int((Double(valSize)/Double(MemoryLayout<AudioStreamBasicDescription>.size)).rounded(.up))
        )
        
        err = AudioFileGetGlobalInfo(selector, specSize, &specifier, &valSize, &value)
        if err != noErr {
            callAlert(.debug, "\(description)(\(formatID.decoded)).getValidFormats returned err code: <\(err)>")
            return []
        }
        return value.filter { $0 != empty }
    }
}

// All writable file type IDs
extension AudioFileType {
    static let writable: [AudioFileTypeID] = {
        let selector = kAudioFileGlobalInfo_WritableTypes
        var valSize = UInt32(0)

        var err = AudioFileGetGlobalInfoSize(selector, 0, nil, &valSize)
        if err != noErr {
            callAlert(.debug, "FileGlobal.Writable.getSize returned err code: <\(err)>")
            return []
        }
        
        var value = [AudioFileTypeID](
            repeating: AudioFileTypeID(),
            count: Int((Double(valSize)/Double(MemoryLayout<AudioFileTypeID>.size)).rounded(.up))
        )
        
        err = AudioFileGetGlobalInfo(selector, 0, nil, &valSize, &value)
        if err != noErr {
            callAlert(.debug, "FileGlobal.Writable returned err code: <\(err)>")
            return []
        }
        return value
    }()
}

// Conformance
extension AudioFileType: Equatable, CustomStringConvertible {
    static func ==(lhs: AudioFileType, rhs: AudioFileType) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
    var description: String { rawValue.decoded }
}

extension AudioFileType {
    // Used when matching similar formats
    static let matchingFlagsOrdered: [FormatFlags] = [
        .nonMixable, .nonInterleaved, .bigEndian, .alignedHigh, .packed
    ]
}
 



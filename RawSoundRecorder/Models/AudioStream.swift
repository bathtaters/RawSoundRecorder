//
//  AudioStream.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/4/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation
import AudioToolbox

// Stream stored vars & initilizer
struct AudioStream: AudioObject {
    let id: AudioStreamID
    let parent: AudioDevice
    
    init(_ device: AudioDevice, _ streamID: AudioStreamID) {
        self.id = streamID
        self.parent = device
    }
}

// Stream interface
extension AudioStream {
    var description: String {
        get { getName() ?? "\((direction?.rawValue ?? "unknown").formatedVarName) Stream #\(Int(startChannel))" }
        set { _ = setName(newValue) }
    }
    var isActive: Bool {
        var value = UInt32(Self.isActiveDefault ? 1 : 0)
        var valSize = UInt32(MemoryLayout.size(ofValue: value))
        var address = Self.isActiveAddress
        let err = AudioObjectGetPropertyData(id, &address, 0, nil, &valSize, &value)
        if err != noErr {
            callAlert(.debug,"\(description): getIsActive error code <\(err)> (Using default value: \(Self.isActiveDefault))")
            return Self.isActiveDefault
        }
        return value != 0
    }
    var direction: AudioDirection? {
        var value = UInt32.max
        var valSize = UInt32(MemoryLayout.size(ofValue: value))
        var address = Self.directionAddress
        let err = AudioObjectGetPropertyData(id, &address, 0, nil, &valSize, &value)
        if err != noErr {
            callAlert(.debug,"\(description): getDirection error code <\(err)>")
            return nil
        }
        return AudioDirection(value)
    }
    var startChannel: UInt32 {
        var value = Self.startChannelDefault
        var valSize = UInt32(MemoryLayout.size(ofValue: value))
        var address = Self.startChannelAddress
        let err = AudioObjectGetPropertyData(id, &address, 0, nil, &valSize, &value)
        if err != noErr {
            callAlert(.debug,"\(description): getStartingChannel error code <\(err)> (Using default value: \(Self.startChannelDefault))")
            return Self.startChannelDefault
        }
        return value
    }
    var lastChannel: Int { Int(startChannel) + channelCount() - 1 }
}

// Stream property accessors
extension AudioStream {
    func getName() -> String? {
        var value = "" as CFString
        var valSize = UInt32(MemoryLayout.size(ofValue: value))
        var address = AudioDevice.nameAddress
        let err = AudioObjectGetPropertyData(id, &address, 0, nil, &valSize, &value)
        if err != noErr {
            callAlert(.debug,"\(debugDescription): getName error code <\(err)>")
            return nil
        }
        let string = value as String
        return string.isEmpty ? nil : string
    }
    func setName(_ name: String) -> OSStatus {
        var value = name as CFString
        let valSize = UInt32(MemoryLayout.size(ofValue: value))
        var address = AudioDevice.nameAddress
        return AudioObjectSetPropertyData(id, &address, 0, nil, valSize, &value)
    }
    
    func getFormat(virtual: Bool = false) -> AudioStreamBasicDescription? {
        var value = AudioStreamBasicDescription()
        var valSize = UInt32(MemoryLayout.size(ofValue: value))
        var address = virtual ? Self.virtualFormatAddress : Self.physicalFormatAddress
        let err = AudioObjectGetPropertyData(id, &address, 0, nil, &valSize, &value)
        if err != noErr {
            callAlert(.debug,"\(description): get\(virtual ? "Virtual" : "Physical")Format error code <\(err)>")
            return nil
        }
        return value == AudioStreamBasicDescription() ? nil : value
    }
    func setFormat(_ format: AudioStreamBasicDescription, virtual: Bool = false) -> OSStatus {
        var value = format
        let valSize = UInt32(MemoryLayout.size(ofValue: value))
        var address = virtual ? Self.virtualFormatAddress : Self.physicalFormatAddress
        return AudioObjectSetPropertyData(id, &address, 0, nil, valSize, &value)
    }
    func getAllFormats(virtual: Bool = false) -> [AudioStreamBasicDescription] {
        var address = virtual ? Self.virtualFormatListAddress : Self.physicalFormatListAddress
        var valSize = AudioDevice.getSize(self, &address)
        
        let arrayCount = Int((Double(valSize)/Double(MemoryLayout<AudioStreamRangedDescription>.size)).rounded(.up))
        let empty = AudioStreamRangedDescription()
        var value = [AudioStreamRangedDescription](repeating: empty, count: arrayCount)
        
        let err = AudioObjectGetPropertyData(id, &address, 0, nil, &valSize, &value)
        if err != noErr {
            callAlert(.debug,"\(description): getAll\(virtual ? "Virtual" : "Physical")Formats error code <\(err)>")
        }
        return value.filter{ $0 != empty }.map{ $0.base }
    }
    
    func channelCount() -> Int {
        return Int(getFormat(virtual: true)?.mChannelsPerFrame ?? 0)
    }
    func getChannelList(allEnabled: Bool = false) -> [AudioChannel] {
        let count = channelCount()
        if count < 1 { return [] }
        let offset = Int(startChannel)
        return (0..<count).map{
            AudioChannel($0 + offset, self, enabled: allEnabled)
        }
    }
}

// Static/Class Properties/Helpers
extension AudioStream {
    private static let startChannelDefault = UInt32(1)
    private static let startChannelAddress = AudioObjectPropertyAddress(
        mSelector: kAudioStreamPropertyStartingChannel,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: AudioObjectPropertyElement(0)
    )
    private static let isActiveDefault = false
    private static let isActiveAddress = AudioObjectPropertyAddress(
        mSelector: kAudioStreamPropertyIsActive,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: AudioObjectPropertyElement(0)
    )
    private static let directionAddress = AudioObjectPropertyAddress(
        mSelector: kAudioStreamPropertyDirection,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: AudioObjectPropertyElement(0)
    )
    private static let physicalFormatAddress = AudioObjectPropertyAddress(
        mSelector: kAudioStreamPropertyPhysicalFormat,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: AudioObjectPropertyElement(0)
    )
    private static let virtualFormatAddress = AudioObjectPropertyAddress(
        mSelector: kAudioStreamPropertyVirtualFormat,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: AudioObjectPropertyElement(0)
    )
    private static let physicalFormatListAddress = AudioObjectPropertyAddress(
        mSelector: kAudioStreamPropertyAvailablePhysicalFormats,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: AudioObjectPropertyElement(0)
    )
    private static let virtualFormatListAddress = AudioObjectPropertyAddress(
        mSelector: kAudioStreamPropertyAvailableVirtualFormats,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: AudioObjectPropertyElement(0)
    )
}

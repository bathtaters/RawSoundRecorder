//
//  InputChannel.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/4/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation
import AudioToolbox

// Channel stored vars & initilizer
class AudioChannel: ObservableObject {
    let number: Int
    let stream: AudioStream
    @Published var enabled: Bool
    @Published var meterValue: Float = .zero
    @Published private var updater = false
    
    var deviceName: String { stream.parent.description }
    lazy var canRename: Bool = {
        var canSet: DarwinBoolean = false
        var address = nameAddress
        let err = AudioObjectIsPropertySettable(stream.parent.id, &address, &canSet)
        if err != noErr {
            callAlert(.debug, "\(debugDescription): canRename error code <\(err)>: \(canSet.description)")
        }
        return canSet.boolValue
    }()
    
    init(_ number: Int, _ stream: AudioStream, enabled: Bool = true) {
        self.number = number
        self.stream = stream
        self.enabled = enabled
    }
    
    // Calculated Property Address
    lazy var nameAddress: AudioObjectPropertyAddress = {
        AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyElementName,
            mScope: stream.direction == .input ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput,
            mElement: AudioObjectPropertyElement(number)
        )
    }()
}

// Channel interface
extension AudioChannel: CustomStringConvertible {
    var description: String {
        if let name = getChannelName(), !name.isEmpty { return name }
        return AudioChannel.defaultDescription
    }
    var name: String {
        get {
            getChannelName() ?? ""
        }
        set {
            if canRename && name != newValue {
                let err = setChannelName(newValue)
                self.updater.toggle()
                if err == noErr { callAlert(.prerelease, "Renamed channel \(number) to: \(newValue)") }
                else {
                    callAlert(.error, "Cannot rename channel \(number).")
                    callAlert(.debug, "Error renaming \(debugDescription) to \(newValue). Error code <\(err)>")
                }
            }
        }
    }
}

// Channel property accessors
extension AudioChannel {
    func getChannelName() -> String? {
        var value = "" as CFString
        var valSize = UInt32(MemoryLayout.size(ofValue: value))
        var address = nameAddress
        let err = AudioObjectGetPropertyData(stream.parent.id, &address, 0, nil, &valSize, &value)
        if err != noErr {
            callAlert(.debug,"\(debugDescription): getName error code <\(err)>")
            
            return nil
        }
        let string = value as String
        return string.isEmpty ? nil : string
    }
    func setChannelName(_ name: String) -> OSStatus {
        var value = name as CFString
        let valSize = UInt32(MemoryLayout.size(ofValue: value))
        var address = nameAddress
        return AudioObjectSetPropertyData(stream.parent.id, &address, 0, nil, valSize, &value)
    }
}

// Create from AudioChannel list
extension AudioChannelMap {
    init(channels: [AudioChannel]) {
        var result = [Int32]()
        for i in channels.indices {
            if channels[i].enabled { result.append(Int32(i)) }
        }
        self.array = result
    }
}

// Additional conformance
extension AudioChannel: Equatable {
    static func == (lhs: AudioChannel, rhs: AudioChannel) -> Bool {
        lhs.stream == rhs.stream && lhs.number == rhs.number
    }
}

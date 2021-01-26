//
//  InputDevice.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/4/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation
import AudioToolbox

// Device stored vars, initilizer & global instance
struct AudioDevice: AudioObject {
    let id: AudioDeviceID
    
    // Stored properties
    let description: String
    let uniqueID: String
    
    init(_ deviceID: AudioDeviceID) {
        var description = "System Object"
        var uniqueID = "SystemObject[\(deviceID)]"
        if deviceID != kAudioObjectSystemObject {
            description = Self.getName(deviceID) ?? "<Unnamed Audio Device #\(deviceID)>"
            uniqueID = Self.getUID(deviceID) ?? "\(description.replacingOccurrences(of: " ", with: "_"))[\(deviceID)]"
        }
        self.id = deviceID
        self.description = description
        self.uniqueID = uniqueID
    }
    static let shared = AudioDevice(AudioDeviceID(kAudioObjectSystemObject))
    
}

// Device property accessors
extension AudioDevice {
    static func getName(_ id: AudioDeviceID) -> String? {
        var value = "" as CFString
        var valSize = UInt32(MemoryLayout.size(ofValue: value))
        var address = AudioDevice.nameAddress
        
        let err = AudioObjectGetPropertyData(id, &address, 0, nil, &valSize, &value)
        if err != noErr {
            callAlert(.debug,"AudioDevice[\(id)]: getName error code <\(err)>")
            return nil
        }
        
        let string = value as String
        return string.isEmpty ? nil : string
    }
    static func getUID(_ id: AudioDeviceID) -> String? {
        var value = "" as CFString
        var valSize = UInt32(MemoryLayout.size(ofValue: value))
        var address = AudioDevice.deviceUIDAddress
        
        let err = AudioObjectGetPropertyData(id, &address, 0, nil, &valSize, &value)
        if err != noErr {
            callAlert(.debug,"AudioDevice[\(id)]: getName error code <\(err)>")
        }
        
        let string = value as String
        return string.isEmpty ? nil : string
    }
    func getTransportType() -> String? {
        var value = UInt32.max
        var valSize = UInt32(MemoryLayout.size(ofValue: value))
        var address = AudioDevice.transportTypeAddress
        let err = AudioObjectGetPropertyData(id, &address, 0, nil, &valSize, &value)
        if err != noErr {
            callAlert(.debug,"\(description): getDeviceTransportType error code <\(err)>")
            return nil
        }
        return value == UInt32.max ? nil : AudioDevice.transportTypeString(value)
    }
    
    var isHidden: Bool {
        var value = UInt32.zero
        var valSize = UInt32(MemoryLayout.size(ofValue: value))
        var address = AudioDevice.isHiddenAddress
        let err = AudioObjectGetPropertyData(id, &address, 0, nil, &valSize, &value)
        if err != noErr {
            callAlert(.debug,"\(description): getIsHidden error code <\(err)> (Using default value: \(false))")
            return false
        }
        return value != 0
    }
    var isAlive: Bool {
        var value = UInt32.zero
        var valSize = UInt32(MemoryLayout.size(ofValue: value))
        var address = AudioDevice.isAliveAddress
        let err = AudioObjectGetPropertyData(id, &address, 0, nil, &valSize, &value)
        if err != noErr {
            callAlert(.debug,"\(description): getIsHidden error code <\(err)> (Using default value: \(false))")
            return false
        }
        return value != 0
    }
    var isRunning: Bool {
        var value = UInt32.zero
        var valSize = UInt32(MemoryLayout.size(ofValue: value))
        var address = AudioDevice.isRunningAddress
        let err = AudioObjectGetPropertyData(id, &address, 0, nil, &valSize, &value)
        if err != noErr {
            callAlert(.debug,"\(description): getIsHidden error code <\(err)> (Using default value: \(false))")
            return false
        }
        return value != 0
    }
    
    func getStreamList() -> [AudioStreamID] {
        var address = AudioDevice.allStreamsAddress
        var valSize = AudioDevice.getSize(self, &address)
        
        let arrayCount = Int((Double(valSize)/Double(MemoryLayout<AudioStreamID>.size)).rounded(.up))
        let empty = AudioStreamID.max
        var value = [AudioStreamID](repeating: empty, count: arrayCount)
        
        let err = AudioObjectGetPropertyData(id, &address, 0, nil, &valSize, &value)
        if err != noErr {
            callAlert(.debug,"System Object: getAllDevices error code <\(err)>")
        }
        return value.filter { $0 != empty }
    }
    
    static func getDeviceList() -> [AudioDeviceID] {
        var address = AudioDevice.allDevicesAddress
        var valSize = AudioDevice.getSize(AudioDevice.shared, &address)
        
        let arrayCount = Int((Double(valSize)/Double(MemoryLayout<AudioDeviceID>.size)).rounded(.up))
        let empty = AudioDeviceID.max
        var value = [AudioDeviceID](repeating: empty, count: arrayCount)
        
        let err = AudioObjectGetPropertyData(AudioDevice.shared.id, &address, 0, nil, &valSize, &value)
        if err != noErr {
            callAlert(.debug,"System Object: getAllDevices error code <\(err)>")
        }
        return value.filter { $0 != empty }
    }
    static func getDefaultDevice(_ direction: AudioDirection) -> AudioDeviceID? {
        var value = UInt32.max
        var valSize = UInt32(MemoryLayout.size(ofValue: value))
        var address = AudioObjectPropertyAddress(
            mSelector: direction == .input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: AudioObjectPropertyElement(0)
        )
        let err = AudioObjectGetPropertyData(AudioDevice.shared.id, &address, 0, nil, &valSize, &value)
        if err != noErr {
            callAlert(.debug,"System Object: getDefault\(direction.rawValue.formatedVarName)Device error code <\(err)>")
            return nil
        }
        return value == UInt32.max ? nil : value
    }
}


// Static/Class Properties/Helpers
extension AudioDevice {
    internal static func getSize<O: AudioObject>(_ object: O, _ address: inout AudioObjectPropertyAddress) -> UInt32 {
        var size = UInt32(0)
        let err = AudioObjectGetPropertyDataSize(object.id, &address, 0, nil, &size)
        if err != noErr {
            callAlert(.debug,"\(object.description): getSize(\(address.debugDescription)) error code <\(err)>. Return: \(size)")
        }
        return size
    }
    internal static let nameAddress = AudioObjectPropertyAddress(
        mSelector: kAudioObjectPropertyName,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: AudioObjectPropertyElement(0)
    )
    internal static let deviceUIDAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceUID,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: AudioObjectPropertyElement(0)
    )
    static private let allDevicesAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: AudioObjectPropertyElement(0)
    )
    static private let allStreamsAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreams,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: AudioObjectPropertyElement(0)
    )
    static private let transportTypeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyTransportType,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: AudioObjectPropertyElement(0)
    )
    static private let isHiddenAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyIsHidden,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: AudioObjectPropertyElement(0)
    )
    static private let isAliveAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsAlive,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: AudioObjectPropertyElement(0)
    )
    static private let isRunningAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: AudioObjectPropertyElement(0)
    )
    private static func transportTypeString(_ transportCode: UInt32) -> String {
        switch transportCode {
        case kAudioDeviceTransportTypeBuiltIn: return "Built-In"
        case kAudioDeviceTransportTypeAggregate: return "Aggregate"
        case kAudioDeviceTransportTypeVirtual: return "Virtual"
        case kAudioDeviceTransportTypePCI: return "PCI Bus"
        case kAudioDeviceTransportTypeUSB: return "USB"
        case kAudioDeviceTransportTypeFireWire: return "FireWire"
        case kAudioDeviceTransportTypeBluetooth: return "Bluetooth"
        case kAudioDeviceTransportTypeBluetoothLE: return "Bluetooth (LE)"
        case kAudioDeviceTransportTypeHDMI: return "HDMI"
        case kAudioDeviceTransportTypeDisplayPort: return "DisplayPort"
        case kAudioDeviceTransportTypeAirPlay: return "AirPlay"
        case kAudioDeviceTransportTypeAVB: return "AVB"
        case kAudioDeviceTransportTypeThunderbolt: return "Thunderbolt"
        case kAudioDeviceTransportTypeUnknown: return "Unknown"
        default: return "\(transportCode.decoded)"
        }
    }
}





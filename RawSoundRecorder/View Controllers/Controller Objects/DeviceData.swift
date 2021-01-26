//
//  DeviceData.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/6/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation
import AudioToolbox

// Session storage object
struct DeviceData {
    let device: AudioDevice
    var streams: [AudioStream] = []
    var selectedStream: AudioStream? = nil
    var formats: [AudioStreamBasicDescription] = []
    var channels: [AudioChannel] = []
    
    init(_ device: AudioDevice, formatSettings: FormatSettings? = nil,
         channelSettings: ChannelEnableSettings = .disableAll) {
        self.device = device
        update(formatSettings: formatSettings, channelSettings: channelSettings)
    }
}

// Interface
extension DeviceData {
    var isEmpty: Bool { channels.count < 1 || selectedStream == nil }
    
    mutating func update(formatSettings: FormatSettings? = nil, channelSettings: ChannelEnableSettings) {
        streams = device.updatedStreamList(.input, streams)
        if selectedStream == nil || !streams.contains(selectedStream!) { selectedStream = streams.first }
        
        if let selectedStream = selectedStream {
            channels = device.updatedChannelList([selectedStream], enableSettings: channelSettings, channels)
            if let formatSettings = formatSettings {
                updateFormatList(formatSettings)
            }
        }
        else { channels = []; formats = [] }
    }
    
    func updated(formatSettings: FormatSettings? = nil, channelSettings: ChannelEnableSettings) -> DeviceData {
        var result = self
        result.update(formatSettings: formatSettings, channelSettings: channelSettings)
        return result
    }
    
    mutating func updateFormatList(_ formatSettings: FormatSettings) {
        if let stream = selectedStream {
            
            // Get list of all formats for selected stream
            var formatList = stream.getAllFormats(virtual: formatSettings.useVirtual)
            
            // Filter by fileType
            formatList = formatList.filterFormats(formatSettings.fileType, formatID: formatSettings.formatID)
            
            // Include currently selected format in case it was filtered out
            if let currentFormat = stream.getFormat(), !formatList.contains(currentFormat) {
                callAlert(.debug, "Current format (\(currentFormat.description)) is not available in menu. Was added to list.")
                formatList.insert(currentFormat, at: 0)
            }
            
            formats.update(formatList)
        }
    }
}


// Device Dictionary special functions
typealias AudioDeviceDict = [AudioDevice: DeviceData]

extension AudioDeviceDict {
    init (_ deviceList: [AudioDevice], formatSettings: FormatSettings? = nil,
          channelSettings: ChannelEnableSettings = .disableAll) {
        self.init(
            uniqueKeysWithValues: deviceList.map { device in
                (device, DeviceData(device, formatSettings: formatSettings, channelSettings: channelSettings) )
        })
    }
    
    mutating func addOrReset(_ device: AudioDevice, formatSettings: FormatSettings? = nil,
                             channelSettings: ChannelEnableSettings = .disableAll) {
        // Add a new device or reset an existing one
        updateValue(DeviceData(device, formatSettings: formatSettings, channelSettings: channelSettings),
                    forKey: device)
    }
    mutating func update(_ device: AudioDevice, formatSettings: FormatSettings? = nil,
                         newChannelSettings: ChannelEnableSettings = .disableAll) {
        // Update only properties that have changed
        if let data = self[device] {
            self[device] = data.updated(formatSettings: formatSettings, channelSettings: newChannelSettings)
        }
        // if it is not in the dict, add it
        else { addOrReset(device, formatSettings: formatSettings, channelSettings: newChannelSettings) }
    }
    
    mutating func removeEmpty() {
        forEach { (device,data) in
            if data.isEmpty { removeValue(forKey: device) }
        }
    }
}

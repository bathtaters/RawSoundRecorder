//
//  DeviceControllers.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/6/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation

extension SessionData {
    func setDeviceIndex(_ index: Int) {
        if deviceList.indices.contains(index) && selectedDevice != deviceList[index] {
            selectedDevice = deviceList[index]
            updateSelectedDevice()
        }
    }
    
}

// Device interface
extension AudioDevice {
    
    static func getAllDevices(_ direction: AudioDirection = .input, showHidden: Bool = false) -> [AudioDevice] {
        getDeviceList().map{AudioDevice($0)}.filter {
            
            // Device must be alive (and not hidden as long as show hidden is false)
            $0.isAlive && (showHidden || !$0.isHidden) && $0.updatedStreamList(direction).count > 0
        }
    }
    
    func channelCount(_ direction: AudioDirection = .input) -> Int {
        updatedStreamList(direction).reduce(0) {$0 + $1.channelCount()}
    }
    
    func updatedStreamList(_ direction: AudioDirection = .input, _ oldList: [AudioStream] = []) -> [AudioStream] {
        let newStreamIDs = getStreamList()
        let newList = newStreamIDs.map{
                    AudioStream(self, $0)
                }.filter{
                    
                    // Only get active streams that are in the right direction
                    $0.direction == direction && $0.isActive
                }
        
        return oldList.updated(newList).sorted{ a,b in a.startChannel < b.startChannel }
    }
    
    func updatedChannelList(_ streams: [AudioStream], enableSettings: ChannelEnableSettings = .disableAll,
                            _ oldList: [AudioChannel] = []) -> [AudioChannel] {
        
        let newList = streams.flatMap { $0.getChannelList(allEnabled: !enableSettings.enable) }
        newList.forEach { $0.setEnableTo(enableSettings) } // Match enable settings
        return oldList.updated(newList).sorted{ a,b in a.number < b.number }
        
    }
    
}


// Enable/Disable channels according to ChannelEnableSettings
extension ChannelEnableSettings {
    func isEnabled(_ channel: Int) -> Bool {
        (channel > channels) != enable
    }
}
extension AudioChannel {
    convenience init(_ number: Int, _ stream: AudioStream, enableSettings: ChannelEnableSettings) {
        self.init(number, stream, enabled: enableSettings.isEnabled(number))
    }
    func setEnableTo(_ enableSettings: ChannelEnableSettings) {
        if enabled != enableSettings.isEnabled(number) { enabled.toggle() }
    }
}



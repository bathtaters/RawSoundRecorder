//
//  SessionData.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/6/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation

final class SessionData: ObservableObject {
    @Published var status: TransportState = .startup
    @Published var selectedDevice: AudioDevice? = nil
    @Published var currentFilename: String = ""
    @Published var selectedFileType: AudioFileType = UserSettings.startupFileType
    @Published var currentFolder: URL = URL.home
    
    @Published private var updater: Bool = false
    
    private var recorder: AudioRecorder? = nil
    
    var meterSettings: MeterSettings = .init()
    var deviceList: [AudioDevice] = []
    var deviceData: AudioDeviceDict = [:]
    
    var settings: UserSettings
    
    init(_ settings: UserSettings) {
        self.settings = settings
        loadState(); loadCache()
        updateDeviceData()
        saveState(); updateCache()
    }
    deinit { saveState(); updateCache() }
    
    
    lazy var fileTypeList: [AudioFileType] = {
        UserSettings.availableFileTypes.map { AudioFileType(rawValue: $0) }
    }()
}


// Session Data interface

extension SessionData {
    func update() { updater.toggle() }
    var recorderInterface: AudioRecorder? { recorder }
    
    func updateDeviceList() {
        let deviceList = AudioDevice.getAllDevices(.input, showHidden: settings.showHiddenDevices)
        guard deviceList.count > 0 else {
            callAlert(.error, "No audio inputs were found, please plug in and reopen application or check settings.")
            return
        }
        self.deviceList = deviceList.sorted(by: { a,b in a.id < b.id })
        updateSelectedDevice()
    }
    func resetDeviceData() {
        clearCache()
        updateDeviceList()
        deviceData = AudioDeviceDict(deviceList, formatSettings: formatSettings,
                                     channelSettings: settings.channelEnabling)
        
        deviceData.removeEmpty()
        updateSelectedDevice()
        updateCache()
    }
    func updateDeviceData() {
        updateDeviceList()
        
        // Update existing devices
        deviceData.keys.forEach {
            deviceData.update($0, formatSettings: formatSettings,
                              newChannelSettings: settings.channelEnabling)
        }
        
        // Add new devices
        deviceList.forEach {
            if !deviceData.keys.contains($0) {
                deviceData.addOrReset($0, formatSettings: formatSettings,
                                      channelSettings: settings.channelEnabling)
            }
        }
        
        // Cleanup list & selected device
        deviceData.removeEmpty()
        updateSelectedDevice()
        updateCache()
    }
    func updateSelectedDevice() {
        defer {
            if let device = selectedDevice {
                
                // Update device data array
                if deviceData[device] != nil {
                    deviceData[device]!.update(formatSettings: formatSettings,
                                               channelSettings: settings.channelEnabling)
                }
                
                // Update recorder interface
                if let recorder = recorder { _ = recorder.updateDevice(device) }
                else { recorder = AudioRecorder(device: device, bufferSize: UserSettings.bufferCapacity) }
            }
        }
        
        // Device is valid
        if let device = selectedDevice, deviceList.contains(device) { return }
        
        // Try default device
        if let device = AudioDevice.defaultInput, deviceList.contains(device) {
            selectedDevice = device
        }
        // Try first device in list
        else if let device = deviceList.first {
            selectedDevice = device
        }
        // DeviceList must be empty
        else {
            selectedDevice = nil
            callAlert(.debug, "No valid devices were found \(deviceList)")
        }
    }
    
    
    // Generate current formatSettings struct
    var formatSettings: FormatSettings {
        FormatSettings(fileType: selectedFileType,
                       formatID: UserSettings.selectedFormat,
                       useVirtual: settings.useVirtualFormats)
    }
}




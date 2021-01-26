//
//  SettingsController.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/6/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation
import AudioToolbox.AudioFormat

// Saving session state
extension SessionData {
    func saveState() {
        settings.currentFile = currentFile
        settings.selectedFileTypeID = selectedFileTypeID
        settings.selectedDeviceUID = selectedDeviceUID
        settings.meterSettings = meterSettings
    }
    func loadState() {
        self.currentFile = settings.currentFile
        self.selectedFileTypeID = settings.selectedFileTypeID
        self.selectedDeviceUID = settings.selectedDeviceUID
        self.meterSettings = settings.meterSettings //MeterSettings()
    }
    func updateCache() { settings.deviceCache = deviceCache }
    func loadCache() { self.deviceCache = settings.deviceCache }
    func clearCache() { settings.clearDeviceCache() }
}

// Translate for UserSettings
extension SessionData {
    
    var currentFile: URL {
        get {
            currentFolder
                .appendingPathComponent(currentFilename)
                .appendingPathExtension(selectedFileType.defaultExt)
        }
        set {
            currentFilename = newValue.deletingPathExtension().lastPathComponent
            currentFolder = newValue.deletingLastPathComponent()
        }
    }
    var selectedFileTypeID: AudioFileTypeID {
        get { selectedFileType.rawValue }
        set {
            let fileType = AudioFileType(rawValue: newValue)
            if fileTypeList.contains(fileType) {
                selectedFileType = fileType
            }
        }
    }
    var selectedDeviceUID: String? {
        get { selectedDevice?.uniqueID }
        set {
            if let newUID = newValue, let device = deviceData.keys.first(where: {
                $0.uniqueID == newUID
            }) {
                selectedDevice = device
                updateSelectedDevice()
            }
        }
    }
    var deviceCache: [String: [String: Any]] {
        get { deviceData.encode() }
        set {
            deviceData = AudioDeviceDict(encoded: newValue,
                                         useHidden: settings.showHiddenDevices,
                                         channelSettings: settings.channelEnabling)
            updateDeviceData()
        }
    }
}

// UserDefaults accessors
extension UserSettings {
    // User Settings
    var pauseEnabled: Bool {
        get { storage.bool(forKey: "pauseEnabled") }
        set { storage.set(newValue, forKey: "pauseEnabled") }
    }
    var showHiddenDevices: Bool {
        get { storage.bool(forKey: "showHiddenDevices") }
        set { storage.set(newValue, forKey: "showHiddenDevices") }
    }
    var useVirtualFormats: Bool {
        get { storage.bool(forKey: "useVirtualFormats") }
        set { storage.set(newValue, forKey: "useVirtualFormats") }
    }
    var channelEnabling: ChannelEnableSettings {
        get { ChannelEnableSettings(encoded: storage.dictionary(forKey: "channelEnabling")) }
        set { storage.set(newValue.encoded(), forKey: "channelEnabling") }
    }
    var meterSettings: MeterSettings {
        get { MeterSettings(encoded: storage.dictionary(forKey: "meterSettings")) }
        set { storage.set(newValue.encoded(), forKey: "meterSettings") }
    }
    
    // Session state
    var currentFile: URL {
        get { storage.url(forKey: "currentFile") ?? Self.defaultSettings["currentFile"]! as! URL }
        set { storage.set(newValue, forKey: "currentFile") }
    }
    var selectedFileTypeID: AudioFileTypeID {
        get { AudioFileTypeID(storage.integer(forKey: "selectedFileTypeID")) }
        set { storage.set(newValue, forKey: "selectedFileTypeID") }
    }
    var selectedDeviceUID: String? {
        get {
            let uid = storage.string(forKey: "selectedDeviceUID")
            return uid?.isEmpty ?? true ? nil : uid
        }
        set {
            if let uid = newValue {
                storage.set(uid, forKey: "selectedDeviceUID")
            }
        }
    }
    
    // Device Cache
    var deviceCache: [String: [String: Any]] {
        get { storage.dictionary(forKey: "deviceCache") as? [String: [String: Any]] ?? [:] }
        set { storage.set(newValue, forKey: "deviceCache") }
    }
    func clearDeviceCache() {
            storage.removeObject(forKey: "deviceCache")
    }
    
}




// Encoding for settings dictionaries

extension AudioChannel {
    func encode() -> Int { number * (enabled ? 1 : -1) }
    func decode(_ encoded: Int) -> Bool {
        if number == Int(encoded.magnitude) {
            enabled = encoded > 0
            return true
        }
        return false
    }
}
extension DeviceData {
    func encode() -> [String: [String: Any]] {
        var data = ["channelMap": channels.map { $0.encode() } as Any ]
        if let stream = selectedStream, let index = streams.firstIndex(of: stream) {
            data.updateValue(index as Any, forKey: "streamIndex")
        }
        return [device.uniqueID: data]
    }
    init?(encoded: [String:[String:Any]], deviceList: [AudioDevice] = [],
          channelSettings: ChannelEnableSettings = .disableAll) {
        
        // Set device
        guard let deviceUID = encoded.first?.key else { return nil }
        
        let devices = deviceList.count > 0 ? deviceList : AudioDevice.getAllDevices(.input, showHidden: true)
        guard let device = devices.first(where: { $0.uniqueID == deviceUID }) else { return nil }
        
        self.init(device, channelSettings: channelSettings)
        
        // Set stream
        guard let deviceDict = encoded[deviceUID] else { return }
        if let streamIndex = deviceDict["streamIndex"] as? Int, streams.count > streamIndex {
            selectedStream = streams[streamIndex]
        }
        update(channelSettings: channelSettings)
        
        // Set channels
        if channels.count > 0, let channelMap = deviceDict["channelMap"] as? [Int] {
            channelMap.forEach { encodedChannel in
                _ = channels.first(where: { $0.decode(encodedChannel) })
            }
        }
    }
}
extension AudioDeviceDict {
    func encode() -> [String: [String: Any]] {
        values.reduce([String: [String: Any]]()) { dict,entry in
            dict.merging(entry.encode()) { (_, new) in new }
        }
    }
    init(encoded: [String: [String: Any]], useHidden: Bool = true, channelSettings: ChannelEnableSettings = .disableAll ) {
        self.init(encoded: encoded,
                  deviceList: AudioDevice.getAllDevices(.input, showHidden: useHidden),
                  channelSettings: channelSettings)
    }
    init(encoded: [String: [String: Any]], deviceList: [AudioDevice], channelSettings: ChannelEnableSettings = .disableAll ) {
        self.init()
        encoded.forEach { entry in
            if let value = DeviceData(encoded: [entry.key: entry.value],
                                      deviceList: deviceList,
                                      channelSettings: channelSettings) {
                updateValue(value, forKey: value.device)
            }
        }
    }
}




// Convert settings structs to/from dictionaries

extension MeterSettings: KVCConvertible {
    init(encoded: [String : Any]) {
        encoded.forEach { (property, value) in
            switch property {
            case "refreshRateMS": if let value = value as? Double { refreshRateMS = value }
            case "minimumDB": if let value = value as? Float { minimumDB = value }
            case "displayNumber": if let value = value as? Bool { displayNumber = value }
            case "yellowThresholdDB": if let value = value as? Float { yellowThresholdDB = value }
            case "redThresholdDB": if let value = value as? Float { redThresholdDB = value }
            default: ()
            }
        }
    }
}
extension ChannelEnableSettings: KVCConvertible {
    init(encoded: [String : Any]) {
        encoded.forEach { (property, value) in
            switch property {
            case "enable": if let value = value as? Bool { enable = value }
            case "channels": if let value = value as? Int { channels = value }
            default: ()
            }
        }
    }
}


//
//  UserSettings.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/4/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation
import AudioToolbox.AudioFormat

// Singleton interface for UserDefaults
struct UserSettings {
    let storage: UserDefaults
    private init?() {
        guard let storage = UserDefaults(suiteName: Self.userSettingsDomain) else { return nil }
        storage.register(defaults: Self.defaultSettings)
        self.storage = storage
    }
    static let shared = UserSettings()
    
    // Developer Tweaks
    static let availableFileTypes: [AudioFileTypeID] = [ kAudioFileWAVEType, kAudioFileAIFFType, kAudioFileCAFType ]
    static let selectedFormat: AudioFormatID = kAudioFormatLinearPCM
    static let clockRefreshHz = 2.0
    static let clockGhostDimPercent = 5.0
    static let accentColor = RGBColor(red: 217, green: 223, blue: 33)
    static let editChannelNames = false
    static let timeoutSeconds: TimeInterval = 15.0
    static let fileOverwrite: Bool = false
    static let fileSafewrite: Bool = true
    static let bufferCapacity: Int = 512 * 8
    static let meterBufferSize: Int = 2
}

// Defaults
extension UserSettings {
    static var defaultSettings: [String: Any] = [
        // User Settings
        "pauseEnabled": true,
        "showHiddenDevices": false,
        "useVirtualFormats": false,
        "channelEnabling": ChannelEnableSettings().encoded(),
        "meterSettings": MeterSettings().encoded(),
        // Session state
        "currentFile": URL.home,
        "selectedFileTypeID": kAudioFileWAVEType,
        "selectedDeviceUID": "",
    ]
}

// Settings Data Types ( w/ default values )
struct ChannelEnableSettings {
    var enable: Bool = true, channels: Int = 2
    static let enableAll = ChannelEnableSettings(enable: false, channels: -1)
    static let disableAll = ChannelEnableSettings(enable: true, channels: -1)
}
struct MeterSettings {
    var enabled: Bool = true, refreshRateMS: Double = 500.0, displayNumber: Bool = false
    var minimumDB: Float = -60.0, yellowThresholdDB: Float = -20.0, redThresholdDB: Float = -3.0
    var barSpacing: CGFloat = 1, barWidth: CGFloat = 1
}
struct FormatSettings {
    var fileType: AudioFileType = UserSettings.startupFileType
    var formatID: AudioFormatID = kAudioFormatLinearPCM
    var useVirtual: Bool = false
}



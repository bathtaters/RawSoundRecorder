//
//  PreviewModels.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/4/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation

let testDeviceName = "Universal Audio Thunderbolt"
func testDevice(_ deviceList: [AudioDevice] = AudioDevice.getAllDevices(.input)) -> AudioDevice {
    deviceList.first(where: { $0.description == testDeviceName }) ?? (AudioDevice.defaultInput ?? deviceList[0])
}

func testChannel(_ num: Int = 1, device: AudioDevice = testDevice()) -> AudioChannel {
    let channels = chanListOf(device)
    if channels.count < 1 || num < 1 { callAlert(.fatal, "TestChannel not found!") }
    return channels[min(num, channels.count) - 1]
}

func chanListOf(_ device: AudioDevice) -> [AudioChannel] {
    return device.updatedChannelList(device.updatedStreamList(.input))
}
extension AudioDevice {
    static var defaultInput: AudioDevice? {
        if let deviceID = getDefaultDevice(.input) { return AudioDevice(deviceID) }
        return nil
    }
}

extension UserSettings {
    private init() {
        storage = UserDefaults(suiteName: UserDefaults.registrationDomain)!
        storage.register(defaults: Self.defaultSettings)
    }
    static let test = UserSettings()
}
extension SessionData {
    static let test = SessionData(.test)
}

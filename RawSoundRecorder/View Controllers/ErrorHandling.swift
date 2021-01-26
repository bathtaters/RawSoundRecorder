//
//  ErrorHandling.swift
//  RawSoundRecord
//
//  Created by Nick Chirumbolo on 11/5/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//
//    Error/Alert handling interface 

import Foundation

var alertLog = [String]()

func callAlert<R: FullReadoutConvertible>(_ level: AlertLevel, _ message: @autoclosure () -> String = "", _ object: R) {
    print("------------- \(R.self) Readout -------------\(object.readout)")
    callAlert(level, message())
}
func callAlert(_ level: AlertLevel, _ message: @autoclosure () -> String = "") {
    let timestamp = " [\(Date())]: "
    switch level {
    case .fatal:
        assert(false, "FATAL ERROR\(timestamp)\(message())")
    case .error:
        print("ERROR\(timestamp)\(message())")
    case .prerelease:
        print("Prerelease\(timestamp)\(message())")
    case .assert:
        assert(false, "PRERELEASE ERR\(timestamp)\(message())")
    case .warning:
        print("WARNING\(timestamp)\(message())")
    case .popup:
        print("Popup\(timestamp)\(message())")
    case .debug:
        print("Debug\(timestamp)\(message())")
    case .log:
        alertLog.append("\(timestamp)\(message())")
    }
}

enum AlertLevel {
    case fatal, error, prerelease, assert, warning, popup, debug, log
}

protocol FullReadoutConvertible {
    var readout: String { get }
}


// ---- Object Debug Descriptions ----- //

import struct AudioToolbox.AudioObjectPropertyAddress

extension AudioObjectPropertyAddress: CustomDebugStringConvertible {
    public var debugDescription: String { "\(mSelector), scope: \(mScope), element: \(mElement)" }
}

extension AudioDevice {
    public var debugDescription: String { self == AudioDevice.shared ? "SystemObject" : "AudioDevice[\(id)]" }
}

extension AudioStream {
    public var debugDescription: String { "\(parent.debugDescription).Stream[\(id)]" }
}

extension AudioChannel: CustomDebugStringConvertible {
    public var debugDescription: String { "\(stream.description) - Channel \(number)" }
}

extension SessionData {
    var allFormatsString: String {
        var str = [String]()
        if let recorder = recorderInterface {
            if let device = self.selectedDevice, let data = deviceData[device],
                let stream = data.selectedStream {
                if let format = stream.getFormat(virtual: false) {
                    str.append("Device (physical): \(format)  ")
                }
                if let format = stream.getFormat(virtual: true) {
                    str.append("Device (virtual): \(format)  ")
                }
            }
            if let format = recorder.meter.getFormat(ofDevice: true) {
                str.append("Meter (input): \(format)  ")
            }
            if let format = recorder.meter.getFormat(ofDevice: false) {
                str.append("Meter (meter): \(format)  ")
            }
            if let format = recorder.recorder.getFormat(ofDevice: true) {
                str.append("Recorder (input): \(format)  ")
            }
            if let format = recorder.recorder.getFormat(ofDevice: false) {
                str.append("Recorder (file): \(format)  ")
            }
        }
        return str.joined(separator: "\n")
    }
}

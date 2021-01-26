//
//  Strings.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/6/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation
import struct CoreAudioTypes.CoreAudioBaseTypes.AudioStreamBasicDescription

// UI constants
extension AudioChannel {
    static let defaultDescription = "Input Channel"
}

// Plist names
extension UserSettings {
    static let userSettingsDomain = "com.nice-sound.raw-sound-recorder.settings"
    //static let deviceCacheDomain = "com.nice-sound.raw-sound-recorder.cache"
}

// Audio Format Flags
extension FormatFlags: CustomStringConvertible {
    static let names: [FormatFlags : String] = [
        .float : "float", .bigEndian : "big-endian", .signed : "signed",
        .packed : "packed", .alignedHigh : "aligned-high",
        .nonInterleaved : "non-interleaved", .nonMixable : "non-mixable"
    ]
    var description: String {
        Self.names.filter { (key, name) in contains(key) }.map{ $0.value }.joined(separator: ", ")
    }
}

// Audio Format
extension AudioStreamBasicDescription: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        self == .init() ? "Does not exist" : "\(mSampleRate.kiloString)Hz/\(bitdepth.description)"
    }
    public var debugDescription: String {
        "Format: '\(mFormatID.decoded)' [\(mFormatID)] \(mSampleRate.kiloString)Hz \(mBitsPerChannel)-bit \(mChannelsPerFrame)-channel [\(mBytesPerFrame) B/F * \(mFramesPerPacket) F/P = \(mBytesPerPacket) B/P] \(FormatFlags(rawValue: mFormatFlags).description)\( mReserved == 0 ? "" : " Resverved:\(mReserved)" )"
    }
}
extension AudioBitDepth: CustomStringConvertible {
    var description: String { "\(depth)-bit \(type.rawValue)" }
}

// URLs
extension URL { var dirPath: String { path + "/" } }

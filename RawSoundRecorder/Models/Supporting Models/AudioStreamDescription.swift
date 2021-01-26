//
//  AudioStreamDescription.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/4/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation
import AudioToolbox


// Type definitions for AudioFormat
struct AudioBitDepth: Equatable, Hashable {
    var depth: Int
    var type: BitType
    enum BitType: String {
        case int = "Integer"
        case uint = "Unsigned Integer"
        case float = "Floating Point"
        static let allSorted: [Self] = [.int, .uint, .float]
    }
}
struct FormatFlags: OptionSet, Hashable {
    let rawValue: AudioFormatFlags
    
    static let float = FormatFlags(rawValue: kAudioFormatFlagIsFloat)
    static let bigEndian = FormatFlags(rawValue: kAudioFormatFlagIsBigEndian)
    static let signed = FormatFlags(rawValue: kAudioFormatFlagIsSignedInteger)
    static let packed = FormatFlags(rawValue: kAudioFormatFlagIsPacked)
    static let alignedHigh = FormatFlags(rawValue: kAudioFormatFlagIsAlignedHigh)
    static let nonInterleaved = FormatFlags(rawValue: kAudioFormatFlagIsNonInterleaved)
    static let nonMixable = FormatFlags(rawValue: kAudioFormatFlagIsNonMixable)
}
extension AudioStreamBasicDescription {
    enum FormatError: String { case valid, samplerate, bitdepth, formatID, formatFlags, reserved }
}



// Convienence setters for AudioFormat
extension AudioStreamBasicDescription {
    var bitdepth: AudioBitDepth {
        get { AudioBitDepth(from: self) }
        set {
            let old = mBitsPerChannel
            mBitsPerChannel = UInt32(newValue.depth)
            newValue.type.setFlags(&mFormatFlags)
            if old > 0 {
                mBytesPerFrame = mBytesPerFrame * mBitsPerChannel / old
                mBytesPerPacket = mBytesPerPacket * mBitsPerChannel / old }
        }
    }
    var channels: Int {
        get { Int(mChannelsPerFrame) }
        set {
            let old = mChannelsPerFrame
            mChannelsPerFrame = UInt32(newValue)
            if old > 0 {
                mBytesPerFrame = mBytesPerFrame * mChannelsPerFrame / old
                mBytesPerPacket = mBytesPerPacket * mChannelsPerFrame / old
            }
        }
    }
    var formatFlags: FormatFlags {
        get { FormatFlags(rawValue: mFormatFlags) }
        set { mFormatFlags = newValue.rawValue }
    }
    
    mutating func pack(framesPerPacket: Int = 1) {
        guard mFormatID == kAudioFormatLinearPCM else {
            callAlert(.error, "Illegal format '\(mFormatID.decoded)', can only record to LPCM.")
            return
        }
        guard mBitsPerChannel % 8 == 0 else {
            callAlert(.error, "Format is not valid, bit-rate (\(mBitsPerChannel)) must be divisible by 8.")
            return
        }
        
        mBytesPerFrame = mChannelsPerFrame * mBitsPerChannel / 8
        mFramesPerPacket = UInt32(framesPerPacket)
        mBytesPerPacket = mBytesPerFrame * mFramesPerPacket
        formatFlags.insert(.packed)
    }
    func packed(framesPerPacket: Int = 1) -> Self {
        var copy = self
        copy.pack(framesPerPacket: framesPerPacket)
        return copy
    }
}


// Error Check/Fix helpers //

// Translate valid array to various formats
extension AudioFileType {
    func bitDepths(_ formatID: AudioFormatID) -> [AudioBitDepth] {
        getFormats(formatID).map { AudioBitDepth(from: $0) }
    }
    func formatFlags(_ formatID: AudioFormatID, bitdepth: AudioBitDepth? = nil) -> [FormatFlags] {
        var validFormats = getFormats(formatID)
        if let matchesBitDepth = bitdepth {
            validFormats = validFormats.filter{ AudioBitDepth(from: $0) == matchesBitDepth }
        }
        return Array(Set(validFormats.map { $0.formatFlags.hidingBitDepthFlags }))
    }
    func isBigEndian(_ formatID: AudioFormatID, bitDepth: AudioBitDepth) -> Bool? {
        for fmt in getFormats(formatID) {
            if AudioBitDepth(from: fmt) == bitDepth {
                return fmt.formatFlags.contains(.bigEndian)
            }
        }
        return nil
    }
}
// Mask relevant flags
extension FormatFlags {
    private static let bitDepthMask: FormatFlags = [.float, .signed]
    var hidingBitDepthFlags: FormatFlags { self.subtracting(.bitDepthMask) }
    
    private static let validCheckMask: [FormatFlags] = [.alignedHigh, .packed, .bigEndian, .nonInterleaved, .nonMixable]
    var validCheckFlags: FormatFlags {
        get { intersection(FormatFlags(FormatFlags.validCheckMask)) }
        set { Self.validCheckMask.forEach{ set($0, to: newValue.contains($0)) } }
    }
}
// Find the most similar bitdepth in an array
extension Array where Element == AudioBitDepth {
    func nearestElement(bitdepth value: AudioBitDepth) -> AudioBitDepth? {
        var matches = [AudioBitDepth]()
        for bitType in AudioBitDepth.BitType.allSorted {
            let depths = filter({ $0.type == bitType }).map({ $0.depth })
            if let depthOfType = depths.nearestElement(value.depth) {
                matches.append(AudioBitDepth(depth: depthOfType, type: bitType))
            }
        }
        if let sameType = matches.first(where: { $0.type == value.type }) {
            if (sameType.depth - value.depth).magnitude < 8 { return sameType }
        }
        return matches.min { a, b in (a.depth - value.depth).magnitude < (b.depth - value.depth).magnitude }
    }
}



// Convienence inits for new types
extension AudioBitDepth.BitType {
    init(flags: FormatFlags) {
        if flags.contains(.float) { self = .float }
        else if flags.contains(.signed) { self = .int }
        else { self = .uint }
    }
    init(_ flagInt: UInt32) { self.init(flags: FormatFlags(rawValue: flagInt)) }
    init(from: AudioStreamBasicDescription) { self.init(from.mFormatFlags) }
}
extension AudioBitDepth {
    init(from: AudioStreamBasicDescription) {
        self.init(depth: Int(from.mBitsPerChannel), type: .init(from: from))
    }
}

// Auto-set flags based on BitDepth struct
extension AudioBitDepth.BitType {
    func setFlags(_ flags: inout FormatFlags) {
        switch self {
        case .float:
            flags.insert(.float)
            flags.insert(.signed)
        case .int:
            flags.remove(.float)
            flags.insert(.signed)
        case .uint:
            flags.remove(.float)
            flags.remove(.signed)
        }
    }
    func setFlags(_ flagInt: inout UInt32) {
        var flags = FormatFlags(rawValue: flagInt)
        setFlags(&flags)
        flagInt = flags.rawValue
    }
    func setFlags(_ audioFormat: inout AudioStreamBasicDescription) {
        setFlags(&(audioFormat.mFormatFlags))
    }
}





// Conformance

extension AudioStreamBasicDescription: Equatable {
    public static func == (lhs: Self,rhs: Self) -> Bool {
        return lhs.mFormatID == rhs.mFormatID && lhs.mSampleRate == rhs.mSampleRate && lhs.mBitsPerChannel == rhs.mBitsPerChannel && lhs.mChannelsPerFrame == rhs.mChannelsPerFrame && lhs.mBytesPerFrame == rhs.mBytesPerFrame && lhs.mBytesPerPacket == rhs.mBytesPerPacket && lhs.mFramesPerPacket == rhs.mFramesPerPacket && lhs.mFormatFlags == rhs.mFormatFlags
            // Ignore reserved field: && lhs.mReserved == rhs.mReserved
    }
}
extension AudioValueRange: Equatable {
    var isSingular: Bool { mMinimum == mMaximum }
    public static func == (lhs: AudioValueRange, rhs: AudioValueRange) -> Bool {
        return lhs.mMinimum == rhs.mMinimum && lhs.mMaximum == rhs.mMaximum
    }
}
extension AudioStreamRangedDescription: Equatable {
    var base: AudioStreamBasicDescription {
        //guard mSampleRateRange.isSingular else { return nil }
        if mFormat.mSampleRate == mSampleRateRange.mMinimum { return mFormat }
        
        var format = mFormat
        format.mSampleRate = mSampleRateRange.mMinimum
        return format
    }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.mFormat == rhs.mFormat && lhs.mSampleRateRange == rhs.mSampleRateRange
    }
}

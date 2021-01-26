//
//  FormatControllers.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/8/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation
import AudioToolbox


// Main setter/getter interface
extension SessionData {
    
    var formatIndex: Int {
        get {
            guard let format = getFormat() else { return 0 }
            return formatList.firstIndex(of: format) ?? 0
        }
        set {
            let list = formatList
            guard list.indices.contains(newValue) else {
                callAlert(.debug, "Cannot set format to invalid index: \(newValue)")
                return
            }
            setFormat(formatList[newValue])
            update()
        }
    }
    
    var formatList: [AudioStreamBasicDescription] {
        if let device = selectedDevice, let data = deviceData[device] {
            return data.formats
        }
        return []
    }
    
    func setFormat(_ format: AudioStreamBasicDescription) {
        guard let recorder = recorderInterface else {
            callAlert(.fatal, "Recorder is not loaded, please restart software.")
            return
        }
        if recorder.recorderEnabled {
            callAlert(.debug, "Cannot change format while recording."); return
        }
        if !formatList.contains(format) {
            callAlert(.debug, "Cannot change to unlisted format: \(format)"); return
        }
        if format == getFormat() {
            callAlert(.debug, "\(format) is already selected."); return
        }
        
        if let device = selectedDevice,
            let data = deviceData[device],
            let stream = data.selectedStream {
            status = .disabled
            let startTime = Date() // Timeout fix
            
            // Test if format is compatible with file
            var recordFormat = format
            if let err = recordFormat.validFix(selectedFileType) {
                callAlert(.debug, "Cannot select format, \(err) is not compatible with \(selectedFileType) file.")
                return
            }
            
            // Save meter state
            var metersEnabled = false
            if recorder.meter.status.isRecording { enableMeters(metersEnabled); metersEnabled.toggle() }
            
            defer {
                // Update AUHALs after all else is done
                recorder.setRecorderFormat(recordFormat)
                enableMeters(metersEnabled)
                status = .stop
            }
            
            let err = stream.setFormat(format, virtual: settings.useVirtualFormats)
            
            // Wait until format change is confirmed, or timeout
            while stream.getFormat(virtual: settings.useVirtualFormats) != format ||
                stream.getFormat(virtual: true) != recorder.recorder.getFormat(ofDevice: true) ||
                stream.getFormat(virtual: true) != recorder.meter.getFormat(ofDevice: true) {
                
                if Date().timeIntervalSince(startTime) > UserSettings.timeoutSeconds {
                    
                    callAlert(.fatal, "Time-out: waited \(UserSettings.timeoutSeconds) seconds for format to change. \(stream.getFormat(virtual: true) ?? .init()) != \(recorder.recorder.getFormat(ofDevice: true) ?? .init())")
                    
                    break
                }
            }
            
            if err == noErr { callAlert(.prerelease, "Format changed to: \(format.description)"); return }
            else {
                callAlert(.debug, "Error when attempting to change format to: \(format.debugDescription). Error code <\(err)>")
            }
        }
        callAlert(.error, "Cannot change format to \(format.description).")
    }
    
    func getFormat() -> AudioStreamBasicDescription? {
        if let device = selectedDevice,
            let data = deviceData[device],
            let stream = data.selectedStream {
            
            return stream.getFormat(virtual: settings.useVirtualFormats)
        }
        return nil
    }
}


// Filter format array based on fileType.formats() array
extension Array where Element == AudioStreamBasicDescription {
    func filterFormats(_ fileType: AudioFileType, formatID: AudioFormatID = kAudioFormatLinearPCM) -> [AudioStreamBasicDescription] {
        func bestDesc(_ descriptions: [AudioStreamBasicDescription], preferredFlags: FormatFlags = []) -> AudioStreamBasicDescription? {
            
            // Get best match if multiple similar descriptions
            var remaining = descriptions
            
            // First Method: Use the one with the most channels
            if let maxChannels = remaining.map({$0.channels}).max() {
                remaining = remaining.filter({$0.channels == maxChannels})
            }
            if remaining.count < 2 { return remaining.first }
            
            // Second Method: Use the one with the most matching flags
            for flag in AudioFileType.matchingFlagsOrdered {
                let matched = remaining.filter{$0.formatFlags.contains(flag) == preferredFlags.contains(flag)}
                if matched.count == 1 { return matched.first }
            }
            
            // Third Method: Use one with most similar flags
            return remaining.min(by: { a,b in
                a.formatFlags.differenceFactor(preferredFlags) < b.formatFlags.differenceFactor(preferredFlags)
            // Fourth Method: Use the first one
            }) ?? remaining.first
        }
        
        // Filter out non-matching bit-depths
        let allValids = fileType.getFormats(formatID)
        let matchingBitdepths = self.filter{ allValids.map({$0.bitdepth}).contains($0.bitdepth) }
        var result = [AudioStreamBasicDescription]()
        
        for i in matchingBitdepths.indices {
            // Skip ASBDs that were already compared previously
            if result.first(where: {$0 ~= matchingBitdepths[i]}) != nil { continue }
            
            // Build array of all similar ASBDs
            var similar = [matchingBitdepths[i]]
            for j in (i+1)..<matchingBitdepths.count {
                if matchingBitdepths[i] ~= matchingBitdepths[j] { similar.append(matchingBitdepths[j]) }
            }
            
            // If only 1 result, append that
            if similar.count == 1 { result.append(similar[0]); continue }
            
            // Append result of bestDesc(), using flags from original fileType.formats array
            let baseDescription = allValids.first(where: {$0.bitdepth == similar[0].bitdepth})
            if let bestDescription = bestDesc(similar, preferredFlags: baseDescription?.formatFlags ?? .init()) {
                result.append(bestDescription)
            }
        }
        return result.filter { $0 != AudioStreamBasicDescription() }
    }
}

// Match Device format to FileType format
extension AudioStreamBasicDescription {
    static let defaultSampleRate = 44100.0
    static let defaultFormatID = kAudioFormatLinearPCM

    func validCheck(_ fileType: AudioFileType) -> FormatError {
        var validFormats = fileType.getFormats(mFormatID)
        if validFormats.count < 1 { return .formatID }
        
        validFormats = validFormats.filter { $0.bitdepth == bitdepth }
        if validFormats.count < 1 { return .bitdepth }
        
        validFormats = validFormats.filter{ $0.formatFlags.validCheckFlags == formatFlags.validCheckFlags }
        if validFormats.count < 1 { return .formatFlags }
        
        if mSampleRate < 1.0 || !mSampleRate.isFinite { return .samplerate }
        
        if mReserved != .zero { return .reserved }
        
        return .valid
    }
    private mutating func validFix(_ fileType: AudioFileType, lastError: FormatError?) -> FormatError? {
        let formatError = validCheck(fileType)

        switch formatError {
        
        // It's all good
        case .valid: return nil
            
        // Force default sampleRate
        case .samplerate:
            callAlert(.debug, "\(mSampleRate.kiloString)Hz is an invalid samplerate. Set to default: \(Self.defaultSampleRate.kiloString)Hz.")
            mSampleRate = Self.defaultSampleRate
            
        // Force default formatID
        case .formatID:
            if lastError == .formatID {
                callAlert(.debug, "Audio FormatID '\(mFormatID.decoded)' has no valid formats for \(fileType.description) file type and it cannot be fixed.")
                return .formatID
            }
            callAlert(.debug, "Audio FormatID '\(mFormatID.decoded)' is invalid. Set to default: '\(Self.defaultFormatID.decoded)'.")
            mFormatID = Self.defaultFormatID
            
        // Find the nearest possible bitdepth
        case .bitdepth:
            if let nearestBitdepth = fileType.bitDepths(mFormatID).nearestElement(bitdepth: bitdepth) {
                callAlert(.debug, "\(bitdepth) is an invalid bit-depth. Changed to: \(nearestBitdepth).")
                bitdepth = nearestBitdepth
            } else {
                callAlert(.debug, "\(bitdepth) is an invalid bit-depth for this format (\(mFormatID.decoded)) and it cannot be fixed.")
                return .bitdepth
            }
            
        // Find the nearset possible format flags
        case .formatFlags:
            if let nearestFlags = fileType.formatFlags(mFormatID, bitdepth: bitdepth).nearestElement(flag: formatFlags.hidingBitDepthFlags) {
                callAlert(.debug, "[\(formatFlags.hidingBitDepthFlags)] is an invalid combination of flags. Changed to [\(nearestFlags)].")
                if nearestFlags.contains(.packed) && !formatFlags.contains(.packed) {
                    pack(framesPerPacket: Int(mFramesPerPacket))
                    callAlert(.debug, "Packing was enabled and related byte values updated.")
                }
                formatFlags.validCheckFlags = nearestFlags
            } else {
                callAlert(.debug, "[\(formatFlags.hidingBitDepthFlags)] is an invalid combination of flags for this format (\(mFormatID.decoded)) and it cannot be fixed.")
                return .formatFlags
            }
            
        // Clear reserved space
        case .reserved: mReserved = .zero
            
        }
        
        // Infinite recursion loop breaker
        if lastError == formatError {
            callAlert(.debug, "Format is not valid. Cannot fix \(formatError) error. (Recursive fix-loop was broken)")
            return formatError
        }
        // Recursively fix until validCheck returns "valid"
        return validFix(fileType, lastError: formatError)
    }
    mutating func validFix(_ fileType: AudioFileType) -> FormatError? { return validFix(fileType, lastError: nil) }
    func isValid(_ fileType: AudioFileType) -> Bool { validCheck(fileType) == .valid }
}


// Equivalent operator ~= for types that would match AudioFileType.formats() array
extension AudioStreamBasicDescription {
    static func ~=(lhs: Self, rhs: Self) -> Bool {
        return lhs.mSampleRate == rhs.mSampleRate && lhs.bitdepth == rhs.bitdepth && lhs.mFormatID == rhs.mFormatID
    }
}

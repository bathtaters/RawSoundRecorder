//
//  AudioMeter.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/9/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation
import AudioToolbox


// Meter accesors/operators
extension AudioRecorder {
    var meterEnabled: Bool { !meter.procData.peakData.isEmpty }
    
    func getPeakHold() -> [Float] { meter.procData.getPeakHold() }
    
    func meterStart() -> OSStatus {
        // Confirm there is a valid format
        guard let format = meter.getFormat(ofDevice: false) else {
            callAlert(.debug, "Cannot start meter without a format.")
            return noErr
        }
        
        // Enable peakData array
        if meter.procData.peakData.isEmpty { meter.procData.initPeakData(format.channels) }
        
        // Force a format match before starting
        while meter.getFormat(ofDevice: false) != meter.getFormat(ofDevice: true) { updateMeterFormat() }
        
        // Start AUHAL if it is stopped
        if meter.status == .stop {
            return meter.start()
        }
        return noErr
    }
    
    func meterStop() -> OSStatus {
        // Disable peakData array
        meter.procData.initPeakData()
        
        // Stop AUHAL
        return meter.stop()
    }
}


// Meter additional functions

extension AudioRecorder {
    
    // Update meter format
    @discardableResult func updateMeterFormat() -> OSStatus {
        var err = noErr
        
        // Stop meters
        let wasRunning = meter.status.isRecording
        if wasRunning {
            err = meterStop()
            guard err == noErr else {
                callAlert(.debug, "AUHAL cannot update format. Unable to stop meters <\(err)>")
                return err
            }
        }
        
        // Get device format
        guard let format = meter.getFormat(ofDevice: true) else {
            callAlert(.debug, "AUHAL cannot update format. Unable to get existing format <\(err)>")
            return kAudioUnitErr_InvalidPropertyValue
        }
                
        // Match output format
        err = meter.setFormat(format)
        if err != noErr { callAlert(.debug, "AUHAL error when updating meter format <\(err)>") }
        
        // Update peakData array
        if meterEnabled { meter.procData.initPeakData(format.channels) }
        
        // Restart
        if wasRunning {
            err = meterStart()
            if err != noErr { callAlert(.debug, "AUHAL error when restarting meters after format update <\(err)>") }
        }
        
        return err
    }
    
    
    // Get meter data from input data
    static func meterHandoff(_ procData: DeviceProcData, _ inFrames: inout UInt32) -> OSStatus {
        guard let readBuffer = procData.buffer.getLastRead() else {
            callAlert(.debug, "Meter buffer is empty: \(procData.buffer.debugDescription)")
            return kAudio_MemFullError
        }
        
        var newPeaks = procData.peakData
        var offset = 0
        var outFrames = UInt32.zero
        outerLoop: for buff in readBuffer {
            if let data = buff.mData {
                let frameCount = Int(buff.mDataByteSize) / MemoryLayout<Float32>.size
                let ptr = UnsafeMutableBufferPointer(start: data.assumingMemoryBound(to: Float32.self), count: frameCount)
                
                for (i,sample) in ptr.enumerated() {
                    let index = (i % Int(buff.mNumberChannels)) + offset
                    if outFrames == inFrames || index >= newPeaks.count { break outerLoop }
                    if newPeaks[index] < sample.magnitude {
                        newPeaks[index] = sample.magnitude
                    }
                    outFrames += 1
                }
            }
            offset += Int(buff.mNumberChannels)
        }
        procData.peakData = newPeaks
        inFrames = outFrames
        
        procData.buffer.releaseAll()
        return noErr
    }
}


// Peak-hold data accessors
extension DeviceProcData {
    func getPeakHold() -> [Float] { defer { clearPeakHold() }; return peakData }
    func clearPeakHold() { initPeakData(peakData.count) }
    func initPeakData(_ count: Int = 0) { peakData = [Float](repeating: .zero, count: count) }
}




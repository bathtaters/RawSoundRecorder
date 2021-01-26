//
//  AudioRecorder.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/13/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation
import AudioToolbox

// Base recorder/meter struct
class AudioRecorder {
    private var meterObject: AUHAL
    private var recorderObject: AUHAL
    private var file: AudioFile? = nil
    
    var meter: AUHAL { meterObject }
    var recorder: AUHAL { recorderObject }
    
    init?(device: AudioDevice, bufferSize: Int = 64) {
        guard let meter = AUHAL(device: device, direction: .input, ringBufferCount: UserSettings.meterBufferSize),
              let recorder = AUHAL(device: device, direction: .input, ringBufferCount: bufferSize) else {
            return nil
        }
        
        recorder.callback = AUHAL.basicInputProc
        meter.callback = AUHAL.basicInputProc
        meter.procData.safeBuffer = false
        
        self.recorderObject = recorder
        self.meterObject = meter
        
        recorderObject.handoff = recorderHandoff
        meterObject.handoff = AudioRecorder.meterHandoff
        
        updateDevice(device)
    }
}

// Recorder accessors/operators
extension AudioRecorder {
    var recorderEnabled: Bool { file != nil }
    
    func recordStart(_ file: AudioFile) -> OSStatus {
        
        guard recorder.status == .stop else {
            callAlert(.prerelease, "Cannot start recording while recorder status is \(recorder.status).")
            return noErr
        }
        
        // Assign file / enable recorder
        self.file = file
        
        // Start recorder AUHAL
        return recorder.start()
    }
    
    func recordStop() -> OSStatus {
        
        guard recorder.status.isRecording else {
            callAlert(.prerelease, "Cannot stop recording while recorder status is \(recorder.status).")
            return noErr
        }
        
        // Stop recorder
        var err = recorder.stop()
        
        guard err == noErr else {
            callAlert(.debug, "Error when attempting to stop recorder.")
            return err
        }
        
        // Close file / disable recorder
        err = file?.close() ?? kAudioFileInvalidFileError
        file = nil
        
        if err != noErr {
            callAlert(.debug, "Error when attempting to close file.")
        }
        
        return err
    }
    
    func recordPause() -> OSStatus { recorder.pause() }
    func recordResume() -> OSStatus { recorder.resume() }
    
}


// Update device/format, create file, handoff function
extension AudioRecorder {
    
    @discardableResult func updateDevice(_ device: AudioDevice) -> OSStatus {
        guard !recorder.status.isRecording else {
            callAlert(.debug, "Attempting to update device while recording.")
            return kAudioHardwareIllegalOperationError
        }
        var err = noErr
        
        // Stop meters
        let wasRunning = meter.status.isRecording
        if wasRunning {
            err = meterStop()
            guard err == noErr else {
                callAlert(.debug, "AUHAL cannot update device. Unable to stop meters <\(err)>")
                return err
            }
        }
        
        // Set device and update format
        if device != meter.device { meter.procData.clearPeakHold() }
        meter.device = device
        recorder.device = device
        
        err = updateMeterFormat()
        
        // Restart
        if wasRunning {
            err = meterStart()
            if err != noErr { callAlert(.debug, "AUHAL error when restarting meters after device update <\(err)>") }
        }
        return err
    }
    
    @discardableResult func setRecorderFormat(_ format: AudioStreamBasicDescription) -> OSStatus {
        guard !recorder.status.isRecording else {
            callAlert(.debug, "Attempting to update format while recording.")
            return kAudioHardwareIllegalOperationError
        }
        
        // Set recorder format
        let rErr = recorder.setFormat(format)
        if rErr != noErr {
            callAlert(.debug, "Error when attempting to set recorder format <\(rErr)>")
        }
        
        // Update meter format
        let mErr = updateMeterFormat()
        if mErr != noErr {
            callAlert(.debug, "Error when attempting to set meter format <\(mErr)>")
        }
        return rErr == noErr ? mErr : rErr
    }
    
    func recorderHandoff(_ procData: DeviceProcData, _ inFrames: inout UInt32) -> OSStatus {
        guard let readBuffer = procData.buffer.getRead() else {
            callAlert(.debug, "Recorder buffer is empty: \(procData.buffer.debugDescription)")
            return kAudio_MemFullError
        }
        
        let err = self.file?.writeBuffer(readBuffer.unsafeMutablePointer,
                                         frameCount: &inFrames) ?? kAudioFileInvalidFileError
        procData.buffer.releaseRead()
        return err
    }
}


//
//  TransportControllers.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/6/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation


extension SessionData {
    func pressRecord() {
        guard let recorder = recorderInterface else {
            callAlert(.fatal, "AudioEngine is not loaded, please restart software")
            status = .disabled
            return
        }
        
        switch status {
        case .record:
            guard settings.pauseEnabled else { return }
            status = .disabled
            if recorder.recordPause() == noErr { status = .pause }
            else { pressStop() }
        
        case .pause:
            status = .disabled
            if recorder.recordResume() == noErr { status = .record }
            else { pressStop() }
            
        case .stop:
            status = .disabled
            status = startRecorder()
            
        default: return
        }
    }
    func pressStop() {
        guard let recorder = recorderInterface else {
            callAlert(.fatal, "AudioEngine is not loaded, please restart software")
            status = .disabled
            return
        }
        guard status.isRecording else { return }
        
        status = .disabled
        _ = recorder.recordStop()
        status = .stop
    }
    
    func startRecorder() -> TransportState {
        guard let recorder = recorderInterface else { return .disabled }
        guard let file = createFile() else { return .stop }
        
        if recorder.recordStart(file) != noErr { pressStop(); return status }
        return .record
    }
    
    var recordButtonImage: String {
        switch status {
        case .record:
            return settings.pauseEnabled ? "Pause" : "RecordDown"
        default: return "RecordUp"
        }
        
    }
    var stopButtonImage: String {
        switch status {
        case .stop, .disabled: return "StopDown"
        default: return "StopUp"
        }
    }
    
}



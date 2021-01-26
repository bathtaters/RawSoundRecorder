//
//  MeterControllers.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/6/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation
import SwiftUI

extension SessionData {
    var meterUpdater: Timer {
        Timer.scheduledTimer(
            withTimeInterval: settings.meterSettings.refreshRateMS / 1000.0,
            repeats: true,
            block: updateMeters
        )
    }
    
    func updateMeters(_: Timer) {
        guard let recorder = recorderInterface, recorder.meterEnabled, recorder.meter.status.isRecording else { return }
        
        let peaks = recorder.getPeakHold()
        for c in channelList.indices {
            if c < peaks.count {
                withAnimation {
                    channelList[c].meterValue = powf(peaks[c],2) // Squaring floats returns scale of 0 > 1 TODO?
                }
            }
        }
    }
    
    func enableMeters(_ enable: Bool) {
        if let recorder = recorderInterface, enable != recorder.meter.status.isRecording {
            let err = enable ? recorder.meterStart() : recorder.meterStop()
            if err != noErr { callAlert(.debug, "Error \(enable ? "start" : "stopp")ing meters. <\(err)>") }
            else { callAlert(.prerelease, "\(enable ? "En" : "Dis")abled input meters.") }
        }
    }
}



// Calculate sizes for display
extension MeterSettings {
    var redFactor: CGFloat { 1.0 - redThresholdDB.dbToScale(minimumDB) }
    var greenFactor: CGFloat { yellowThresholdDB.dbToScale(minimumDB) }
    var yellowFactor: CGFloat { 1.0 - greenFactor - redFactor }
    var barCountFactor: CGFloat { barSpacing + barWidth }
}

// Meter transforms
extension Float {
    func percentToScale(_ minDB: Float) -> Float {
        if self > 1.0 { return 1 }
        
        let scale = 1 - log10(self) * 10 / minDB
        
        return max(scale, 0.0)
    }
    
    func dbToScale(_ minDB: Float) -> CGFloat {
        return CGFloat(1 - (self/minDB))
    }
    
    func percentToDB(_ minDB: Float = -1000) -> Float {
        if self > 1.0 { return 0.0 }
        
        let db = log10(self) * 10
        
        if db < minDB { return -.infinity }
        return db
    }
}

// 10^(db/10)

//
//  ClockController.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/7/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation
import struct SwiftUI.Color

// Start/Stop clock on record state change
extension ClockTimer {
    mutating func updateFrom(_ status: TransportState) {
        switch status {
        case .record:
            if !isPaused { reset() }
            start()
            
        case .pause:
            isPaused = true
            stop()
            
        case .stop:
            isPaused = false
            stop()
            
        default: return }
    }
}

// Redraw clock on a set timer
extension ClockView {
    var clockTimer: Timer {
        Timer.scheduledTimer(
            withTimeInterval: session.clockUpdateInterval,
            repeats: true,
            block: { _ in
                if self.session.status == .record { self.clock.update() }
                if self.session.status == .pause { self.isDimmed.toggle() }
                else if self.isDimmed { self.isDimmed = false }
            }
        )
    }
}



// Drawing Digit Segments
enum DigitLogic: Int, CaseIterable {
    case upper = 0, middle, lower
    case upperLeft, upperRight
    case lowerLeft, lowerRight
    
    private static let onDict: [Set<Int>] = [
        Set(arrayLiteral: 0,2,3,5,6,7,8,9), // upper = 0
        Set(arrayLiteral: 2,3,4,5,6,8,9), // middle
        Set(arrayLiteral: 0,2,3,5,6,8,9), // lower
        
        Set(arrayLiteral: 0,4,5,6,8,9), // upperLeft
        Set(arrayLiteral: 0,1,2,3,4,7,8,9), // upperRight
        
        Set(arrayLiteral: 0,2,6,8), // lowerLeft
        Set(arrayLiteral: 0,1,3,4,5,6,7,8,9) // lowerRight
        
    ]
    func on(_ forChar: Character) -> Bool {
        if let num = forChar.wholeNumberValue,
            rawValue < Self.onDict.count
            { return Self.onDict[rawValue].contains(num) }
        return false
    }
}



// Get settings
extension SessionData {
    var clockColor: Color { Color(rgb: UserSettings.accentColor) }
    var clockUpdateInterval: TimeInterval { 1.0 / UserSettings.clockRefreshHz }
    func clockOpacity(_ isDimmed: Bool) -> Double {
        return isDimmed ? UserSettings.clockGhostDimPercent / 100.0 : 1.0
    }
}
extension Color {
    init(rgb: RGBColor) {
        self.init(red: Double(rgb.red)/255.0,
                  green: Double(rgb.green)/255.0,
                  blue: Double(rgb.blue)/255.0
        )
    }
}

// Helpers
extension CGPoint {
    var flipped: CGPoint { .init(x: y, y: x) }
}


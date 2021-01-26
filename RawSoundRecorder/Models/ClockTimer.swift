//
//  ClockTimer.swift
//  RawSoundRecord
//
//  Created by Nick Chirumbolo on 11/20/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation

// Timer Struct
struct ClockTimer {
    private var updater = true
    private var startTime: TimeInterval? = nil
    private var storedTime: TimeInterval = 0.0
    private var currentTime: TimeInterval { Date().timeIntervalSinceReferenceDate }
    var value: Double {
        if let startTime = startTime { return storedTime + currentTime - startTime }
        return storedTime
    }
    var isPaused: Bool = false
}

// Timer base interface
extension ClockTimer {
    var isRunning: Bool { startTime != nil }
    mutating func update() { updater.toggle() }
    mutating func start() { startTime = currentTime }
    mutating func stop() {
        if let startTime = startTime { storedTime += currentTime - startTime }
        startTime = nil
    }
    mutating func reset() {
        startTime = nil
        storedTime = 0.0
    }
}

// Display methods
extension ClockTimer: CustomStringConvertible {
    static private let seperator = ":"
    private var array: [Int] {
        let seconds = Int(value.magnitude)
        return [seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60]
    }
    var description: String {
        array.map{String(format: "%02d",$0)}.joined(separator: Self.seperator)
    }
}

// Conformance for comparisons
extension ClockTimer: Comparable, Equatable {
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.value < rhs.value }
}

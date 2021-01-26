//
//  SoundDictionaries.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/4/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation
import typealias AudioToolbox.AudioObjectID

enum TransportState {
    case disabled, stop, record, pause
    
    static let startup = TransportState.stop
    var disableUI: Bool { get { self != .stop } set {} }
    var isRecording: Bool {
        self == .record || self == .pause
    }
}

enum AudioDirection: String, CaseIterable {
    case input, output
    var inverse: Self { self == .output ? .input : .output }
    var code: UInt32 { self == .output ? 0 : 1 }
    init?(_ code: UInt32) {
        if code == 1 { self = .input }
        else if code == 1 { self = .output }
        else { return nil }
    }
}





// Protocol for Dictionaries
protocol ConstantDictionary: CaseIterable, RawRepresentable, Equatable where RawValue == String {
    associatedtype ValueInt: FixedWidthInteger
    var value: ValueInt { get }
    var fourCC: String { get }
    init?(_ value: ValueInt)
    init?(_ fourCC: String)
}
extension ConstantDictionary {
    var fourCC: String { self.value.decoded }
    init?(_ value: ValueInt) {
        if let value = Self.allCases.first(where: { $0.value == value }) {
            self = value }
        else { return nil }
    }
    init?(_ fourCC: String) {
        if let encoded = ValueInt(fourCC: fourCC) { self.init(encoded) }
        else { return nil }
    }
}

// Protocol for Objects
protocol AudioObject: CustomStringConvertible, Hashable, Identifiable {
    var id: AudioObjectID { get }
}

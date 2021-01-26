//
//  Filenamer.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/6/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation

// Filenamer struct
struct Filename {
    var title: String
    var ext: String
    var suffix: FilenameSuffix
    var counter: UInt? { suffix > .nothing ? _counter : nil }
    
    private var _counter: UInt = 0
    private var timeStamp: Date = Date()
    
    init(title: String, ext: String, counterStart: UInt?, suffix: FilenameSuffix) {
        self.title = title
        self.ext = ext
        self.suffix = suffix
        if let counter = counterStart { setCounter(counter) }
    }
}

// Main Interface
extension Filename {
    mutating func updateTimeStamp(_ to: Date? = nil) { timeStamp = to ?? Date() }
    mutating func incCounter(by: Int = 1) {
        if suffix == .nothing { suffix = .counterOnly }
        _counter = UInt(max(Int(_counter) + by, 0))
    }
    mutating func setCounter(_ to: UInt? = nil) {
        if suffix == .nothing { suffix = .counterOnly }
        if let to = to { _counter = to }
    }
    
    init(_ title: String = "Untitled", ext: String = "", useCounter: Bool = true,
                     suffix: FilenameSuffix = .counterOnly) {
        self.init(title: title, ext: ext,
                  counterStart: (useCounter && suffix != .nothing ) ? Filename.defaultCounterStart : nil,
                  suffix: suffix)
    }
    static let defaultCounterStart: UInt = 1
}

// To/From Filename String
extension Filename {
    var date: String? {
        suffix.hasDate ? Filename.dateFormat.string(from: timeStamp) : nil
    }
    var time: String? {
        suffix.hasTime ? Filename.timeFormat.string(from: timeStamp) : nil
    }
    
    var extensionless: String {
        let cStr = counter == nil ? "" : "\(Filename.counterSeperator)\(String(format: "%0\(Filename.padCounterTo)d", counter!))"
        let dStr = date == nil ? "" : "\(Filename.dateTimeSeperator)\(date!)"
        let tStr = time == nil ? "" : "\(Filename.dateTimeSeperator)\(time!)"
        return "\(title)\(cStr)\(dStr)\(tStr)"
    }
    var filename: String {
        get { "\(extensionless).\(ext)" }
        set { updateFromFilename(newValue) }
    }
    mutating func filenameCurrentTime() -> String {
        if suffix > .counterOnly { updateTimeStamp() }
        return filename
    }
    
    mutating func updateFromFilename(_ filename: String, hasCounter: Bool? = nil) {
        var splitFn = Filename.regEx.matches(in: filename)
        if splitFn.count != 6 { return }
        
        var dDate: Date?
        var tDate: Date?
        
        // Get title
        if splitFn[1] != "" { title = splitFn[1] }
        splitFn.removeFirst(2)
        splitFn = splitFn.map{ $0.count > 1 ? String($0.suffix($0.count - 1)) : "" }
        
        // Determine if it has counter either using hint or logic
        var isCounter = true
        if let hasCounter = hasCounter { isCounter = hasCounter }
        else if splitFn[2] == "" && splitFn[0].count == Filename.dateFormat.count && Filename.dateFormat.date(from: splitFn[0]) != nil { isCounter = false }
        
        // Get (counter) + timeStampe
        if isCounter, let counter = UInt(splitFn[0]) {
            setCounter(counter)
            Filename.padCounterTo = splitFn[0].count
        }
        if splitFn[isCounter ? 1 : 0].count == Filename.dateFormat.count, let dStamp = Filename.dateFormat.date(from: splitFn[isCounter ? 1 : 0]) {
            dDate = dStamp; suffix = .date
        }
        if splitFn[isCounter ? 2 : 1].count == Filename.timeFormat.count, let tStamp = Filename.timeFormat.date(from: splitFn[isCounter ? 2 : 1]) {
            tDate = tStamp; suffix = .dateTime
        }
        if dDate != nil || tDate != nil {
            updateTimeStamp(timeStamp.setting(toDate: dDate, toTime: tDate))
        }
        
        // Get extension
        if splitFn[3] != "" { ext = splitFn[3] }
    }
    init(_ filename: String, hasCounter: Bool? = nil) {
        self.init(filename, suffix: .nothing)
        
        updateFromFilename(filename, hasCounter: hasCounter)
    }
}

// Reg Ex constants
extension Filename {
    static var regEx: NSRegularExpression {
        let counter = #"\#(counterSeperator)\d+"#
        let date = #"\#(dateTimeSeperator)\d{\#(dateFormat.string(from: Date()).count)}"#
        let time = #"\#(dateTimeSeperator)\d{\#(timeFormat.string(from: Date()).count)}"#
        let ext = #"\.\w*"#
        let anyNum = #"[\#(counterSeperator)\#(dateTimeSeperator)]\d+[\.\#(dateTimeSeperator)$]"#
        return NSRegularExpression(#"^((?:(?!\#(anyNum)|\#(ext)$).)*)(\#(counter))?(\#(date))?(\#(time))?(\#(ext))?$"#)!
    }
    static let counterSeperator = Character("_")
    static let dateTimeSeperator = Character("_")
    static var padCounterTo = 3
    static let dateFormat = DateFormatter("MMddyy")
    static let timeFormat = DateFormatter("HHmmss")
}

// Suffix enum
extension Filename {
    enum FilenameSuffix: Int, Comparable {
        case nothing = 0, counterOnly, date, dateTime
        var hasDate: Bool { self == .date || self == .dateTime }
        var hasTime: Bool { self == .dateTime }
        static func < (lhs: Filename.FilenameSuffix, rhs: Filename.FilenameSuffix) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

// Conformance
extension Filename: Equatable {
    static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.filename == rhs.filename
    }
}

// Changing just time/date of Date
extension Date {
    func setting(toDate date: Date? = nil, toTime time: Date? = nil) -> Date {
        if time == nil && date == nil { return self }
        let dFmt = "MM-dd-yyyy"
        let tFmt = "HH:mm:ss.SSSS"
        
        let dStr = DateFormatter(dFmt).string(from: date ?? self)
        let tStr = DateFormatter(tFmt).string(from: time ?? self)
        return DateFormatter("\(dFmt) 'at' \(tFmt)").date(from: "\(dStr) at \(tStr)")!
    }
}

// Get string length of DateFormatter
extension DateFormatter {
    var count: Int { self.string(from: Date()).count }
}

//
//  HelperExtensions.swift
//  RawSoundRecord
//
//  Created by Nick Chirumbolo on 11/6/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//
//   This includes any little utilities for standard types

import Foundation

// View Properties struct
struct ViewInfo {
    let size: CGSize
    let spacing: CGSize
    let offset: CGSize
}

// Range scaling
extension CGFloat {
    public func map(from: ClosedRange<CGFloat>, to: ClosedRange<CGFloat>) -> CGFloat {
        let result = ((self - from.lowerBound) / (from.upperBound - from.lowerBound)) * (to.upperBound - to.lowerBound) + to.lowerBound
        return result
    }
}

// Simplifying RegEx
extension NSRegularExpression {
    public func matches(in str: String, options: MatchingOptions = []) -> [String] {
        var result = [String]()
        let match = matches(in: str, options: options,
                            range: NSRange(str.startIndex..<str.endIndex, in: str))
        guard match.count > 0 else { return result }
        for i in 0..<match[0].numberOfRanges {
            if let range = Range<String.Index>(match[0].range(at: i), in: str) {
                result.append(String(str[range]))
            } else { result.append("") }
        }
        return result
    }
    public convenience init?(_ pattern: String) {
        do { try self.init(pattern: pattern) }
        catch {
            assert(false,"Illegal regular expression: \(pattern).")
            return nil
        }
    }
}

// Add string <-> binary decoding/encoding
extension FixedWidthInteger {
    public var decoded: String {
        return String(bytes: withUnsafeBytes(of: self.bigEndian, Array.init), encoding: .utf8) ?? ""
    }
    public init?(fourCC: String) {
        guard fourCC.count <= Self.bitWidth/8 else {
            callAlert(.debug, "String is too long for encoding: '\(fourCC)' [\(fourCC.count) should be <= \(Self.bitWidth/8)]")
            return nil
        }
        self = fourCC.utf8.reduce(Self(0), { sum,next in (sum << 8) + Self(next) })
    }
}

// Capitalization for enum strings & variable names
extension String {
    var formatedVarName: String { prefix(1).uppercased() + dropFirst() }
}

// Get nearest value in a stridable collection
extension Collection where Element: Strideable {
    public func nearestElement(_ value: Element, roundUp: Bool = true) -> Element? {
        let sorted = self.sorted()
        
        switch sorted.firstIndex(where: { $0 > value }) {
        case nil: return sorted.last
        case 0: return sorted.first
        case let i:
            let lower = sorted[i! - 1].distance(to: value).magnitude
            let upper = sorted[i!].distance(to: value).magnitude
            
            if lower > upper || (lower == upper && roundUp) { return sorted[i!] }
            else { return sorted[i! - 1] }
        }
    }
}

// Find the closest match in an OptionSet collection
extension Collection where Element: OptionSet, Element.RawValue: FixedWidthInteger {
    func nearestElement(flag value: Element) -> Element? {
        var matches = map { ($0, value.intersection($0).count, value.symmetricDifference($0).count) }
        
        // Find flags w/ max total of: similarFlags - differentFlags
        guard let maxElem = matches.max(by: {a,b in a.1 - a.2 < b.1 - b.2 }) else { return nil }
        let maxFactor = maxElem.1 - maxElem.2
        matches = matches.filter{ $0.1 - $0.2 == maxFactor }
        guard matches.count > 1 else { return matches.first?.0 }
        
        // If more than 1, find the remaining flag with the least differences
        guard let minDiff = matches.min(by: {a,b in a.2 < b.2}) else { return nil }
        matches = matches.filter{ $0.2 == minDiff.2 }
        guard matches.count > 1 else { return matches.first?.0 }
        
        // If more than 1, find the remaining flag with the lowest rawValue
        return matches.map{ $0.0 }.min(by: {a,b in a.rawValue < b.rawValue})
    }
}

// Update object array with new array while retaining original objects
extension Array where Element: Equatable {
    public mutating func update(_ newValues: [Element]) {
        removeAll(where: { !newValues.contains($0) })
        append(contentsOf: newValues.filter({ !self.contains($0) }))
    }
    public func updated(_ newValues: [Element]) -> Self {
        var result = self
        result.update(newValues)
        return result
    }
}

// File/Folder helpers
extension URL {
    public static let home = FileManager.default.homeDirectoryForCurrentUser
    
    public func exists(andIsDir: Bool = false) -> Bool {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
            return andIsDir ? isDir.boolValue : true
        }
        return false
    }
    public func isDir() -> Bool { exists(andIsDir: true) }
    
    public init?(fromPath: String, mustBeDir: Bool = false) {
        guard fromPath.count > 0 else { return nil }
        
        var urlStr = fromPath.replacingOccurrences(of: "~", with: URL.home.path) // Home shortening
        urlStr.removeAll(where: {$0 == Character("\\")}) // Terminal escapes
        
        self.init(fileURLWithPath: urlStr, isDirectory: mustBeDir)
        
        guard self.exists(andIsDir: mustBeDir) else {
            callAlert(.debug, "Path does not exist \(mustBeDir ? " or is not a folder" : ""): \(self.path)")
            return nil
        }
    }
    
}

// Add GMT TimeZone
extension TimeZone { public static let GMT = TimeZone(secondsFromGMT: 0)! }
// Simple DateFormatter init
extension DateFormatter {
    public convenience init(_ formatString: String, timeZone: TimeZone = .current) {
        self.init()
        self.timeZone = timeZone
        dateFormat = formatString
    }
}

// Floating point extensions
extension Double {
    // Get string in "kilo-[whatever]" with estimated rounding
    var kiloString: String {
        var suffix = "k", num = self
        if num < 1000.0 { num = num * 1000.0; suffix = "" }
        
        let dCount = (1...4).reversed().first(where: {
            num.truncatingRemainder(dividingBy: pow(10.0, 4.0 - Double($0))) != 0.0
        })
        return String(format: "%.\(dCount ?? 0)f", (num / 1000.0)) + suffix
    }
}

// Simple KVC interface
protocol KVCConvertible {
    func encoded() -> [String: Any]
    init(encoded: [String: Any])
    init()
}
extension KVCConvertible {
    func encoded() -> [String: Any] {
        let mirror = Mirror(reflecting: self)
        let dict = Dictionary(uniqueKeysWithValues: mirror.children.lazy.map({ (label:String?, value:Any) -> (String, Any)? in
            guard let label = label else { return nil }
            if let value = value as? KVCConvertible { return (label, value.encoded()) }
            return (label, value)
        }).compactMap { $0 })
        return dict
    }
    init(encoded: [String: Any]?) {
        if let encoded = encoded { self.init(encoded: encoded) }
        else { self.init() }
    }
}

// Helpers for OptionSet to work with audio flags
extension OptionSet where RawValue: FixedWidthInteger {
    mutating func set(_ member: Element, to: Bool = true) {
        if to { insert(member) }
        else { remove(member) }
    }
    
    var count: Int { rawValue.nonzeroBitCount }
    
    func differenceFactor(_ other: Self) -> Int {
        symmetricDifference(other).count - intersection(other).count
    }
}






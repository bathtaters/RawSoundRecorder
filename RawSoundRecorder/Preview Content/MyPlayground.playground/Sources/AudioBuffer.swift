//
//  AudioBuffer.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 1/11/21.
//  Copyright © 2021 Nice Sound. All rights reserved.
//

import Foundation
import AudioToolbox

public struct AudioRingBuffer: CustomDebugStringConvertible {
    public typealias Element = UInt32
    
    private var buffer: [Element] = []
    private var writeIndex: Int = -1
    private var readIndex: Int = -1
    
    public init(_ count: Int) {
        reset(count: count)
    }
    
    public var debugDescription: String { buffer.debugDescription + " <read:\(readIndex), write:\(writeIndex)>" }
}

extension AudioRingBuffer {
    // Data-specific methods
    public mutating func reset(count: Int) {
        if writeIndex >= 0 && readIndex >= 0 { free() }
        if count > 0 {
            writeIndex = 0
            readIndex = 0
        }
        buffer = .init(repeating: UInt32.max, count: count)
    }
    
    public mutating func free() {
        writeIndex = -1
        readIndex = -1
        guard count > 0 else { return }
        //buffer[0].unsafeMutablePointer.deallocate()
        buffer = []
    }
}

extension AudioRingBuffer {
    // Generic ring buffer methods
    
    public var count: Int { buffer.count }
    
    public var toWrite: Int { buffer.count - toRead }
    public var canWrite: Bool { writeIndex < 0 ? false : toWrite != 0 }
    
    public var toRead: Int { writeIndex - readIndex }
    public var canRead: Bool { readIndex < 0 ? false : toRead != 0 }
    
    public mutating func writeNext(_ data: Element) -> Bool {
        guard canWrite else { return false }
        buffer[writeIndex % buffer.count] = data
        writeIndex += 1
        return true
    }
    
    public mutating func readNext(advance: Bool = true) -> Element? {
        guard canRead else { return nil }
        let result = buffer[readIndex % buffer.count]
        if advance { readIndex += 1 }
        return result
    }
    
    public mutating func readLast() -> Element? {
        guard canRead else { return nil }
        readIndex = writeIndex - 1
        return readNext()
    }
    
}

//
//  AudioBuffer.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 1/11/21.
//  Copyright © 2021 Nice Sound. All rights reserved.
//

import Foundation
import AudioToolbox

public struct AudioRingBuffer {
    public typealias Element = UnsafeMutableAudioBufferListPointer
    
    private var buffer: [Element] = []
    private var writeIndex: Int = -1
    private var lockIndex: Int = -1
    private var readIndex: Int = -1
    
    public init(_ count: Int, _ bufferSize: Int) {
        reset(count: count, bufferSize: bufferSize)
    }
}

extension AudioRingBuffer {
    public mutating func reset(count: Int, bufferSize: Int) {
        if writeIndex >= 0 && readIndex >= 0 { free() }
        if count > 0 {
            writeIndex = 0
            readIndex = 0
            lockIndex = 0
        }
        buffer = .init(repeating: AudioBufferList.allocate(maximumBuffers: bufferSize),
                       count: count)
    }
    
    public mutating func free() {
        writeIndex = -1
        readIndex = -1
        lockIndex = -1
        guard count > 0 else { return }
        buffer[0].unsafeMutablePointer.deallocate()
        buffer = []
    }
}

extension AudioRingBuffer {
    public var count: Int { buffer.count }
    
    private var toWrite: Int { count - writeIndex + readIndex }
    public var canWrite: Bool { writeIndex == -1 ? false : toWrite != 0 }
    public var canCommit: Bool { lockIndex != writeIndex }
    
    private var toRead: Int { lockIndex - readIndex }
    public var canRead: Bool { readIndex == -1 ? false : toRead != 0 }
    
    
    // Pointer specific write implementation
    public mutating func getWritePtr(force: Bool = false) -> Element? {
        guard force || canWrite else { return nil }
        let result = buffer[writeIndex % buffer.count]
        writeIndex += 1
        return result
    }
    @discardableResult public mutating func commitWrite() -> Bool {
        if canCommit { lockIndex += 1; return true }
        return false
    }
    
    
    // Generic ring buffer reader
    public func getRead() -> Element? {
        guard canRead else { return nil }
        return buffer[readIndex % buffer.count]
    }
    @discardableResult public mutating func releaseRead() -> Bool {
        if canRead { readIndex += 1; return true }
        return false
    }
    
    
    // Read latest entry and release all data (Works on generic ring buffer)
    public func getLastRead() -> Element? {
        guard canRead else { return nil }
        return buffer[(writeIndex - 1) % buffer.count]
    }
    @discardableResult public mutating func releaseAll() -> Bool {
        if canRead { readIndex = writeIndex - 1; return true }
        return false
    }
}

// Debug printout
extension AudioRingBuffer: CustomDebugStringConvertible {
    public var debugDescription: String { "Buffer(size: \(self.count), read: \(readIndex), write: \(writeIndex)>" }
}

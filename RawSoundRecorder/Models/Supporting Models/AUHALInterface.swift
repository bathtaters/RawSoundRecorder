//
//  AUHALInterface.swift
//  RawSoundRecorder
//
//  Created by Nick Chirumbolo on 12/9/20.
//  Copyright © 2020 Nice Sound. All rights reserved.
//

import Foundation
import AudioToolbox

// AUHAL-specific objects
// DeviceProcHandoff( AudioBuffer ptr [do NOT release], inFrameCount [update to outFrameCount])
typealias DeviceProcHandoff = (DeviceProcData, inout UInt32)->(OSStatus)

class DeviceProcData {
    var unit: AudioComponentInstance
    var buffer: AudioRingBuffer
    var handoff: DeviceProcHandoff?
    var currentSample: Float64? = nil
    var peakData: [Float32] = []
    var safeBuffer: Bool = true
    private lazy var handoffQueue: DispatchQueue = {
        DispatchQueue(label: "HandoffThread", qos: safeBuffer ? .userInteractive : .utility)
    }()
    //private let handoffQueue = DispatchQueue(label: "HandoffThread", qos: .userInteractive)
    fileprivate let handoffGroup = DispatchGroup()
    
    init(_ unit: AudioComponentInstance, bufferCount: Int,
         bufferSize: Int = 0, handoff: DeviceProcHandoff?) {
        self.unit = unit
        self.buffer = .init(bufferCount, bufferSize)
        self.handoff = handoff
    }
    deinit { awaitThread(); buffer.free() }
}

struct AudioChannelMap: ExpressibleByArrayLiteral {
    var array: [Int32]
    init(_ array: [Int32] = []) { self.array = array }
    init(arrayLiteral elements: Int32...) { self.array = elements }
    init(outputSize: Int, cleared: Bool = false) {
        self.array = [Int32](repeating: Self.noSource, count: outputSize)
        if !cleared { self.array = self.array.enumerated().map{Int32($0.offset)} }
    }
    static let noSource = Int32(-1)
}




// AUHAL base class
class AUHAL {
    private let auhal: AudioComponentInstance
    private var setDevice: AudioDevice!
    private var setStatus = TransportState.disabled
    
    var callback: AURenderCallback? = nil
    var procData: DeviceProcData
    
    init?(device: AudioDevice, direction: AudioDirection, ringBufferCount: Int = 8) {
        guard let auhalComponent = AudioComponent.auHAL else {
            callAlert(.debug, "AUHAL not found."); return nil }
        guard let auhal = AudioComponentInstance(component: auhalComponent) else {
            callAlert(.debug, "Error instantiating AUHAL."); return nil }
        
        self.auhal = auhal
        self.procData = .init(auhal, bufferCount: ringBufferCount)
        
        let err = setDirection(direction)
        guard err == noErr else { callAlert(.debug, "Could not set \(device) AUHAL as \(direction) <\(err)>"); return nil }
        
        self.device = device
        guard setDevice != nil else { callAlert(.debug, "Failed to start meters. Could not set \(device) as AUHAL device."); return nil }
        
        setStatus = .stop
    }
    deinit {
        if status == .record || status == .pause { _ = stop() }
        setStatus = .disabled
        onDeinit()
        AudioComponentInstanceDispose(auhal)
    }


// AUHAL main interface
    
    func start() -> OSStatus {
        guard status == .stop else {
            callAlert(.debug, "Cannot start \(device) AUHAL from \(status).")
            return kAudioUnitErr_CannotDoInCurrentContext // Rolled while not stopped
        }
        
        while isRunning ?? false {
            AudioOutputUnitStop(auhal)
        }
        
        var err = setCallback()
        if err != noErr { callAlert(.debug, "\(device) AUHAL error setting callback <\(err)>. Unable to start."); return err }
        
        err = AudioUnitInitialize(auhal)
        if err != noErr { callAlert(.debug, "\(device) AUHAL error initializing <\(err)>. Unable to start."); return err }

        err = AudioOutputUnitStart(auhal)
        if err == noErr { setStatus = .record }
        else {
            AudioUnitUninitialize(auhal)
            callAlert(.debug, "\(device) AUHAL error starting <\(err)>.")
        }
        return err
    }
    
    func pause() -> OSStatus {
        guard status == .record else {
            callAlert(.debug, "Cannot pause \(device) AUHAL from \(status).")
            return kAudioUnitErr_CannotDoInCurrentContext // Paused while not rolling
        }
        
        let err = AudioOutputUnitStop(auhal)
        if err == noErr { setStatus = .pause }
        else { callAlert(.debug, "\(device) AUHAL error pausing <\(err)>.") }
        return err
    }
    
    func resume() -> OSStatus {
        guard status == .pause else {
            callAlert(.debug, "Cannot resume \(device) AUHAL from \(status).")
            return kAudioUnitErr_CannotDoInCurrentContext // Resumed while not paused
        }
        
        let err = AudioOutputUnitStart(auhal)
        if err == noErr { setStatus = .record }
        else { callAlert(.debug, "\(device) AUHAL error resuming <\(err)>.") }
        return err
    }
    
    func stop() -> OSStatus {
        guard status.isRecording else {
            callAlert(.debug, "Cannot stop \(device) AUHAL from \(status).")
            return kAudioUnitErr_CannotDoInCurrentContext // Stopped while not rolling/paused
        }
        
        var err = noErr
        if status == .record {
            err = AudioOutputUnitStop(auhal)
            if procData.safeBuffer { procData.awaitThread() }
            guard err == noErr else {
                callAlert(.debug, "\(device) AUHAL error stopping <\(err)>.")
                return err
            }
        }
        
        setStatus = .pause
        err = AudioUnitUninitialize(auhal)
        if err == noErr { setStatus = .stop }
        else { callAlert(.debug, "\(device) AUHAL error uninitializing <\(err)>.") }
        return err
    }
    
    func onDeinit() {
        () // Abstract Function: Runs before deinit
    }
    
}

// Pre-defined input/output processors
extension AUHAL {
    static let basicInputProc: AURenderCallback = { (inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
        let procData = Unmanaged<DeviceProcData>.fromOpaque(inRefCon).takeUnretainedValue()
        
        guard let nextBuffer = procData.buffer.getWritePtr(force: !procData.safeBuffer) else {
            callAlert(.debug, "AUHAL: Audio buffer is full: \(procData.buffer.debugDescription)")
            return kAudio_MemFullError
        }
        var err = AudioUnitRender(procData.unit, ioActionFlags, inTimeStamp,
                                      inBusNumber, inNumberFrames,
                                      nextBuffer.unsafeMutablePointer )
            
        // Check for dropped frames
        if let sample = procData.currentSample, inTimeStamp.pointee.mSampleTime > sample {
            callAlert(.debug, "AUHAL: Render dropped \(inTimeStamp.pointee.mSampleTime - sample) frames.")
        }
        procData.currentSample = inTimeStamp.pointee.mSampleTime + Float64(inNumberFrames)
        
        guard err == noErr else {
            callAlert(.debug, "AUHAL: Render error code <\(err)>")
            return err
        }
        
        procData.buffer.commitWrite()
        
        // Run handoff function
        if let handoff = procData.handoff {
            procData.thread {
                var frames = inNumberFrames
                err = handoff(procData, &frames)
                if frames != inNumberFrames {
                    callAlert(.debug, "AUHAL: Handoff dropped/missing \(inNumberFrames.distance(to: frames)) frames.")
                }
                if err != noErr { callAlert(.debug, "AUHAL: Handoff error code <\(err)>") }
            }
        }
        return err
    }
}


// AUHAL property accessors
extension AUHAL {
    
    var status: TransportState { setStatus }
    
    var handoff: DeviceProcHandoff? {
        get { procData.handoff }
        set { if let handoff = newValue { procData.handoff = handoff } }
    }
    
    var device: AudioDevice {
        get { setDevice }
        set {
            var value = newValue.id

            let err = AudioUnitSetProperty(auhal,
                                           kAudioOutputUnitProperty_CurrentDevice,
                                           kAudioUnitScope_Global,
                                           0, &value,
                                           UInt32(MemoryLayout.size(ofValue: value)))
            
            if err == noErr { self.setDevice = newValue }
            else { callAlert(.debug, "AUHAL change device to: \(newValue) error code <\(err)>") }
        }
    }
    
    var isRunning: Bool? {
        var value = UInt32.max
        var size = UInt32(MemoryLayout.size(ofValue: value))
        
        let err = AudioUnitGetProperty(auhal,
                                       kAudioOutputUnitProperty_IsRunning,
                                       kAudioUnitScope_Global,
                                       0, &value, &size)
        if err != noErr {
            callAlert(.debug, "\(device) AUHAL: isRunning error code <\(err)>")
        }
        return value == .max ? nil : value != 0
    }
    
    func getDirection() -> AudioDirection? {
        var value = UInt32.max
        var size = UInt32(MemoryLayout.size(ofValue: value))
        
        // Ask if Output is enabled
        var err = AudioUnitGetProperty(auhal,
                                       kAudioOutputUnitProperty_EnableIO,
                                       AudioDirection.output.auScope(),
                                       AudioDirection.output.auBus,
                                       &value, &size)
        if err != noErr {
            callAlert(.debug, "\(device) AUHAL: getDirection error code <\(err)>")
        }
        guard value != UInt32.max else { return nil } // no value
        let outputEnabled = value != 0
        
        // Ask if Input is enabled
        err = AudioUnitGetProperty(auhal,
                                   kAudioOutputUnitProperty_EnableIO,
                                   AudioDirection.input.auScope(),
                                   AudioDirection.input.auBus,
                                   &value, &size)
        if err != noErr {
            callAlert(.debug, "\(device) AUHAL: getDirection error code <\(err)>")
        }
        guard value != UInt32.max else { return nil } // no value
        
        // Determine device direction
        if value != 0 && !outputEnabled { return .input }
        if value == 0 && outputEnabled { return .output }
        return nil
    }
    
    func setDirection(_ to: AudioDirection = .output) -> OSStatus {
        let size = UInt32(MemoryLayout<UInt32>.size)
        
        // Enable selected direction
        var value: UInt32 = 1 // Enable
        var err = AudioUnitSetProperty(auhal,
                                       kAudioOutputUnitProperty_EnableIO,
                                       to.auScope(),
                                       to.auBus,
                                       &value, size)
        guard err == noErr else { return err }
        
        // Disable opposite direction
        value = 0 // Disable
        err = AudioUnitSetProperty(auhal,
                                   kAudioOutputUnitProperty_EnableIO,
                                   to.inverse.auScope(),
                                   to.inverse.auBus,
                                   &value, size)
        return err
    }
    
    
    func getFormat(ofDevice: Bool = true) -> AudioStreamBasicDescription? {
        guard let direction = getDirection() else {
            callAlert(.debug, "Cannot get \(device) AUHAL format because direction is not set.")
            return nil
        }
        
        var value = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout.size(ofValue: value))
        
        let err = AudioUnitGetProperty(auhal,
                                       kAudioUnitProperty_StreamFormat,
                                       direction.auScope(ofDevice: ofDevice),
                                       direction.auBus,
                                       &value, &size)
        if err != noErr {
            callAlert(.debug, "\(device) AUHAL: getFormat error code <\(err)>")
        }
        return value == AudioStreamBasicDescription() ? nil : value
    }
    
    func setFormat(_ to: AudioStreamBasicDescription) -> OSStatus {
        guard let direction = getDirection() else {
            callAlert(.debug, "Cannot set \(device) AUHAL format because direction is not set.")
            return kAudioUnitErr_InvalidElement
        }
        
        var value = to
        let err = AudioUnitSetProperty(auhal,
                                       kAudioUnitProperty_StreamFormat,
                                       direction.auScope(ofDevice: false),
                                       direction.auBus,
                                       &value,
                                       UInt32(MemoryLayout.size(ofValue: value)))
        return err
    }
    
    func getChannelMap() -> AudioChannelMap? {
        guard let direction = getDirection() else {
            callAlert(.debug, "Cannot get \(device) AUHAL channel map because direction is not set.")
            return nil
        }
        
        // Get size of stored map
        var size = UInt32(0)
        var err = AudioUnitGetPropertyInfo(auhal,
                                           kAudioOutputUnitProperty_ChannelMap,
                                           direction.auScope(ofDevice: false),
                                           direction.auBus,
                                           &size, nil)
        guard err == noErr else {
            callAlert(.debug, "\(device) AUHAL: getChannelMap.getSize error code <\(err)>")
            return nil
        }
        
        // Get map
        var value = [AudioChannelMap.ArrayLiteralElement](
            repeating: AudioChannelMap.noSource,
            count: Int((Double(size)/Double(MemoryLayout<Int32>.size)).rounded(.up))
        )
        err = AudioUnitGetProperty(auhal,
                                   kAudioOutputUnitProperty_ChannelMap,
                                   direction.auScope(ofDevice: false),
                                   direction.auBus,
                                   &value, &size)
        
        guard err == noErr else {
            callAlert(.debug, "\(device) AUHAL: getChannelMap error code <\(err)>")
            return nil
        }
        return AudioChannelMap(value)
    }
    
    func setChannelMap(_ to: AudioChannelMap) -> OSStatus {
        guard let direction = getDirection() else {
            callAlert(.debug, "Cannot set \(device) AUHAL channel map because direction is not set.")
            return kAudioUnitErr_InvalidElement
        }
        
        var value = to.array
        return AudioUnitSetProperty(auhal,
                                    kAudioOutputUnitProperty_ChannelMap,
                                    direction.auScope(ofDevice: false),
                                    direction.auBus,
                                    &value,
                                    UInt32(value.count * MemoryLayout<AudioChannelMap.ArrayLiteralElement>.size))
    }
    
    private func setCallback() -> OSStatus {
        guard let throughFormat = getFormat(ofDevice: false) else {
            callAlert(.debug, "\(device) AUHAL cannot set callback because software-side format is not set.")
            return kAudioUnitErr_InvalidPropertyValue
        }
        
        // Setup processor data object
        procData.updateFormat(throughFormat)
        
        // Set processor callback function
        var value = AURenderCallbackStruct(
            inputProc: callback,
            inputProcRefCon: UnsafeMutableRawPointer(Unmanaged<DeviceProcData>.passUnretained(procData).toOpaque())
        )
        return AudioUnitSetProperty(auhal,
                                    kAudioOutputUnitProperty_SetInputCallback,
                                    kAudioUnitScope_Global,
                                    0, &value,
                                    UInt32(MemoryLayout.size(ofValue: value)))
    }
    
}



// ---- Helper extensions for AUHAL ---- //

// Set ProcData using audio format
extension DeviceProcData {
    fileprivate func updateFormat(_ format: AudioStreamBasicDescription) {
        let ringCount = buffer.count
        buffer.free()
        currentSample = nil
        
        buffer.reset(count: ringCount,
            bufferSize: format.formatFlags.contains(.nonInterleaved) ? format.channels : 1
        )
    }
    func thread(_ block: @escaping (() -> Void)) {
        handoffQueue.async(group: handoffGroup, qos: safeBuffer ? .userInteractive : .utility, flags: .inheritQoS, execute: block)
    }
    func awaitThread() {
        handoffGroup.wait()
    }
    
    convenience init(_ unit: AudioComponentInstance,
                     format: AudioStreamBasicDescription = .init(),
                     bufferCount: Int,
                     handoff: DeviceProcHandoff? = nil) {
        self.init(unit, bufferCount: bufferCount, bufferSize: 1, handoff: handoff)
        if format != .init() { updateFormat(format) }
    }
    
}

// auHal scope/bus from direction
extension AudioDirection {
    var auBus: AudioUnitElement { self == .output ? 0 : 1 }
    func auScope(ofDevice: Bool = true) -> AudioUnitScope {
        (self == .output) == ofDevice ? kAudioUnitScope_Output : kAudioUnitScope_Input
    }
}

// AUHAL instantiation chain
extension AudioComponentInstance {
    init?(component: AudioComponent) {
        var instance: AudioComponentInstance?
        let err = AudioComponentInstanceNew(component, &instance)
        if err != OSStatus(0) { callAlert(.debug, "Create AudioCompInstance Error <Code:\(err)>") }
        if let instance = instance { self.init(instance) }
        else { return nil }
    }
}
extension AudioComponent {
    static let auHAL: AudioComponent? = {
        var description = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0, componentFlagsMask: 0
        )
        return AudioComponentFindNext(nil, &description)
    }()
}


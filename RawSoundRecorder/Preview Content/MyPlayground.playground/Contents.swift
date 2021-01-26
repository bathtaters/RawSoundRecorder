import Cocoa
import AudioToolbox

DispatchQoS.background.qosClass.rawValue.rawValue
DispatchQoS.default.qosClass.rawValue.rawValue
DispatchQoS.unspecified.qosClass.rawValue.rawValue
DispatchQoS.userInitiated.qosClass.rawValue.rawValue
DispatchQoS.userInteractive.qosClass.rawValue.rawValue
DispatchQoS.utility.qosClass.rawValue.rawValue

var buff = AudioRingBuffer(10)

func buffer(readOperation: Bool, val: UInt32 = 0) -> UInt32 {
    if readOperation, let result = buff.readNext() {
        return result
    }
    else if buff.writeNext(UInt32(val)) { return 0 }
    return .max
}

for i in 0..<36 {
    let val = UInt32(101 + i)
    let flip = arc4random_uniform(2) == 1
    let result = buffer(readOperation: flip, val: val)
    
    print("\(flip ? "Reading: \(result)" : "Writing: \(val) \(result == 0)") {read: \(buff.toRead) \(buff.canRead), write: \(buff.toWrite) \(buff.canWrite)}")
    if result == .max { print("ERROR"); break }
}

print(buff)
print("\(buff.readLast() ?? .max)")
print(buff)

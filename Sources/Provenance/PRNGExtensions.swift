import Foundation
import WolfBase

extension Xoshiro256StarStar {
    init(_ data: Data) {
        self.init(state: Self.toState(from: data))
    }
    
    var stateData: Data {
        get { Self.toData(from: state) }
        set { self.state = Self.toState(from: newValue) }
    }
    
    static func toState(from data: Data) -> (UInt64, UInt64, UInt64, UInt64) {
        guard data.count == 32 else {
            preconditionFailure()
        }
        return data.withUnsafeBytes { rawBuf in
            rawBuf.withMemoryRebound(to: UInt64.self) { buf in
                (buf[0].littleEndian, buf[1].littleEndian, buf[2].littleEndian, buf[3].littleEndian)
            }
        }
    }
    
    static func toData(from state: (UInt64, UInt64, UInt64, UInt64)) -> Data {
        Data([
            state.0.serialized(littleEndian: true),
            state.1.serialized(littleEndian: true),
            state.2.serialized(littleEndian: true),
            state.3.serialized(littleEndian: true)
        ].joined())
    }
}

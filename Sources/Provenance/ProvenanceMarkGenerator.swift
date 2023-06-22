import Foundation
import WolfBase
import BCCrypto

public class ProvenanceMarkGenerator {
    public let seed: Data
    public let id: Data
    public var nextSeq: UInt32
    public private(set) var rng: Xoshiro256StarStar
    public var name: String
    
    public init(seed: Data, id: Data, nextSeq: UInt32, rng: Xoshiro256StarStar, name: String) {
        self.seed = seed
        self.id = id
        self.nextSeq = nextSeq
        self.rng = rng
        self.name = name
    }
    
    public convenience init(seed: Data, id: Data, name: String = "") {
        self.init(seed: seed, id: id, nextSeq: 0, rng: Xoshiro256StarStar(seed.data), name: name)
    }
    
    public convenience init(passphrase: String, name: String = "", using rng: inout any RandomNumberGenerator) {
        let seed = extendKey(passphrase.utf8Data)
        let id = rng.randomData(ProvenanceMark.linkLength)
        self.init(seed: seed, id: id, name: name)
    }

    public convenience init(passphrase: String, name: String = "") {
        var rng: RandomNumberGenerator = SystemRandomNumberGenerator()
        self.init(passphrase: passphrase, name: name, using: &rng)
    }
    
    public func next(date: Date = Date()) -> ProvenanceMark {
        defer {
            nextSeq += 1
        }
        
        let key: Data
        if nextSeq == 0 {
            key = id
        } else {
            key = rng.randomData(ProvenanceMark.linkLength)
        }

        var nextRNG = rng
        let nextKey = nextRNG.randomData(ProvenanceMark.linkLength)

        return ProvenanceMark(key: key, id: id, seq: nextSeq, date: date, nextKey: nextKey)!
    }
}

extension Xoshiro256StarStar {
    init(_ data: Data) {
        guard data.count == 32 else {
            preconditionFailure()
        }
        let state = data.withUnsafeBytes { rawBuf in
            rawBuf.withMemoryRebound(to: UInt64.self) { buf in
                (buf[0].littleEndian, buf[1].littleEndian, buf[2].littleEndian, buf[3].littleEndian)
            }
        }
        self.init(state: state)
    }
}

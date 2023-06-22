import Foundation
import DCBOR
import WolfBase
import BCCrypto

public class ProvenanceMarkGenerator {
    public let seed: Data
    public let id: Data
    public var nextSeq: UInt32
    public private(set) var rng: Xoshiro256StarStar
    
    public init(seed: Data, id: Data, nextSeq: UInt32, rng: Xoshiro256StarStar) {
        self.seed = seed
        self.id = id
        self.nextSeq = nextSeq
        self.rng = rng
    }
    
    public convenience init(seed: Data, id: Data) {
        self.init(seed: seed, id: id, nextSeq: 0, rng: Xoshiro256StarStar(seed.data))
    }
    
    convenience init(passphrase: String, using rng: inout any RandomNumberGenerator) {
        let seed = extendKey(passphrase.utf8Data)
        let id = rng.randomData(ProvenanceMark.linkLength)
        self.init(seed: seed, id: id)
    }

    public convenience init(passphrase: String) {
        var rng: RandomNumberGenerator = SecureRandomNumberGenerator()
        self.init(passphrase: passphrase, using: &rng)
    }
    
    public func next(date: Date = Date(), info: (any CBOREncodable)? = nil) -> ProvenanceMark {
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

        return ProvenanceMark(key: key, id: id, seq: nextSeq, date: date, nextKey: nextKey, info: info)!
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

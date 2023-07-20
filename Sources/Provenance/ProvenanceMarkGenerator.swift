import Foundation
import DCBOR
import WolfBase
import BCCrypto

public struct ProvenanceMarkGenerator: Hashable, Codable {
    public let res: ProvenanceMarkResolution
    public let seed: Data
    public let id: Data
    public var nextSeq: UInt32
    public var rngState: Data

    public init(resolution res: ProvenanceMarkResolution, seed: Data, id: Data, nextSeq: UInt32, rngState: Data) {
        self.res = res
        self.seed = seed
        self.id = id
        self.nextSeq = nextSeq
        self.rngState = rngState
    }

    public init(resolution res: ProvenanceMarkResolution, seed: Data, id: Data) {
        self.init(resolution: res, seed: seed, id: id, nextSeq: 0, rngState: seed)
    }
    
    public init<R>(resolution res: ProvenanceMarkResolution, seed: Data, using rng: inout R) where R: RandomNumberGenerator {
        let id = rng.randomData(res.linkLength)
        self.init(resolution: res, seed: seed, id: id)
    }
    
    public init<R>(resolution res: ProvenanceMarkResolution, using rng: inout R) where R: RandomNumberGenerator {
        let seed = rng.randomData(32)
        self.init(resolution: res, seed: seed, using: &rng)
    }
    
    public init(resolution res: ProvenanceMarkResolution) {
        var rng: RandomNumberGenerator = SecureRandomNumberGenerator.shared
        self.init(resolution: res, using: &rng)
    }
    
    public init<R>(resolution res: ProvenanceMarkResolution, passphrase: String, using rng: inout R) where R: RandomNumberGenerator {
        let seed = extendKey(passphrase.utf8Data)
        self.init(resolution: res, seed: seed, using: &rng)
    }
    
    public init(resolution res: ProvenanceMarkResolution, seed: Data) {
        var rng: RandomNumberGenerator = SecureRandomNumberGenerator()
        self.init(resolution: res, seed: seed, using: &rng)
    }
    
    public init(resolution res: ProvenanceMarkResolution, passphrase: String) {
        var rng: RandomNumberGenerator = SecureRandomNumberGenerator()
        self.init(resolution: res, passphrase: passphrase, using: &rng)
    }
    
    public mutating func next(date: Date = Date(), info: (any CBOREncodable)? = nil) -> ProvenanceMark {
        defer {
            nextSeq += 1
        }
        
        var rng = Xoshiro256StarStar(rngState)
        
        let key: Data
        if nextSeq == 0 {
            key = id
        } else {
            key = rng.randomData(res.linkLength)
            rngState = rng.stateData
        }
        
        var nextRNG = rng
        let nextKey = nextRNG.randomData(res.linkLength)
        
        return ProvenanceMark(resolution: res, key: key, nextKey: nextKey, id: id, seq: nextSeq, date: date, info: info)!
    }
}

extension ProvenanceMarkGenerator: CustomStringConvertible {
    public var description: String {
        "ProvenanceMarkGenerator(id: \(id.hex), res: \(res), seed: \(seed.hex), nextSeq: \(nextSeq), rngState: \(rngState.hex))"
    }
}

import Foundation
import CryptoSwift
import URKit
import func WolfBase.deserialize
import func WolfBase.todo

public struct ProvenanceMark: Codable, Hashable {
    public let _res: Int
    
    public let key: Data
    public let hash: Data
    public let chainID: Data
    public let seqBytes: Data
    public let dateBytes: Data
    public let infoBytes: Data
    
    public let seq: UInt32
    public let date: Date

    public let message: Data
    
    public let markID: Data
    
    // KLUDGE ALERT: Temporary workaround for the fact that pre-release SwiftData
    // does not properly persist codable enums!
    public var res: ProvenanceMarkResolution {
        ProvenanceMarkResolution(rawValue: _res)!
    }
    
    public var info: CBOR? {
        guard !infoBytes.isEmpty else {
            return nil
        }
        return try? CBOR(infoBytes)
    }

    public init?(resolution res: ProvenanceMarkResolution, key: Data, nextKey: Data, chainID: Data, seq: UInt32, date: Date, info: (any CBOREncodable)? = nil) {
        self._res = res.rawValue
        
        guard
            key.count == res.linkLength,
            chainID.count == res.linkLength,
            let dateBytes = res.serializeDate(date),
            let seqBytes = res.serializeSeq(seq)
        else {
            return nil
        }
        self.key = key
        self.chainID = chainID
        self.seqBytes = seqBytes
        self.seq = seq
        self.dateBytes = dateBytes
        self.date = res.deserializeDate(dateBytes)!
        if let info {
            self.infoBytes = info.cborData
        } else {
            self.infoBytes = Data()
        }
        self.hash = Self.hash(resolution: res, key: key, nextKey: nextKey, chainID: chainID, seqBytes: seqBytes, dateBytes: dateBytes, infoBytes: infoBytes)
        let payload = chainID + hash + seqBytes + dateBytes + infoBytes
        self.message = key + obfuscate(key: key, message: payload)
        
        self.markID = Self.markID(message: message)
    }
    
    public init?(resolution res: ProvenanceMarkResolution, message: Data) {
        self._res = res.rawValue
        guard message.count >= res.fixedLength else {
            return nil
        }
        self.message = message
        self.key = message[res.keyRange]
        let payload = obfuscate(key: key, message: message[res.linkLength...])
        self.hash = payload[res.hashRange]
        self.chainID = payload[res.chainIDRange]
        self.seqBytes = payload[res.seqBytesRange]
        guard let seq = res.deserializeSeq(seqBytes) else {
            return nil
        }
        self.seq = seq
        self.dateBytes = payload[res.dateBytesRange]
        guard let date = res.deserializeDate(dateBytes) else {
            return nil
        }
        self.date = date
        let infoBytes = payload[res.infoRange]
        if infoBytes.isEmpty {
            self.infoBytes = Data()
        } else {
            if (try? CBOR(infoBytes)) != nil {
                self.infoBytes = infoBytes
            } else {
                return nil
            }
        }

        self.markID = Self.markID(message: message)
    }

    private static func hash(resolution res: ProvenanceMarkResolution, key: Data, nextKey: Data, chainID: Data, seqBytes: Data, dateBytes: Data, infoBytes: Data) -> Data {
        sha256([key, nextKey, chainID, seqBytes, dateBytes, infoBytes], prefix: res.linkLength)
    }
    
    private static func markID(message: Data) -> Data {
        sha256(message)
    }
}

public extension ProvenanceMark {
    func precedes(next: ProvenanceMark) -> Bool {
        // `next` can't be a genesis
        next.seq != 0 &&
        next.key != next.chainID &&
        // `next` must have the next highest sequence number
        seq == next.seq - 1 &&
        // `next` must have an equal or later date
        date <= next.date &&
        // `next` must reveal the key that was used to generate this mark's hash
        hash == Self.hash(resolution: res, key: key, nextKey: next.key, chainID: chainID, seqBytes: seqBytes, dateBytes: dateBytes, infoBytes: infoBytes)
    }
    
    static func isSequenceValid(marks: [ProvenanceMark]) -> Bool {
        guard marks.count >= 2 else {
            return false
        }
        if marks.first!.seq == 0 {
            guard marks.first!.isGenesis else {
                return false
            }
        }
        return zip(marks, marks.dropFirst()).allSatisfy { $0.precedes(next: $1) }
    }
    
    var isGenesis: Bool {
        seq == 0 &&
        key == chainID
    }
}

public extension ProvenanceMark {
    init?(resolution res: ProvenanceMarkResolution, bytewords: String) {
        guard let message = try? Bytewords.decode(bytewords) else {
            return nil
        }
        self.init(resolution: res, message: message)
    }
    
    func bytewords(style: Bytewords.Style = .standard) -> String {
        Bytewords.encode(message, style: style)
    }
}

public extension ProvenanceMark {
    init?(urlEncoding: String) {
        guard
            let cborData = try? Bytewords.decode(urlEncoding, style: .minimal)
        else {
            return nil
        }
        
        try? self.init(cborData: cborData)
    }
    
    var urlEncoding: String {
        Bytewords.encode(cborData, style: .minimal)
    }
}

extension ProvenanceMark: Equatable {
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.res == rhs.res &&
        lhs.key == rhs.key &&
        lhs.hash == rhs.hash &&
        lhs.chainID == rhs.chainID &&
        lhs.seqBytes == rhs.seqBytes &&
        lhs.dateBytes == rhs.dateBytes &&
        lhs.infoBytes == rhs.infoBytes
    }
}

extension ProvenanceMark: CustomStringConvertible {
    public var description: String {
        var components: [String] = [
            "key: \(key.hex)",
            "hash: \(hash.hex)",
            "chainID: \(chainID.hex)",
//            "seqBytes: \(seqBytes.hex)",
//            "dateBytes: \(dateBytes.hex)",
            "seq: \(seq)",
            "date: \(date.ISO8601Format())",
//            "message: \(message.hex)"
        ]
        
        if let info {
            components.append("info: \(info)")
        }
        
        return components.joined(separator: ", ").flanked("ProvenanceMark(", ")")
    }
}

extension ProvenanceMark: URCodable {
    public static let cborTag = Tag(0x50524f56, "provenance")

    public var untaggedCBOR: CBOR {
        [
            res.rawValue.cbor,
            CBOR.bytes(message)
        ].cbor
    }

    public init(untaggedCBOR: CBOR) throws {
        guard
            case let CBOR.array(elements) = untaggedCBOR,
            elements.count == 2,
            case let resolutionRawValue = try Int(cbor: elements[0]),
            let res = ProvenanceMarkResolution(rawValue: resolutionRawValue),
            case let CBOR.bytes(message) = elements[1],
            let mark = ProvenanceMark(resolution: res, message: message)
        else {
            throw CBORError.invalidFormat
        }
        self = mark
    }
}

//extension ProvenanceMark: Codable {
//    enum CodingKeys: CodingKey {
//        case res
//        case message
//    }
//    
//    public init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        let res = try container.decode(Int.self, forKey: .res)
//        guard let resolution = ProvenanceMarkResolution(rawValue: res) else {
//            throw DecodingError.dataCorruptedError(forKey: .res, in: container, debugDescription: "Invalid resoution value.")
//        }
//        let message = try container.decode(Data.self, forKey: .message)
//        guard let result = Self.init(resolution: resolution, message: message) else {
//            throw DecodingError.dataCorruptedError(forKey: .message, in: container, debugDescription: "Invalid message.")
//        }
//        self = result
//    }
//    
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(_res, forKey: .res)
//        try container.encode(message, forKey: .message)
//    }
//}

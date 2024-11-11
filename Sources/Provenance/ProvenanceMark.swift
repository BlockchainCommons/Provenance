import Foundation
import CryptoSwift
import URKit
import func WolfBase.deserialize
import func WolfBase.todo

public struct ProvenanceMark: Codable, Hashable {
    public let res: ProvenanceMarkResolution
    
    public let key: Data
    public let hash: Data
    public let chainID: Data
    public let seqBytes: Data
    public let dateBytes: Data
    public let infoBytes: Data
    
    public let seq: UInt32
    public let date: Date
    
    public var idWords: String {
        return hash
            .prefix(4)
            .map({ Bytewords.allWords[Int($0)] })
            .joined(separator: " ")
            .uppercased()
    }

    public var info: CBOR? {
        guard !infoBytes.isEmpty else {
            return nil
        }
        return try? CBOR(infoBytes)
    }
    
    public var message: Data {
        let payload = chainID + hash + seqBytes + dateBytes + infoBytes
        return key + obfuscate(key: key, message: payload)
    }

    public init?(resolution res: ProvenanceMarkResolution, key: Data, nextKey: Data, chainID: Data, seq: UInt32, date: Date, info: (any CBOREncodable)? = nil) {
        self.res = res
        
        guard
            key.count == res.linkLength,
            nextKey.count == res.linkLength,
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
    }
    
    public init?(resolution res: ProvenanceMarkResolution, message: Data) {
        self.res = res
        guard message.count >= res.fixedLength else {
            return nil
        }
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
    }

    private static func hash(resolution res: ProvenanceMarkResolution, key: Data, nextKey: Data, chainID: Data, seqBytes: Data, dateBytes: Data, infoBytes: Data) -> Data {
        sha256([key, nextKey, chainID, seqBytes, dateBytes, infoBytes], prefix: res.linkLength)
    }
}

public extension ProvenanceMark {
    enum CodingKeys: CodingKey {
        case chainID
        case date
        case hash
        case info
        case key
        case res
        case seq
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(res, forKey: .res)
        try container.encode(key, forKey: .key)
        try container.encode(hash, forKey: .hash)
        try container.encode(chainID, forKey: .chainID)
        try container.encode(seq, forKey: .seq)
        try container.encode(date.ISO8601Format(), forKey: .date)
        if !infoBytes.isEmpty {
            try container.encode(infoBytes, forKey: .info)
        }
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.res = try container.decode(ProvenanceMarkResolution.self, forKey: .res)

        self.key = try container.decode(Data.self, forKey: .key)
        guard key.count == res.linkLength else {
            throw DecodingError.dataCorruptedError(forKey: .key, in: container, debugDescription: "Invalid key length")
        }

        self.hash = try container.decode(Data.self, forKey: .hash)
        guard hash.count == res.linkLength else {
            throw DecodingError.dataCorruptedError(forKey: .hash, in: container, debugDescription: "Invalid hash length")
        }

        self.chainID = try container.decode(Data.self, forKey: .chainID)
        guard chainID.count == res.linkLength else {
            throw DecodingError.dataCorruptedError(forKey: .chainID, in: container, debugDescription: "Invalid chain ID length")
        }

        self.seq = try container.decode(UInt32.self, forKey: .seq)
        guard let seqBytes = res.serializeSeq(seq) else {
            throw DecodingError.dataCorruptedError(forKey: .seq, in: container, debugDescription: "Invalid seq")
        }
        self.seqBytes = seqBytes

        let dateString = try container.decode(String.self, forKey: .date)
        self.date = try Date(iso8601: dateString)
        guard let dateBytes = res.serializeDate(date) else {
            throw DecodingError.dataCorruptedError(forKey: .date, in: container, debugDescription: "Invalid date")
        }
        self.dateBytes = dateBytes

        self.infoBytes = try container.decodeIfPresent(Data.self, forKey: .info) ?? Data()
        if !self.infoBytes.isEmpty {
            guard (try? CBOR(infoBytes)) != nil else {
                throw DecodingError.dataCorruptedError(forKey: .info, in: container, debugDescription: "Invalid info")
            }
        }
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
        lhs.res == rhs.res && lhs.message == rhs.message
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
    public static let cborTags = [Tag(0x50524f56, "provenance")]

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

extension ProvenanceMark {
    public var fingerprint: Data {
        sha256(self.cborData)
    }
}

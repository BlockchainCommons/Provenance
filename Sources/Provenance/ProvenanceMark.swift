import Foundation
import CryptoSwift
import URKit
import func WolfBase.deserialize
import func WolfBase.todo

public struct ProvenanceMark {
    public let res: ProvenanceMarkResolution
    
    public let key: Data
    public let hash: Data
    public let id: Data
    public let seqBytes: Data
    public let dateBytes: Data
    public let infoBytes: Data
    
    public let seq: UInt32
    public let date: Date
    public let info: CBOR?

    public let message: Data
    
    public init?(resolution res: ProvenanceMarkResolution, key: Data, nextKey: Data, id: Data, seq: UInt32, date: Date, info: (any CBOREncodable)? = nil) {
        self.res = res
        
        guard
            key.count == res.linkLength,
            id.count == res.linkLength,
            let dateBytes = res.serializeDate(date),
            let seqBytes = res.serializeSeq(seq)
        else {
            return nil
        }
        self.key = key
        self.id = id
        self.seqBytes = seqBytes
        self.seq = seq
        self.dateBytes = dateBytes
        self.date = date
        if let info {
            self.info = info.cbor
            self.infoBytes = info.cborData
        } else {
            self.info = nil
            self.infoBytes = Data()
        }
        self.hash = Self.hash(resolution: res, key: key, nextKey: nextKey, id: id, seqBytes: seqBytes, dateBytes: dateBytes, infoBytes: infoBytes)
        let payload = id + hash + seqBytes + dateBytes + infoBytes
        self.message = key + obfuscate(key: key, message: payload)
    }
    
    public init?(resolution res: ProvenanceMarkResolution, message: Data) {
        self.res = res
        guard message.count >= res.fixedLength else {
            return nil
        }
        self.message = message
        self.key = message[res.keyRange]
        let payload = obfuscate(key: key, message: message[res.linkLength...])
        self.hash = payload[res.hashRange]
        self.id = payload[res.idRange]
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
            self.info = nil
            self.infoBytes = Data()
        } else {
            if let info = try? CBOR(infoBytes) {
                self.info = info
                self.infoBytes = infoBytes
            } else {
                return nil
            }
        }
    }

    private static func hash(resolution res: ProvenanceMarkResolution, key: Data, nextKey: Data, id: Data, seqBytes: Data, dateBytes: Data, infoBytes: Data) -> Data {
        sha256([key, nextKey, id, seqBytes, dateBytes, infoBytes], count: res.linkLength)
    }
}

public extension ProvenanceMark {
    func precedes(next: ProvenanceMark) -> Bool {
        // `next` can't be a genesis
        next.seq != 0 &&
        next.key != next.id &&
        // `next` must have the next highest sequence number
        seq == next.seq - 1 &&
        // `next` must have an equal or later date
        date <= next.date &&
        // `next` must reveal the key that was used to generate this mark's hash
        hash == Self.hash(resolution: res, key: key, nextKey: next.key, id: id, seqBytes: seqBytes, dateBytes: dateBytes, infoBytes: infoBytes)
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
        key == id
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
        lhs.id == rhs.id &&
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
            "id: \(id.hex)",
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

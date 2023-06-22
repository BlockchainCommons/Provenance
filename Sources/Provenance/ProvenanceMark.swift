import Foundation
import CryptoSwift
import URKit
import func WolfBase.deserialize
import func WolfBase.todo

public struct ProvenanceMark {
    static let linkLength = 8
    static let seqBytesLength = 4
    static let dateBytesLength = 4
    static let hashLength = 8
    
    static let totalLength = linkLength + linkLength + seqBytesLength + dateBytesLength + hashLength
    
    static let keyRange = 0..<linkLength
    
    // payload
    static let idRange = 0 ..< linkLength
    static let seqBytesRange = idRange.upperBound ..< (idRange.upperBound + seqBytesLength)
    static let dateBytesRange = seqBytesRange.upperBound ..< (seqBytesRange.upperBound + dateBytesLength)
    static let hashRange = dateBytesRange.upperBound ..< (dateBytesRange.upperBound + hashLength)
    
    public let key: Data
    public let id: Data
    public let seqBytes: Data
    public let dateBytes: Data
    public let hash: Data
    
    public let seq: UInt32
    public let date: Date
    public let message: Data
    
    public init?(key: Data, id: Data, seq: UInt32, date: Date, nextKey: Data) {
        guard
            key.count == Self.linkLength,
            id.count == Self.linkLength,
            let dateBytes = date.provenanceSerialized
        else {
            return nil
        }
        self.key = key
        self.id = id
        self.seqBytes = seq.serialized
        self.seq = seq
        self.dateBytes = dateBytes
        self.hash = Self.hash(key: key, id: id, seqBytes: seqBytes, dateBytes: dateBytes, nextKey: nextKey)
        self.date = date
        let payload = id + seqBytes + dateBytes + hash
        self.message = key + obfuscate(key: key, message: payload)
    }
    
    public init?(message: Data) {
        guard message.count == Self.totalLength else {
            return nil
        }
        self.message = message
        self.key = message[Self.keyRange]
        let payload = obfuscate(key: key, message: message[Self.linkLength...])
        self.id = payload[Self.idRange]
        self.seqBytes = payload[Self.seqBytesRange]
        guard let seq = deserialize(UInt32.self, seqBytes) else {
            return nil
        }
        self.seq = seq
        self.dateBytes = payload[Self.dateBytesRange]
        guard let date = Date(provenanceSerialized: dateBytes) else {
            return nil
        }
        self.date = date
        self.hash = payload[Self.hashRange]
    }
}

public extension ProvenanceMark {
    init?(bytewords: String) {
        guard let message = try? Bytewords.decode(bytewords) else {
            return nil
        }
        self.init(message: message)
    }
    
    func bytewords(style: Bytewords.Style = .standard) -> String {
        Bytewords.encode(message, style: style)
    }
}

public extension ProvenanceMark {
    var minimalBytewords: String { Bytewords.encode(cborData, style: .minimal) }
    
    init?(minimalBytewords: String) {
        guard let data = try? Bytewords.decode(minimalBytewords, style: .minimal) else {
            return nil
        }
        try? self.init(cborData: data)
    }
}

public extension ProvenanceMark {
    func url(base: URL) -> URL {
        var result = base
        let value = Bytewords.encode(taggedCBOR.cborData, style: .minimal)
        result.append(queryItems: [URLQueryItem(name: "provenance", value: minimalBytewords)])
        return result
    }
    
    init?(url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        guard
            let item = queryItems.first(where: { $0.name.lowercased() == "provenance" }),
            let minimalBytewords = item.value
        else {
            return nil
        }
        self.init(minimalBytewords: minimalBytewords)
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
        hash == Self.hash(key: key, id: id, seqBytes: seqBytes, dateBytes: dateBytes, nextKey: next.key)
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
    
    private static func hash(key: Data, id: Data, seqBytes: Data, dateBytes: Data, nextKey: Data) -> Data {
        sha256([key, id, seqBytes, dateBytes, nextKey], count: Self.hashLength)
    }
}

extension ProvenanceMark: Equatable {
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.key == rhs.key && lhs.id == rhs.id && lhs.dateBytes == rhs.dateBytes && lhs.hash == rhs.hash
    }
}

extension ProvenanceMark: CustomStringConvertible {
    public var description: String {
        "ProvenanceMark(key: \(key.hex), id: \(id.hex), seqBytes: \(seqBytes.hex), dateBytes: \(dateBytes.hex), hash: \(hash.hex), seq: \(seq), date: \(date.ISO8601Format()), message: \(message.hex)"
    }
}

extension Date {
    var provenanceSerialized: Data? {
        guard let n = UInt32(exactly: floor(timeIntervalSinceReferenceDate)) else {
            return nil
        }
        return n.serialized
    }
    
    init? (provenanceSerialized data: Data) {
        guard let n = deserialize(UInt32.self, data) else {
            return nil
        }
        self.init(timeIntervalSinceReferenceDate: TimeInterval(n))
    }
}

extension ProvenanceMark: URCodable {
    public static let cborTag = Tag(0x50524f56, "provenance")

    public var untaggedCBOR: CBOR {
        CBOR.bytes(message)
    }

    public init(untaggedCBOR: CBOR) throws {
        guard
            case let CBOR.bytes(message) = untaggedCBOR,
            let mark = ProvenanceMark(message: message)
        else {
            throw CBORError.invalidFormat
        }
        self = mark
    }
}

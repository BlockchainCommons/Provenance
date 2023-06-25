import Foundation
import WolfBase

// LOW (16 bytes)
// 0000  0000  0000  00  00
// 0123  4567  89ab  cd  ef
// key   hash  id    seq date

// MEDIUM (32 bytes)
// 00000000  00000000  11111111  1111  1111
// 01234567  89abcdef  01234567  89ab  cdef
// key       hash      id        seq   date

// QUARTILE (60 bytes)
// 0000000000000000  1111111111111111  2222222222222222  3333  33333333
// 0123456789abcdef  0123456789abcdef  0123456789abcdef  0123  456789ab
// key               hash              id                seq   date

// HIGH (108 bytes)
// 00000000000000001111111111111111  22222222222222223333333333333333  44444444444444445555555555555555  6666  66666666
// 0123456789abcdef0123456789abcdef  0123456789abcdef0123456789abcdef  0123456789abcdef0123456789abcdef  0123  456789ab
// key                               hash                              id                                seq   date

public enum ProvenanceMarkResolution: Int {
    case low
    case medium
    case quartile
    case high
    
    public var linkLength: Int {
        switch self {
        case .low:
            return 4
        case .medium:
            return 8
        case .quartile:
            return 16
        case .high:
            return 32
        }
    }
    
    public var seqBytesLength: Int {
        switch self {
        case .low:
            return 2
        case .medium, .quartile, .high:
            return 4
        }
    }
    
    public var dateBytesLength: Int {
        switch self {
        case .low:
            return 2
        case .medium:
            return 4
        case .quartile, .high:
            return 8
        }
    }

    public var fixedLength: Int { linkLength * 3 + seqBytesLength + dateBytesLength }
    
    public var keyRange: Range<Int> { 0..<linkLength }
    public var idRange: Range<Int> { 0 ..< linkLength }
    public var hashRange: Range<Int> { idRange.upperBound ..< (idRange.upperBound + linkLength) }
    public var seqBytesRange: Range<Int> { hashRange.upperBound ..< (hashRange.upperBound + seqBytesLength) }
    public var dateBytesRange: Range<Int> { seqBytesRange.upperBound ..< (seqBytesRange.upperBound + dateBytesLength) }
    public var infoRange : PartialRangeFrom<Int> { dateBytesRange.upperBound... }
    
    public func serializeDate(_ date: Date) -> Data? {
        switch self {
        case .low:
            return date.serialize2Bytes()
        case .medium:
            return date.serialize4Bytes()
        case .quartile, .high:
            return date.serialize8Bytes()
        }
    }
    
    public func deserializeDate(_ data: Data) -> Date? {
        switch self {
        case .low:
            return Date.deserialize2Bytes(data)
        case .medium:
            return Date.deserialize4Bytes(data)
        case .quartile, .high:
            return Date.deserialize8Bytes(data)
        }
    }
    
    public func serializeSeq(_ seq: UInt32) -> Data? {
        switch seqBytesLength {
        case 2:
            guard let s = UInt16(exactly: seq) else {
                return nil
            }
            return s.serialized
        case 4:
            return seq.serialized
        default:
            preconditionFailure()
        }
    }
    
    public func deserializeSeq(_ data: Data) -> UInt32? {
        guard data.count == seqBytesLength else {
            return nil
        }
        switch seqBytesLength {
        case 2:
            return UInt32(deserialize(UInt16.self, data)!)
        case 4:
            return deserialize(UInt32.self, data)!
        default:
            preconditionFailure()
        }
    }
}


extension Date {
    // fedcba9876543210
    // yyyyyyymmmmddddd
    func serialize2Bytes() -> Data? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let components = calendar.dateComponents([.year, .month, .day], from: self)
        guard
            let year = components.year,
            let month = components.month,
            let day = components.day
        else {
            return nil
        }
        let yy = year - 2000
        guard (0..<128).contains(yy) else {
            return nil
        }
        let y = UInt16(yy)
        let m = UInt16(month)
        let d = UInt16(day)
        let value = (y << 9) | (m << 5) | d
        return value.serialized
    }
    
    static func deserialize2Bytes(_ data: Data) -> Date? {
        guard let value = deserialize(UInt16.self, data) else {
            return nil
        }
        let day = Int(value & 0b11111)
        let month = Int((value >> 5) & 0b1111)
        let year = Int((value >> 9) & 0b1111111) + 2000
        let components = DateComponents(year: year, month: month, day: day)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let date = calendar.date(from: components)
        return date
    }

    func serialize4Bytes() -> Data? {
        guard let n = UInt32(exactly: floor(timeIntervalSinceReferenceDate)) else {
            return nil
        }
        return n.serialized
    }
    
    static func deserialize4Bytes(_ data: Data) -> Date? {
        guard let n = deserialize(UInt32.self, data) else {
            return nil
        }
        return Self(timeIntervalSinceReferenceDate: TimeInterval(n))
    }

    func serialize8Bytes() -> Data? {
        guard let n = UInt64(exactly: floor(timeIntervalSinceReferenceDate * 1000)) else {
            return nil
        }
        return n.serialized
    }
    
    static func deserialize8Bytes(_ data: Data) -> Date? {
        guard let n = deserialize(UInt64.self, data) else {
            return nil
        }
        return Self(timeIntervalSinceReferenceDate: TimeInterval(Double(n) / 1000.0))
    }
}

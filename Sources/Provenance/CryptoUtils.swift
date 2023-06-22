import Foundation
import CryptoSwift

func sha256(_ data: Data) -> Data {
    Data(CryptoSwift.SHA2(variant: .sha256).calculate(for: data.bytes))
}

func sha256(_ data: [Data], count: Int) -> Data {
    sha256(Data(data.joined())).prefix(count)
}

func extendKey(_ data: Data) -> Data {
    try! Data(HKDF(password: data.bytes, salt: [], info: [], keyLength: 32, variant: .sha2(.sha256)).calculate())
}

func obfuscate(key: Data, message: Data) -> Data {
    guard !message.isEmpty else {
        return message
    }
    let extendedKey = Array(extendKey(key))
    let iv = Array(extendedKey.reversed().prefix(12))
    let result = try! Data(ChaCha20(key: extendedKey, iv: iv).encrypt(message.bytes))
    return result
}

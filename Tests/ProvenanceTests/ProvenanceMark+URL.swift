import Foundation
import Provenance
import URKit

public extension ProvenanceMark {
    func url(base: URL) -> URL {
        var result = base
        result.append(queryItems: [URLQueryItem(name: "provenance", value: urlEncoding)])
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
        self.init(urlEncoding: minimalBytewords)
    }
}

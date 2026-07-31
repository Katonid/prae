import Foundation
import CryptoKit

/// Two-level image cache. Network data is decoded off the main actor and disk size is bounded.
actor ImageService {
    private let memory = NSCache<NSURL, NSData>()
    private let directory: URL
    private var maxMegabytes: Int
    private var session: URLSession

    init(maxMegabytes: Int = 256, wifiOnly: Bool = true, fileManager: FileManager = .default) {
        self.maxMegabytes = maxMegabytes
        session = Self.makeSession(wifiOnly: wifiOnly)
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = base.appending(path: "PhotoSpotImages", directoryHint: .isDirectory)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func data(for url: URL) async throws -> Data {
        if let cached = memory.object(forKey: url as NSURL) { return cached as Data }
        let file = directory.appending(path: SHA256.hash(data: Data(url.absoluteString.utf8)).hex)
        let data: Data
        if let disk = try? Data(contentsOf: file) { data = disk }
        else {
            let (download, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw ServiceError.invalidResponse }
            data = download
            try? data.write(to: file, options: .atomic)
            trim(toMegabytes: maxMegabytes)
        }
        memory.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
        return data
    }

    func trim(toMegabytes limit: Int) {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        )) ?? []
        let records = files.compactMap { url -> (URL, Date, Int)? in
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else { return nil }
            return (url, values.contentModificationDate ?? .distantPast, values.fileSize ?? 0)
        }.sorted { $0.1 < $1.1 }
        var total = records.reduce(0) { $0 + $1.2 }, target = max(0, limit) * 1_048_576
        for record in records where total > target {
            try? FileManager.default.removeItem(at: record.0); total -= record.2
        }
    }

    func setLimit(megabytes: Int) {
        maxMegabytes = megabytes
        trim(toMegabytes: megabytes)
    }

    func setWiFiOnly(_ wifiOnly: Bool) {
        session.invalidateAndCancel()
        session = Self.makeSession(wifiOnly: wifiOnly)
    }

    private static func makeSession(wifiOnly: Bool) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.allowsCellularAccess = !wifiOnly
        configuration.allowsExpensiveNetworkAccess = !wifiOnly
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: configuration)
    }
}

private extension SHA256.Digest {
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}

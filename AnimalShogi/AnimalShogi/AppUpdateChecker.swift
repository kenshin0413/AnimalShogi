import Foundation

struct AppUpdate: Identifiable {
    let storeVersion: String
    let storeURL: URL

    var id: String { storeVersion }
}

enum AppUpdateChecker {
    private struct LookupResponse: Decodable {
        let results: [LookupResult]
    }

    private struct LookupResult: Decodable {
        let version: String
        let trackViewUrl: URL
    }

    /// App Storeの公開版が、端末に入っている版より新しい場合だけ返す。
    static func check() async -> AppUpdate? {
        guard
            let bundleID = Bundle.main.bundleIdentifier,
            let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            var components = URLComponents(string: "https://itunes.apple.com/lookup")
        else { return nil }

        components.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID),
            URLQueryItem(name: "country", value: "jp")
        ]
        guard let url = components.url else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            request.cachePolicy = .reloadRevalidatingCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else { return nil }

            let result = try JSONDecoder().decode(LookupResponse.self, from: data).results.first
            guard let result,
                  result.version.compare(currentVersion, options: .numeric) == .orderedDescending else {
                return nil
            }
            return AppUpdate(storeVersion: result.version, storeURL: result.trackViewUrl)
        } catch {
            // オフラインやApp Store未公開時は、ゲームを止めず何も表示しない。
            return nil
        }
    }
}

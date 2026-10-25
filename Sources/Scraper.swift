import Foundation
import WebKit

// Elrejtett scraper webview: valodi WebKit tolti az oldalt (atjut a Cloudflare-en),
// a FO felulet SOHA nem jeleniti meg a weboldalt - csak az adatokat kapja meg.
final class Scraper: NSObject, WKNavigationDelegate {
    static let shared = Scraper()
    private var web: WKWebView!
    private var busy = false
    private var queue: [() -> Void] = []

    private override init() {
        super.init()
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()
        let w = WKWebView(frame: .zero, configuration: cfg)
        w.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1 DMDMedia/2.0"
        w.navigationDelegate = self
        web = w
    }

    typealias Done = (Result<[String: Any], Error>) -> Void

    func scrape(_ urlString: String, completion: @escaping Done) {
        run(urlString, post: nil, completion: completion)
    }

    func scrapePost(kind: String, params: [String: String], completion: @escaping Done) {
        let call: String
        if kind == "season" {
            call = "JSON.stringify(fetchSeason(\(jsStr(params["kod"] ?? "")), \(jsStr(params["evad"] ?? "1"))))"
        } else {
            call = "JSON.stringify(fetchSearch(\(jsStr(params["q"] ?? ""))))"
        }
        run(nil, post: call, completion: completion)
    }

    private func jsStr(_ s: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: [s], options: [])
        guard let d = data, let arr = String(data: d, encoding: .utf8) else { return "\"\"" }
        return String(arr.dropFirst().dropLast())
    }

    private func run(_ urlString: String?, post: String?, completion: @escaping Done) {
        let job = { [weak self] in
            guard let self = self else { return }
            if let post = post {
                self.evalLoop(post, attempt: 0, completion: completion)
            } else if let urlString = urlString, let url = URL(string: urlString) {
                var req = URLRequest(url: url)
                req.setValue("https://dmdamedia.hu/", forHTTPHeaderField: "Referer")
                self.web.load(req)
                self.waitAndExtract(attempt: 0, completion: completion)
            } else {
                completion(.failure(NSError(domain: "dmd", code: 1)))
            }
        }
        if busy { queue.append(job) } else { busy = true; job() }
    }

    private func nextJob() {
        if queue.isEmpty { busy = false } else { let j = queue.removeFirst(); j() }
    }

    private func waitAndExtract(attempt: Int, completion: @escaping Done) {
        DispatchQueue.main.asyncAfter(deadline: .now() + (attempt == 0 ? 1.2 : 1.2)) { [weak self] in
            guard let self = self else { return }
            self.web.evaluateJavaScript(Extractor.js + "\n;JSON.stringify(extractCurrent())") { res, _ in
                if let s = res as? String, let data = s.data(using: .utf8),
                   let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                    let title = (obj["title"] as? String) ?? ""
                    let challenge = title.range(of: "just a moment|attention|checking|cloudflare", options: .regularExpression) != nil && title.count < 40
                    let empty = ((obj["cards"] as? [Any])?.isEmpty ?? true)
                        && ((obj["episodes"] as? [Any])?.isEmpty ?? true)
                        && ((obj["providers"] as? [Any])?.isEmpty ?? true)
                        && (obj["iframe"] as? String) == nil
                        && ((obj["desc"] as? String) ?? "").isEmpty
                    if !challenge && (!empty || !title.isEmpty) {
                        completion(.success(obj))
                        self.nextJob()
                        return
                    }
                }
                if attempt < 24 {
                    self.waitAndExtract(attempt: attempt + 1, completion: completion)
                } else {
                    completion(.failure(NSError(domain: "dmd", code: 2)))
                    self.nextJob()
                }
            }
        }
    }

    private func evalLoop(_ js: String, attempt: Int, completion: @escaping Done) {
        web.evaluateJavaScript(Extractor.js + "\n;" + js) { [weak self] res, _ in
            if let s = res as? String, let data = s.data(using: .utf8),
               let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                completion(.success(obj))
                self?.nextJob()
            } else if attempt < 4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    self?.evalLoop(js, attempt: attempt + 1, completion: completion)
                }
            } else {
                completion(.failure(NSError(domain: "dmd", code: 3)))
                self?.nextJob()
            }
        }
    }
}

enum JSONX {
    static func arr(_ any: Any?) -> [[String: Any]] {
        (any as? [[String: Any]]) ?? []
    }
    static func str(_ any: Any?) -> String { (any as? String) ?? "" }
    static func int(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let d = any as? Double { return Int(d) }
        return nil
    }
}

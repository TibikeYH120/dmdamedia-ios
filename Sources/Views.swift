import SwiftUI
import WebKit

let BASE = "https://dmdamedia.hu"

struct Card: Identifiable {
    let id = UUID()
    let url: String; let kind: String; let title: String; let poster: String
    let sxxexx: String; let date: String; let year: String; let badges: [String]
    init(_ d: [String: Any]) {
        url = JSONX.str(d["url"]); kind = JSONX.str(d["kind"]); title = JSONX.str(d["title"])
        poster = JSONX.str(d["poster"]); sxxexx = JSONX.str(d["sxxexx"]); date = JSONX.str(d["date"])
        year = JSONX.str(d["year"]); badges = (d["badges"] as? [String]) ?? []
    }
}

struct Episode: Identifiable {
    let id = UUID()
    let url: String; let season: Int?; let ep: Int?; let title: String
    init(_ d: [String: Any]) {
        url = JSONX.str(d["url"]); season = JSONX.int(d["season"]); ep = JSONX.int(d["ep"]); title = JSONX.str(d["title"])
    }
}

struct Provider: Identifiable {
    let id = UUID()
    let name: String; let url: String; let active: Bool
    init(_ d: [String: Any]) {
        name = JSONX.str(d["name"]); url = JSONX.str(d["url"]); active = (d["active"] as? Bool) ?? false
    }
}

struct Season: Identifiable {
    let id = UUID()
    let n: Int; let kod: String; let label: String
    init(_ d: [String: Any]) {
        n = JSONX.int(d["n"]) ?? 1; kod = JSONX.str(d["kod"]); label = JSONX.str(d["label"])
    }
}

let CATS: [(String, String)] = [
    ("akcio", "Akció"), ("animacios", "Animációs"), ("befejezett", "Befejezett"), ("bunugyi", "Bűnügyi"),
    ("csaladi", "Családi"), ("dokumentum", "Dokumentum"), ("drama", "Dráma"), ("eletrajzi", "Életrajzi"),
    ("fantasy", "Fantasy"), ("haborus", "Háborús"), ("horror", "Horror"), ("ismeretterjeszto", "Ismeretterjesztő"),
    ("kaland", "Kaland"), ("krimi", "Krimi"), ("mese", "Mese"), ("minisorozat", "Minisorozat"),
    ("misztikus", "Misztikus"), ("politikai", "Politikai"), ("reality", "Reality"), ("romantikus", "Romantikus"),
    ("sci-fi", "Sci-fi"), ("sport", "Sport"), ("telenovella", "Telenovella"), ("thriller", "Thriller"),
    ("tortenelmi", "Történelmi"), ("vigjatek", "Vígjáték"), ("western", "Western"), ("zenes", "Zenés")
]

// ---------- Kártya rács ----------
struct CardGrid: View {
    let cards: [Card]
    let columns = [GridItem(.adaptive(minimum: 112), spacing: 12)]
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(cards) { c in
                NavigationLink(destination: DetailView(pageURL: c.url)) {
                    VStack(alignment: .leading, spacing: 6) {
                        ZStack(alignment: .topLeading) {
                            AsyncImage(url: URL(string: c.poster)) { phase in
                                if let img = phase.image { img.resizable().aspectRatio(contentMode: .fill) }
                                else { Color.white.opacity(0.06) }
                            }
                            .frame(height: 168)
                            .clipped()
                            .cornerRadius(10)
                            HStack(spacing: 4) {
                                if !c.sxxexx.isEmpty { Badge(t: c.sxxexx, c: Color.cyan.opacity(0.9)) }
                                if let imdb = c.badges.first(where: { $0.range(of: "^[0-9]", options: .regularExpression) != nil }) {
                                    Badge(t: "IMDb " + imdb, c: Color.yellow.opacity(0.85))
                                }
                            }
                            .padding(6)
                        }
                        Text(c.title).font(.system(size: 12.5, weight: .semibold)).lineLimit(2).foregroundColor(.white)
                        Text(c.date.isEmpty ? c.year : c.date).font(.system(size: 10.5)).foregroundColor(Color.white.opacity(0.55))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct Badge: View {
    let t: String; let c: Color
    var body: some View {
        Text(t).font(.system(size: 9.5, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 3)
            .background(Color.black.opacity(0.72)).foregroundColor(c).cornerRadius(6)
    }
}

struct LoadingView: View {
    var text = "Betöltés..."
    var body: some View {
        VStack(spacing: 14) {
            ProgressView().scaleEffect(1.3)
            Text(text).font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ---------- Kezdőlap ----------
struct HomeView: View {
    @State private var sections: [(String, [Card])] = []
    @State private var loading = true
    var body: some View {
        ScrollView {
            if loading { LoadingView().frame(height: 420) }
            else {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(sections, id: \.0) { s in
                        if !s.1.isEmpty {
                            Text(s.0).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                            CardGrid(cards: Array(s.1.prefix(18)))
                        }
                    }
                }.padding(14)
            }
        }
        .background(Color(red: 0.043, green: 0.059, blue: 0.102).ignoresSafeArea())
        .navigationTitle("DMD Media")
        .onAppear { if sections.isEmpty { load() } }
    }
    func load() {
        let g = DispatchGroup()
        var home: [String: Any] = [:], sor: [String: Any] = [:], film: [String: Any] = [:]
        let targets: [(String, String)] = [("home", BASE + "/"), ("sor", BASE + "/sorozatok?orderby=friss"), ("film", BASE + "/filmek?orderby=friss")]
        for (key, u) in targets {
            g.enter()
            Scraper.shared.scrape(u) { r in
                if case .success(let d) = r {
                    if key == "sor" { sor = d } else if key == "film" { film = d } else { home = d }
                }
                g.leave()
            }
        }
        g.notify(queue: .main) {
            let hc = JSONX.arr(home["cards"]).map(Card.init)
            let sc = JSONX.arr(sor["cards"]).map(Card.init)
            let fc = JSONX.arr(film["cards"]).map(Card.init)
            sections = [
                ("Legújabb sorozat részek", sc.filter { $0.kind == "episode" }),
                ("TOP Sorozatok", hc.filter { $0.kind == "series" }),
                ("TOP Filmek", hc.filter { $0.kind == "movie" }),
                ("Legújabb filmek", fc.filter { $0.kind == "movie" }),
                ("Napi felkapott", hc)
            ]
            loading = false
        }
    }
}

// ---------- Lista ----------
struct CatalogView: View {
    let listURL: String
    let title: String
    var pagerBase: String? = nil
    @State private var cards: [Card] = []
    @State private var page = 1
    @State private var loading = true
    var body: some View {
        ScrollView {
            if loading { LoadingView().frame(height: 420) }
            else {
                VStack(spacing: 14) {
                    CardGrid(cards: cards).padding(14)
                    if let base = pagerBase {
                        HStack(spacing: 10) {
                            if page > 1 { Button("❮ Előző") { load(page - 1, base) } }
                            Text("\(page). oldal").foregroundColor(.white.opacity(0.7)).font(.system(size: 13))
                            Button("Következő ❯") { load(page + 1, base) }
                        }
                        .buttonStyle(.bordered)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .background(Color(red: 0.043, green: 0.059, blue: 0.102).ignoresSafeArea())
        .navigationTitle(title)
        .onAppear { if cards.isEmpty { load(1, pagerBase) } }
    }
    func load(_ p: Int, _ base: String?) {
        loading = true
        page = p
        var url = listURL
        if let base = base, p > 1 { url = base + String(p) }
        Scraper.shared.scrape(url) { r in
            DispatchQueue.main.async {
                if case .success(let d) = r { cards = JSONX.arr(d["cards"]).map(Card.init) }
                loading = false
            }
        }
    }
}

// ---------- Kategóriák ----------
struct CategoryView: View {
    let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(CATS, id: \.0) { slug, name in
                    NavigationLink(destination: CatalogView(listURL: BASE + "/kategoria/" + slug, title: name, pagerBase: BASE + "/kategoria/" + slug + "?oldal=")) {
                        Text(name).font(.system(size: 14.5, weight: .bold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(18)
                            .background(Color.white.opacity(0.05)).cornerRadius(12)
                    }.buttonStyle(.plain)
                }
            }.padding(14)
        }
        .background(Color(red: 0.043, green: 0.059, blue: 0.102).ignoresSafeArea())
        .navigationTitle("Kategóriák")
    }
}

// ---------- Keresés ----------
struct SearchView: View {
    @State private var q = ""
    @State private var cards: [Card] = []
    @State private var loading = false
    @State private var searched = false
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Keresés (cím, év, színész)...", text: $q)
                    .textFieldStyle(.roundedBorder).onSubmit { search() }
                Button("Keresés") { search() }.buttonStyle(.borderedProminent)
            }.padding(14)
            if loading { LoadingView() }
            else if searched && cards.isEmpty {
                Text("Nincs találat.").foregroundColor(.white.opacity(0.6)).padding(40)
            } else {
                ScrollView { CardGrid(cards: cards).padding(14) }
            }
            Spacer()
        }
        .background(Color(red: 0.043, green: 0.059, blue: 0.102).ignoresSafeArea())
        .navigationTitle("Keresés")
    }
    func search() {
        guard !q.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        loading = true; searched = true
        Scraper.shared.scrapePost(kind: "search", params: ["q": q]) { r in
            DispatchQueue.main.async {
                if case .success(let d) = r { cards = JSONX.arr(d["cards"]).map(Card.init) }
                loading = false
            }
        }
    }
}

// ---------- Részletek ----------
struct DetailView: View {
    let pageURL: String
    @State private var d: [String: Any] = [:]
    @State private var loading = true
    @State private var seasonN = 1
    @State private var eps: [Episode] = []
    @State private var seasons: [Season] = []
    @State private var kod = ""
    @State private var player: (String, String)? = nil
    @State private var providers: [Provider] = []

    var body: some View {
        ScrollView {
            if loading { LoadingView().frame(height: 420) }
            else {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        AsyncImage(url: URL(string: JSONX.str(d["poster"]))) { phase in
                            if let img = phase.image { img.resizable().aspectRatio(contentMode: .fill) }
                            else { Color.white.opacity(0.06) }
                        }
                        .frame(width: 130, height: 195).clipped().cornerRadius(12)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(JSONX.str(d["title"])).font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                            if !JSONX.str(d["year"]).isEmpty {
                                Text(JSONX.str(d["year"])).font(.system(size: 12)).foregroundColor(.white.opacity(0.6))
                            }
                            if let iframe = d["iframe"] as? String, !iframe.isEmpty {
                                Button {
                                    openWatch(url: iframe)
                                } label: {
                                    Label("Lejátszás", systemImage: "play.fill").frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent).tint(Color(red: 0.545, green: 0.361, blue: 0.965))
                            }
                            if !providers.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(providers) { p in
                                            Button(p.name) { openWatch(url: p.url) }
                                                .buttonStyle(.bordered).font(.system(size: 12))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if !JSONX.str(d["desc"]).isEmpty {
                        Text(JSONX.str(d["desc"])).font(.system(size: 13.5)).foregroundColor(Color.white.opacity(0.82)).lineSpacing(3)
                    }
                    if !seasons.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(seasons) { s in
                                    Button(s.label.isEmpty ? "\(s.n). évad" : s.label) {
                                        seasonN = s.n; loadSeason()
                                    }
                                    .buttonStyle(.bordered)
                                    .foregroundColor(s.n == seasonN ? Color(red: 0.13, green: 0.83, blue: 0.93) : .white)
                                }
                            }
                        }
                    }
                    if !eps.isEmpty {
                        Text("Epizódok").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                        ForEach(eps) { e in
                            Button {
                                openEpisode(e.url)
                            } label: {
                                HStack {
                                    Text(e.ep != nil ? "\(e.ep!). rész" : "Lejátszás")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(red: 0.13, green: 0.83, blue: 0.93))
                                    Text(e.title).font(.system(size: 12.5)).foregroundColor(.white.opacity(0.75)).lineLimit(2)
                                    Spacer()
                                    Image(systemName: "play.circle").foregroundColor(.white.opacity(0.5))
                                }
                                .padding(12).background(Color.white.opacity(0.05)).cornerRadius(11)
                            }.buttonStyle(.plain)
                        }
                    }
                    Text("Csak a lejátszó töltődik be — reklámblokkolóval.").font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
                }
                .padding(14)
            }
        }
        .background(Color(red: 0.043, green: 0.059, blue: 0.102).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: Binding(
            get: { player.map { PlayerItem(url: $0.0, title: $0.1) } },
            set: { _ in player = nil }
        )) { item in
            PlayerView(playerURL: item.url, title: item.title, episodeURL: pageURL)
        }
        .onAppear { if loading { load() } }
    }

    func load() {
        Scraper.shared.scrape(pageURL) { r in
            DispatchQueue.main.async {
                if case .success(let data) = r {
                    d = data
                    seasons = JSONX.arr(data["seasons"]).map(Season.init)
                    eps = JSONX.arr(data["episodes"]).map(Episode.init)
                    providers = JSONX.arr(data["providers"]).map(Provider.init)
                    if let s = seasons.first { seasonN = s.n; kod = s.kod }
                    else { kod = guessKod(pageURL) }
                }
                loading = false
            }
        }
    }

    func loadSeason() {
        loading = true
        Scraper.shared.scrapePost(kind: "season", params: ["kod": kod, "evad": String(seasonN)]) { r in
            DispatchQueue.main.async {
                if case .success(let data) = r { eps = JSONX.arr(data["episodes"]).map(Episode.init) }
                loading = false
            }
        }
    }

    func openEpisode(_ url: String) {
        loading = true
        Scraper.shared.scrape(url) { r in
            DispatchQueue.main.async {
                loading = false
                if case .success(let data) = r {
                    if let iframe = data["iframe"] as? String, !iframe.isEmpty {
                        player = (iframe, JSONX.str(data["title"]))
                    }
                }
            }
        }
    }

    func openWatch(url: String) {
        if url.contains("dmdamedia.hu") && url.contains("?a=") {
            Scraper.shared.scrape(url) { r in
                DispatchQueue.main.async {
                    if case .success(let data) = r, let iframe = data["iframe"] as? String, !iframe.isEmpty {
                        player = (iframe, JSONX.str(data["title"]))
                    }
                }
            }
        } else {
            player = (url, JSONX.str(d["title"]))
        }
    }

    func guessKod(_ u: String) -> String {
        guard let comps = URL(string: u)?.pathComponents, comps.count > 1 else { return "" }
        return comps[1]
    }
}

struct PlayerItem: Identifiable {
    let id = UUID()
    let url: String
    let title: String
}

// ---------- Lejátszó (CSAK a lejátszó töltődik be) ----------
struct PlayerView: View {
    let playerURL: String
    let title: String
    let episodeURL: String
    @Environment(\.presentationMode) var dismiss
    @State private var providers: [Provider] = []
    @State private var current: String

    init(playerURL: String, title: String, episodeURL: String) {
        self.playerURL = playerURL
        self.title = title
        self.episodeURL = episodeURL
        _current = State(initialValue: playerURL)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss.wrappedValue.dismiss() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 17, weight: .bold))
                }
                Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Spacer()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(providers) { p in
                            Button(p.name) { switchTo(p.url) }
                                .buttonStyle(.bordered).font(.system(size: 11))
                        }
                    }
                }
            }
            .padding(10)
            .background(Color(red: 0.043, green: 0.059, blue: 0.102))
            .foregroundColor(.white)
            PlayerWebView(urlString: current)
                .background(Color.black)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            Scraper.shared.scrape(episodeURL) { r in
                DispatchQueue.main.async {
                    if case .success(let d) = r { providers = JSONX.arr(d["providers"]).map(Provider.init) }
                }
            }
        }
    }

    func switchTo(_ url: String) {
        var u = url
        if u.hasPrefix("?") { u = episodeURL.replacingOccurrences(of: "#.*", with: "", options: .regularExpression) + u }
        Scraper.shared.scrape(u) { r in
            DispatchQueue.main.async {
                if case .success(let d) = r, let iframe = d["iframe"] as? String, !iframe.isEmpty {
                    current = iframe
                }
            }
        }
    }
}

struct PlayerWebView: UIViewRepresentable {
    let urlString: String
    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        AdBlock.install(on: cfg)
        let w = WKWebView(frame: .zero, configuration: cfg)
        w.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1 DMDMedia/2.0"
        w.uiDelegate = context.coordinator
        w.navigationDelegate = context.coordinator
        if let u = URL(string: urlString) {
            var req = URLRequest(url: u)
            req.setValue("https://dmdamedia.hu/", forHTTPHeaderField: "Referer")
            w.load(req)
        }
        return w
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let u = URL(string: urlString), uiView.url?.absoluteString != urlString {
            var req = URLRequest(url: u)
            req.setValue("https://dmdamedia.hu/", forHTTPHeaderField: "Referer")
            uiView.load(req)
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        // popup-tiltas: target=_blank / window.open nem nyit ablakot (reklam)
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            return nil
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let host = navigationAction.request.url?.host?.lowercased() else {
                decisionHandler(.cancel); return
            }
            let adLike = ["gatecpm", "doubleclick", "googlesyndication", "popads", "exoclick", "adsterra", "propeller", "onclickads"]
            for a in adLike where host.contains(a) {
                decisionHandler(.cancel); return
            }
            decisionHandler(.allow)
        }
    }
}

// ---------- Gyökér ----------
struct RootView: View {
    var body: some View {
        TabView {
            NavigationView { HomeView() }
                .tabItem { Label("Kezdőlap", systemImage: "house.fill") }
            NavigationView { CatalogView(listURL: BASE + "/sorozatok?orderby=friss", title: "Sorozatok", pagerBase: BASE + "/sorozatok/friss/oldal/") }
                .tabItem { Label("Sorozatok", systemImage: "tv.fill") }
            NavigationView { CatalogView(listURL: BASE + "/filmek?orderby=friss", title: "Filmek", pagerBase: BASE + "/filmek/friss/oldal/") }
                .tabItem { Label("Filmek", systemImage: "film.fill") }
            NavigationView { CategoryView() }
                .tabItem { Label("Kategóriák", systemImage: "square.grid.2x2.fill") }
            NavigationView { SearchView() }
                .tabItem { Label("Keresés", systemImage: "magnifyingglass") }
        }
        .accentColor(Color(red: 0.545, green: 0.361, blue: 0.965))
        .preferredColorScheme(.dark)
    }
}

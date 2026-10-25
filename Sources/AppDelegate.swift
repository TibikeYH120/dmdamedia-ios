import UIKit
import WebKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.rootViewController = BrowserViewController()
        w.makeKeyAndVisible()
        window = w
        return true
    }
}

final class BrowserViewController: UIViewController, WKNavigationDelegate {
    var webView: WKWebView!
    private let home = URL(string: "https://dmdamedia.hu/")!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.043, green: 0.059, blue: 0.102, alpha: 1)

        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        let script = WKUserScript(source: Self.inject, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        cfg.userContentController.addUserScript(script)

        webView = WKWebView(frame: view.bounds, configuration: cfg)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = view.backgroundColor
        view.addSubview(webView)
        webView.load(URLRequest(url: home))
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }

    // Ugyanaz a sotet dizajn + kompakt alkalmazas-sav, mint az asztali verzio.
    static let inject = """
    (function(){
      if (document.getElementById('dmd-chrome')) return;
      var css = document.createElement('style');
      css.textContent = `
        html{background:#0B0F1A}
        body{background:#0B0F1A!important;color:#E6E9F0!important;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif!important;padding-top:calc(env(safe-area-inset-top) + 50px)!important}
        #dmd-chrome{position:fixed;top:0;left:0;right:0;height:calc(env(safe-area-inset-top) + 50px);padding-top:env(safe-area-inset-top);z-index:2147483647;display:flex;align-items:center;gap:8px;padding-left:12px;padding-right:12px;box-sizing:border-box;background:rgba(11,15,26,0.97);border-bottom:1px solid rgba(139,92,246,0.25)}
        #dmd-chrome button{width:40px;height:40px;border-radius:12px;border:1px solid rgba(139,92,246,0.35);background:#141A2A;color:#E6E9F0;font-size:17px}
        #dmd-chrome .b{font-weight:800;font-size:12px;letter-spacing:0.6px;background:linear-gradient(90deg,#8B5CF6,#22D3EE);-webkit-background-clip:text;background-clip:text;color:transparent;margin-right:2px}
        #dmd-chrome .l{display:flex;gap:2px;margin-left:4px}
        #dmd-chrome .l a{color:#B7C0D4;text-decoration:none;font-size:12px;font-weight:600;padding:10px 10px;border-radius:10px}
        h1,h2,h3,h4{color:#F2F5FB!important}
        a{color:#9DB4E8}
        img{border-radius:10px}
        input,select,textarea{background:#141A2A!important;color:#E6E9F0!important;border:1px solid rgba(139,92,246,0.35)!important;border-radius:10px!important;padding:10px 12px!important}
        button,input[type=submit],input[type=button],.btn{background:#8B5CF6!important;color:#fff!important;border:0!important;border-radius:10px!important;padding:10px 16px!important;font-weight:600!important}
        ::-webkit-scrollbar{width:0;height:0}
      `;
      document.head.appendChild(css);
      var bar = document.createElement('div');
      bar.id = 'dmd-chrome';
      bar.innerHTML = '<span class="b">DMD MEDIA</span>' +
        '<button data-a="back">&#8592;</button>' +
        '<button data-a="fwd">&#8594;</button>' +
        '<button data-a="reload">&#8635;</button>' +
        '<span class="l">' +
          '<a href="https://dmdamedia.hu/filmek">Filmek</a>' +
          '<a href="https://dmdamedia.hu/sorozatok">Sorozatok</a>' +
        '</span>' +
        '<span style="flex:1"></span>' +
        '<button data-a="home">&#8962;</button>';
      document.body.appendChild(bar);
      bar.addEventListener('click', function(e){
        var b = e.target.closest('button'); if(!b) return;
        var a = b.getAttribute('data-a');
        if(a==='back') history.back();
        else if(a==='fwd') history.forward();
        else if(a==='reload') location.reload();
        else if(a==='home') location.href='https://dmdamedia.hu/';
      });
    })();
    """
}

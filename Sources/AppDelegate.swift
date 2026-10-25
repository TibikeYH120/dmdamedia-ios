import SwiftUI
import UIKit
import WebKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AdBlock.prepare { _ in }
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.rootViewController = UIHostingController(rootView: RootView())
        w.makeKeyAndVisible()
        window = w
        return true
    }
}

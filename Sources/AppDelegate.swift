import UIKit

/// Deliberately a plain UIKit app with no storyboard and no scene manifest: one window, one
/// web view, nothing to configure in a GUI I cannot see. `RadioViewController` does the work;
/// this exists to put it on screen.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = RadioViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

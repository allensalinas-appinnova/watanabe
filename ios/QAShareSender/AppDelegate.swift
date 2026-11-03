import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    let configuration = UISceneConfiguration(name: "QA sender", sessionRole: session.role)
    configuration.delegateClass = SenderSceneDelegate.self
    return configuration
  }
}
final class SenderSceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
    guard let scene = scene as? UIWindowScene else { return }
    window = UIWindow(windowScene: scene)
    window?.rootViewController = SenderController()
    window?.makeKeyAndVisible()
  }
}

final class SenderController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad(); view.backgroundColor = .systemBackground
    let pdf = UIButton(type: .system); pdf.setTitle("Share PDF",for:.normal); pdf.addTarget(self,action:#selector(sharePDF),for:.touchUpInside)
    let image = UIButton(type:.system); image.setTitle("Share image",for:.normal); image.addTarget(self,action:#selector(shareImage),for:.touchUpInside)
    let stack = UIStackView(arrangedSubviews:[pdf,image]); stack.axis = .vertical; stack.spacing = 30; stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack);NSLayoutConstraint.activate([stack.centerXAnchor.constraint(equalTo:view.centerXAnchor),stack.centerYAnchor.constraint(equalTo:view.centerYAnchor)])
  }
  @objc func sharePDF() { share("pdf",data:ReceiptFixtures.pdf) }
  @objc func shareImage() { share("png",data:ReceiptFixtures.image) }
  func share(_ ext:String,data:Data) {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("qa-receipt.\(ext)")
    try! data.write(to:url)
    let activity = UIActivityViewController(activityItems:[url],applicationActivities:nil)
    activity.popoverPresentationController?.sourceView = view
    present(activity,animated:true)
  }
}

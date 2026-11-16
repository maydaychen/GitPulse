#if os(iOS)
import UIKit
import SwiftUI
import UniformTypeIdentifiers
import GiteaKit

@objc(ShareViewController)
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        Task { @MainActor in
            let urlString = await extractSharedURLString()
            let route = DeepLinkRouter.parse(urlString)
            let card = ShareTargetCardView(
                sharedURLString: urlString,
                parsedRoute: route,
                onConfirm: { [weak self] in
                    self?.extensionContext?.completeRequest(returningItems: nil)
                },
                onCancel: { [weak self] in
                    self?.extensionContext?.cancelRequest(withError: NSError(domain: "com.maydaychen.teapulse.share", code: 0))
                }
            )
            let hosting = UIHostingController(rootView: card)
            addChild(hosting)
            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(hosting.view)
            NSLayoutConstraint.activate([
                hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            hosting.didMove(toParent: self)
        }
    }

    private func extractSharedURLString() async -> String {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return "" }
        for item in items {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                    return url.absoluteString
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                    return text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return ""
    }
}
#endif

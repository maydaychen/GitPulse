#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import GiteaKit

@objc(MacShareViewController)
final class MacShareViewController: NSViewController {
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 240))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
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
                    self?.extensionContext?.cancelRequest(withError: NSError(domain: "com.maydaychen.teapulse.macshare", code: 0))
                }
            )
            let hosting = NSHostingView(rootView: card)
            hosting.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(hosting)
            NSLayoutConstraint.activate([
                hosting.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hosting.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hosting.topAnchor.constraint(equalTo: view.topAnchor),
                hosting.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
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

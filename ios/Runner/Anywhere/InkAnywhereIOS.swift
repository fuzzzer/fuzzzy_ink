import Flutter
import SwiftUI
import UIKit

/// "Lock from other apps" on an iPhone (experimental): the native "Lock a
/// message" sheet over Fuzzzy Ink, opened by the App Shortcut (Shortcuts,
/// Siri, Spotlight, the Action button). It is a system sheet (medium and
/// large, with the grabber), which iOS 26 draws as Liquid Glass; the content
/// is the shared SwiftUI view (apple/Anywhere).
///
/// While it is up, the window stays out of screenshots and recordings (the
/// app's own secure-field technique, [InkGuard.holdSecure]). When it goes
/// away, whatever happened, `relock` goes to Dart.
@available(iOS 15.0, *)
@MainActor
final class InkAnywhereIOS: NSObject, AnywhereHost, UIAdaptivePresentationControllerDelegate {
  static let shared = InkAnywhereIOS()

  private var channel: InkAnywhereChannel?
  private var sheet: UIViewController?
  private var model: InkAnywhereModel?
  /// A request that came before the engine was up (a cold start from the
  /// Shortcut).
  private var waiting: AnywhereMode?

  func register(messenger: FlutterBinaryMessenger) {
    let channel = InkAnywhereChannel(messenger: messenger)
    channel.onEvent = { [weak self] event, arguments in
      self?.model?.handle(event: event, arguments)
    }
    self.channel = channel
    if let mode = waiting {
      waiting = nil
      present(mode: mode)
    }
  }

  /// Puts the sheet over the app. Its first step asks Dart where things
  /// stand: off, locked (Face ID or the master password), or ready.
  func present(mode: AnywhereMode) {
    guard let channel else {
      waiting = mode
      return
    }
    guard sheet == nil, let top = InkAnywhereIOS.topController() else { return }
    let model = InkAnywhereModel(channel: channel, mode: mode)
    model.host = self
    let controller = UIHostingController(rootView: InkAnywhereView(model: model))
    controller.modalPresentationStyle = .pageSheet
    if #available(iOS 26.0, *) {
      // The system sheet's own glass shows through.
      controller.view.backgroundColor = .clear
    }
    if let sheet = controller.sheetPresentationController {
      sheet.detents = [.medium(), .large()]
      sheet.prefersGrabberVisible = true
    }
    controller.presentationController?.delegate = self
    self.model = model
    self.sheet = controller
    InkGuard.shared.holdSecure(true)
    top.present(controller, animated: true)
    Task { await model.start() }
  }

  // MARK: AnywhereHost

  /// Fuzzzy Ink is right under the sheet: `show` and `openInApp` put their
  /// screen there, then the sheet closes ([finish]).
  func bringAppForward() {}

  func finish() {
    guard let sheet else { return }
    sheet.dismiss(animated: true) { [weak self] in self?.ended() }
  }

  func share(_ sealed: String) {
    guard let sheet else { return }
    let activity = UIActivityViewController(activityItems: [sealed], applicationActivities: nil)
    activity.popoverPresentationController?.sourceView = sheet.view
    sheet.present(activity, animated: true)
  }

  // MARK: UIAdaptivePresentationControllerDelegate

  /// Swiped down.
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    ended()
  }

  private func ended() {
    guard let model else { return }
    self.model = nil
    sheet = nil
    InkGuard.shared.holdSecure(false)
    Task { await model.close() }
  }

  private static func topController() -> UIViewController? {
    var top = UIApplication.shared.delegate?.window??.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}

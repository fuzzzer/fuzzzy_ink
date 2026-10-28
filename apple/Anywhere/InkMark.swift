import SwiftUI

#if os(macOS)
  import AppKit
  import FlutterMacOS
  typealias InkPlatformImage = NSImage
#else
  import Flutter
  import UIKit
  typealias InkPlatformImage = UIImage
#endif

/// Fuzzzy Ink's mark (the drop in the sun) from the app's own Flutter
/// assets, so the native pieces show the same logo as the app.
@available(iOS 15.0, macOS 12.0, *)
enum InkMark {
  /// The brand red of the mark (`assets/logo/ink_mark.svg`).
  static let red = Color(red: 0xB2 / 255, green: 0x26 / 255, blue: 0x1D / 255)

  static let image: InkPlatformImage? = load("assets/logo/3.0x/ink_mark.png")

  static func load(_ asset: String) -> InkPlatformImage? {
    let key = FlutterDartProject.lookupKey(forAsset: asset)
    var bundles = [Bundle.main]
    #if os(macOS)
      if let frameworks = Bundle.main.privateFrameworksPath,
        let app = Bundle(path: frameworks + "/App.framework")
      {
        bundles.append(app)
      }
    #endif
    for bundle in bundles {
      if let path = bundle.path(forResource: key, ofType: nil),
        let image = InkPlatformImage(contentsOfFile: path)
      {
        return image
      }
    }
    return nil
  }
}

/// The mark, or a drop symbol when the asset is not there (previews).
@available(iOS 15.0, macOS 12.0, *)
struct InkMarkView: View {
  var size: CGFloat = 22

  var body: some View {
    Group {
      if let image = InkMark.image {
        #if os(macOS)
          Image(nsImage: image).resizable()
        #else
          Image(uiImage: image).resizable()
        #endif
      } else {
        Image(systemName: "drop.circle.fill").resizable().foregroundColor(InkMark.red)
      }
    }
    .aspectRatio(contentMode: .fit)
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

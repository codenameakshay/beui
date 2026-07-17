import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    // Open the gallery at a comfortable desktop size. Disable state
    // restoration + autosave so a previously-restored frame doesn't win.
    self.isRestorable = false
    self.setFrameAutosaveName("")
    self.setContentSize(NSSize(width: 1440, height: 900))
    self.center()
  }
}

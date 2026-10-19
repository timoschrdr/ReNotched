import AppKit
import SwiftUI

struct Track {
    var title: String
    var artist: String
    var artwork: NSImage?
    var artID = 0              // changes with every new cover → triggers the cover animation
    var tint: Color = .white   // dominant colour of the cover
    var duration: Double = 0
}

import SwiftUI

#if os(macOS)
import AppKit

struct PlatformColors {
    static var controlBackground: Color {
        Color(NSColor.controlBackgroundColor)
    }
    
    static var separator: Color {
        Color(NSColor.separatorColor)
    }
    
    static var windowBackground: Color {
        Color(NSColor.windowBackgroundColor)
    }
    
    static var textBackground: Color {
        Color(NSColor.textBackgroundColor)
    }
    
    static var secondarySystemBackground: Color {
        Color(NSColor.controlBackgroundColor)
    }
}

#elseif os(iOS)
import UIKit

struct PlatformColors {
    static var controlBackground: Color {
        Color(.systemBackground)
    }
    
    static var separator: Color {
        Color(.separator)
    }
    
    static var windowBackground: Color {
        Color(.systemBackground)
    }
    
    static var textBackground: Color {
        Color(.secondarySystemBackground)
    }
    
    static var secondarySystemBackground: Color {
        Color(.secondarySystemBackground)
    }
}

#endif


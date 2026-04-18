import SwiftUI
import ImageIO

#if canImport(UIKit) && !os(visionOS)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit) && !os(visionOS)
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
typealias PlatformImage = NSImage
#elseif os(visionOS)
typealias PlatformImage = CGImage
#else
typealias PlatformImage = CGImage
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if canImport(UIKit) && !os(visionOS)
        self = Image(uiImage: platformImage)
        #elseif canImport(AppKit)
        self = Image(nsImage: platformImage)
        #elseif os(visionOS)
        self = Image(decorative: platformImage, scale: 1.0)
        #else
        self = Image(systemName: "photo")
        #endif
    }
}

func platformImage(from data: Data) -> PlatformImage? {
    #if canImport(UIKit) && !os(visionOS)
    return PlatformImage(data: data)
    #elseif canImport(AppKit)
    return PlatformImage(data: data)
    #elseif os(visionOS)
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
    #else
    return nil
    #endif
}

func platformImage(from fileURL: URL) -> PlatformImage? {
    #if canImport(UIKit) && !os(visionOS)
    return PlatformImage(contentsOfFile: fileURL.path)
    #elseif canImport(AppKit)
    return PlatformImage(contentsOf: fileURL)
    #elseif os(visionOS)
    guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
    #else
    return nil
    #endif
}

extension Color {
    static var platformSecondaryBackground: Color {
        #if canImport(UIKit) && !os(visionOS)
        return Color(.secondarySystemBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor.windowBackgroundColor)
        #else
        return Color.secondary.opacity(0.08)
        #endif
    }

    static var platformSystemBackground: Color {
        #if canImport(UIKit) && !os(visionOS)
        return Color(.systemBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor.windowBackgroundColor)
        #else
        return Color.black
        #endif
    }

    static var platformSeparator: Color {
        #if canImport(UIKit) && !os(visionOS)
        return Color(.separator)
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor.separatorColor)
        #else
        return Color.white.opacity(0.15)
        #endif
    }

    static var platformTertiaryLabel: Color {
        #if canImport(UIKit) && !os(visionOS)
        return Color(.tertiaryLabel)
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor.secondaryLabelColor)
        #else
        return Color.secondary.opacity(0.7)
        #endif
    }

    static var platformSystemFill: Color {
        #if canImport(UIKit) && !os(visionOS)
        return Color(.systemFill)
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor.controlBackgroundColor)
        #else
        return Color.secondary.opacity(0.12)
        #endif
    }
}

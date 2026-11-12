import AppKit
import CodexBarCore
import XCTest
@testable import CodexBar

/// Custom build: checks the green/orange/red thresholds and can render a preview of the coloured Claude icon.
///
/// Preview:
///   CODEXBAR_COLOR_PREVIEW_PATH=/path/to/preview.png swift test --filter IconColorThresholdTests
@MainActor
final class IconColorThresholdTests: XCTestCase {
    func test_thresholds() {
        XCTAssertEqual(IconRenderer.remainingTint(100), .systemGreen)
        XCTAssertEqual(IconRenderer.remainingTint(50), .systemGreen)
        XCTAssertEqual(IconRenderer.remainingTint(49.9), .systemOrange)
        XCTAssertEqual(IconRenderer.remainingTint(25), .systemOrange)
        XCTAssertEqual(IconRenderer.remainingTint(24.9), .systemRed)
        XCTAssertEqual(IconRenderer.remainingTint(0), .systemRed)
        XCTAssertEqual(IconRenderer.remainingTint(nil), .systemGray)
    }

    func test_meterIconIsFullColour() {
        let icon = IconRenderer.makeIcon(
            primaryRemaining: 80,
            weeklyRemaining: 20,
            creditsRemaining: nil,
            stale: false,
            style: .claude,
            quotaLayoutPolicy: .provider(.claude))
        XCTAssertFalse(icon.isTemplate)
    }

    func test_renderPreview() throws {
        guard let path = ProcessInfo.processInfo.environment["CODEXBAR_COLOR_PREVIEW_PATH"] else {
            throw XCTSkip("Set CODEXBAR_COLOR_PREVIEW_PATH to render the preview.")
        }
        // (session left %, weekly left %)
        let cases: [(Double, Double)] = [(90, 75), (60, 40), (35, 20), (12, 55)]
        let iconSide: CGFloat = 18 * 5
        let cellW: CGFloat = 170
        let labelH: CGFloat = 44
        let cellH: CGFloat = iconSide + labelH + 24
        let size = NSSize(width: cellW * CGFloat(cases.count), height: cellH * 2)
        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0))
        NSGraphicsContext.saveGraphicsState()
        let ctx = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: rep))
        NSGraphicsContext.current = ctx
        ctx.imageInterpolation = .none

        for (row, name) in [NSAppearance.Name.aqua, .darkAqua].enumerated() {
            let appearance = try XCTUnwrap(NSAppearance(named: name))
            appearance.performAsCurrentDrawingAppearance {
                let y = size.height - CGFloat(row + 1) * cellH
                let isLight = name == .aqua
                NSColor(white: isLight ? 0.93 : 0.13, alpha: 1).setFill()
                NSRect(x: 0, y: y, width: size.width, height: cellH).fill()
                let textColor = NSColor(white: isLight ? 0.15 : 0.9, alpha: 1)
                for (col, value) in cases.enumerated() {
                    let icon = IconRenderer.makeIcon(
                        primaryRemaining: value.0,
                        weeklyRemaining: value.1,
                        creditsRemaining: nil,
                        stale: false,
                        style: .claude,
                        quotaLayoutPolicy: .provider(.claude))
                    let x = CGFloat(col) * cellW + (cellW - iconSide) / 2
                    icon.draw(in: NSRect(x: x, y: y + labelH + 12, width: iconSide, height: iconSide))
                    let label = "Session \(Int(value.0))% left\nWeek \(Int(value.1))% left"
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    (label as NSString).draw(
                        in: NSRect(x: CGFloat(col) * cellW, y: y + 6, width: cellW, height: labelH),
                        withAttributes: [
                            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
                            .foregroundColor: textColor,
                            .paragraphStyle: style,
                        ])
                }
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: path), options: .atomic)
        print("Wrote \(path)")
    }
}

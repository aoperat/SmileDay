import AppKit

let canvas = NSSize(width: 1080, height: 1080)
let outputDirectory = URL(fileURLWithPath: "docs/marketing/instagram-carousel", isDirectory: true)
let cocoa = NSColor(calibratedRed: 0.25, green: 0.18, blue: 0.22, alpha: 1)
let coral = NSColor(calibratedRed: 1.00, green: 0.38, blue: 0.24, alpha: 1)
let orange = NSColor(calibratedRed: 1.00, green: 0.63, blue: 0.26, alpha: 1)
let yellow = NSColor(calibratedRed: 1.00, green: 0.78, blue: 0.24, alpha: 1)
let cream = NSColor(calibratedRed: 1.00, green: 0.97, blue: 0.91, alpha: 1)
let muted = NSColor(calibratedRed: 0.49, green: 0.41, blue: 0.45, alpha: 1)

func rectFromTop(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
    NSRect(x: x, y: canvas.height - y - height, width: width, height: height)
}

func fill(_ color: NSColor) {
    color.setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: canvas)).fill()
}

func roundedRect(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func text(
    _ string: String,
    x: CGFloat,
    top: CGFloat,
    width: CGFloat,
    height: CGFloat,
    size: CGFloat,
    weight: NSFont.Weight = .regular,
    color: NSColor = cocoa,
    alignment: NSTextAlignment = .left,
    lineSpacing: CGFloat = 0
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineSpacing = lineSpacing
    paragraph.lineBreakMode = .byWordWrapping
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph,
        .kern: -1.4
    ]
    NSAttributedString(string: string, attributes: attributes)
        .draw(in: rectFromTop(x, top, width, height))
}

func drawSmile(center: NSPoint, width: CGFloat, color: NSColor, lineWidth: CGFloat) {
    color.setStroke()
    color.setFill()
    let eyeRadius = lineWidth * 0.52
    NSBezierPath(ovalIn: NSRect(x: center.x - width * 0.23 - eyeRadius, y: center.y + width * 0.12, width: eyeRadius * 2, height: eyeRadius * 2)).fill()
    NSBezierPath(ovalIn: NSRect(x: center.x + width * 0.23 - eyeRadius, y: center.y + width * 0.12, width: eyeRadius * 2, height: eyeRadius * 2)).fill()
    let mouth = NSBezierPath()
    mouth.move(to: NSPoint(x: center.x - width * 0.34, y: center.y))
    mouth.curve(
        to: NSPoint(x: center.x + width * 0.34, y: center.y),
        controlPoint1: NSPoint(x: center.x - width * 0.18, y: center.y - width * 0.28),
        controlPoint2: NSPoint(x: center.x + width * 0.18, y: center.y - width * 0.28)
    )
    mouth.lineWidth = lineWidth
    mouth.lineCapStyle = .round
    mouth.stroke()
}

func drawImage(_ path: String, in rect: NSRect, radius: CGFloat = 0) {
    guard let image = NSImage(contentsOfFile: path) else { return }
    NSGraphicsContext.saveGraphicsState()
    if radius > 0 {
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    }
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

func drawPageNumber(_ number: Int, dark: Bool = true) {
    text(String(format: "%02d / 05", number), x: 850, top: 1000, width: 150, height: 40, size: 22, weight: .semibold, color: dark ? muted : cream.withAlphaComponent(0.85), alignment: .right)
}

func render(name: String, drawing: () -> Void) {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvas.width),
        pixelsHigh: Int(canvas.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("비트맵 생성 실패: \(name)")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    drawing()
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("PNG 생성 실패: \(name)")
    }
    try! png.write(to: outputDirectory.appendingPathComponent(name))
}

render(name: "01-cover.png") {
    fill(yellow)
    text("SMILEDAY", x: 80, top: 82, width: 920, height: 46, size: 28, weight: .bold, color: cocoa, alignment: .center)
    drawSmile(center: NSPoint(x: 540, y: 720), width: 390, color: cocoa, lineWidth: 27)
    text("웃으면\n좋잖아요", x: 80, top: 480, width: 920, height: 230, size: 98, weight: .heavy, color: cocoa, alignment: .center, lineSpacing: -5)
    roundedRect(rectFromTop(168, 798, 744, 86), radius: 43, color: cream.withAlphaComponent(0.92))
    text("잘 웃지 않는 나를 위한 작은 미소 습관", x: 168, top: 821, width: 744, height: 42, size: 27, weight: .semibold, color: muted, alignment: .center)
    drawPageNumber(1, dark: true)
}

render(name: "02-why.png") {
    fill(cream)
    text("웃을 일이\n적은 날에도", x: 82, top: 106, width: 916, height: 220, size: 88, weight: .heavy, color: cocoa, alignment: .center, lineSpacing: -6)
    text("미소 한 번은 내가 정할 수 있으니까.", x: 110, top: 355, width: 860, height: 56, size: 33, weight: .medium, color: muted, alignment: .center)
    roundedRect(rectFromTop(103, 488, 874, 388), radius: 70, color: yellow)
    drawSmile(center: NSPoint(x: 540, y: 375), width: 520, color: cocoa, lineWidth: 34)
    text("평가하지 않고, 부담 주지 않게", x: 110, top: 920, width: 860, height: 48, size: 28, weight: .semibold, color: cocoa, alignment: .center)
    drawPageNumber(2)
}

render(name: "03-loop.png") {
    fill(NSColor(calibratedRed: 1.0, green: 0.94, blue: 0.86, alpha: 1))
    text("아주 짧고\n단순하게", x: 74, top: 82, width: 480, height: 190, size: 82, weight: .heavy, color: cocoa, lineSpacing: -6)
    text("알림 → 5초 미소 → 완료", x: 76, top: 294, width: 540, height: 56, size: 31, weight: .bold, color: coral)
    roundedRect(rectFromTop(620, 76, 360, 850), radius: 68, color: cocoa.withAlphaComponent(0.10))
    drawImage("docs/marketing/screenshots/smileday-home.png", in: rectFromTop(650, 108, 300, 780), radius: 48)
    let steps = [("1", "원하는 시간에\n알림을 받고"), ("2", "몇 초 동안\n미소 짓고"), ("3", "오늘의 미소로\n기록해요")]
    for (index, step) in steps.enumerated() {
        let y = CGFloat(410 + index * 170)
        roundedRect(rectFromTop(76, y, 76, 76), radius: 38, color: index == 1 ? coral : yellow)
        text(step.0, x: 76, top: y + 17, width: 76, height: 42, size: 29, weight: .bold, color: cocoa, alignment: .center)
        text(step.1, x: 180, top: y - 3, width: 390, height: 92, size: 31, weight: .semibold, color: cocoa, lineSpacing: 3)
    }
    drawPageNumber(3)
}

render(name: "04-record.png") {
    fill(coral)
    text("오늘의 미소가\n하나씩 쌓여요", x: 80, top: 78, width: 920, height: 188, size: 78, weight: .heavy, color: cream, alignment: .center, lineSpacing: -6)
    text("잘했는지 채점하지 않고, 웃어본 순간만 가볍게 기록해요.", x: 100, top: 282, width: 880, height: 88, size: 29, weight: .medium, color: cream.withAlphaComponent(0.92), alignment: .center)
    roundedRect(rectFromTop(251, 390, 578, 558), radius: 60, color: cream.withAlphaComponent(0.25))
    drawImage("docs/marketing/screenshots/smileday-history.png", in: rectFromTop(281, 420, 518, 498), radius: 38)
    drawPageNumber(4, dark: false)
}

render(name: "05-cta.png") {
    fill(yellow)
    roundedRect(rectFromTop(420, 100, 240, 240), radius: 56, color: cream)
    drawImage("SmileDay/Assets.xcassets/AppIcon.appiconset/AppIcon-light.png", in: rectFromTop(438, 118, 204, 204), radius: 44)
    text("오늘,\n미소 한 번부터", x: 80, top: 405, width: 920, height: 210, size: 86, weight: .heavy, color: cocoa, alignment: .center, lineSpacing: -5)
    text("SmileDay와 시작해보세요", x: 110, top: 655, width: 860, height: 60, size: 36, weight: .bold, color: cocoa, alignment: .center)
    roundedRect(rectFromTop(180, 770, 720, 86), radius: 43, color: cream.withAlphaComponent(0.92))
    text("모든 기록은 내 기기에만 저장돼요", x: 180, top: 793, width: 720, height: 42, size: 27, weight: .semibold, color: muted, alignment: .center)
    drawSmile(center: NSPoint(x: 540, y: 120), width: 180, color: cocoa.withAlphaComponent(0.30), lineWidth: 14)
    drawPageNumber(5)
}

print("Instagram carousel generated at \(outputDirectory.path)")

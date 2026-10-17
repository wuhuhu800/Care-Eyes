import Cocoa

// 离屏渲染 1024x1024 应用图标：深色圆角底 + 抽象眼睛 + 倒计时环
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }

// 背景：深墨色圆角矩形
let inset: CGFloat = 32
let bgRect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let radius: CGFloat = 210
let bgPath = CGPath(roundedRect: bgRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.addPath(bgPath)
ctx.clip()
let colors = [
    NSColor(calibratedRed: 0.13, green: 0.14, blue: 0.17, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.08, alpha: 1).cgColor
] as CFArray
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
ctx.resetClip()

// 外圈进度环（暖色，暗示计时）
let center = CGPoint(x: size / 2, y: size / 2)
ctx.setStrokeColor(NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.30, alpha: 0.30).cgColor)
ctx.setLineWidth(26)
ctx.addArc(center: center, radius: 300, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.strokePath()

ctx.setStrokeColor(NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.30, alpha: 1.0).cgColor)
ctx.setLineWidth(26)
ctx.setLineCap(.round)
ctx.addArc(center: center, radius: 300, startAngle: .pi / 2, endAngle: .pi / 2 - .pi * 1.45, clockwise: true)
ctx.strokePath()

// 眼睛轮廓（杏仁形）
let eyeW: CGFloat = 380
let eyeH: CGFloat = 220
let eyePath = CGMutablePath()
eyePath.move(to: CGPoint(x: center.x - eyeW / 2, y: center.y))
eyePath.addQuadCurve(
    to: CGPoint(x: center.x + eyeW / 2, y: center.y),
    control: CGPoint(x: center.x, y: center.y + eyeH)
)
eyePath.addQuadCurve(
    to: CGPoint(x: center.x - eyeW / 2, y: center.y),
    control: CGPoint(x: center.x, y: center.y - eyeH)
)
ctx.addPath(eyePath)
ctx.setFillColor(NSColor.white.withAlphaComponent(0.95).cgColor)
ctx.fillPath()

// 瞳孔：闭眼状态用一道平线表达「休息」
let lid = CGRect(x: center.x - 92, y: center.y - 16, width: 184, height: 30)
ctx.setFillColor(NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.13, alpha: 1).cgColor)
let lidPath = CGPath(roundedRect: lid, cornerWidth: 15, cornerHeight: 15, transform: nil)
ctx.addPath(lidPath)
ctx.fillPath()

img.unlockFocus()

// 输出 PNG
guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
try! png.write(to: URL(fileURLWithPath: out))
print("icon written: \(out)")

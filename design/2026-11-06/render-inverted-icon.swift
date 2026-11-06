// Preview only. No application sources, settings or power assertions are changed.
// swift design/2026-11-06/render-inverted-icon.swift design/2026-11-06
import AppKit
import SwiftUI

private let amber = Color(nsColor: .systemOrange)
private let ink = Color(red: 0.13, green: 0.16, blue: 0.20)
private let secondary = Color(red: 0.38, green: 0.42, blue: 0.47)
private let circlePreview = CommandLine.arguments.contains("--circle")

private struct Circuit: View {
    var color: Color
    var size: CGFloat

    var body: some View {
        Canvas { context, frame in
            context.scaleBy(x: frame.width / 18, y: frame.height / 18)
            var ring = Path()
            ring.addArc(center: CGPoint(x: 9, y: 9), radius: 7,
                        startAngle: .degrees(-60), endAngle: .degrees(240), clockwise: false)
            context.stroke(ring, with: .color(color),
                           style: StrokeStyle(lineWidth: 1.55, lineCap: .round))
            let bolt = Path { p in
                p.move(to: CGPoint(x: 10, y: 3.5))
                p.addLine(to: CGPoint(x: 5.6, y: 9.4))
                p.addLine(to: CGPoint(x: 8.6, y: 9.4))
                p.addLine(to: CGPoint(x: 7.9, y: 14.3))
                p.addLine(to: CGPoint(x: 12.4, y: 8))
                p.addLine(to: CGPoint(x: 9.4, y: 8))
                p.closeSubpath()
            }
            context.fill(bolt, with: .color(color))
        }.frame(width: size, height: size)
    }
}

private struct Icon: View {
    var inverted: Bool
    var size: CGFloat = 18
    var circular = false

    var body: some View {
        ZStack {
            if inverted {
                if circular {
                    Circle().fill(amber)
                } else {
                    RoundedRectangle(cornerRadius: size * 0.235, style: .continuous)
                        .fill(amber)
                }
            }
            Circuit(color: inverted ? .white : amber, size: inverted ? size * 0.79 : size)
        }.frame(width: size, height: size)
    }
}

private struct MenuBar: View {
    var inverted: Bool
    var dark: Bool
    var circular = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "externaldrive").font(.system(size: 12))
            Image(systemName: "speaker.wave.2.fill").font(.system(size: 12)).padding(.leading, 6)
            Spacer(minLength: 10)
            Icon(inverted: inverted, circular: circular)
            Text("2:34").font(.system(size: 11, weight: .medium, design: .monospaced))
            Image(systemName: "wifi").font(.system(size: 12)).padding(.leading, 8)
            Text("周五  10:24").font(.system(size: 11)).padding(.leading, 4)
        }
        .padding(.horizontal, 14)
        .frame(height: 30)
        .foregroundStyle(dark ? Color.white : ink)
        .background(dark ? Color(red: 0.13, green: 0.17, blue: 0.22) : Color.white,
                    in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct PreviewColumn: View {
    var inverted: Bool
    var circular = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(circular ? "圆形底 · 这次调整" : (inverted ? "圆角方形底 · 上一版" : "现有图标"))
                .font(.system(size: 17, weight: .semibold))
            Text(inverted ? "黄色实心底 · 白色环形闪电" : "透明底 · 黄色环形闪电")
                .font(.system(size: 12)).foregroundStyle(secondary).padding(.top, 7)
            HStack(spacing: 26) {
                Icon(inverted: inverted, size: 96, circular: circular)
                VStack(alignment: .leading, spacing: 9) {
                    Text("放大看造型").font(.system(size: 12, weight: .medium))
                    Text(circular ? "黄色底改成正圆\n白色标识保持不变" : (inverted ? "保留原来的标识\n增加完整的色块" : "主要由圆环和闪电\n两部分线条构成"))
                        .font(.system(size: 12)).foregroundStyle(secondary).lineSpacing(5)
                }
            }.frame(height: 130).padding(.top, 19).padding(.bottom, 21)
            Text("菜单栏尺寸 · 18 pt")
                .font(.system(size: 11)).foregroundStyle(secondary).padding(.bottom, 10)
            MenuBar(inverted: inverted, dark: false, circular: circular)
            MenuBar(inverted: inverted, dark: true, circular: circular).padding(.top, 10)
        }.frame(width: 366, alignment: .leading)
    }
}

private struct Board: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(circlePreview ? "图标 C · 圆形底预览" : "图标 C · 反色预览").font(.system(size: 25, weight: .semibold))
            Text(circlePreview ? "沿用黄底白标，把圆角方形改成圆形。" : "把白底黄标换成黄底白标，看看在菜单栏里的存在感。")
                .font(.system(size: 13)).foregroundStyle(secondary).padding(.top, 10)
            HStack(alignment: .top, spacing: 44) {
                PreviewColumn(inverted: circlePreview)
                PreviewColumn(inverted: true, circular: circlePreview)
            }.padding(.top, 34)
            Rectangle().fill(ink.opacity(0.1)).frame(height: 1).padding(.top, 30)
            Text("仅设计预览 · 菜单栏与时间为示意 · 本轮未修改程序")
                .font(.system(size: 11)).foregroundStyle(secondary).padding(.top, 15)
        }
        .padding(36)
        .foregroundStyle(ink)
        .background(Color(red: 0.93, green: 0.95, blue: 0.97))
    }
}

try MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    let output = URL(fileURLWithPath: CommandLine.arguments.count > 1
                     ? CommandLine.arguments[1] : "design/2026-11-06", isDirectory: true)
    @MainActor func save<V: View>(_ view: V, _ name: String) throws {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
        renderer.scale = 2
        guard let image = renderer.cgImage,
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: output.appendingPathComponent(name))
        print("Rendered \(name): \(image.width) × \(image.height)")
    }
    try save(Board(), circlePreview ? "icon-c-circular-preview.png" : "icon-c-inverted-preview.png")
    try save(Icon(inverted: true, size: 256, circular: circlePreview).padding(32).background(Color.white),
             circlePreview ? "icon-c-circular-large.png" : "icon-c-inverted-large.png")
}

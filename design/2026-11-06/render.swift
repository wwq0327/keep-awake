// Standalone design study. Does not import or change the running app.
// Run: swift design/2026-11-06/render.swift design/2026-11-06
import AppKit
import SwiftUI

let ink = Color(red: 0.13, green: 0.16, blue: 0.20)
let muted = Color(red: 0.39, green: 0.43, blue: 0.48)
let orange = Color(red: 0.80, green: 0.36, blue: 0.04)
let green = Color(red: 0.13, green: 0.52, blue: 0.33)
let paper = Color(red: 0.97, green: 0.98, blue: 0.99)
let line = Color(red: 0.87, green: 0.89, blue: 0.91)
let slate = Color(red: 0.12, green: 0.17, blue: 0.23)
let mist = Color(red: 0.72, green: 0.77, blue: 0.82)

enum Mark: Int, CaseIterable {
    case sunrise, coffee, circuit
    var title: String { ["极昼 · 日出", "续杯 · 咖啡", "常亮 · 环形闪电"][rawValue] }
}

// All marks share an 18 pt artboard and are drawn as vectors.
struct Glyph: View {
    let mark: Mark
    var on = true
    var color = orange
    var size: CGFloat = 18
    var body: some View {
        Canvas { context, frame in
            let s = frame.width / 18
            context.scaleBy(x: s, y: s)
            let stroke = StrokeStyle(lineWidth: 1.55, lineCap: .round, lineJoin: .round)
            func draw(_ path: Path) { context.stroke(path, with: .color(color), style: stroke) }
            switch mark {
            case .sunrise:
                let sun = Path { p in
                    p.move(to: CGPoint(x: 4.5, y: 11.5))
                    p.addCurve(to: CGPoint(x: 13.5, y: 11.5), control1: CGPoint(x: 4.5, y: 5.2), control2: CGPoint(x: 13.5, y: 5.2))
                    p.closeSubpath()
                }
                if on { context.fill(sun, with: .color(color)) } else { draw(sun) }
                draw(Path { p in
                    p.move(to: CGPoint(x: 2, y: 12)); p.addLine(to: CGPoint(x: 16, y: 12))
                    p.move(to: CGPoint(x: 9, y: 2)); p.addLine(to: CGPoint(x: 9, y: 3.7))
                    p.move(to: CGPoint(x: 3.2, y: 4.5)); p.addLine(to: CGPoint(x: 4.4, y: 5.8))
                    p.move(to: CGPoint(x: 14.8, y: 4.5)); p.addLine(to: CGPoint(x: 13.6, y: 5.8))
                    p.move(to: CGPoint(x: 5, y: 15.2)); p.addLine(to: CGPoint(x: 13, y: 15.2))
                })
            case .coffee:
                let cup = Path { p in
                    p.move(to: CGPoint(x: 3, y: 6.5)); p.addLine(to: CGPoint(x: 12, y: 6.5))
                    p.addLine(to: CGPoint(x: 12, y: 10.7))
                    p.addQuadCurve(to: CGPoint(x: 9.4, y: 13.3), control: CGPoint(x: 12, y: 13.3))
                    p.addLine(to: CGPoint(x: 5.6, y: 13.3))
                    p.addQuadCurve(to: CGPoint(x: 3, y: 10.7), control: CGPoint(x: 3, y: 13.3)); p.closeSubpath()
                }
                if on { context.fill(cup, with: .color(color)) } else { draw(cup) }
                draw(Path { p in
                    p.move(to: CGPoint(x: 12, y: 7.4)); p.addLine(to: CGPoint(x: 13.9, y: 7.4))
                    p.addCurve(to: CGPoint(x: 12, y: 11.3), control1: CGPoint(x: 17.4, y: 7.4), control2: CGPoint(x: 16.4, y: 11.3))
                    p.move(to: CGPoint(x: 2.4, y: 15.4)); p.addLine(to: CGPoint(x: 14.2, y: 15.4))
                    p.move(to: CGPoint(x: 6, y: 4)); p.addCurve(to: CGPoint(x: 6.5, y: 1.7), control1: CGPoint(x: 4.8, y: 3.1), control2: CGPoint(x: 7.2, y: 2.8))
                    p.move(to: CGPoint(x: 9.4, y: 4)); p.addCurve(to: CGPoint(x: 9.9, y: 1.7), control1: CGPoint(x: 8.2, y: 3.1), control2: CGPoint(x: 10.6, y: 2.8))
                })
            case .circuit:
                draw(Path { p in
                    p.addArc(center: CGPoint(x: 9, y: 9), radius: 7, startAngle: .degrees(-60), endAngle: .degrees(240), clockwise: false)
                })
                let bolt = Path { p in
                    p.move(to: CGPoint(x: 10, y: 3.5)); p.addLine(to: CGPoint(x: 5.6, y: 9.4))
                    p.addLine(to: CGPoint(x: 8.6, y: 9.4)); p.addLine(to: CGPoint(x: 7.9, y: 14.3))
                    p.addLine(to: CGPoint(x: 12.4, y: 8)); p.addLine(to: CGPoint(x: 9.4, y: 8)); p.closeSubpath()
                }
                if on { context.fill(bolt, with: .color(color)) }
                else { context.stroke(bolt, with: .color(color), style: StrokeStyle(lineWidth: 1.1, lineJoin: .round)) }
            }
        }.frame(width: size, height: size).accessibilityLabel(mark.title)
    }
}

struct KeyCap: View {
    var dark = false
    var body: some View {
        Text("⌃⌥⌘K").font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(dark ? mist : muted).padding(.horizontal, 7).padding(.vertical, 4)
            .background((dark ? Color.white : ink).opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
    }
}

struct StateLabel: View {
    var on = true
    var dark = false
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(on ? (dark ? Color.orange : orange) : (dark ? mist : muted)).frame(width: 5, height: 5)
            Text(on ? "防闲置休眠已开启" : "已关闭 · 跟随系统设置")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(on ? (dark ? Color.orange : orange) : (dark ? mist : muted))
        }
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    var dark = false
    var body: some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundStyle(dark ? mist : muted)
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium, design: .monospaced))
                .monospacedDigit().foregroundStyle(dark ? Color.white : ink)
        }
    }
}

struct Action: View {
    var on = true
    var dark = false
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "power").font(.system(size: 12, weight: .semibold))
            Text(on ? "停止保持" : "开始保持唤醒").font(.system(size: 13, weight: .semibold))
        }.foregroundStyle(dark ? slate : (on ? ink : Color.white))
            .frame(maxWidth: .infinity).frame(height: 36)
            .background(dark ? Color(red: 1, green: 0.73, blue: 0.36) : (on ? ink.opacity(0.065) : orange), in: RoundedRectangle(cornerRadius: 9))
    }
}

struct CompactPanel: View {
    var on = true
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Glyph(mark: .circuit, on: on, color: on ? orange : muted)
                Text("Keep Awake").font(.system(size: 13, weight: .semibold))
                Spacer(); KeyCap()
            }.padding(.bottom, 18)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(on ? "保持唤醒中" : "跟随系统休眠").font(.system(size: 20, weight: .semibold))
                    Text("允许锁屏和熄屏").font(.system(size: 12)).foregroundStyle(muted)
                }
                Spacer()
                ZStack(alignment: on ? .trailing : .leading) {
                    Capsule().fill(on ? orange : muted.opacity(0.3)).frame(width: 38, height: 23)
                    Circle().fill(.white).frame(width: 19, height: 19).padding(2)
                }.frame(width: 38, height: 23)
            }.padding(.bottom, 18)
            Rectangle().fill(line).frame(height: 1)
            VStack(spacing: 14) {
                MetricRow(label: on ? "本次保持" : "上次保持", value: "02:34:18")
                MetricRow(label: "累计保持", value: "128:46:05")
                MetricRow(label: "程序已运行", value: "05:12:40")
            }.padding(.vertical, 18)
            Rectangle().fill(line).frame(height: 1)
            HStack(alignment: .top) {
                Text("手动睡眠、合盖和低电量仍可休眠").font(.system(size: 10)).foregroundStyle(muted)
                Spacer(minLength: 4)
                Text("退出").font(.system(size: 11)).foregroundStyle(muted)
            }.padding(.top, 14)
        }.padding(20).frame(width: 320, height: 296)
            .foregroundStyle(ink).background(paper)
    }
}

struct SessionPanel: View {
    var on = true
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Glyph(mark: .sunrise, on: on, color: on ? .orange : mist)
                Text("Keep Awake").font(.system(size: 13, weight: .semibold))
                Spacer(); KeyCap(dark: true)
            }.padding(.bottom, 25)
            StateLabel(on: on, dark: true)
            Text("02:34:18").font(.system(size: 45, weight: .light, design: .rounded))
                .monospacedDigit().tracking(-1).padding(.top, 9)
            Text(on ? "本次保持" : "上次保持").font(.system(size: 11)).foregroundStyle(mist).padding(.top, 5)
            HStack(spacing: 0) {
                VStack(spacing: 7) {
                    Text("累计保持").font(.system(size: 11)).foregroundStyle(mist)
                    Text("128:46:05").font(.system(size: 15, weight: .medium, design: .monospaced))
                }.frame(maxWidth: .infinity)
                Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1, height: 31)
                VStack(spacing: 7) {
                    Text("程序已运行").font(.system(size: 11)).foregroundStyle(mist)
                    Text("05:12:40").font(.system(size: 15, weight: .medium, design: .monospaced))
                }.frame(maxWidth: .infinity)
            }.padding(.top, 25).padding(.bottom, 22)
            Action(on: on, dark: true)
            Text("允许锁屏与熄屏").font(.system(size: 11)).foregroundStyle(mist).padding(.top, 13)
            HStack(alignment: .top) {
                Text("手动睡眠、合盖和低电量仍可休眠").font(.system(size: 10)).foregroundStyle(mist)
                Spacer(minLength: 4)
                Text("退出").font(.system(size: 11)).foregroundStyle(mist)
            }.padding(.top, 12)
        }.padding(22).frame(width: 340, height: 382).foregroundStyle(.white).background(slate)
    }
}

struct SplitPanel: View {
    var on = true
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Keep Awake").font(.system(size: 13, weight: .semibold))
                Spacer(); KeyCap()
            }.padding(.horizontal, 20).padding(.vertical, 16)
            Rectangle().fill(line).frame(height: 1)
            HStack(spacing: 0) {
                VStack(spacing: 12) {
                    Glyph(mark: .coffee, on: on, color: on ? orange : muted, size: 38)
                    VStack(spacing: 5) {
                        Text(on ? "正在保持" : "保持已关闭").font(.system(size: 14, weight: .semibold))
                        Text(on ? "防闲置休眠" : "跟随系统设置").font(.system(size: 10)).foregroundStyle(muted)
                    }
                }.frame(width: 124, height: 152)
                    .background(on ? orange.opacity(0.065) : muted.opacity(0.055))
                VStack(alignment: .leading, spacing: 0) {
                    Text(on ? "本次保持" : "上次保持").font(.system(size: 11)).foregroundStyle(muted)
                    Text("02:34:18").font(.system(size: 27, weight: .medium, design: .rounded))
                        .monospacedDigit().padding(.top, 4).padding(.bottom, 17)
                    MetricRow(label: "累计保持", value: "128:46:05")
                    MetricRow(label: "已运行", value: "05:12:40").padding(.top, 10)
                }.padding(.horizontal, 17).frame(maxWidth: .infinity)
            }
            Rectangle().fill(line).frame(height: 1)
            HStack(spacing: 12) {
                Action(on: on)
                Text("退出").font(.system(size: 12)).foregroundStyle(muted).frame(width: 32)
            }.padding(.horizontal, 18).padding(.top, 15)
            VStack(alignment: .leading, spacing: 3) {
                Text("允许锁屏与熄屏")
                Text("手动睡眠、合盖和低电量仍可休眠")
            }.font(.system(size: 10)).foregroundStyle(muted)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.top, 11)
            Spacer(minLength: 0)
        }.frame(width: 388, height: 328).foregroundStyle(ink).background(paper)
    }
}

struct FramedPanel<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    let mark: Mark
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Spacer()
                Glyph(mark: mark)
                Text("2:34").font(.system(size: 11, weight: .medium, design: .monospaced))
                Image(systemName: "wifi").font(.system(size: 12)).padding(.leading, 12)
                Text("周五  10:24").font(.system(size: 11)).padding(.leading, 6)
            }.foregroundStyle(ink).padding(.horizontal, 16).frame(height: 28)
                .background(Color.white.opacity(0.8))
            Triangle().fill(mark == .sunrise ? slate : paper).frame(width: 20, height: 10).offset(x: width / 2 - 153, y: 1)
            content.clipShape(RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(ink.opacity(0.08), lineWidth: 0.7))
                .shadow(color: ink.opacity(0.12), radius: 12, y: 6)
            Spacer(minLength: 0)
        }.frame(width: width, height: height)
    }
}

struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.closeSubpath() }
    }
}

struct UIColumn<Content: View>: View {
    let code: String
    let title: String
    let note: String
    let size: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(code).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(muted)
            Text(title).font(.system(size: 23, weight: .semibold)).padding(.top, 8)
            Text(size).font(.system(size: 11, design: .monospaced)).foregroundStyle(muted).padding(.top, 7).padding(.bottom, 24)
            content.frame(height: 430, alignment: .top)
            Text(note).font(.system(size: 13)).foregroundStyle(muted).lineSpacing(6).padding(.top, 18)
        }.frame(width: 388, alignment: .leading)
    }
}

struct UIBoard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Text("Keep Awake").font(.system(size: 32, weight: .semibold))
                Text("界面布局 · 三种方向").font(.system(size: 16)).foregroundStyle(muted).padding(.leading, 12)
                Spacer()
                Text("DESIGN STUDY / 2026.11").font(.system(size: 10, design: .monospaced)).foregroundStyle(muted)
            }
            Text("同一组功能，三种信息重心。图标与界面可以自由组合。").font(.system(size: 14)).foregroundStyle(muted).padding(.top, 12)
            HStack(alignment: .top, spacing: 30) {
                UIColumn(code: "UI A · 推荐", title: "原生轻面板", note: "开关前置，三项统计直接读。\n最适合随手开关、看完即走。", size: "320 × 296 pt") {
                    FramedPanel(width: 320, height: 430, mark: .circuit) { CompactPanel() }
                        .frame(width: 388)
                }
                UIColumn(code: "UI B", title: "会话计时台", note: "本次时长成为视觉中心。\n适合长时间保持，深色更安静。", size: "340 × 382 pt") {
                    FramedPanel(width: 340, height: 430, mark: .sunrise) { SessionPanel() }
                        .frame(width: 388)
                }
                UIColumn(code: "UI C", title: "状态与数据分区", note: "左侧看状态，右侧读数据。\n横向更舒展，主操作独立在下方。", size: "388 × 328 pt") {
                    FramedPanel(width: 388, height: 430, mark: .coffee) { SplitPanel() }
                }
            }.padding(.top, 38)
            Rectangle().fill(line).frame(height: 1).padding(.top, 28)
            HStack {
                Text("示意数据 · 非真实使用记录").font(.system(size: 11)).foregroundStyle(muted)
                Spacer()
                Text("保留：全局热键 / 三项时长 / 退出 / 锁屏与熄屏说明").font(.system(size: 11)).foregroundStyle(muted)
            }.padding(.top, 16)
        }.padding(44).frame(width: 1312).foregroundStyle(ink)
            .background(Color(red: 0.92, green: 0.94, blue: 0.96))
    }
}

struct IconColumn: View {
    let mark: Mark
    let description: String
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("ICON \(["A", "B", "C"][mark.rawValue])").font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(muted)
                if mark == .circuit { Text("推荐").font(.system(size: 10, weight: .medium)).foregroundStyle(orange).padding(.horizontal, 6).padding(.vertical, 3).background(orange.opacity(0.08), in: Capsule()) }
            }.frame(height: 22)
            Text(mark.title).font(.system(size: 23, weight: .semibold)).padding(.top, 8)
            HStack(spacing: 28) {
                ZStack {
                    RoundedRectangle(cornerRadius: 27).fill(paper)
                        .overlay(RoundedRectangle(cornerRadius: 27).stroke(Color.white, lineWidth: 2))
                    Glyph(mark: mark, size: 66)
                }.frame(width: 116, height: 116).shadow(color: ink.opacity(0.08), radius: 14, y: 6)
                VStack(alignment: .leading, spacing: 9) {
                    Text("应用图标示意").font(.system(size: 11, weight: .medium))
                    Text("共用菜单栏轮廓\n形成统一识别").font(.system(size: 11)).foregroundStyle(muted).lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }.padding(.top, 30).padding(.bottom, 26)
            HStack(spacing: 22) {
                iconState("保持开启", on: true, tint: orange)
                iconState("活跃 · 未开启", on: false, tint: green)
                iconState("闲置 · 未开启", on: false, tint: muted)
            }
            VStack(alignment: .leading, spacing: 9) {
                Text("菜单栏实际尺寸 · 18 pt").font(.system(size: 10)).foregroundStyle(muted)
                HStack(spacing: 7) {
                    Spacer(); Glyph(mark: mark)
                    Text("2:34").font(.system(size: 11, design: .monospaced))
                    Image(systemName: "wifi").font(.system(size: 11)).padding(.leading, 12)
                    Text("10:24").font(.system(size: 11)).padding(.leading, 8)
                }.frame(height: 30).padding(.horizontal, 12)
                    .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 6))
                HStack(spacing: 7) {
                    Spacer(); Glyph(mark: mark, color: .orange)
                    Text("2:34").font(.system(size: 11, design: .monospaced))
                    Image(systemName: "wifi").font(.system(size: 11)).padding(.leading, 12)
                    Text("10:24").font(.system(size: 11)).padding(.leading, 8)
                }.foregroundStyle(.white).frame(height: 30).padding(.horizontal, 12)
                    .background(slate, in: RoundedRectangle(cornerRadius: 6))
            }.padding(.top, 26)
            Text(description).font(.system(size: 13)).foregroundStyle(muted).lineSpacing(6).padding(.top, 22)
        }.frame(width: 360, alignment: .leading)
    }
    func iconState(_ title: String, on: Bool, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Glyph(mark: mark, on: on, color: tint, size: 28)
            Text(title).font(.system(size: 10)).foregroundStyle(muted)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct IconBoard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Text("Keep Awake").font(.system(size: 32, weight: .semibold))
                Text("图标设计 · 三种方向").font(.system(size: 16)).foregroundStyle(muted).padding(.leading, 12)
                Spacer()
                Text("VECTOR / 18 PT FIRST").font(.system(size: 10, design: .monospaced)).foregroundStyle(muted)
            }
            Text("先看小尺寸辨识度，再看放大造型。开启用实心，关闭用线框；颜色辅助表达状态。").font(.system(size: 14)).foregroundStyle(muted).padding(.top, 12)
            HStack(alignment: .top, spacing: 48) {
                IconColumn(mark: .sunrise, description: "太阳停在地平线上，表达持续清醒。\n气质轻盈，更有独立小工具的辨识度。")
                IconColumn(mark: .coffee, description: "一杯热咖啡，表达让电脑继续工作。\n含义亲切直观，适合偏生活化的风格。")
                IconColumn(mark: .circuit, description: "保留现有闪电，用断开的圆环形成标识。\n延续已有认知，菜单栏里更紧凑利落。")
            }.padding(.top, 38)
            Rectangle().fill(line).frame(height: 1).padding(.top, 30)
            Text("橙 = 防闲置休眠已开启     绿 = 近期有操作，防休眠未开启     灰 = 闲置，防休眠未开启")
                .font(.system(size: 12)).foregroundStyle(muted).padding(.top, 17)
        }.padding(44).frame(width: 1312).foregroundStyle(ink)
            .background(Color(red: 0.92, green: 0.94, blue: 0.96))
    }
}

@MainActor
func save<V: View>(_ view: V, name: String, output: URL, scale: CGFloat = 2) throws {
    let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
    renderer.scale = scale
    guard let cg = renderer.cgImage else { fatalError("Could not render \(name)") }
    let rep = NSBitmapImageRep(cgImage: cg)
    guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("Could not encode \(name)") }
    try png.write(to: output.appendingPathComponent(name + ".png"))
    print("Rendered \(name): \(cg.width) × \(cg.height)")
}

try MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "design/2026-11-06", isDirectory: true)
    try save(IconBoard(), name: "icons-comparison", output: output)
    try save(UIBoard(), name: "ui-comparison", output: output)
    try save(CompactPanel(), name: "ui-a-on", output: output)
    try save(CompactPanel(on: false), name: "ui-a-off", output: output)
    try save(SessionPanel(), name: "ui-b-on", output: output)
    try save(SessionPanel(on: false), name: "ui-b-off", output: output)
    try save(SplitPanel(), name: "ui-c-on", output: output)
    try save(SplitPanel(on: false), name: "ui-c-off", output: output)
    for mark in Mark.allCases {
        try save(Glyph(mark: mark, size: 144).padding(40).background(paper), name: "icon-\(["a", "b", "c"][mark.rawValue])-large", output: output)
    }
}

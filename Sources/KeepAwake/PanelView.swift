import AppKit
import SwiftUI

/// The popover panel shown when the menu-bar icon is clicked.
///
/// The size is fixed (`PanelView.size`) and shared with the popover's
/// `contentSize` in AppDelegate — `NSHostingController.sizingOptions` is set
/// to `[]` there, so AppKit never resizes the popover after it is shown.
/// (A post-show resize is what made the popover drift away from the icon.)
struct PanelView: View {

    /// Keep in sync with `popover.contentSize` (both set from here).
    static let size = NSSize(width: 320, height: 296)

    @ObservedObject var model: AppState
    @State private var showsDetails = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: 20)
                .padding(.bottom, 14)
            statusControl
                .frame(height: 44)
                .padding(.bottom, 14)
            Divider()
            stats
            Divider()
            footer
                .frame(height: 50, alignment: .top)
                .padding(.top, 10)
        }
        .padding(20)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.94))
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(nsImage: StatusIcon.image(for: model.displayState))
                .renderingMode(.original)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
            Text("Keep Awake")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text("⌃⌥⌘K")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .strikethrough(model.hotKeyError != nil)
                .help(model.hotKeyError ?? "切换保持唤醒")
                .accessibilityLabel(model.hotKeyError == nil
                    ? "快捷键：Control、Option、Command、K"
                    : "快捷键不可用，使用保持唤醒开关")
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
        }
    }

    private var statusControl: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.isKeepingAwake ? "保持唤醒中" : "跟随系统休眠")
                    .font(.system(size: 20, weight: .semibold))
                    .lineLimit(1)
                Text("允许锁屏和熄屏")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Toggle("保持唤醒", isOn: Binding(
                get: { model.isKeepingAwake },
                set: { enabled in
                    if enabled != model.isKeepingAwake { model.toggleKeepAwake() }
                }
            ))
            .toggleStyle(AwakeSwitchStyle())
            .labelsHidden()
            .help(model.isKeepingAwake ? "停止保持唤醒" : "开始保持唤醒")
            .accessibilityHint("只防止闲置休眠，允许锁屏和熄屏")
        }
    }

    // MARK: Stats

    private var stats: some View {
        VStack(spacing: 13) {
            statRow(
                label: model.isKeepingAwake ? "本次保持" : "上次保持",
                value: model.hasSession ? durationText(model.sessionSeconds) : "—"
            )
            statRow(
                label: "累计保持",
                value: durationText(model.totalAwakeSeconds)
            )
            statRow(label: "程序已运行", value: durationText(model.uptimeSeconds))
        }
        .frame(height: 74)
        .padding(.vertical, 14)
    }

    private func statRow(label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize()
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Feedback

    private var feedback: some View {
        Group {
            if model.errors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("手动睡眠、合盖和低电量仍可休眠")
                    if !model.isKeepingAwake {
                        Text("绿色仅表示近期有操作")
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(model.errors.enumerated()), id: \.offset) { _, error in
                                Label(error, systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(.red)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollIndicators(.visible)
                    .frame(height: 32)
                    Button("\(model.errors.count) 项提示 · 查看全部") {
                        showsDetails = true
                    }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(alignment: .top, spacing: 8) {
            feedback
            VStack(spacing: 9) {
                Button("退出") { NSApp.terminate(nil) }
                    .font(.system(size: 11))
                    .help("退出并解除本工具的防休眠限制")
                Button {
                    showsDetails.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .frame(width: 24, height: 20)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(model.errors.isEmpty ? "保持唤醒说明" : "运行提示与保持唤醒说明")
                .popover(isPresented: $showsDetails) { details }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private var details: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if !model.errors.isEmpty {
                    Text("运行提示").font(.system(size: 13, weight: .semibold))
                    ForEach(Array(model.errors.enumerated()), id: \.offset) { _, error in
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                    Divider()
                }
                Text("保持唤醒说明").font(.system(size: 13, weight: .semibold))
                Text("开启后防止因没有键鼠操作而触发的系统闲置休眠，允许锁屏和熄屏。手动睡眠、合盖和低电量仍可休眠。")
                Text("绿色仅表示最近 120 秒有键鼠操作，防休眠仍未开启；灰色表示闲置。")
                Text("保持时长不计系统休眠时间。停止或退出只解除本工具的防休眠限制。")
            }
            .font(.system(size: 11))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .scrollIndicators(.visible)
        .frame(width: 268, height: model.errors.isEmpty ? 244 : 360)
    }

    // MARK: Helpers

    private func durationText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(
            format: "%02d:%02d:%02d",
            total / 3600,
            (total % 3600) / 60,
            total % 60
        )
    }
}

/// Keep the chosen orange state visible even when the popover is inactive.
/// The accessibility representation retains native switch actions and values.
private struct AwakeSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? Color.orange : Color.secondary.opacity(0.25))
                Circle()
                    .fill(.white)
                    .frame(width: 19, height: 19)
                    .padding(2)
            }
            .frame(width: 38, height: 23)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
                .toggleStyle(.switch)
        }
    }
}

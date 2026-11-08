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
    @FocusState private var durationFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: 20)
                .padding(.bottom, 10)
            statusControl
                .frame(height: 28)
                .padding(.bottom, 5)
            timingControl
                .padding(.bottom, 9)
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
        .onDisappear { model.durationDraft = nil }
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
                .help(model.hotKeyError ?? localized("切换保持唤醒", "Toggle keep awake"))
                .accessibilityLabel(model.hotKeyError == nil
                    ? localized("快捷键：Control、Option、Command、K", "Shortcut: Control, Option, Command, K")
                    : localized("快捷键不可用，使用保持唤醒开关", "Shortcut unavailable; use the switch"))
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
            Text(model.isKeepingAwake ? localized("保持唤醒中", "Keeping Awake") : localized("跟随系统休眠", "System Sleep"))
                .font(.system(size: 20, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            Toggle(localized("保持唤醒", "Keep Awake"), isOn: Binding(
                get: { model.isKeepingAwake },
                set: { enabled in
                    if enabled != model.isKeepingAwake { model.toggleKeepAwake() }
                }
            ))
            .toggleStyle(AwakeSwitchStyle())
            .labelsHidden()
            .help(model.isKeepingAwake ? localized("停止保持唤醒", "Stop keeping awake") : localized("开始保持唤醒", "Start keeping awake"))
            .accessibilityHint(localized("只防止闲置休眠，允许锁屏和熄屏", "Prevents idle sleep; allows lock and display sleep"))
        }
    }

    private var timingControl: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(model.countdownSeconds == nil ? localized("保持时长", "Duration") : localized("剩余时间", "Time remaining"))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if let remaining = model.countdownSeconds {
                    Text(AwakeDuration.full(remaining.rounded(.up)))
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.orange)
                } else if model.isKeepingAwake {
                    Text(localized("不限时", "Unlimited"))
                } else {
                    timingButton(localized("不限时", "Unlimited"), width: 68, selected: !model.usesTimer) {
                        model.selectTimer(false)
                    }
                    if model.durationDraft != nil {
                        TextField("HH:MM", text: Binding(
                            get: { model.durationDraft ?? "" },
                            set: { model.durationDraft = $0 }
                        ))
                        .multilineTextAlignment(.center)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(width: 104)
                        .focused($durationFocused)
                        .accessibilityLabel(localized("保持时长，小时冒号分钟", "Duration, hours colon minutes"))
                        .onAppear { durationFocused = true }
                        .onSubmit { model.commitDurationEdit() }
                        .onExitCommand { model.durationDraft = nil }
                    } else {
                        timingButton(durationLabel, width: 104, selected: model.usesTimer) {
                            model.selectTimer(true)
                        }
                        .simultaneousGesture(TapGesture(count: 2).onEnded { model.beginDurationEdit() })
                        .accessibilityAction(named: Text(localized("编辑时长", "Edit duration"))) { model.beginDurationEdit() }
                    }
                }
            }
            .font(.system(size: 12))
            .frame(height: 26)
            Text(timingHint)
                .font(.system(size: 10))
                .foregroundStyle(invalidDuration ? Color.red : Color.secondary)
                .lineLimit(1)
                .frame(height: 14, alignment: .leading)
        }
    }

    private var durationLabel: String {
        let hours = model.durationMinutes / 60
        let minutes = model.durationMinutes % 60
        if hours == 0 { return localized("\(minutes) 分钟", "\(minutes) min") }
        if minutes == 0 { return localized("\(hours) 小时", "\(hours) h") }
        return localized("\(hours) 小时 \(minutes) 分", "\(hours) h \(minutes) min")
    }

    private var invalidDuration: Bool {
        guard let draft = model.durationDraft else { return false }
        return AwakeDuration.timerMinutes(draft) == nil
    }

    private var timingHint: String {
        if model.isKeepingAwake {
            return localized("允许锁屏和熄屏", "Lock and display sleep allowed")
        }
        if invalidDuration {
            return localized("请输入 00:01–24:00，例如 01:30", "Enter 00:01–24:00, e.g. 01:30")
        }
        if model.durationDraft != nil {
            return localized("小时:分钟 · 回车保存 · Esc 取消", "Hours:minutes · Return to save · Esc to cancel")
        }
        return localized("单击选用时长，双击编辑", "Click to select a duration, double-click to edit")
    }

    private func timingButton(_ title: String, width: CGFloat, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: selected ? .semibold : .regular))
                .frame(width: width, height: 24)
                .background(Color.primary.opacity(selected ? 0.13 : 0.06), in: RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Stats

    private var stats: some View {
        VStack(spacing: 9) {
            statRow(
                label: model.isKeepingAwake ? localized("本次保持", "Current session") : localized("上次保持", "Last session"),
                value: model.hasSession ? AwakeDuration.full(model.sessionSeconds) : "—"
            )
            statRow(
                label: localized("累计保持", "Total awake"),
                value: AwakeDuration.full(model.totalAwakeSeconds)
            )
            statRow(label: localized("程序已运行", "App uptime"), value: AwakeDuration.full(model.uptimeSeconds))
        }
        .frame(height: 66)
        .padding(.vertical, 8)
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
                    Text(localized("手动睡眠、合盖和低电量仍可休眠", "Manual sleep, lid closure and low battery can still cause sleep"))
                    if !model.isKeepingAwake {
                        Text(localized("绿色仅表示近期有操作", "Green only indicates recent activity"))
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
                    Button(localized("\(model.errors.count) 项提示 · 查看全部", "\(model.errors.count) alerts · View all")) {
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
                Button(localized("退出", "Quit")) { NSApp.terminate(nil) }
                    .font(.system(size: 11))
                    .help(localized("退出并解除本工具的防休眠限制", "Quit and release this app’s sleep prevention"))
                Button {
                    showsDetails.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .frame(width: 24, height: 20)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(model.errors.isEmpty ? localized("保持唤醒说明", "About Keep Awake") : localized("运行提示与保持唤醒说明", "Alerts and about Keep Awake"))
                .popover(isPresented: $showsDetails) { details }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    var detailsSize: NSSize {
        NSSize(width: 268, height: model.errors.isEmpty ? 244 : 360)
    }

    // Internal so the native snapshot hook can also verify alert actions.
    var details: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if !model.errors.isEmpty {
                    Text(localized("运行提示", "Alerts")).font(.system(size: 13, weight: .semibold))
                    ForEach(Array(model.errors.enumerated()), id: \.offset) { _, error in
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                    if model.hotKeyError != nil {
                        Button(localized("重试快捷键", "Retry shortcut")) {
                            model.retryHotKey()
                        }
                        .help(localized("冲突解除后重新注册，不会中断本次保持", "Register again after resolving the conflict, without interrupting this session"))
                    }
                    Divider()
                }
                Text(localized("保持唤醒说明", "About Keep Awake")).font(.system(size: 13, weight: .semibold))
                Text(localized("开启后防止因没有键鼠操作而触发的系统闲置休眠，允许锁屏和熄屏。手动睡眠、合盖和低电量仍可休眠。", "Prevents idle system sleep while allowing lock and display sleep. Manual sleep, lid closure and low battery can still cause sleep."))
                Text(localized("绿色仅表示最近 120 秒有键鼠操作，防休眠仍未开启；灰色表示闲置。", "Green means input in the last 120 seconds, not sleep prevention. Gray means idle."))
                Text(localized("保持时长不计系统休眠时间。停止或退出只解除本工具的防休眠限制。", "Awake time excludes system sleep. Stopping or quitting only releases this app’s sleep prevention."))
            }
            .font(.system(size: 11))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .scrollIndicators(.visible)
        .frame(width: detailsSize.width, height: detailsSize.height)
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

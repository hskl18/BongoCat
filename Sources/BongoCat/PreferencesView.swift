import AppKit
import Combine
import SwiftUI

private enum PreferencesPage: String, CaseIterable, Identifiable {
    case cat
    case models
    case general
    case input
    case shortcuts
    case about

    var id: String { rawValue }

    @MainActor
    func title(language: AppLanguage) -> String {
        switch self {
        case .cat:
            L10n.text("pages.preference.cat.title", language: language, fallback: "Cat")
        case .models:
            L10n.text("model.models", language: language, fallback: "Models")
        case .general:
            L10n.text("pages.preference.general.title", language: language, fallback: "General")
        case .input:
            L10n.text("input.title", language: language, fallback: "Input")
        case .shortcuts:
            L10n.text("pages.preference.shortcut.title", language: language, fallback: "Shortcuts")
        case .about:
            L10n.text("pages.preference.about.title", language: language, fallback: "About")
        }
    }

    var symbol: String {
        switch self {
        case .cat: "cat.fill"
        case .models: "square.grid.2x2"
        case .general: "gearshape"
        case .input: "keyboard"
        case .shortcuts: "command"
        case .about: "info.circle"
        }
    }
}

struct PreferencesView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var inputMonitor: InputMonitor
    @ObservedObject var modelLibrary: ModelLibrary
    let scene: CatSceneState
    let diagnostics: DiagnosticsService

    @State private var selection: PreferencesPage? = .cat

    var body: some View {
        NavigationSplitView {
            List(PreferencesPage.allCases, selection: $selection) { page in
                Label(page.title(language: settings.language), systemImage: page.symbol)
                    .tag(page)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            Group {
                switch selection ?? .cat {
                case .cat:
                    CatPreferences(settings: settings, scene: scene, modelLibrary: modelLibrary)
                case .models:
                    ModelPreferences(settings: settings, modelLibrary: modelLibrary)
                case .general:
                    GeneralPreferences(settings: settings)
                case .input:
                    InputPreferences(settings: settings, inputMonitor: inputMonitor)
                case .shortcuts:
                    ShortcutPreferences(
                        settings: settings,
                        modelLibrary: modelLibrary,
                        scene: scene
                    )
                case .about:
                    AboutPreferences(
                        settings: settings,
                        inputMonitor: inputMonitor,
                        modelLibrary: modelLibrary,
                        diagnostics: diagnostics
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)
        }
        .frame(minWidth: 760, minHeight: 560)
    }
}

private struct ShortcutPreferences: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var modelLibrary: ModelLibrary
    @ObservedObject var scene: CatSceneState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                PageHeading(
                    title: L10n.text(
                        "pages.preference.shortcut.title",
                        language: settings.language,
                        fallback: "Shortcuts"
                    ),
                    subtitle: L10n.text(
                        "shortcut.subtitle",
                        language: settings.language,
                        fallback: "Global shortcuts for BongoCat."
                    )
                )

                shortcutSection(
                    title: L10n.text(
                        "shortcut.application",
                        language: settings.language,
                        fallback: "App"
                    ),
                    items: ShortcutCommand.allCases.map {
                        ShortcutItem(
                            id: $0.id,
                            title: $0.title(language: settings.language)
                        )
                    }
                )

                if let model = modelLibrary.selectedModel, !scene.motions.isEmpty {
                    shortcutSection(
                        title: L10n.text(
                            "shortcut.motions",
                            language: settings.language,
                            fallback: "Motions"
                        ),
                        items: scene.motions.map {
                            ShortcutItem(
                                id: ShortcutIdentifier.motion(model: model, motion: $0),
                                title: motionTitle($0)
                            )
                        }
                    )
                }

                if let model = modelLibrary.selectedModel, !scene.expressions.isEmpty {
                    shortcutSection(
                        title: L10n.text(
                            "shortcut.expressions",
                            language: settings.language,
                            fallback: "Expressions"
                        ),
                        items: scene.expressions.map {
                            ShortcutItem(
                                id: ShortcutIdentifier.expression(model: model, expression: $0),
                                title: L10n.text(
                                    "pages.preference.model.behaviorModal.labels.expressionIndex",
                                    language: settings.language,
                                    fallback: "Expression {index}",
                                    replacements: ["index": String($0.index + 1)]
                                )
                            )
                        }
                    )
                }
            }
        }
    }

    private func shortcutSection(title: String, items: [ShortcutItem]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.leading, 2)

            VStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { index in
                    shortcutRow(items[index])
                    if index < items.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 10)
            .background(.quaternary.opacity(0.45), in: .rect(cornerRadius: 10))
        }
    }

    private func shortcutRow(_ item: ShortcutItem) -> some View {
        HStack(spacing: 12) {
            Text(item.title)
                .lineLimit(1)
            Spacer(minLength: 12)

            HStack(spacing: 6) {
                ShortcutRecorder(
                    value: settings.shortcuts[item.id],
                    language: settings.language,
                    onChange: { settings.setShortcut($0, for: item.id) },
                    onRecordingChange: { settings.isRecordingShortcut = $0 }
                )
                .frame(width: 96, height: 22)

                Button(
                    L10n.text("shortcut.clear", language: settings.language, fallback: "Clear"),
                    systemImage: "xmark.circle.fill"
                ) {
                    settings.setShortcut(nil, for: item.id)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(settings.shortcuts[item.id] == nil)
            }
        }
        .frame(minHeight: 28)
    }

    private func motionTitle(_ motion: ModelMotion) -> String {
        if motion.group.lowercased().contains("lock") {
            return L10n.text(
                "shortcut.lockMotion",
                language: settings.language,
                fallback: "Lock {index}",
                replacements: ["index": String(motion.index + 1)]
            )
        }

        return L10n.text(
            "pages.preference.model.behaviorModal.labels.motionIndex",
            language: settings.language,
            fallback: "Motion {index}",
            replacements: ["index": String(motion.index + 1)]
        )
    }
}

private struct ShortcutItem: Identifiable {
    let id: String
    let title: String
}

private struct ShortcutRecorder: NSViewRepresentable {
    let value: ShortcutDefinition?
    let language: AppLanguage
    let onChange: (ShortcutDefinition?) -> Void
    let onRecordingChange: (Bool) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.onChange = onChange
        button.onRecordingChange = onRecordingChange
        button.language = language
        button.update(value: value)
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        button.onChange = onChange
        button.onRecordingChange = onRecordingChange
        button.language = language
        button.update(value: value)
    }
}

private final class ShortcutRecorderButton: NSButton {
    var onChange: ((ShortcutDefinition?) -> Void)?
    var onRecordingChange: ((Bool) -> Void)?

    private var value: ShortcutDefinition?
    private var recording = false
    var language: AppLanguage = .english

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        focusRingType = .exterior
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        guard super.becomeFirstResponder() else { return false }
        recording = true
        title = L10n.text(
            "components.shortcut.hints.pressRecordShortcut",
            language: language,
            fallback: "Press keys"
        )
        onRecordingChange?(true)
        return true
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            recording = false
            onRecordingChange?(false)
            refreshTitle()
        }
        return resigned
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            window?.makeFirstResponder(nil)
            return
        }
        if event.keyCode == 51 || event.keyCode == 117 {
            onChange?(nil)
            window?.makeFirstResponder(nil)
            return
        }
        guard !KeyCodeNames.modifierKeys.contains(event.keyCode) else { return }

        let modifiers = ShortcutModifiers(eventFlags: event.modifierFlags)
        guard !modifiers.isEmpty || KeyCodeNames.functionKeys.contains(event.keyCode) else {
            NSSound.beep()
            return
        }
        guard KeyCodeNames.names[event.keyCode] != nil else {
            NSSound.beep()
            return
        }

        onChange?(ShortcutDefinition(keyCode: event.keyCode, modifiers: modifiers))
        window?.makeFirstResponder(nil)
    }

    func update(value: ShortcutDefinition?) {
        self.value = value
        if !recording { refreshTitle() }
    }

    private func refreshTitle() {
        title = value?.displayName ?? L10n.text(
            "components.shortcut.hints.clickRecordShortcut",
            language: language,
            fallback: "Record"
        )
    }
}

private struct GeneralPreferences: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeading(
                title: L10n.text(
                    "pages.preference.general.title",
                    language: settings.language,
                    fallback: "General"
                ),
                subtitle: L10n.text(
                    "general.subtitle",
                    language: settings.language,
                    fallback: "Application behavior and appearance."
                )
            )

            Form {
                Section(L10n.text(
                    "pages.preference.general.labels.appSettings",
                    language: settings.language,
                    fallback: "Application"
                )) {
                    Toggle(
                        L10n.text(
                            "pages.preference.general.labels.launchOnStartup",
                            language: settings.language,
                            fallback: "Launch at login"
                        ),
                        isOn: $settings.launchAtLogin
                    )
                    Toggle(
                        L10n.text(
                            "pages.preference.general.labels.showTaskbarIcon",
                            language: settings.language,
                            fallback: "Show Dock icon"
                        ),
                        isOn: $settings.showDockIcon
                    )
                    Toggle(
                        L10n.text(
                            "pages.preference.general.labels.showTrayIcon",
                            language: settings.language,
                            fallback: "Show menu bar icon"
                        ),
                        isOn: $settings.showMenuBarIcon
                    )
                }

                Section(L10n.text(
                    "pages.preference.general.labels.appearanceSettings",
                    language: settings.language,
                    fallback: "Appearance"
                )) {
                    Picker(
                        L10n.text(
                            "pages.preference.general.labels.themeMode",
                            language: settings.language,
                            fallback: "Theme"
                        ),
                        selection: $settings.appearance
                    ) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.title(language: settings.language)).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker(
                        L10n.text(
                            "pages.preference.general.labels.language",
                            language: settings.language,
                            fallback: "Language"
                        ),
                        selection: $settings.language
                    ) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.nativeTitle).tag(language)
                        }
                    }
                }

            }
            .formStyle(.grouped)
        }
    }
}

private struct CatPreferences: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var scene: CatSceneState
    @ObservedObject var modelLibrary: ModelLibrary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeading(
                    title: "BongoCat",
                    subtitle: L10n.text(
                        "cat.subtitle",
                        language: settings.language,
                        fallback: "A native desktop companion for this Mac."
                    )
                )

                Form {
                    Section(L10n.text(
                        "pages.preference.cat.labels.modelSettings",
                        language: settings.language,
                        fallback: "Model"
                    )) {
                        Picker(
                            L10n.text("cat.model", language: settings.language, fallback: "Model"),
                            selection: $modelLibrary.selectedID
                        ) {
                            ForEach(modelLibrary.models) { model in
                                Text(displayName(for: model)).tag(model.id)
                            }
                        }
                        .pickerStyle(.segmented)

                        Toggle(
                            L10n.text(
                                "pages.preference.cat.labels.mirrorMode",
                                language: settings.language,
                                fallback: "Mirror model"
                            ),
                            isOn: $settings.mirror
                        )
                        Toggle(
                            L10n.text(
                                "cat.mirrorPointer",
                                language: settings.language,
                                fallback: "Mirror pointer response"
                            ),
                            isOn: $settings.mouseMirror
                        )
                        Toggle(
                            L10n.text(
                                "cat.ignorePointer",
                                language: settings.language,
                                fallback: "Ignore pointer movement"
                            ),
                            isOn: $settings.ignoreMouseMovement
                        )
                        Toggle(
                            L10n.text(
                                "pages.preference.cat.labels.motionSound",
                                language: settings.language,
                                fallback: "Motion sound"
                            ),
                            isOn: $settings.motionSound
                        )
                        Toggle(
                            L10n.text(
                                "pages.preference.cat.labels.behavior",
                                language: settings.language,
                                fallback: "Motions and expressions"
                            ),
                            isOn: $settings.behaviorsEnabled
                        )
                        Stepper(
                            settings.maximumFramesPerSecond == 0
                                ? L10n.text(
                                    "cat.maxDisplay",
                                    language: settings.language,
                                    fallback: "Maximum frame rate: Display"
                                )
                                : L10n.text(
                                    "cat.maxFPS",
                                    language: settings.language,
                                    fallback: "Maximum frame rate: {value} FPS",
                                    replacements: [
                                        "value": String(settings.maximumFramesPerSecond),
                                    ]
                                ),
                            value: $settings.maximumFramesPerSecond,
                            in: 0 ... 240,
                            step: 5
                        )
                    }

                    if settings.behaviorsEnabled {
                        Section(L10n.text(
                            "pages.preference.model.behaviorModal.labels.motion",
                            language: settings.language,
                            fallback: "Motions"
                        )) {
                            ForEach(scene.motions) { motion in
                                Button("\(motion.group) \(motion.index + 1)") {
                                    scene.play(motion)
                                }
                            }
                        }

                        Section(L10n.text(
                            "pages.preference.model.behaviorModal.labels.expression",
                            language: settings.language,
                            fallback: "Expressions"
                        )) {
                            ForEach(scene.expressions) { expression in
                                Button(L10n.text(
                                    "pages.preference.model.behaviorModal.labels.expressionIndex",
                                    language: settings.language,
                                    fallback: "Expression {index}",
                                    replacements: ["index": String(expression.index + 1)]
                                )) {
                                    scene.apply(expression)
                                }
                            }
                        }
                    }

                    Section(L10n.text(
                        "pages.preference.cat.labels.windowSettings",
                        language: settings.language,
                        fallback: "Window"
                    )) {
                        Toggle(
                            L10n.text("cat.show", language: settings.language, fallback: "Show cat"),
                            isOn: $settings.catVisible
                        )
                        Toggle(
                            L10n.text(
                                "cat.keepAbove",
                                language: settings.language,
                                fallback: "Keep above other windows"
                            ),
                            isOn: $settings.alwaysOnTop
                        )
                        Toggle(
                            L10n.text(
                                "cat.ignoreClicks",
                                language: settings.language,
                                fallback: "Ignore pointer clicks"
                            ),
                            isOn: $settings.clickThrough
                        )
                        Toggle(
                            L10n.text(
                                "cat.lock",
                                language: settings.language,
                                fallback: "Lock cat position"
                            ),
                            isOn: $settings.positionLocked
                        )
                        Toggle(
                            L10n.text(
                                "pages.preference.cat.labels.keepInScreen",
                                language: settings.language,
                                fallback: "Keep within the active screen"
                            ),
                            isOn: $settings.keepOnScreen
                        )

                        LabeledContent(L10n.text(
                            "pages.preference.cat.labels.hideOnHover",
                            language: settings.language,
                            fallback: "Hide on hover"
                        )) {
                            HStack(spacing: 12) {
                                Toggle(
                                    L10n.text(
                                        "pages.preference.cat.labels.hideOnHover",
                                        language: settings.language,
                                        fallback: "Hide on hover"
                                    ),
                                    isOn: $settings.hideOnHover
                                )
                                    .labelsHidden()
                                if settings.hideOnHover {
                                    Slider(value: $settings.hideOnHoverDelay, in: 0 ... 3, step: 0.25)
                                        .frame(width: 150)
                                    Text(settings.hideOnHoverDelay.formatted(.number.precision(.fractionLength(0 ... 2))) + " s")
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                        .frame(width: 48, alignment: .trailing)
                                }
                            }
                        }

                        LabeledContent(L10n.text(
                            "pages.preference.cat.labels.windowSize",
                            language: settings.language,
                            fallback: "Size"
                        )) {
                            HStack(spacing: 12) {
                                Slider(value: $settings.scale, in: 10 ... 500, step: 5)
                                    .frame(width: 220)
                                Text("\(Int(settings.scale))%")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .frame(width: 44, alignment: .trailing)
                            }
                        }

                        LabeledContent(L10n.text(
                            "pages.preference.cat.labels.opacity",
                            language: settings.language,
                            fallback: "Opacity"
                        )) {
                            HStack(spacing: 12) {
                                Slider(value: $settings.opacity, in: 10 ... 100, step: 5)
                                    .frame(width: 220)
                                Text("\(Int(settings.opacity))%")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .frame(width: 44, alignment: .trailing)
                            }
                        }

                        LabeledContent(L10n.text(
                            "cat.cornerRadius",
                            language: settings.language,
                            fallback: "Corner radius"
                        )) {
                            HStack(spacing: 12) {
                                Slider(value: $settings.cornerRadius, in: 0 ... 50, step: 1)
                                    .frame(width: 220)
                                Text("\(Int(settings.cornerRadius))%")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .frame(width: 44, alignment: .trailing)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
            }
        }
    }

    private func displayName(for model: ModelRecord) -> String {
        model.isPreset ? model.mode.title(language: settings.language) : model.name
    }
}

private struct ModelPreferences: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var modelLibrary: ModelLibrary

    @State private var pendingDeletion: ModelRecord?
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 12)]
    private let contentWidth: CGFloat = 864

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeading(
                    title: L10n.text("model.models", language: settings.language, fallback: "Models"),
                    subtitle: L10n.text(
                        "model.subtitle",
                        language: settings.language,
                        fallback: "Built-in and imported Live2D models."
                    )
                )

                Button(action: chooseModels) {
                    Label(
                        L10n.text(
                            "pages.preference.model.hints.clickOrDragToImport",
                            language: settings.language,
                            fallback: "Import Models"
                        ),
                        systemImage: "square.and.arrow.down"
                    )
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .frame(maxWidth: contentWidth)
                .buttonStyle(.glass)
                .dropDestination(for: URL.self) { urls, _ in
                    importModels(urls)
                    return true
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(modelLibrary.models) { model in
                        modelCard(model)
                    }
                }
                .frame(maxWidth: contentWidth, alignment: .leading)
            }
        }
        .alert(
            L10n.text(
                "model.deleteTitle",
                language: settings.language,
                fallback: "Delete {name}?",
                replacements: ["name": pendingDeletion.map(displayName(for:)) ?? "Model"]
            ),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            )
        ) {
            Button(
                L10n.text("model.delete", language: settings.language, fallback: "Delete"),
                role: .destructive
            ) {
                guard let model = pendingDeletion else { return }
                do {
                    try modelLibrary.delete(model)
                } catch {
                    errorMessage = error.localizedDescription
                }
                pendingDeletion = nil
            }
            Button(
                L10n.text("model.cancel", language: settings.language, fallback: "Cancel"),
                role: .cancel
            ) { pendingDeletion = nil }
        } message: {
            Text(L10n.text(
                "model.deleteMessage",
                language: settings.language,
                fallback: "The model folder will be moved to the Trash."
            ))
        }
    }

    @ViewBuilder
    private func modelCard(_ model: ModelRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                modelLibrary.select(model)
            } label: {
                Group {
                    if let image = coverImage(for: model) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "cat.fill")
                            .font(.system(size: 42))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1.72, contentMode: .fit)
                .clipped()
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain)

            HStack {
                Text(displayName(for: model))
                    .lineLimit(1)
                Spacer()
                if modelLibrary.selectedID == model.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            HStack {
                Button(
                    L10n.text("model.reveal", language: settings.language, fallback: "Reveal"),
                    systemImage: "folder"
                ) {
                    modelLibrary.reveal(model)
                }
                .labelStyle(.iconOnly)
                if !model.isPreset {
                    Button(
                        L10n.text("model.delete", language: settings.language, fallback: "Delete"),
                        systemImage: "trash",
                        role: .destructive
                    ) {
                        pendingDeletion = model
                    }
                    .labelStyle(.iconOnly)
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }

    private func coverImage(for model: ModelRecord) -> NSImage? {
        guard let manifest = try? ModelManifest.load(from: model.directoryURL),
              let coverURL = manifest.coverURL
        else { return nil }
        return NSImage(contentsOf: coverURL)
    }

    private func displayName(for model: ModelRecord) -> String {
        model.isPreset ? model.mode.title(language: settings.language) : model.name
    }

    private func chooseModels() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        importModels(panel.urls)
    }

    private func importModels(_ urls: [URL]) {
        errorMessage = nil
        Task {
            do {
                try await modelLibrary.importModels(from: urls)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct InputPreferences: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var inputMonitor: InputMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageHeading(
                title: L10n.text("input.title", language: settings.language, fallback: "Input"),
                subtitle: L10n.text(
                    "input.subtitle",
                    language: settings.language,
                    fallback: "Bongo Cat listens without modifying keyboard or pointer events."
                )
            )

            LabeledContent(L10n.text(
                "input.status",
                language: settings.language,
                fallback: "Status"
            )) {
                Label(
                    inputMonitor.status.title(language: settings.language),
                    systemImage: statusSymbol
                )
                    .foregroundStyle(statusColor)
            }

            if case let .failed(message) = inputMonitor.status {
                Text(message)
                    .foregroundStyle(.secondary)
            }

            if inputMonitor.status != .listening {
                Button(L10n.text(
                    "input.openSettings",
                    language: settings.language,
                    fallback: "Open Input Monitoring Settings"
                )) {
                    inputMonitor.requestPermission()
                }
                .buttonStyle(.glassProminent)
            }

            Text(L10n.text(
                "input.retryHint",
                language: settings.language,
                fallback: "If BongoCat already appears enabled, switch it off and on again. Return here and listening will retry automatically."
            ))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var statusSymbol: String {
        inputMonitor.status == .listening ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var statusColor: Color {
        inputMonitor.status == .listening ? .green : .orange
    }
}

private struct AboutPreferences: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var inputMonitor: InputMonitor
    @ObservedObject var modelLibrary: ModelLibrary
    let diagnostics: DiagnosticsService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(
                    title: "BongoCat",
                    subtitle: L10n.text(
                        "about.subtitle",
                        language: settings.language,
                        fallback: "A native BongoCat for macOS 26 and later."
                    )
                )

                LabeledContent(L10n.text(
                    "about.version",
                    language: settings.language,
                    fallback: "Version"
                )) {
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown")
                }
                LabeledContent(L10n.text(
                    "about.sourceCode",
                    language: settings.language,
                    fallback: "Source Code"
                )) {
                    Link(
                        "hskl18/BongoCat",
                        destination: URL(string: "https://github.com/hskl18/BongoCat")!
                    )
                }
                LabeledContent(L10n.text(
                    "about.license",
                    language: settings.language,
                    fallback: "License"
                )) { Text("MIT") }

                Divider()

                DisclosureGroup(L10n.text(
                    "about.diagnostics",
                    language: settings.language,
                    fallback: "Diagnostics"
                )) {
                    HStack {
                        Button(L10n.text(
                            "about.copyInfo",
                            language: settings.language,
                            fallback: "Copy App Information"
                        )) {
                            diagnostics.copyApplicationInformation(
                                inputStatus: inputMonitor.status,
                                selectedModel: modelLibrary.selectedModel
                            )
                        }
                        Button(L10n.text(
                            "pages.preference.about.buttons.viewLog",
                            language: settings.language,
                            fallback: "View Logs"
                        )) { diagnostics.revealLogs() }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
}

private struct PageHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

@MainActor
final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    private var languageCancellable: AnyCancellable?

    init(settings: AppSettings, rootView: PreferencesView) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 610),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.text(
            "pages.preference.title",
            language: settings.language,
            fallback: "BongoCat Settings"
        )
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.center()
        window.contentViewController = NSHostingController(rootView: rootView)
        super.init(window: window)
        window.delegate = self
        languageCancellable = settings.$language
            .removeDuplicates()
            .sink { [weak window] language in
                window?.title = L10n.text(
                    "pages.preference.title",
                    language: language,
                    fallback: "BongoCat Settings"
                )
            }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}

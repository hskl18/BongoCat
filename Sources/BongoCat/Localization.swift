import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case simplifiedChinese = "zh-CN"
    case traditionalChinese = "zh-TW"
    case english = "en-US"
    case vietnamese = "vi-VN"
    case portuguese = "pt-BR"

    var id: String { rawValue }

    var nativeTitle: String {
        switch self {
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .english: "English"
        case .vietnamese: "Tiếng Việt"
        case .portuguese: "Português"
        }
    }

    static func systemDefault(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard let preferred = preferredLanguages.first?.lowercased() else { return .english }
        if preferred.hasPrefix("zh-hant") || preferred.hasPrefix("zh-tw") || preferred.hasPrefix("zh-hk") {
            return .traditionalChinese
        }
        if preferred.hasPrefix("zh") { return .simplifiedChinese }
        if preferred.hasPrefix("vi") { return .vietnamese }
        if preferred.hasPrefix("pt") { return .portuguese }
        return .english
    }
}

struct LocaleCatalog {
    let values: [String: String]

    static func load(from url: URL) throws -> LocaleCatalog {
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        guard let dictionary = object as? [String: Any] else { return LocaleCatalog(values: [:]) }
        var values: [String: String] = [:]
        flatten(dictionary, prefix: "", output: &values)
        return LocaleCatalog(values: values)
    }

    private static func flatten(
        _ dictionary: [String: Any],
        prefix: String,
        output: inout [String: String]
    ) {
        for (key, value) in dictionary {
            let path = prefix.isEmpty ? key : "\(prefix).\(key)"
            if let text = value as? String {
                output[path] = text
            } else if let nested = value as? [String: Any] {
                flatten(nested, prefix: path, output: &output)
            }
        }
    }
}

@MainActor
enum L10n {
    private static var catalogs: [AppLanguage: LocaleCatalog] = [:]

    static let requiredUpstreamKeys: Set<String> = [
        "pages.preference.title",
        "pages.preference.cat.title",
        "pages.preference.general.title",
        "pages.preference.model.title",
        "pages.preference.shortcut.title",
        "pages.preference.about.title",
        "pages.preference.cat.labels.modelSettings",
        "pages.preference.cat.labels.mirrorMode",
        "pages.preference.cat.labels.mouseMirror",
        "pages.preference.cat.labels.ignoreMouse",
        "pages.preference.cat.labels.windowSettings",
        "pages.preference.cat.labels.passThrough",
        "pages.preference.cat.labels.alwaysOnTop",
        "pages.preference.cat.labels.keepInScreen",
        "pages.preference.cat.labels.windowSize",
        "pages.preference.cat.labels.windowRadius",
        "pages.preference.cat.labels.opacity",
        "pages.preference.cat.labels.motionSound",
        "pages.preference.cat.labels.behavior",
        "pages.preference.cat.labels.hideOnHover",
        "pages.preference.cat.labels.maxFPS",
        "pages.preference.general.labels.appSettings",
        "pages.preference.general.labels.launchOnStartup",
        "pages.preference.general.labels.showTaskbarIcon",
        "pages.preference.general.labels.showTrayIcon",
        "pages.preference.general.labels.appearanceSettings",
        "pages.preference.general.labels.themeMode",
        "pages.preference.general.labels.language",
        "pages.preference.general.options.auto",
        "pages.preference.general.options.lightMode",
        "pages.preference.general.options.darkMode",
        "pages.preference.model.hints.clickOrDragToImport",
        "pages.preference.model.behaviorModal.labels.motion",
        "pages.preference.model.behaviorModal.labels.expression",
        "pages.preference.model.behaviorModal.labels.motionIndex",
        "pages.preference.model.behaviorModal.labels.expressionIndex",
        "pages.preference.shortcut.labels.toggleCat",
        "pages.preference.shortcut.labels.togglePreferences",
        "pages.preference.shortcut.labels.mirrorMode",
        "pages.preference.shortcut.labels.passThrough",
        "pages.preference.shortcut.labels.alwaysOnTop",
        "pages.preference.about.labels.appLog",
        "pages.preference.about.labels.appInfo",
        "pages.preference.about.buttons.viewLog",
        "components.shortcut.hints.pressRecordShortcut",
        "components.shortcut.hints.clickRecordShortcut",
        "composables.useAppMenu.labels.preference",
        "composables.useAppMenu.labels.hideCat",
        "composables.useAppMenu.labels.showCat",
        "composables.useAppMenu.labels.passThrough",
        "composables.useAppMenu.labels.windowSize",
        "composables.useAppMenu.labels.opacity",
        "composables.useAppMenu.labels.restartApp",
        "composables.useAppMenu.labels.quitApp",
    ]

    static let extra: [AppLanguage: [String: String]] = [
        .english: [
            "input.title": "Input",
            "input.subtitle": "Bongo Cat listens without modifying keyboard or pointer events.",
            "input.status": "Status",
            "input.stopped": "Stopped",
            "input.permission": "Input Monitoring required",
            "input.listening": "Listening",
            "input.unavailable": "Unavailable",
            "input.openSettings": "Open Input Monitoring Settings",
            "input.retryHint": "If BongoCat already appears enabled, switch it off and on again. Return here and listening will retry automatically.",
            "general.subtitle": "Application behavior and appearance.",
            "cat.subtitle": "A native desktop companion for this Mac.",
            "cat.show": "Show cat",
            "cat.lock": "Lock cat position",
            "cat.keepAbove": "Keep above other windows",
            "cat.ignoreClicks": "Ignore pointer clicks",
            "cat.mirrorPointer": "Mirror pointer response",
            "cat.ignorePointer": "Ignore pointer movement",
            "cat.maxDisplay": "Maximum frame rate: Display",
            "cat.maxFPS": "Maximum frame rate: {value} FPS",
            "cat.cornerRadius": "Corner radius",
            "cat.model": "Model",
            "model.models": "Models",
            "model.subtitle": "Built-in and imported Live2D models.",
            "model.deleteTitle": "Delete {name}?",
            "model.deleteMessage": "The model folder will be moved to the Trash.",
            "model.delete": "Delete",
            "model.cancel": "Cancel",
            "model.reveal": "Reveal",
            "model.standard": "Standard",
            "model.keyboard": "Keyboard",
            "model.gamepad": "Gamepad",
            "model.unavailable": "Model resources unavailable",
            "shortcut.subtitle": "Global shortcuts for BongoCat.",
            "shortcut.application": "App",
            "shortcut.motions": "Motions",
            "shortcut.expressions": "Expressions",
            "shortcut.clear": "Clear",
            "shortcut.lockMotion": "Lock {index}",
            "shortcut.showHide": "Show/hide",
            "shortcut.showSettings": "Settings",
            "shortcut.mirror": "Mirror",
            "shortcut.clickThrough": "Click-through",
            "shortcut.alwaysOnTop": "Always on top",
            "about.subtitle": "A native BongoCat for macOS 26 and later.",
            "about.version": "Version",
            "about.sourceCode": "Source Code",
            "about.license": "License",
            "about.diagnostics": "Diagnostics",
            "about.copyInfo": "Copy App Information",
            "menu.keepAbove": "Keep Above Other Windows",
            "menu.lock": "Lock Cat Position",
            "menu.sourceCode": "Source Code",
        ],
        .simplifiedChinese: [
            "input.title": "输入",
            "input.subtitle": "Bongo Cat 只监听键盘和指针事件，不会修改它们。",
            "input.status": "状态",
            "input.stopped": "已停止",
            "input.permission": "需要输入监控权限",
            "input.listening": "正在监听",
            "input.unavailable": "不可用",
            "input.openSettings": "打开输入监控设置",
            "input.retryHint": "如果 BongoCat 已显示为启用，请先关闭再重新开启。返回此处后会自动重试监听。",
            "general.subtitle": "应用行为和外观。",
            "cat.subtitle": "这台 Mac 上的原生桌面伙伴。",
            "cat.show": "显示猫咪",
            "cat.lock": "锁定猫咪位置",
            "cat.keepAbove": "保持在其他窗口上方",
            "cat.ignoreClicks": "忽略指针点击",
            "cat.mirrorPointer": "镜像指针响应",
            "cat.ignorePointer": "忽略指针移动",
            "cat.maxDisplay": "最高帧率：跟随显示器",
            "cat.maxFPS": "最高帧率：{value} FPS",
            "cat.cornerRadius": "圆角",
            "cat.model": "模型",
            "model.models": "模型",
            "model.subtitle": "内置及导入的 Live2D 模型。",
            "model.deleteTitle": "删除 {name}？",
            "model.deleteMessage": "模型文件夹将移到废纸篓。",
            "model.delete": "删除",
            "model.cancel": "取消",
            "model.reveal": "在访达中显示",
            "model.standard": "标准",
            "model.keyboard": "键盘",
            "model.gamepad": "手柄",
            "model.unavailable": "模型资源不可用",
            "shortcut.subtitle": "BongoCat 全局快捷键。",
            "shortcut.application": "应用",
            "shortcut.motions": "动作",
            "shortcut.expressions": "表情",
            "shortcut.clear": "清除",
            "shortcut.lockMotion": "锁定 {index}",
            "shortcut.showHide": "显示/隐藏",
            "shortcut.showSettings": "设置",
            "shortcut.mirror": "镜像",
            "shortcut.clickThrough": "点击穿透",
            "shortcut.alwaysOnTop": "窗口置顶",
            "about.subtitle": "专为 macOS 26 及更高版本打造的原生 BongoCat。",
            "about.version": "版本",
            "about.sourceCode": "源代码",
            "about.license": "许可证",
            "about.diagnostics": "诊断",
            "about.copyInfo": "复制应用信息",
            "menu.keepAbove": "保持在其他窗口上方",
            "menu.lock": "锁定猫咪位置",
            "menu.sourceCode": "源代码",
        ],
        .traditionalChinese: [
            "input.title": "輸入",
            "input.subtitle": "Bongo Cat 只監聽鍵盤和指標事件，不會修改它們。",
            "input.status": "狀態",
            "input.stopped": "已停止",
            "input.permission": "需要輸入監控權限",
            "input.listening": "正在監聽",
            "input.unavailable": "無法使用",
            "input.openSettings": "開啟輸入監控設定",
            "input.retryHint": "如果 BongoCat 已顯示為啟用，請先關閉再重新開啟。返回此處後會自動重試監聽。",
            "general.subtitle": "應用程式行為和外觀。",
            "cat.subtitle": "這台 Mac 上的原生桌面夥伴。",
            "cat.show": "顯示貓咪",
            "cat.lock": "鎖定貓咪位置",
            "cat.keepAbove": "保持在其他視窗上方",
            "cat.ignoreClicks": "忽略指標點擊",
            "cat.mirrorPointer": "鏡像指標回應",
            "cat.ignorePointer": "忽略指標移動",
            "cat.maxDisplay": "最高影格率：跟隨顯示器",
            "cat.maxFPS": "最高影格率：{value} FPS",
            "cat.cornerRadius": "圓角",
            "cat.model": "模型",
            "model.models": "模型",
            "model.subtitle": "內建及匯入的 Live2D 模型。",
            "model.deleteTitle": "刪除 {name}？",
            "model.deleteMessage": "模型資料夾將移到垃圾桶。",
            "model.delete": "刪除",
            "model.cancel": "取消",
            "model.reveal": "在 Finder 中顯示",
            "model.standard": "標準",
            "model.keyboard": "鍵盤",
            "model.gamepad": "控制器",
            "model.unavailable": "模型資源無法使用",
            "shortcut.subtitle": "BongoCat 全域快速鍵。",
            "shortcut.application": "應用程式",
            "shortcut.motions": "動作",
            "shortcut.expressions": "表情",
            "shortcut.clear": "清除",
            "shortcut.lockMotion": "鎖定 {index}",
            "shortcut.showHide": "顯示/隱藏",
            "shortcut.showSettings": "設定",
            "shortcut.mirror": "鏡像",
            "shortcut.clickThrough": "點擊穿透",
            "shortcut.alwaysOnTop": "視窗置頂",
            "about.subtitle": "專為 macOS 26 及更高版本打造的原生 BongoCat。",
            "about.version": "版本",
            "about.sourceCode": "原始碼",
            "about.license": "授權條款",
            "about.diagnostics": "診斷",
            "about.copyInfo": "複製應用程式資訊",
            "menu.keepAbove": "保持在其他視窗上方",
            "menu.lock": "鎖定貓咪位置",
            "menu.sourceCode": "原始碼",
        ],
        .vietnamese: [
            "input.title": "Đầu vào",
            "input.subtitle": "Bongo Cat lắng nghe mà không sửa đổi sự kiện bàn phím hoặc con trỏ.",
            "input.status": "Trạng thái",
            "input.stopped": "Đã dừng",
            "input.permission": "Cần quyền Giám sát đầu vào",
            "input.listening": "Đang lắng nghe",
            "input.unavailable": "Không khả dụng",
            "input.openSettings": "Mở cài đặt Giám sát đầu vào",
            "input.retryHint": "Nếu BongoCat đã được bật, hãy tắt rồi bật lại. Khi quay lại đây, ứng dụng sẽ tự động thử lắng nghe lại.",
            "general.subtitle": "Hành vi và giao diện ứng dụng.",
            "cat.subtitle": "Bạn đồng hành màn hình gốc cho máy Mac này.",
            "cat.show": "Hiện mèo",
            "cat.lock": "Khóa vị trí mèo",
            "cat.keepAbove": "Luôn trên các cửa sổ khác",
            "cat.ignoreClicks": "Bỏ qua nhấp chuột",
            "cat.mirrorPointer": "Đảo phản hồi con trỏ",
            "cat.ignorePointer": "Bỏ qua chuyển động con trỏ",
            "cat.maxDisplay": "Tốc độ khung hình tối đa: Màn hình",
            "cat.maxFPS": "Tốc độ khung hình tối đa: {value} FPS",
            "cat.cornerRadius": "Bán kính góc",
            "cat.model": "Mô hình",
            "model.models": "Mô hình",
            "model.subtitle": "Các mô hình Live2D có sẵn và đã nhập.",
            "model.deleteTitle": "Xóa {name}?",
            "model.deleteMessage": "Thư mục mô hình sẽ được chuyển vào Thùng rác.",
            "model.delete": "Xóa",
            "model.cancel": "Hủy",
            "model.reveal": "Hiện trong Finder",
            "model.standard": "Tiêu chuẩn",
            "model.keyboard": "Bàn phím",
            "model.gamepad": "Tay cầm",
            "model.unavailable": "Tài nguyên mô hình không khả dụng",
            "shortcut.subtitle": "Phím tắt toàn cục cho BongoCat.",
            "shortcut.application": "Ứng dụng",
            "shortcut.motions": "Chuyển động",
            "shortcut.expressions": "Biểu cảm",
            "shortcut.clear": "Xóa",
            "shortcut.lockMotion": "Khóa {index}",
            "shortcut.showHide": "Hiện/ẩn",
            "shortcut.showSettings": "Cài đặt",
            "shortcut.mirror": "Lật gương",
            "shortcut.clickThrough": "Nhấp xuyên",
            "shortcut.alwaysOnTop": "Luôn ở trên",
            "about.subtitle": "BongoCat gốc dành cho macOS 26 trở lên.",
            "about.version": "Phiên bản",
            "about.sourceCode": "Mã nguồn",
            "about.license": "Giấy phép",
            "about.diagnostics": "Chẩn đoán",
            "about.copyInfo": "Sao chép thông tin ứng dụng",
            "menu.keepAbove": "Luôn trên các cửa sổ khác",
            "menu.lock": "Khóa vị trí mèo",
            "menu.sourceCode": "Mã nguồn",
        ],
        .portuguese: [
            "input.title": "Entrada",
            "input.subtitle": "O Bongo Cat escuta sem modificar eventos do teclado ou do ponteiro.",
            "input.status": "Status",
            "input.stopped": "Parado",
            "input.permission": "Monitoramento de entrada necessário",
            "input.listening": "Escutando",
            "input.unavailable": "Indisponível",
            "input.openSettings": "Abrir ajustes de Monitoramento de Entrada",
            "input.retryHint": "Se o BongoCat já estiver ativado, desative e ative novamente. Ao voltar, o aplicativo tentará escutar automaticamente.",
            "general.subtitle": "Comportamento e aparência do aplicativo.",
            "cat.subtitle": "Um companheiro nativo para a área de trabalho deste Mac.",
            "cat.show": "Mostrar gato",
            "cat.lock": "Bloquear posição do gato",
            "cat.keepAbove": "Manter acima das outras janelas",
            "cat.ignoreClicks": "Ignorar cliques do ponteiro",
            "cat.mirrorPointer": "Espelhar resposta do ponteiro",
            "cat.ignorePointer": "Ignorar movimento do ponteiro",
            "cat.maxDisplay": "Taxa máxima de quadros: Tela",
            "cat.maxFPS": "Taxa máxima de quadros: {value} FPS",
            "cat.cornerRadius": "Raio dos cantos",
            "cat.model": "Modelo",
            "model.models": "Modelos",
            "model.subtitle": "Modelos Live2D integrados e importados.",
            "model.deleteTitle": "Excluir {name}?",
            "model.deleteMessage": "A pasta do modelo será movida para o Lixo.",
            "model.delete": "Excluir",
            "model.cancel": "Cancelar",
            "model.reveal": "Mostrar no Finder",
            "model.standard": "Padrão",
            "model.keyboard": "Teclado",
            "model.gamepad": "Controle",
            "model.unavailable": "Recursos do modelo indisponíveis",
            "shortcut.subtitle": "Atalhos globais do BongoCat.",
            "shortcut.application": "Aplicativo",
            "shortcut.motions": "Movimentos",
            "shortcut.expressions": "Expressões",
            "shortcut.clear": "Limpar",
            "shortcut.lockMotion": "Trava {index}",
            "shortcut.showHide": "Mostrar/ocultar",
            "shortcut.showSettings": "Ajustes",
            "shortcut.mirror": "Espelhar",
            "shortcut.clickThrough": "Cliques atravessam",
            "shortcut.alwaysOnTop": "Sempre no topo",
            "about.subtitle": "Um BongoCat nativo para macOS 26 ou posterior.",
            "about.version": "Versão",
            "about.sourceCode": "Código-fonte",
            "about.license": "Licença",
            "about.diagnostics": "Diagnóstico",
            "about.copyInfo": "Copiar informações do aplicativo",
            "menu.keepAbove": "Manter acima das outras janelas",
            "menu.lock": "Bloquear posição do gato",
            "menu.sourceCode": "Código-fonte",
        ],
    ]

    static func text(
        _ key: String,
        language: AppLanguage,
        fallback: String,
        replacements: [String: String] = [:]
    ) -> String {
        var value = extra[language]?[key]
            ?? catalog(for: language).values[key]
            ?? fallback
        for (name, replacement) in replacements {
            value = value.replacingOccurrences(of: "{\(name)}", with: replacement)
        }
        return value
    }

    private static func catalog(for language: AppLanguage) -> LocaleCatalog {
        if let cached = catalogs[language] { return cached }
        guard let url = Bundle.main.url(
            forResource: language.rawValue,
            withExtension: "json",
            subdirectory: "Locales"
        ), let catalog = try? LocaleCatalog.load(from: url) else {
            let empty = LocaleCatalog(values: [:])
            catalogs[language] = empty
            return empty
        }
        catalogs[language] = catalog
        return catalog
    }
}

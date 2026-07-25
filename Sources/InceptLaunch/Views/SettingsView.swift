import SwiftUI
import UniformTypeIdentifiers

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general, interface, appManagement, about

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .general: return "settings.general"
        case .interface: return "settings.interface"
        case .appManagement: return "settings.appManagement"
        case .about: return "settings.about"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .interface: return "paintbrush"
        case .appManagement: return "square.grid.2x2"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @State private var preferences = UserPreferences.default
    @State private var selectedCategory: SettingsCategory? = .general
    private let preferencesStore = PreferencesStore()
    weak var viewModel: LaunchpadViewModel?

    var body: some View {
        NavigationSplitView {
            List(SettingsCategory.allCases, selection: $selectedCategory) { category in
                Label(Localizer.t(category.localizationKey), systemImage: category.icon)
                    .tag(category)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 200)
        } detail: {
            switch selectedCategory {
            case .general:
                GeneralSettingsView(preferences: $preferences, onSave: savePreferences)
            case .interface:
                AppearanceSettingsView(preferences: $preferences, onSave: savePreferences)
            case .appManagement:
                AppManagementSettingsView(preferences: $preferences, viewModel: viewModel, onSave: savePreferences)
            case .about:
                AboutView(preferences: preferences)
            case nil:
                Text("")
            }
        }
        .frame(width: 700, height: 520)
        .onAppear {
            preferences = (try? preferencesStore.load()) ?? .default
            Localizer.setLanguage(preferences.language)
        }
        .onChange(of: preferences.language) { _, newLang in
            Localizer.setLanguage(newLang)
            savePreferences()
        }
    }

    private func savePreferences() {
        do {
            try preferencesStore.save(preferences)
            DiagLog.write("preferences saved OK, showSystemApps=\(preferences.showSystemApplications)")
        } catch {
            DiagLog.write("preferences SAVE FAILED: \(error)")
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Binding var preferences: UserPreferences
    let onSave: () -> Void

    var body: some View {
        Form {
            Section(Localizer.t("settings.language")) {
                Picker("Language", selection: $preferences.language) {
                    ForEach(UserPreferences.Language.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
            }

            Section(Localizer.t("settings.animations")) {
                Toggle(Localizer.t("settings.animateIcons"), isOn: $preferences.animateIcons)
                Toggle(Localizer.t("settings.animatePageFlip"), isOn: $preferences.animatePageFlip)
                Toggle(Localizer.t("settings.animateFolder"), isOn: $preferences.animateFolder)
                Toggle(Localizer.t("settings.animateDrag"), isOn: $preferences.animateDrag)
                Toggle(Localizer.t("settings.animateSearch"), isOn: $preferences.animateSearch)
            }

            Section(Localizer.t("settings.launch")) {
                TextField(Localizer.t("settings.hotKey"), text: $preferences.hotKey)
                Toggle(Localizer.t("settings.launchAtLogin"), isOn: $preferences.launchAtLogin)
                Toggle(Localizer.t("settings.showMenuBarIcon"), isOn: $preferences.showMenuBarIcon)
                Toggle(Localizer.t("settings.showDockIcon"), isOn: $preferences.showDockIcon)
            }
        }
        .formStyle(.grouped)
        .onChange(of: preferences.hotKey) { _, _ in onSave() }
        .onChange(of: preferences.launchAtLogin) { _, _ in onSave() }
        .onChange(of: preferences.showMenuBarIcon) { _, _ in onSave() }
        .onChange(of: preferences.showDockIcon) { _, _ in onSave() }
        .onChange(of: preferences.animateIcons) { _, _ in onSave() }
        .onChange(of: preferences.animatePageFlip) { _, _ in onSave() }
        .onChange(of: preferences.animateFolder) { _, _ in onSave() }
        .onChange(of: preferences.animateDrag) { _, _ in onSave() }
        .onChange(of: preferences.animateSearch) { _, _ in onSave() }
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @Binding var preferences: UserPreferences
    let onSave: () -> Void

    var body: some View {
        Form {
            Section(Localizer.t("settings.appearance")) {
                Slider(value: $preferences.backgroundBlur, in: 0...1) {
                    Text(Localizer.t("settings.backgroundBlur"))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(Localizer.t("settings.appIcon")).font(.headline)
                    HStack(spacing: 12) {
                        ForEach(UserPreferences.AppIconStyle.allCases, id: \.self) { style in
                            IconThumbnailView(
                                style: style,
                                isSelected: preferences.appIconStyle == style
                            )
                            .onTapGesture {
                                preferences.appIconStyle = style
                                IconSwitcher.apply(style)
                                onSave()
                            }
                        }
                    }
                }
            }

            Section(Localizer.t("settings.background")) {
                Picker("Background mode", selection: $preferences.backgroundMode) {
                    Text(Localizer.t("settings.showDesktop")).tag(UserPreferences.BackgroundMode.desktop)
                    Text(Localizer.t("settings.uploadBackground")).tag(UserPreferences.BackgroundMode.uploaded)
                }
                .pickerStyle(.segmented)

                if preferences.backgroundMode == .uploaded {
                    BackgroundImagePicker(
                        images: $preferences.backgroundImages,
                        onSave: onSave
                    )
                    if preferences.backgroundImages.count >= 2 {
                        Toggle(Localizer.t("settings.autoCarousel"), isOn: $preferences.autoCarousel)
                        Text(preferences.autoCarousel
                             ? Localizer.t("settings.carouselHint")
                             : Localizer.t("settings.firstImageHint"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: preferences.backgroundBlur) { _, _ in onSave() }
        .onChange(of: preferences.backgroundMode) { _, _ in onSave() }
        .onChange(of: preferences.autoCarousel) { _, _ in onSave() }
    }
}

// MARK: - App Management Settings

struct AppManagementSettingsView: View {
    @Binding var preferences: UserPreferences
    weak var viewModel: LaunchpadViewModel?
    let onSave: () -> Void

    var body: some View {
        Form {
            Section(Localizer.t("settings.systemApps")) {
                Toggle(Localizer.t("settings.showSystemApps"), isOn: $preferences.showSystemApplications)
            }

            Section(Localizer.t("settings.hiddenApps")) {
                Toggle(Localizer.t("settings.showHiddenInSearch"), isOn: $preferences.showHiddenInSearch)

                if let vm = viewModel, !vm.hiddenApps.isEmpty {
                    ForEach(vm.hiddenApps) { record in
                        HStack {
                            AppIconSmall(record: record)
                            Text(record.name)
                            Spacer()
                            Button(Localizer.t("menu.unhide")) {
                                viewModel?.unhideApp(id: record.id)
                                onSave()
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } else {
                    Text(Localizer.t("settings.noHiddenApps"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: preferences.showSystemApplications) { _, newValue in
            DiagLog.write("showSystemApplications toggled to \(newValue), viewModel is \(viewModel == nil ? "nil" : "valid")")
            viewModel?.showSystemApplications = newValue
            onSave()
        }
        .onChange(of: preferences.showHiddenInSearch) { _, newValue in
            DiagLog.write("showHiddenInSearch toggled to \(newValue), viewModel is \(viewModel == nil ? "nil" : "valid")")
            viewModel?.showHiddenInSearch = newValue
            onSave()
        }
    }
}

// MARK: - About View

struct AboutView: View {
    let preferences: UserPreferences
    @State private var showCopied = false

    private var appIcon: NSImage? {
        let name = preferences.appIconStyle.resourceName
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "icns"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        return NSImage(named: name)
    }

    private var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Group {
                if let img = appIcon {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.gray.opacity(0.3))
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(radius: 4)

            Text("InceptLaunch")
                .font(.title2.weight(.semibold))

            Text("\(Localizer.t("about.version")) \(versionString)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                linkRow(label: Localizer.t("about.website"), value: "www.xiaoanhome.xyz") {
                    NSWorkspace.shared.open(URL(string: "https://www.xiaoanhome.xyz/")!)
                }
                linkRow(label: "X", value: "@countquery") {
                    NSWorkspace.shared.open(URL(string: "https://x.com/countquery")!)
                }
                linkRow(label: Localizer.t("about.wechatOA"), value: "mowenfeigong") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("mowenfeigong", forType: .string)
                    showCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCopied = false
                    }
                }
            }
            .padding(.top, 8)

            if showCopied {
                Text(Localizer.t("about.copied"))
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func linkRow(label: String, value: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: action) {
                Text(value)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Background Image Picker

struct BackgroundImagePicker: View {
    @Binding var images: [String]
    let onSave: () -> Void

    private let maxImages = 10
    /// 5 columns × 2 rows grid
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    uploadImages()
                } label: {
                    Label(Localizer.t("settings.upload"), systemImage: "plus")
                }
                .disabled(images.count >= maxImages)

                if !images.isEmpty {
                    Button(role: .destructive) {
                        images.removeAll()
                        onSave()
                    } label: {
                        Label(Localizer.t("settings.resetBackground"), systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()
                Text("\(images.count)/\(maxImages)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !images.isEmpty {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(images.indices, id: \.self) { index in
                        BackgroundThumbnail(
                            path: images[index],
                            onDelete: {
                                images.remove(at: index)
                                onSave()
                            }
                        )
                        .draggable("\(index)")
                        .dropDestination(for: String.self) { items, _ in
                            guard let sourceStr = items.first,
                                  let sourceIndex = Int(sourceStr),
                                  sourceIndex != index else { return false }
                            let moved = images.remove(at: sourceIndex)
                            images.insert(moved, at: index)
                            onSave()
                            return true
                        }
                    }
                }
            }
        }
    }

    private func uploadImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.allowedContentTypes = [.image]
        panel.prompt = Localizer.t("settings.chooseImage")

        guard panel.runModal() == .OK else { return }

        let remaining = maxImages - images.count
        let newPaths = panel.urls.prefix(remaining).map { $0.path }
        images.append(contentsOf: newPaths)
        onSave()
    }
}

struct BackgroundThumbnail: View {
    let path: String
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let nsImage = NSImage(contentsOfFile: path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
            }
            .frame(height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white, .black.opacity(0.5))
            }
            .buttonStyle(.plain)
            .padding(4)
        }
    }
}

// MARK: - Small App Icon for Hidden Apps List

struct AppIconSmall: View {
    let record: AppRecord

    var body: some View {
        let nsImage = NSWorkspace.shared.icon(forFile: record.path)
        Image(nsImage: nsImage)
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .frame(width: 24, height: 24)
    }
}

// MARK: - Icon Thumbnail View

struct IconThumbnailView: View {
    let style: UserPreferences.AppIconStyle
    let isSelected: Bool

    private var nsImage: NSImage? {
        let name = style.thumbnailName
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "icns"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        return NSImage(named: name)
    }

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if let img = nsImage {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(Text(style.displayName).font(.caption2))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
            )
            .shadow(radius: isSelected ? 3 : 1)
            Text(style.displayName)
                .font(.caption2)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .contentShape(Rectangle())
    }
}

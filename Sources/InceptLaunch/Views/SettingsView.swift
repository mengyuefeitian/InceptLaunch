import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @State private var preferences = UserPreferences.default
    private let preferencesStore = PreferencesStore()
    weak var viewModel: LaunchpadViewModel?

    var body: some View {
        Form {
            Section(Localizer.t("settings.language")) {
                Picker("Language", selection: $preferences.language) {
                    ForEach(UserPreferences.Language.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
            }

            Section(Localizer.t("settings.launch")) {
                TextField(Localizer.t("settings.hotKey"), text: $preferences.hotKey)
                Toggle(Localizer.t("settings.launchAtLogin"), isOn: $preferences.launchAtLogin)
                Toggle(Localizer.t("settings.showMenuBarIcon"), isOn: $preferences.showMenuBarIcon)
                Toggle(Localizer.t("settings.showDockIcon"), isOn: $preferences.showDockIcon)
            }

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
                                savePreferences()
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
                        onSave: savePreferences
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

            Section(Localizer.t("settings.animations")) {
                Toggle(Localizer.t("settings.animateIcons"), isOn: $preferences.animateIcons)
                Toggle(Localizer.t("settings.animatePageFlip"), isOn: $preferences.animatePageFlip)
                Toggle(Localizer.t("settings.animateFolder"), isOn: $preferences.animateFolder)
                Toggle(Localizer.t("settings.animateDrag"), isOn: $preferences.animateDrag)
                Toggle(Localizer.t("settings.animateSearch"), isOn: $preferences.animateSearch)
            }

            Section(Localizer.t("settings.hiddenApps")) {
                if let vm = viewModel, !vm.hiddenApps.isEmpty {
                    ForEach(vm.hiddenApps) { record in
                        HStack {
                            AppIconSmall(record: record)
                            Text(record.name)
                            Spacer()
                            Button(Localizer.t("menu.unhide")) {
                                viewModel?.unhideApp(id: record.id)
                                savePreferences()
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } else {
                    Text(Localizer.t("settings.noHiddenApps"))
                        .foregroundStyle(.secondary)
                }
            }

            Section(Localizer.t("settings.apps")) {
                Toggle(Localizer.t("settings.showSystemApps"), isOn: $preferences.showSystemApplications)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 560, height: 520)
        .onAppear {
            preferences = (try? preferencesStore.load()) ?? .default
            Localizer.setLanguage(preferences.language)
        }
        .onChange(of: preferences.hotKey) { _, _ in savePreferences() }
        .onChange(of: preferences.launchAtLogin) { _, _ in savePreferences() }
        .onChange(of: preferences.showMenuBarIcon) { _, _ in savePreferences() }
        .onChange(of: preferences.showDockIcon) { _, _ in savePreferences() }
        .onChange(of: preferences.backgroundBlur) { _, _ in savePreferences() }
        .onChange(of: preferences.reduceMotion) { _, _ in savePreferences() }
        .onChange(of: preferences.showSystemApplications) { _, _ in savePreferences() }
        .onChange(of: preferences.language) { _, newLang in
            Localizer.setLanguage(newLang)
            savePreferences()
        }
        .onChange(of: preferences.backgroundMode) { _, _ in savePreferences() }
        .onChange(of: preferences.autoCarousel) { _, _ in savePreferences() }
        .onChange(of: preferences.animateIcons) { _, _ in savePreferences() }
        .onChange(of: preferences.animatePageFlip) { _, _ in savePreferences() }
        .onChange(of: preferences.animateFolder) { _, _ in savePreferences() }
        .onChange(of: preferences.animateDrag) { _, _ in savePreferences() }
        .onChange(of: preferences.animateSearch) { _, _ in savePreferences() }
    }

    private func savePreferences() {
        try? preferencesStore.save(preferences)
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

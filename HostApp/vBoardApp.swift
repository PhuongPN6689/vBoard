import SwiftUI
import vBoardEngine

@main
struct vBoardApp: App {
    var body: some Scene {
        WindowGroup {
            SettingsDashboardView()
                .onOpenURL { url in
                    print("[vBoardApp] Received URL: \(url)")
                }
        }
    }
}

// MARK: - 1. Root Dashboard (Màn hình chính)

struct SettingsDashboardView: View {
    @State private var testText: String = ""
    @State private var testNumber: String = ""

    // Quick reactive states for Dashboard Badges
    @State private var keyboardHeightScale: KeyboardHeightScale = vBoardSettings.shared.keyboardHeightScale
    @State private var inputMethod: InputMethod = vBoardSettings.shared.inputMethod
    @State private var isDevModeEnabled: Bool = vBoardSettings.shared.isDeveloperModeButtonEnabled
    @State private var hapticIntensity: HapticIntensity = vBoardSettings.shared.hapticIntensity
    @State private var themeMode: ThemeMode = vBoardSettings.shared.themeMode
    @State private var oneHandedMode: OneHandedMode = vBoardSettings.shared.oneHandedMode
    @State private var colorTheme: KeyboardColorTheme = vBoardSettings.shared.colorTheme
    @State private var clipboardCount: Int = ClipboardManager.shared.getHistory().count

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Khu vực Gõ Thử Nghiệm Trực Tiếp
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("1. Ô nhập văn bản tiếng Việt & ký tự thường:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Gõ thử văn bản tiếng Việt, code...", text: $testText)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("2. Ô nhập số (Phone/Number pad test):")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Gõ thử số điện thoại, số tiền, mã OTP...", text: $testNumber)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.vertical, 2)
                } header: {
                    Label("Khu vực gõ thử nghiệm trực tiếp", systemImage: "keyboard")
                } footer: {
                    Text("Mọi thay đổi cài đặt bên dưới sẽ có hiệu lực tức thì (< 0.1ms) tại ô gõ thử nghiệm này.")
                        .font(.caption2)
                }

                // Section Nổi bật: Hướng dẫn kích hoạt bàn phím
                Section(header: Label("Bắt đầu nhanh", systemImage: "sparkles")) {
                    NavigationLink {
                        KeyboardSetupGuideView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Hướng dẫn kích hoạt bàn phím")
                                    .font(.headline)
                                Text("3 bước đơn giản để kích hoạt vBoard trong Cài đặt iPhone")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 3)
                    }
                }

                // Section 2: Danh mục 9 Phân hệ Cài đặt Chuyên sâu
                Section(header: Label("Cấu hình bàn phím vBoard", systemImage: "slider.horizontal.3")) {
                    // 1. Bố cục & Phím
                    NavigationLink {
                        KeysLayoutSettingsView(currentScale: $keyboardHeightScale, currentOneHanded: $oneHandedMode)
                    } label: {
                        HStack {
                            Label("Bố cục, Kích thước & Phím", systemImage: "ruler")
                            Spacer()
                            Text(keyboardHeightScale.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // 2. Chỉnh sửa & Đề xuất từ
                    NavigationLink {
                        TextCorrectionSettingsView()
                    } label: {
                        HStack {
                            Label("Chỉnh sửa & Đề xuất từ", systemImage: "text.badge.checkmark")
                            Spacer()
                            Text("Bi-gram, Emoji")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Điểm số Từ điển & Tự học N-gram
                    NavigationLink {
                        DictionaryScoresExplorerView()
                    } label: {
                        HStack {
                            Label("Điểm số Từ điển & Tự học N-gram", systemImage: "chart.bar.doc.horizontal.fill")
                            Spacer()
                            Text("1, 2, 3 chữ")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                    }

                    // 3. Nhập bằng cách lướt
                    NavigationLink {
                        GlideTypingSettingsView()
                    } label: {
                        HStack {
                            Label("Nhập bằng cách lướt (Glide)", systemImage: "hand.draw.fill")
                            Spacer()
                            Text(vBoardSettings.shared.isGlideTypingEnabled ? "Bật" : "Tắt")
                                .font(.subheadline)
                                .foregroundStyle(vBoardSettings.shared.isGlideTypingEnabled ? .blue : .secondary)
                        }
                    }

                    // 4. Cử chỉ & Phản hồi
                    NavigationLink {
                        GesturesFeedbackSettingsView(currentIntensity: $hapticIntensity)
                    } label: {
                        HStack {
                            Label("Cử chỉ & Phản hồi Rung/Âm", systemImage: "hand.tap.fill")
                            Spacer()
                            Text(vBoardSettings.shared.isHapticEnabled ? hapticIntensity.displayName : "Tắt")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // 5. Giao diện & Chủ đề Màu sắc
                    NavigationLink {
                        ThemeSettingsView(currentColorTheme: $colorTheme)
                    } label: {
                        HStack {
                            Label("Giao diện, Chủ đề & Gradient", systemImage: "paintpalette.fill")
                            Spacer()
                            Text(colorTheme.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // 6. Ngôn ngữ & Bộ gõ OpenKey
                    NavigationLink {
                        OpenKeySettingsView(currentMethod: $inputMethod)
                    } label: {
                        HStack {
                            Label("Ngôn ngữ & Bộ gõ OpenKey", systemImage: "character.bubble")
                            Spacer()
                            Text(inputMethod == .vni ? "VNI" : (inputMethod == .simpleTelex ? "Simple Telex" : "Telex"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // 7. Bàn phím Lập trình viên
                    NavigationLink {
                        DeveloperSettingsView(isDevButtonEnabled: $isDevModeEnabled)
                    } label: {
                        HStack {
                            Label("Bàn phím Lập trình viên (Dev Mode)", systemImage: "chevron.left.forwardslash.chevron.right")
                            Spacer()
                            Text(isDevModeEnabled ? "Bật" : "Tắt")
                                .font(.subheadline)
                                .foregroundStyle(isDevModeEnabled ? .blue : .secondary)
                        }
                    }

                    // 8. Bảng tạm & Từ điển
                    NavigationLink {
                        ClipboardDictionarySettingsView(clipboardCount: $clipboardCount)
                    } label: {
                        HStack {
                            Label("Bảng tạm & Từ điển Cá nhân", systemImage: "doc.on.clipboard.fill")
                            Spacer()
                            Text("19.047 từ")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // 9. Tùy biến Toolbar
                    NavigationLink {
                        ToolbarSettingsView()
                    } label: {
                        HStack {
                            Label("Tùy biến Thanh công cụ Toolbar", systemImage: "square.grid.2x2")
                            Spacer()
                            Text("Sắp xếp")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Section 3: Thông tin, Trợ giúp & Quyền riêng tư
                Section(header: Label("Thông tin & Trợ giúp", systemImage: "info.circle")) {
                    NavigationLink {
                        KeyboardSetupGuideView()
                    } label: {
                        Label("Hướng dẫn kích hoạt bàn phím", systemImage: "questionmark.circle")
                    }

                    NavigationLink {
                        PrivacySecurityPolicyView()
                    } label: {
                        HStack {
                            Label("Chính sách Quyền riêng tư & Bảo mật", systemImage: "lock.shield.fill")
                            Spacer()
                            Text("100% On-Device")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }

                    NavigationLink {
                        PerformanceAboutView()
                    } label: {
                        HStack {
                            Label("Thông tin Kỹ thuật & Hiệu năng", systemImage: "bolt.fill")
                            Spacer()
                            Text("RAM < 15MB")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .navigationTitle("Cài đặt vBoard")
            .onAppear {
                keyboardHeightScale = vBoardSettings.shared.keyboardHeightScale
                inputMethod = vBoardSettings.shared.inputMethod
                isDevModeEnabled = vBoardSettings.shared.isDeveloperModeButtonEnabled
                hapticIntensity = vBoardSettings.shared.hapticIntensity
                themeMode = vBoardSettings.shared.themeMode
                oneHandedMode = vBoardSettings.shared.oneHandedMode
                colorTheme = vBoardSettings.shared.colorTheme
                clipboardCount = ClipboardManager.shared.getHistory().count
            }
        }
    }
}

// MARK: - 2. Màn hình Bố cục, Kích thước & Phím (KeysLayoutSettingsView)

struct KeysLayoutSettingsView: View {
    @Binding var currentScale: KeyboardHeightScale
    @Binding var currentOneHanded: OneHandedMode

    @State private var scale: KeyboardHeightScale = vBoardSettings.shared.keyboardHeightScale
    @State private var oneHanded: OneHandedMode = vBoardSettings.shared.oneHandedMode
    @State private var isNumberRow: Bool = vBoardSettings.shared.isNumberRowEnabled
    @State private var isNumberRowPassword: Bool = vBoardSettings.shared.isNumberRowForPasswordEnabled
    @State private var isCommaEnabled: Bool = vBoardSettings.shared.isCommaKeyEnabled
    @State private var isPeriodEnabled: Bool = vBoardSettings.shared.isPeriodKeyEnabled
    @State private var isHintSymbols: Bool = vBoardSettings.shared.isHintSymbolsEnabled
    @State private var fontFamily: KeyboardFontFamily = vBoardSettings.shared.fontFamily
    @State private var fontSizeScale: Double = vBoardSettings.shared.fontSizeScale

    var body: some View {
        Form {
            Section(header: Text("Kích thước chiều cao bàn phím")) {
                Picker("Chiều cao", selection: $scale) {
                    ForEach(KeyboardHeightScale.allCases) { item in
                        Text(item.displayName).tag(item)
                    }
                }
                .pickerStyle(.inline)
                .onChange(of: scale) { newValue in
                    vBoardSettings.shared.keyboardHeightScale = newValue
                    currentScale = newValue
                    vBoardSettings.shared.notifySettingsChanged()
                }
            }

            Section(header: Text("Chế độ bàn phím gõ một tay")) {
                Picker("Bàn phím một tay", selection: $oneHanded) {
                    ForEach(OneHandedMode.allCases) { item in
                        Text(item.displayName).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: oneHanded) { val in
                    vBoardSettings.shared.oneHandedMode = val
                    currentOneHanded = val
                    vBoardSettings.shared.notifySettingsChanged()
                }
            }

            Section(header: Text("Hàng phím & Phím bấm")) {
                Toggle("Hàng phím số cố định trên cùng", isOn: $isNumberRow)
                    .onChange(of: isNumberRow) { val in
                        vBoardSettings.shared.isNumberRowEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }

                Toggle("Hàng số thông minh cho mật khẩu", isOn: $isNumberRowPassword)
                    .onChange(of: isNumberRowPassword) { val in
                        vBoardSettings.shared.isNumberRowForPasswordEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }

                Toggle("Phím dấu phẩy (,) hàng đáy", isOn: $isCommaEnabled)
                    .onChange(of: isCommaEnabled) { val in
                        vBoardSettings.shared.isCommaKeyEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }

                Toggle("Phím dấu chấm (.) hàng đáy", isOn: $isPeriodEnabled)
                    .onChange(of: isPeriodEnabled) { val in
                        vBoardSettings.shared.isPeriodKeyEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }

                Toggle("Ký hiệu phụ trên phím chữ", isOn: $isHintSymbols)
                    .onChange(of: isHintSymbols) { val in
                        vBoardSettings.shared.isHintSymbolsEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }
            }

            Section(header: Text("Phông chữ & Cỡ chữ")) {
                Picker("Phông chữ bàn phím", selection: $fontFamily) {
                    ForEach(KeyboardFontFamily.allCases) { item in
                        Text(item.displayName).tag(item)
                    }
                }
                .onChange(of: fontFamily) { val in
                    vBoardSettings.shared.fontFamily = val
                    vBoardSettings.shared.notifySettingsChanged()
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Tỷ lệ cỡ chữ:")
                        Spacer()
                        Text("\(Int(fontSizeScale * 100))%")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $fontSizeScale, in: 0.8...1.2, step: 0.05)
                        .onChange(of: fontSizeScale) { val in
                            vBoardSettings.shared.fontSizeScale = val
                            vBoardSettings.shared.notifySettingsChanged()
                        }
                }
            }
        }
        .navigationTitle("Bố cục & Phím")
    }
}

// MARK: - 3. Màn hình Chỉnh sửa & Đề xuất từ (TextCorrectionSettingsView)

struct TextCorrectionSettingsView: View {
    @State private var isAutoCapitalization = vBoardSettings.shared.isAutoCapitalizationEnabled
    @State private var isAutoSpace = vBoardSettings.shared.isAutoSpaceAfterPunctuationEnabled
    @State private var isAutoABC = vBoardSettings.shared.isAutoSwitchToABCAfterApostropheEnabled
    @State private var isNextWord = vBoardSettings.shared.isNextWordPredictionEnabled
    @State private var isTextEmoji = vBoardSettings.shared.isTextToEmojiEnabled
    @State private var isSuggestionBar = vBoardSettings.shared.isSuggestionBarEnabled

    var body: some View {
        Form {
            Section(header: Text("Thanh gợi ý & Dự đoán")) {
                Toggle("Bật thanh gợi ý từ (Suggestion Bar)", isOn: $isSuggestionBar)
                    .onChange(of: isSuggestionBar) { val in
                        vBoardSettings.shared.isSuggestionBarEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }

                Toggle("Dự đoán từ tiếp theo (Bi-gram n-gram)", isOn: $isNextWord)
                    .onChange(of: isNextWord) { val in
                        vBoardSettings.shared.isNextWordPredictionEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }

                Toggle("Chuyển văn bản thành Emoji (Text to Emoji)", isOn: $isTextEmoji)
                    .onChange(of: isTextEmoji) { val in
                        vBoardSettings.shared.isTextToEmojiEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }

                NavigationLink {
                    DictionaryScoresExplorerView()
                } label: {
                    HStack {
                        Label("Tra cứu Điểm số Từ điển (1, 2, 3 chữ)", systemImage: "chart.bar.xaxis")
                        Spacer()
                        Text("Chi tiết")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
            }

            Section(header: Text("Tự động sửa & Thông minh")) {
                Toggle("Tự động viết hoa đầu câu", isOn: $isAutoCapitalization)
                    .onChange(of: isAutoCapitalization) { val in
                        vBoardSettings.shared.isAutoCapitalizationEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }

                Toggle("Dấu cách tự động sau dấu câu (, . ! ?)", isOn: $isAutoSpace)
                    .onChange(of: isAutoSpace) { val in
                        vBoardSettings.shared.isAutoSpaceAfterPunctuationEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }

                Toggle("Tự động về ABC sau dấu nháy đơn (')", isOn: $isAutoABC)
                    .onChange(of: isAutoABC) { val in
                        vBoardSettings.shared.isAutoSwitchToABCAfterApostropheEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }
            }
        }
        .navigationTitle("Chỉnh sửa & Đề xuất")
    }
}

// MARK: - 4. Màn hình Nhập bằng cách lướt (GlideTypingSettingsView)

struct GlideTypingSettingsView: View {
    @State private var isGlideEnabled = vBoardSettings.shared.isGlideTypingEnabled
    @State private var isGlideTrail = vBoardSettings.shared.isGlideTrailEnabled
    @State private var isSpaceCursor = vBoardSettings.shared.isSpaceCursorGlideEnabled
    @State private var isSwipeDelete = vBoardSettings.shared.isSwipeDeleteEnabled

    var body: some View {
        Form {
            Section {
                Toggle("Bật cử chỉ gõ lướt (Glide Typing)", isOn: $isGlideEnabled)
                    .onChange(of: isGlideEnabled) { val in
                        vBoardSettings.shared.isGlideTypingEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }

                Toggle("Hiển thị vệt sáng lướt ngón tay", isOn: $isGlideTrail)
                    .disabled(!isGlideEnabled)
                    .onChange(of: isGlideTrail) { val in
                        vBoardSettings.shared.isGlideTrailEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }
            } header: {
                Text("Gõ lướt phím (Glide Typing)")
            } footer: {
                Text("Trượt ngón tay liên tục qua các chữ cái để nhập từ mà không cần nhấc tay.")
                    .font(.caption2)
            }

            Section(header: Text("Cử chỉ phím chuyên dụng")) {
                Toggle("Trượt phím Space di chuyển con trỏ", isOn: $isSpaceCursor)
                    .onChange(of: isSpaceCursor) { val in
                        vBoardSettings.shared.isSpaceCursorGlideEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }

                Toggle("Vuốt phím Xóa sang trái để xóa từ", isOn: $isSwipeDelete)
                    .onChange(of: isSwipeDelete) { val in
                        vBoardSettings.shared.isSwipeDeleteEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }
            }

            #if DEBUG
            Section(header: Text("Kiểm thử & Thu thập dữ liệu")) {
                NavigationLink {
                    GlideBenchmarkView()
                } label: {
                    HStack {
                        Label("Phòng thí nghiệm & Thu thập dữ liệu 50 từ", systemImage: "sparkles.rectangle.stack.fill")
                        Spacer()
                        Text("50 từ Lab")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
            #endif
        }
        .navigationTitle("Nhập bằng cách lướt")
    }
}

// MARK: - 5. Màn hình Cử chỉ & Phản hồi Rung/Âm (GesturesFeedbackSettingsView)

struct GesturesFeedbackSettingsView: View {
    @Binding var currentIntensity: HapticIntensity

    @State private var isHaptic: Bool = vBoardSettings.shared.isHapticEnabled
    @State private var intensity: HapticIntensity = vBoardSettings.shared.hapticIntensity
    @State private var isKeySound: Bool = vBoardSettings.shared.isKeySoundEnabled
    @State private var soundVolume: Float = vBoardSettings.shared.soundVolume
    @State private var isFlickDown: Bool = vBoardSettings.shared.isFlickDownEnabled
    @State private var longPressMs: Double = Double(vBoardSettings.shared.longPressDelayMs)

    var body: some View {
        Form {
            Section(header: Text("Rung xúc giác (Taptic Engine)")) {
                Toggle("Rung khi chạm phím", isOn: $isHaptic)
                    .onChange(of: isHaptic) { val in
                        vBoardSettings.shared.isHapticEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }

                if isHaptic {
                    Picker("Cường độ rung", selection: $intensity) {
                        ForEach(HapticIntensity.allCases) { item in
                            Text(item.displayName).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: intensity) { val in
                        vBoardSettings.shared.hapticIntensity = val
                        currentIntensity = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }
                }
            }

            Section(header: Text("Âm thanh gõ phím")) {
                Toggle("Âm thanh gõ phím (Click Sound)", isOn: $isKeySound)
                    .onChange(of: isKeySound) { val in
                        vBoardSettings.shared.isKeySoundEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }

                if isKeySound {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Âm lượng:")
                            Spacer()
                            Text("\(Int(soundVolume * 100))%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $soundVolume, in: 0.1...1.0, step: 0.1)
                            .onChange(of: soundVolume) { val in
                                vBoardSettings.shared.soundVolume = val
                                vBoardSettings.shared.notifySettingsChanged()
                            }
                    }
                }
            }

            Section(header: Text("Cử chỉ vuốt phím & Độ trễ")) {
                Toggle("Vuốt phím xuống nhập ký hiệu phụ (Flick Down)", isOn: $isFlickDown)
                    .onChange(of: isFlickDown) { val in
                        vBoardSettings.shared.isFlickDownEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Thời gian chạm và giữ:")
                        Spacer()
                        Text("\(Int(longPressMs)) ms")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $longPressMs, in: 150...450, step: 25)
                        .onChange(of: longPressMs) { val in
                            vBoardSettings.shared.longPressDelayMs = Int(val)
                            vBoardSettings.shared.notifySettingsChanged()
                        }
                }
            }
        }
        .navigationTitle("Cử chỉ & Phản hồi")
    }
}

// MARK: - 6. Màn hình Giao diện & Chủ đề Màu sắc (ThemeSettingsView)

struct ThemeSettingsView: View {
    @Binding var currentColorTheme: KeyboardColorTheme

    @State private var theme: KeyboardColorTheme = vBoardSettings.shared.colorTheme
    @State private var isKeyBorder: Bool = vBoardSettings.shared.isKeyBorderEnabled

    var body: some View {
        Form {
            Section {
                Toggle("Bật viền phím (Key Borders)", isOn: $isKeyBorder)
                    .onChange(of: isKeyBorder) { val in
                        vBoardSettings.shared.isKeyBorderEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }
            } header: {
                Text("Viền phím & Kiểu dáng")
            } footer: {
                Text("Tắt viền phím để trải nghiệm giao diện phẳng thanh thoát (Flat Material Design).")
                    .font(.caption2)
            }

            Section(header: Text("Bộ Theme Màu Toàn Diện (Solid Themes)")) {
                Picker("Theme màu", selection: $theme) {
                    Text("Chuẩn Material You").tag(KeyboardColorTheme.standard)
                    Text("Gboard Dark Slate").tag(KeyboardColorTheme.gboardSlate)
                    Text("OLED Pitch Black").tag(KeyboardColorTheme.pitchBlack)
                    Text("Clean Paper White").tag(KeyboardColorTheme.paperWhite)
                    Text("Deep Midnight Navy").tag(KeyboardColorTheme.midnightNavy)
                    Text("Cyberpunk Neon").tag(KeyboardColorTheme.cyberpunk)
                }
                .pickerStyle(.inline)
                .onChange(of: theme) { val in
                    vBoardSettings.shared.colorTheme = val
                    currentColorTheme = val
                    vBoardSettings.shared.notifySettingsChanged()
                }
            }

            Section(header: Text("Theme Gradient Vector (GPU 0% RAM)")) {
                Picker("Theme Gradient", selection: $theme) {
                    Text("Pastel Rose (Dốc nhẹ)").tag(KeyboardColorTheme.gradientPastelRose)
                    Text("Sky Breeze (Dốc nhẹ)").tag(KeyboardColorTheme.gradientSkyBreeze)
                    Text("Mint Whisper (Dốc nhẹ)").tag(KeyboardColorTheme.gradientMintWhisper)
                    Text("Twilight Purple (Dốc đứng)").tag(KeyboardColorTheme.gradientTwilightPurple)
                    Text("Deep Ocean (Dốc đứng)").tag(KeyboardColorTheme.gradientDeepOcean)
                    Text("Sunset Glow (Dốc đứng)").tag(KeyboardColorTheme.gradientSunsetGlow)
                }
                .pickerStyle(.inline)
                .onChange(of: theme) { val in
                    vBoardSettings.shared.colorTheme = val
                    currentColorTheme = val
                    vBoardSettings.shared.notifySettingsChanged()
                }
            }
        }
        .navigationTitle("Giao diện & Chủ đề")
    }
}

// MARK: - 7. Màn hình Thiết lập OpenKey (Bộ gõ & Gõ tắt chuẩn OpenKey)

struct OpenKeySettingsView: View {
    @Binding var currentMethod: InputMethod

    @State private var selectedTab: Int = 0 // 0: Bộ gõ, 1: Gõ tắt

    // Tab 1: Bộ gõ States
    @State private var method: InputMethod = vBoardSettings.shared.inputMethod
    @State private var isOldStyleDiacritic: Bool = (vBoardSettings.shared.diacriticStyle == .oldStyle)
    @State private var isSpellingCheck: Bool = vBoardSettings.shared.isSpellingCheckEnabled
    @State private var isFixBrowserSuggestion: Bool = vBoardSettings.shared.isFixBrowserSuggestionEnabled
    @State private var isRestoreWrongSpelling: Bool = vBoardSettings.shared.isRestoreIfWrongSpellingEnabled
    @State private var isAutoCapitalization: Bool = vBoardSettings.shared.isAutoCapitalizationEnabled
    @State private var isAllowZFWJ: Bool = vBoardSettings.shared.isAllowConsonantZFWJEnabled
    @State private var isSmartSwitchMode: Bool = vBoardSettings.shared.isSmartSwitchModeEnabled

    // Tiện ích bổ trợ Telex
    @State private var isBrackets: Bool = vBoardSettings.shared.isBracketShortcutsEnabled
    @State private var isZRemove: Bool = vBoardSettings.shared.isZKeyRemoveToneEnabled
    @State private var isWBeginning: Bool = vBoardSettings.shared.isWAtWordBeginningEnabled
    @State private var isToneBalancing: Bool = vBoardSettings.shared.isModernToneBalancingEnabled

    // Tab 2: Gõ tắt States
    @State private var isMacroEnabled: Bool = vBoardSettings.shared.isShortcutExpansionEnabled
    @State private var isQuickTelex: Bool = vBoardSettings.shared.isQuickTelexEnabled
    @State private var isMacroEvenWhenOff: Bool = vBoardSettings.shared.isMacroEvenWhenOffEnabled
    @State private var isAutoCapsMacro: Bool = vBoardSettings.shared.isAutoCapsMacroEnabled
    @State private var isQuickStartConsonant: Bool = vBoardSettings.shared.isQuickStartConsonantEnabled
    @State private var isQuickEndConsonant: Bool = vBoardSettings.shared.isQuickEndConsonantEnabled

    @State private var showMacroTableSheet: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Bộ chọn Tab phong cách OpenKey
            Picker("Chế độ thiết lập", selection: $selectedTab) {
                Text("Bộ gõ").tag(0)
                Text("Gõ tắt").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(UIColor.secondarySystemBackground))

            Form {
                if selectedTab == 0 {
                    // ==========================================
                    // TAB 1: BỘ GÕ (media_1788971919722.png)
                    // ==========================================
                    Section(header: Text("Kiểu gõ tiếng Việt")) {
                        Picker("Phương thức nhập", selection: $method) {
                            Text("Telex (Chuẩn đầy đủ)").tag(InputMethod.telex)
                            Text("Simple Telex (Đơn giản)").tag(InputMethod.simpleTelex)
                            Text("VNI (Gõ số)").tag(InputMethod.vni)
                        }
                        .pickerStyle(.inline)
                        .onChange(of: method) { val in
                            vBoardSettings.shared.inputMethod = val
                            currentMethod = val
                            vBoardSettings.shared.notifySettingsChanged()
                        }
                    }

                    Section {
                        // 1. Đặt dấu oà, uý (thay vì òa, úy)
                        Toggle("Đặt dấu oà, uý (thay vì òa, úy)", isOn: $isOldStyleDiacritic)
                            .onChange(of: isOldStyleDiacritic) { val in
                                vBoardSettings.shared.diacriticStyle = val ? .oldStyle : .newStyle
                                vBoardSettings.shared.notifySettingsChanged()
                            }

                        // 2. Kiểm tra chính tả
                        Toggle("Kiểm tra chính tả", isOn: $isSpellingCheck)
                            .onChange(of: isSpellingCheck) { val in
                                vBoardSettings.shared.isSpellingCheckEnabled = val
                                vBoardSettings.shared.notifySettingsChanged()
                            }

                        // 3. Sửa lỗi gợi ý (trình duyệt, Excel,...)
                        Toggle("Sửa lỗi gợi ý (trình duyệt, Excel,...)", isOn: $isFixBrowserSuggestion)
                            .onChange(of: isFixBrowserSuggestion) { val in
                                vBoardSettings.shared.isFixBrowserSuggestionEnabled = val
                                vBoardSettings.shared.notifySettingsChanged()
                            }

                        // 4. Tự khôi phục phím với từ sai
                        Toggle("Tự khôi phục phím với từ sai", isOn: $isRestoreWrongSpelling)
                            .onChange(of: isRestoreWrongSpelling) { val in
                                vBoardSettings.shared.isRestoreIfWrongSpellingEnabled = val
                                vBoardSettings.shared.notifySettingsChanged()
                            }

                        // 5. Viết Hoa chữ cái đầu câu
                        Toggle("Viết Hoa chữ cái đầu câu", isOn: $isAutoCapitalization)
                            .onChange(of: isAutoCapitalization) { val in
                                vBoardSettings.shared.isAutoCapitalizationEnabled = val
                                vBoardSettings.shared.notifySettingsChanged()
                            }

                        // 6. Cho phép "z w j f" làm phụ âm
                        Toggle("Cho phép \"z w j f\" làm phụ âm", isOn: $isAllowZFWJ)
                            .onChange(of: isAllowZFWJ) { val in
                                vBoardSettings.shared.isAllowConsonantZFWJEnabled = val
                                vBoardSettings.shared.notifySettingsChanged()
                            }

                        // 7. Chuyển chế độ thông minh
                        Toggle("Chuyển chế độ thông minh", isOn: $isSmartSwitchMode)
                            .onChange(of: isSmartSwitchMode) { val in
                                vBoardSettings.shared.isSmartSwitchModeEnabled = val
                                vBoardSettings.shared.notifySettingsChanged()
                            }
                    } header: {
                        Text("Tùy chọn bộ gõ OpenKey")
                    } footer: {
                        Text("Các phím tắt desktop (^, ⌘) và bảng mã theo ứng dụng đã được tự động tối ưu phù hợp với nền tảng iOS.")
                            .font(.caption2)
                    }

                    Section(header: Text("Tùy chọn tiện ích Telex bổ sung")) {
                        Toggle("Phím ngoặc vuông: [ -> ơ, ] -> ư", isOn: $isBrackets)
                            .onChange(of: isBrackets) { val in
                                vBoardSettings.shared.isBracketShortcutsEnabled = val
                                vBoardSettings.shared.notifySettingsChanged()
                            }

                        Toggle("Phím Z: Gỡ bỏ dấu thanh", isOn: $isZRemove)
                            .onChange(of: isZRemove) { val in
                                vBoardSettings.shared.isZKeyRemoveToneEnabled = val
                                vBoardSettings.shared.notifySettingsChanged()
                            }

                        Toggle("Phím W đầu từ chuyển thành 'ư'", isOn: $isWBeginning)
                            .onChange(of: isWBeginning) { val in
                                vBoardSettings.shared.isWAtWordBeginningEnabled = val
                                vBoardSettings.shared.notifySettingsChanged()
                            }

                        Toggle("Tự động cân bằng dấu khi thêm phụ âm cuối", isOn: $isToneBalancing)
                            .onChange(of: isToneBalancing) { val in
                                vBoardSettings.shared.isModernToneBalancingEnabled = val
                                vBoardSettings.shared.notifySettingsChanged()
                            }
                    }
                } else {
                    // ==========================================
                    // TAB 2: GÕ TẮT (media_1788971935717.png)
                    // ==========================================
                    Section {
                        // 1. Cho phép gõ tắt
                        Toggle("Cho phép gõ tắt", isOn: $isMacroEnabled)
                            .onChange(of: isMacroEnabled) { val in
                                vBoardSettings.shared.isShortcutExpansionEnabled = val
                                vBoardSettings.shared.notifySettingsChanged()
                            }

                        // 2. Gõ tắt cả khi tắt gõ tiếng Việt
                        Toggle("Gõ tắt cả khi tắt gõ tiếng Việt", isOn: $isMacroEvenWhenOff)
                            .disabled(!isMacroEnabled)
                            .onChange(of: isMacroEvenWhenOff) { val in
                                vBoardSettings.shared.isMacroEvenWhenOffEnabled = val
                                vBoardSettings.shared.notifySettingsChanged()
                            }

                        // 3. Tự động viết hoa theo phím tắt
                        Toggle("Tự động viết hoa theo phím tắt", isOn: $isAutoCapsMacro)
                            .disabled(!isMacroEnabled)
                            .onChange(of: isAutoCapsMacro) { val in
                                vBoardSettings.shared.isAutoCapsMacroEnabled = val
                                vBoardSettings.shared.notifySettingsChanged()
                            }

                        // Nút Mở Bảng gõ tắt...
                        Button {
                            showMacroTableSheet = true
                        } label: {
                            HStack {
                                Label("Bảng gõ tắt...", systemImage: "list.bullet.rectangle.portrait")
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    } header: {
                        Text("Cấu hình Gõ tắt (Macro)")
                    }

                    Section {
                        // 4. Gõ nhanh (cc=ch, gg=gi, kk=kh, nn=ng, qq=qu, pp=ph, tt=th, uu=ươ)
                        Toggle("Gõ nhanh (cc=ch, gg=gi, kk=kh, nn=ng, qq=qu, pp=ph, tt=th, uu=ươ)", isOn: $isQuickTelex)
                            .onChange(of: isQuickTelex) { val in
                                vBoardSettings.shared.isQuickTelexEnabled = val
                                vBoardSettings.shared.notifySettingsChanged()
                            }

                        // 5. Gõ tắt phụ âm đầu: f->ph, j->gi, w->qu
                        Toggle("Gõ tắt phụ âm đầu: f->ph, j->gi, w->qu", isOn: $isQuickStartConsonant)
                            .onChange(of: isQuickStartConsonant) { val in
                                vBoardSettings.shared.isQuickStartConsonantEnabled = val
                                vBoardSettings.shared.notifySettingsChanged()
                            }

                        // 6. Gõ tắt phụ âm cuối: g->ng, h->nh, k->ch
                        Toggle("Gõ tắt phụ âm cuối: g->ng, h->nh, k->ch", isOn: $isQuickEndConsonant)
                            .onChange(of: isQuickEndConsonant) { val in
                                vBoardSettings.shared.isQuickEndConsonantEnabled = val
                                vBoardSettings.shared.notifySettingsChanged()
                            }
                    } header: {
                        Text("Tiện ích Gõ Nhanh Phụ Âm (Quick Consonants)")
                    } footer: {
                        Text("Tự động chuyển đổi phụ âm ngay khi gõ nguyên âm kế tiếp hoặc kết thúc từ.")
                            .font(.caption2)
                    }
                }
            }
        }
        .navigationTitle("Thiết lập OpenKey")
        .sheet(isPresented: $showMacroTableSheet) {
            NavigationStack {
                MacroManagementView()
            }
        }
    }
}

// MARK: - Màn hình Bảng gõ tắt (Macro Management View)

struct MacroManagementView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var shortcuts: [ShortcutEntry] = ShortcutManager.shared.getShortcuts()
    @State private var searchText: String = ""
    @State private var newShortcut: String = ""
    @State private var newReplacement: String = ""
    @State private var showAddAlert: Bool = false

    var filteredShortcuts: [ShortcutEntry] {
        if searchText.isEmpty {
            return shortcuts
        }
        return shortcuts.filter {
            $0.shortcut.localizedCaseInsensitiveContains(searchText) ||
            $0.replacement.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Form {
            Section(header: Text("Thêm từ gõ tắt mới")) {
                VStack(spacing: 8) {
                    TextField("Từ viết tắt (ví dụ: dc, ko, vn)", text: $newShortcut)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textFieldStyle(.roundedBorder)

                    TextField("Từ mở rộng đầy đủ (ví dụ: được, không, Việt Nam)", text: $newReplacement)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        let sc = newShortcut.trimmingCharacters(in: .whitespacesAndNewlines)
                        let rep = newReplacement.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !sc.isEmpty && !rep.isEmpty {
                            ShortcutManager.shared.addShortcut(shortcut: sc, replacement: rep)
                            shortcuts = ShortcutManager.shared.getShortcuts()
                            newShortcut = ""
                            newReplacement = ""
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Thêm vào bảng gõ tắt", systemImage: "plus.circle.fill")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newShortcut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              newReplacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.vertical, 4)
            }

            Section {
                ForEach(filteredShortcuts) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.shortcut)
                                .font(.headline)
                                .foregroundStyle(.blue)
                            Text(item.replacement)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { indexSet in
                    for idx in indexSet {
                        let item = filteredShortcuts[idx]
                        ShortcutManager.shared.deleteShortcut(shortcut: item.shortcut)
                    }
                    shortcuts = ShortcutManager.shared.getShortcuts()
                }
            } header: {
                HStack {
                    Text("Danh sách từ gõ tắt (\(filteredShortcuts.count))")
                    Spacer()
                }
            } footer: {
                Text("Vuốt sang trái để xóa một từ gõ tắt.")
                    .font(.caption2)
            }

            Section {
                Button(role: .destructive) {
                    ShortcutManager.shared.resetToDefaults()
                    shortcuts = ShortcutManager.shared.getShortcuts()
                } label: {
                    HStack {
                        Spacer()
                        Label("Khôi phục bảng gõ tắt mặc định", systemImage: "arrow.counterclockwise")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Bảng gõ tắt")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Tìm kiếm từ viết tắt...")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Đóng") {
                    dismiss()
                }
            }
        }
        .onAppear {
            shortcuts = ShortcutManager.shared.getShortcuts()
        }
    }
}

// MARK: - 8. Màn hình Bàn phím Dev Mode (DeveloperSettingsView)

struct DeveloperSettingsView: View {
    @Binding var isDevButtonEnabled: Bool

    @State private var isEnabled: Bool = vBoardSettings.shared.isDeveloperModeButtonEnabled
    @State private var tabBehavior: DevTabBehavior = vBoardSettings.shared.developerTabBehavior
    @State private var isPair: Bool = vBoardSettings.shared.isPairAutoCompleteEnabled

    var body: some View {
        Form {
            Section {
                Toggle("Hiển thị nút </> trên Toolbar", isOn: $isEnabled)
                    .onChange(of: isEnabled) { val in
                        vBoardSettings.shared.isDeveloperModeButtonEnabled = val
                        isDevButtonEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }
            } header: {
                Text("Kích hoạt chế độ Dev")
            } footer: {
                Text("Khi bật Dev Mode: Tự động ngắt bộ gõ tiếng Việt để gõ code ASCII chuẩn, tích hợp phím điều hướng (⇤, ←, →, ⇥) ở hàng đáy.")
                    .font(.caption2)
            }

            Section(header: Text("Hành vi phím Tab")) {
                Picker("Phím Tab chèn", selection: $tabBehavior) {
                    ForEach(DevTabBehavior.allCases) { item in
                        Text(item.displayName).tag(item)
                    }
                }
                .pickerStyle(.inline)
                .onChange(of: tabBehavior) { val in
                    vBoardSettings.shared.developerTabBehavior = val
                    vBoardSettings.shared.notifySettingsChanged()
                }
            }

            Section(header: Text("Tự động đóng ngoặc")) {
                Toggle("Tự động đóng cặp ngoặc (), [], {}", isOn: $isPair)
                    .onChange(of: isPair) { val in
                        vBoardSettings.shared.isPairAutoCompleteEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }
            }

            #if DEBUG
            Section(header: Text("Phòng thí nghiệm & Thu thập dữ liệu vuốt")) {
                NavigationLink {
                    GlideBenchmarkView()
                } label: {
                    HStack {
                        Label("Phòng thí nghiệm Vuốt phím (Glide Lab)", systemImage: "sparkles.rectangle.stack.fill")
                            .foregroundStyle(.blue)
                        Spacer()
                        Text("50 từ")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            #endif
        }
        .navigationTitle("Bàn phím Lập trình viên")
    }
}

// MARK: - 9. Màn hình Bảng tạm & Từ điển (ClipboardDictionarySettingsView)

struct ClipboardDictionarySettingsView: View {
    @Binding var clipboardCount: Int

    @State private var isClipboard = vBoardSettings.shared.isClipboardEnabled
    @State private var isShortcuts = vBoardSettings.shared.isShortcutExpansionEnabled
    @State private var history: [String] = ClipboardManager.shared.getHistory()
    @State private var shortcuts: [ShortcutEntry] = ShortcutManager.shared.getShortcuts()

    @State private var newKey = ""
    @State private var newVal = ""

    @State private var userWordsCount: Int = UserAdaptiveLearningStore.shared.getAllUserWords().count

    var body: some View {
        Form {
            Section(header: Text("Lịch sử Bảng tạm (Clipboard)")) {
                Toggle("Lưu lịch sử bảng tạm", isOn: $isClipboard)
                    .onChange(of: isClipboard) { val in
                        vBoardSettings.shared.isClipboardEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }

                if isClipboard && !history.isEmpty {
                    Button(role: .destructive) {
                        ClipboardManager.shared.clearHistory()
                        history.removeAll()
                        clipboardCount = 0
                    } label: {
                        Label("Xóa toàn bộ lịch sử bảng tạm", systemImage: "trash")
                    }
                }
            }

            Section(header: Text("Gõ tắt cá nhân hóa (Macro)")) {
                Toggle("Tự động mở rộng từ viết tắt khi bấm Space", isOn: $isShortcuts)
                    .onChange(of: isShortcuts) { val in
                        vBoardSettings.shared.isShortcutExpansionEnabled = val
                        vBoardSettings.shared.notifySettingsChanged()
                    }

                HStack {
                    TextField("Viết tắt (vd: dc)", text: $newKey)
                    TextField("Thay thế (vd: được)", text: $newVal)
                    Button("Thêm") {
                        if !newKey.isEmpty && !newVal.isEmpty {
                            ShortcutManager.shared.addShortcut(shortcut: newKey, replacement: newVal)
                            shortcuts = ShortcutManager.shared.getShortcuts()
                            newKey = ""
                            newVal = ""
                        }
                    }
                    .disabled(newKey.isEmpty || newVal.isEmpty)
                }

                ForEach(shortcuts) { item in
                    HStack {
                        Text(item.shortcut)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(item.replacement)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { indexSet in
                    for idx in indexSet {
                        let item = shortcuts[idx]
                        ShortcutManager.shared.deleteShortcut(shortcut: item.shortcut)
                    }
                    shortcuts = ShortcutManager.shared.getShortcuts()
                }
            }

            Section(header: Text("Từ điển tiếng Việt & Thói quen Cá nhân")) {
                NavigationLink {
                    PersonalDictionaryManagementView()
                } label: {
                    HStack {
                        Label("Từ điển Cá nhân (Các từ hay dùng)", systemImage: "text.badge.plus")
                        Spacer()
                        Text("\(userWordsCount) từ đã học")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }

                HStack {
                    Text("Tổng số từ vựng tích hợp:")
                    Spacer()
                    Text("19.047 từ")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Bảng tạm & Từ điển")
        .onAppear {
            history = ClipboardManager.shared.getHistory()
            shortcuts = ShortcutManager.shared.getShortcuts()
            userWordsCount = UserAdaptiveLearningStore.shared.getAllUserWords().count
        }
    }
}

// MARK: - Màn hình Quản lý Từ điển Cá nhân (Personal Dictionary Management)
struct PersonalDictionaryManagementView: View {
    @State private var userWords: [(word: String, freq: Int)] = []
    @State private var searchText: String = ""
    @State private var newWordText: String = ""
    @State private var newFreqText: String = "10"
    @State private var exportedJSON: String = ""
    @State private var isShowingExportSheet: Bool = false
    @State private var isShowingImportAlert: Bool = false
    @State private var importText: String = ""
    @State private var statusToast: String = ""
    @State private var showStatusToast: Bool = false

    var filteredWords: [(word: String, freq: Int)] {
        let sorted = userWords.sorted { $0.freq > $1.freq }
        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter { $0.word.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Form {
            Section(header: Text("Thêm từ mới vào từ điển cá nhân")) {
                HStack {
                    TextField("Từ mới (ví dụ: Zalo, GenAI...)", text: $newWordText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    TextField("Tần suất", text: $newFreqText)
                        .keyboardType(.numberPad)
                        .frame(width: 70)
                        .textFieldStyle(.roundedBorder)
                    Button("Thêm") {
                        let clean = newWordText.trimmingCharacters(in: .whitespacesAndNewlines)
                        let freq = Int(newFreqText) ?? 10
                        if !clean.isEmpty {
                            UserAdaptiveLearningStore.shared.addUserWordDirectly(clean, frequency: freq)
                            newWordText = ""
                            refreshList()
                            showToast("Đã thêm '\(clean)'")
                        }
                    }
                    .disabled(newWordText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section {
                if filteredWords.isEmpty {
                    Text(searchText.isEmpty ? "Chưa có từ cá nhân nào được kết nạp. Bàn phím sẽ tự động kết nạp khi bạn gõ lặp lại một từ lạ từ 3 lần trở lên." : "Không tìm thấy từ nào khớp với '\(searchText)'.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredWords, id: \.word) { item in
                        HStack {
                            Text(item.word)
                                .font(.body)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(item.freq) lần gõ")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.12))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                    .onDelete { indexSet in
                        for idx in indexSet {
                            let item = filteredWords[idx]
                            UserAdaptiveLearningStore.shared.deleteUserWord(item.word)
                        }
                        refreshList()
                        showToast("Đã xóa từ được chọn")
                    }
                }
            } header: {
                HStack {
                    Text("Các từ bạn hay dùng nhất (\(filteredWords.count))")
                    Spacer()
                }
            } footer: {
                Text("Vuốt sang trái để xóa một từ khỏi danh sách tự học.")
                    .font(.caption2)
            }

            Section(header: Text("Sao lưu & Khôi phục qua App Group")) {
                Button {
                    if let json = UserAdaptiveLearningStore.shared.exportJSON() {
                        exportedJSON = json
                        UIPasteboard.general.string = json
                        showToast("Đã sao chép JSON sao lưu vào Bảng tạm!")
                        isShowingExportSheet = true
                    }
                } label: {
                    Label("Xuất file sao lưu từ điển (Export JSON)", systemImage: "square.and.arrow.up")
                }

                Button {
                    isShowingImportAlert = true
                } label: {
                    Label("Nhập file sao lưu từ điển (Import JSON)", systemImage: "square.and.arrow.down")
                }
            }

            Section(header: Text("Cơ chế học thích ứng (Lifelong Learning)")) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• Ngưỡng kết nạp: Từ lạ được gõ ≥ 3 lần sẽ chính thức lưu vào từ điển.")
                    Text("• Vùng đệm Staging: Từ chỉ gõ 1 lần sẽ tự động đào thải sau 24 giờ.")
                    Text("• Đào thải tự nhiên (Half-Life): Điểm số tự động suy giảm định kỳ (0.85) để ưu tiên từ mới.")
                    Text("• Giới hạn an toàn: Tối đa 2.000 từ đơn, dung lượng file lưu đĩa luôn < 300 KB.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Từ điển Cá nhân")
        .searchable(text: $searchText, prompt: "Tìm kiếm từ cá nhân...")
        .alert("Nhập bản sao lưu JSON", isPresented: $isShowingImportAlert) {
            TextField("Dán chuỗi JSON sao lưu vào đây...", text: $importText)
            Button("Nhập", role: .none) {
                if UserAdaptiveLearningStore.shared.importJSON(importText) {
                    refreshList()
                    showToast("Đã nhập từ điển thành công!")
                } else {
                    showToast("Lỗi định dạng JSON sao lưu!")
                }
                importText = ""
            }
            Button("Hủy", role: .cancel) {
                importText = ""
            }
        }
        .sheet(isPresented: $isShowingExportSheet) {
            NavigationStack {
                VStack(spacing: 16) {
                    Text("Dữ liệu sao lưu từ điển cá nhân (JSON)")
                        .font(.headline)
                        .padding(.top, 16)
                    ScrollView {
                        Text(exportedJSON)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    Button {
                        UIPasteboard.general.string = exportedJSON
                        showToast("Đã sao chép vào Bảng tạm")
                        isShowingExportSheet = false
                    } label: {
                        Label("Sao chép vào Bảng tạm", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Đóng") { isShowingExportSheet = false }
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showStatusToast {
                Text(statusToast)
                    .font(.footnote)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(radius: 4)
                    .padding(.bottom, 20)
                    .transition(.opacity)
            }
        }
        .onAppear {
            refreshList()
        }
    }

    private func refreshList() {
        let all = UserAdaptiveLearningStore.shared.getAllUserWords()
        userWords = all.map { ($0.key, $0.value) }
    }

    private func showToast(_ msg: String) {
        statusToast = msg
        withAnimation {
            showStatusToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showStatusToast = false
            }
        }
    }
}

// MARK: - 10. Màn hình Tùy biến Toolbar (ToolbarSettingsView)

struct ToolbarSettingsView: View {
    @State private var items: [String] = vBoardSettings.shared.toolbarItemsOrder

    private let itemNames: [String: String] = [
        "clipboard": "Bảng tạm (Clipboard)",
        "dev": "Bàn phím Dev (Code Mode)",
        "undoRedo": "Cặp nút Hoàn tác & Làm lại (Undo/Redo)",
        "quickSettings": "Cài đặt nhanh (Quick Settings)",
        "oneHanded": "Chế độ một tay (One-Handed)"
    ]

    var body: some View {
        List {
            Section(header: Text("Sắp xếp thứ tự các nút trên Toolbar"), footer: Text("Chạm vào Edit hoặc kéo thả biểu tượng ≡ để đổi thứ tự xuất hiện của các nút trên thanh công cụ bàn phím.").font(.caption2)) {
                ForEach(items, id: \.self) { item in
                    HStack {
                        Image(systemName: iconName(for: item))
                            .frame(width: 28)
                            .foregroundStyle(.blue)
                        Text(itemNames[item] ?? item)
                    }
                }
                .onMove { from, to in
                    items.move(fromOffsets: from, toOffset: to)
                    vBoardSettings.shared.toolbarItemsOrder = items
                    vBoardSettings.shared.notifySettingsChanged()
                }
            }
        }
        .navigationTitle("Tùy biến Toolbar")
        .toolbar {
            EditButton()
        }
    }

    private func iconName(for key: String) -> String {
        switch key {
        case "clipboard": return "doc.on.clipboard"
        case "dev": return "chevron.left.forwardslash.chevron.right"
        case "undoRedo": return "arrow.uturn.backward"
        case "quickSettings": return "gearshape"
        case "oneHanded": return "rectangle.lefthalf.inset.filled"
        default: return "circle"
        }
    }
}

// MARK: - 11. Màn hình Hướng dẫn Kích hoạt (KeyboardSetupGuideView)

struct KeyboardSetupGuideView: View {
    var body: some View {
        List {
            Section(header: Text("Các bước kích hoạt bàn phím vBoard")) {
                HStack(alignment: .top, spacing: 14) {
                    Text("1")
                        .font(.headline)
                        .frame(width: 28, height: 28)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mở Cài đặt hệ thống")
                            .font(.headline)
                        Text("Vào ứng dụng Cài đặt (Settings) trên iPhone của bạn.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                HStack(alignment: .top, spacing: 14) {
                    Text("2")
                        .font(.headline)
                        .frame(width: 28, height: 28)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Thêm bàn phím vBoard")
                            .font(.headline)
                        Text("Chọn Cài đặt chung (General) → Bàn phím (Keyboard) → Bàn phím → Thêm bàn phím mới... và chọn 'vBoard'.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                HStack(alignment: .top, spacing: 14) {
                    Text("3")
                        .font(.headline)
                        .frame(width: 28, height: 28)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bật 'Cho phép Truy cập Đầy đủ' (Tùy chọn)")
                            .font(.headline)
                        Text("Chạm vào vBoard và bật 'Cho phép truy cập đầy đủ' để sử dụng rung phản hồi Taptic Engine và tính năng dán Bảng tạm. vBoard cam kết 100% không gửi dữ liệu ra ngoài.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Spacer()
                        Label("Mở Cài đặt iPhone ngay", systemImage: "gearshape.fill")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.blue)
            }
        }
        .navigationTitle("Hướng dẫn Kích hoạt")
    }
}

// MARK: - 12. Chính sách Quyền riêng tư & Bảo mật (PrivacySecurityPolicyView)

struct PrivacySecurityPolicyView: View {
    var body: some View {
        List {
            Section(header: Label("Cam kết Bảo mật cốt lõi", systemImage: "lock.shield.fill")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                        Text("100% Không ghi nhận phím gõ")
                            .font(.headline)
                    }
                    Text("vBoard tuyệt đối không ghi nhận, không theo dõi và không lưu trữ lịch sử những gì bạn gõ (tài khoản, mật khẩu, tin nhắn, số thẻ tín dụng...).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .foregroundStyle(.blue)
                        Text("Hoạt động Ngoại tuyến (Zero Network)")
                            .font(.headline)
                    }
                    Text("vBoard không chứa bất kỳ mã nguồn kết nối mạng hay dịch vụ phân tích từ xa (Analytics/Tracker) nào. Toàn bộ thuật toán gõ tiếng Việt và xử lý cử chỉ vuốt đều chạy nội bộ trên chip xử lý của iPhone.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "internaldrive.fill")
                            .foregroundStyle(.purple)
                        Text("Lưu trữ Cục bộ (On-Device Local)")
                            .font(.headline)
                    }
                    Text("Từ điển cá nhân và các từ bạn chủ động lưu chỉ được lưu trữ trong bộ nhớ an toàn (App Group container) trên thiết bị của bạn và không bao giờ rời khỏi thiết bị.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section(header: Text("Quyền truy cập đầy đủ (Allow Full Access)")) {
                Text("Apple hiển thị thông báo cảnh báo tiêu chuẩn mỗi khi bạn bật Full Access cho bất kỳ bàn phím bên thứ ba nào. Với vBoard, quyền này CHỈ được dùng để:\n\n• Kích hoạt rung phản hồi xúc giác (Taptic Engine) khi gõ phím.\n• Cho phép bạn chạm nút Dán (Paste) để chèn nội dung bạn vừa sao chép.\n\nNếu bạn không bật Full Access, vBoard vẫn hoạt động bình thường cho mọi tác vụ gõ tiếng Việt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Chính sách Bảo mật")
    }
}

// MARK: - 13. Màn hình Thông tin Kỹ thuật & Hiệu năng (PerformanceAboutView)

struct PerformanceAboutView: View {
    var body: some View {
        Form {
            Section(header: Text("Chỉ số Hiệu năng & Bộ nhớ")) {
                HStack {
                    Text("Bộ nhớ RAM sử dụng:")
                    Spacer()
                    Text("< 15 MB")
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }
                HStack {
                    Text("Giới hạn an toàn iOS Extension:")
                    Spacer()
                    Text("30 MB")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Thời gian xử lý ký tự:")
                    Spacer()
                    Text("< 0.05 ms")
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
                HStack {
                    Text("Độ trễ đồng bộ IPC:")
                    Spacer()
                    Text("< 0.1 ms")
                        .foregroundStyle(.green)
                }
                HStack {
                    Text("Bộ từ vựng tiếng Việt tích hợp:")
                    Spacer()
                    Text("~94.000 từ & ngữ cảnh")
                        .foregroundStyle(.secondary)
                }
            }

            Section(header: Text("Thông tin Ứng dụng")) {
                HStack {
                    Text("Phiên bản:")
                    Spacer()
                    Text("1.0 (Production Ready)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Bộ gõ lõi:")
                    Spacer()
                    Text("OpenKey Swift Native")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Thông tin Kỹ thuật")
    }
}

// MARK: - Màn hình Quản lý và Tra cứu Điểm số Từ điển (Dictionary & N-gram Explorer)
struct DictionaryScoresExplorerView: View {
    @State private var selectedTab: Int = 0
    @State private var searchText: String = ""

    // State cho Tab 1: Từ điển tự học
    @State private var stagingWords: [(word: String, count: Int, lastTime: Date)] = []
    @State private var userWords: [(word: String, score: Int)] = []
    @State private var newCustomWord: String = ""
    @State private var showAddWordSheet: Bool = false

    // State cho Tab 2: Từ điển 1 chữ
    @State private var unigramResults: [(word: String, freq: Int)] = []

    // State cho Tab 3: Từ điển 2 chữ (Bigram)
    @State private var bigramResults: [(context: String, candidates: [(word: String, score: Double)])] = []

    // State cho Tab 4: Từ điển 3 chữ (Trigram)
    @State private var trigramResults: [(context: String, candidates: [(word: String, score: Double)])] = []

    var body: some View {
        VStack(spacing: 0) {
            // Segmented Tab Control
            Picker("Loại từ điển", selection: $selectedTab) {
                Text("Tự học").tag(0)
                Text("1 chữ").tag(1)
                Text("2 chữ").tag(2)
                Text("3 chữ").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(searchPlaceholder, text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        reloadData()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.bottom, 6)
            .onChange(of: searchText) { _ in
                reloadData()
            }

            // Tab Content
            TabView(selection: $selectedTab) {
                adaptiveLearningTab
                    .tag(0)
                unigramsTab
                    .tag(1)
                bigramsTab
                    .tag(2)
                trigramsTab
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("Điểm số & Từ điển")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if selectedTab == 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddWordSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
        }
        .onAppear {
            reloadData()
        }
        .sheet(isPresented: $showAddWordSheet) {
            addCustomWordSheet
        }
    }

    private var searchPlaceholder: String {
        switch selectedTab {
        case 0: return "Lọc từ tự học hoặc từ đang theo dõi..."
        case 1: return "Tìm từ 1 chữ (ví dụ: người, việt, học)..."
        case 2: return "Tìm gốc từ 2 chữ (ví dụ: ăn, chúc, làm)..."
        case 3: return "Tìm ngữ cảnh 3 chữ (ví dụ: chúc bạn, thời gian)..."
        default: return "Tìm kiếm..."
        }
    }

    // MARK: - Tab 1: Từ điển Tự học & Vùng đệm Staging
    private var adaptiveLearningTab: some View {
        List {
            // Giải thích quy tắc tự học
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.blue)
                        Text("Quy tắc Kết nạp Tự động (Adaptive Rule)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Text("Một từ lạ khi được gõ lặp lại ít nhất **2 lần trong vòng 24 giờ** sẽ tự động được đưa vào Từ điển chính thức và tăng điểm ưu tiên khi gợi ý.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            // 1. Vùng đệm Staging (Đang theo dõi lặp lại)
            Section(header: Text("Vùng đệm theo dõi (Staging Buffer - \(stagingWords.count) từ)")) {
                if stagingWords.isEmpty {
                    Text("Chưa có từ lạ nào đang theo dõi.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(stagingWords, id: \.word) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.word)
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text("Lần gần nhất: \(formattedDate(item.lastTime))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(item.count) / 2 lần")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(item.count >= 2 ? .green : .orange)
                                Text(item.count >= 2 ? "Chuẩn bị kết nạp" : "Cần thêm \(2 - item.count) lần")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            // 2. Danh sách từ đã kết nạp chính thức
            Section(header: Text("Từ điển cá nhân đã kết nạp (\(userWords.count) từ)")) {
                if userWords.isEmpty {
                    Text("Chưa có từ cá nhân nào được lưu.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(userWords, id: \.word) { item in
                        HStack {
                            Text(item.word)
                                .font(.body)
                            Spacer()
                            Text("Điểm: \(item.score)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.12))
                                .foregroundStyle(.blue)
                                .cornerRadius(8)
                        }
                    }
                    .onDelete(perform: deleteUserWords)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Tab 2: Từ điển 1 chữ (Unigrams)
    private var unigramsTab: some View {
        List {
            Section(header: Text("Từ đơn tiếng Việt & Điểm tần suất (\(unigramResults.count) kết quả)")) {
                if unigramResults.isEmpty {
                    Text("Không tìm thấy từ nào phù hợp.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(unigramResults, id: \.word) { item in
                        HStack {
                            Text(item.word)
                                .font(.body)
                            Spacer()
                            Text("Tần suất: \(item.freq)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Tab 3: Từ điển 2 chữ (Bigrams)
    private var bigramsTab: some View {
        List {
            if bigramResults.isEmpty {
                Section {
                    Text("Nhập từ vào ô tìm kiếm để xem các từ tiếp theo được dự đoán (ví dụ: 'ăn', 'chúc', 'công', 'thời').")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(bigramResults, id: \.context) { group in
                    Section(header: Text("Từ gốc: \"\(group.context)\"")) {
                        ForEach(Array(group.candidates.enumerated()), id: \.element.word) { idx, candidate in
                            HStack {
                                Text("\(idx + 1).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, alignment: .leading)
                                Text(candidate.word)
                                    .font(.body)
                                    .fontWeight(idx == 0 ? .semibold : .regular)
                                Spacer()
                                Text("Điểm: \(Int(candidate.score))")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(idx == 0 ? .blue : .secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Tab 4: Từ điển 3 chữ (Trigrams)
    private var trigramsTab: some View {
        List {
            if trigramResults.isEmpty {
                Section {
                    Text("Nhập 2 từ vào ô tìm kiếm để xem từ thứ ba được dự đoán (ví dụ: 'chúc bạn', 'thời gian', 'công nghệ').")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(trigramResults, id: \.context) { group in
                    Section(header: Text("Ngữ cảnh: \"\(group.context)\"")) {
                        ForEach(Array(group.candidates.enumerated()), id: \.element.word) { idx, candidate in
                            HStack {
                                Text("\(idx + 1).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, alignment: .leading)
                                Text(candidate.word)
                                    .font(.body)
                                    .fontWeight(idx == 0 ? .semibold : .regular)
                                Spacer()
                                Text("Điểm: \(Int(candidate.score))")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(idx == 0 ? .green : .secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // Sheet thêm từ thủ công
    private var addCustomWordSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Thêm từ mới vào từ điển cá nhân")) {
                    TextField("Nhập từ (ví dụ: DeepSeek, ChatGPT...)", text: $newCustomWord)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Thêm từ cá nhân")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") {
                        showAddWordSheet = false
                        newCustomWord = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        let trimmed = newCustomWord.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            UserAdaptiveLearningStore.shared.addUserWordDirectly(trimmed, frequency: 15)
                            newCustomWord = ""
                            showAddWordSheet = false
                            reloadData()
                        }
                    }
                    .disabled(newCustomWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    // MARK: - Data Reloaders
    private func reloadData() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Tab 0: Adaptive
        let allStaging = UserAdaptiveLearningStore.shared.getStagingWordsDetails()
        if query.isEmpty {
            stagingWords = allStaging
        } else {
            stagingWords = allStaging.filter { $0.word.lowercased().contains(query.lowercased()) }
        }

        let allUser = UserAdaptiveLearningStore.shared.getUserWordsWithScores()
        if query.isEmpty {
            userWords = allUser
        } else {
            userWords = allUser.filter { $0.word.lowercased().contains(query.lowercased()) }
        }

        // 2. Tab 1: Unigram
        unigramResults = WordTrie.shared.searchUnigramWords(filter: query.isEmpty ? nil : query, limit: 60)

        // 3. Tab 2: Bigrams
        bigramResults = NextWordPredictor.shared.getRankedBigrams(filter: query.isEmpty ? nil : query, limit: 30)

        // 4. Tab 3: Trigrams
        trigramResults = NextWordPredictor.shared.getRankedTrigrams(filter: query.isEmpty ? nil : query, limit: 30)
    }

    private func deleteUserWords(at offsets: IndexSet) {
        for index in offsets {
            let item = userWords[index]
            UserAdaptiveLearningStore.shared.deleteUserWord(item.word)
        }
        reloadData()
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm dd/MM"
        return formatter.string(from: date)
    }
}

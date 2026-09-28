import SwiftUI
import vBoardEngine
import vBoardKeyboard

// MARK: - Embedded Keyboard Representable for Live Swiping & Playback

struct EmbeddedKeyboardViewRepresentable: UIViewRepresentable {
    let keyboardView: KeyboardView
    let height: CGFloat
    let bottomPadding: CGFloat

    func makeUIView(context: Context) -> UIView {
        // Kích hoạt tính năng vuốt để nhập trong phiên thử nghiệm
        vBoardSettings.shared.isGlideTypingEnabled = true
        vBoardSettings.shared.isGlideTrailEnabled = true

        let container = UIView()
        container.backgroundColor = .clear

        keyboardView.customBottomPadding = bottomPadding
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(keyboardView)

        NSLayoutConstraint.activate([
            keyboardView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            keyboardView.topAnchor.constraint(equalTo: container.topAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        keyboardView.customBottomPadding = bottomPadding
        keyboardView.refreshLayout()
        keyboardView.setNeedsLayout()
        keyboardView.layoutIfNeeded()
    }
}

// MARK: - Main Glide Lab & Benchmark View

public struct GlideBenchmarkView: View {
    public enum BenchmarkWordSet: String, CaseIterable, Identifiable {
        case standard50 = "Bộ 50 từ chuẩn"
        case random100 = "Bộ 100 từ ngẫu nhiên"
        case top1000 = "Bộ 1000 từ phổ biến"

        public var id: String { rawValue }
        public var shortTitle: String {
            switch self {
            case .standard50: return "50 từ chuẩn"
            case .random100: return "100 từ ngẫu nhiên"
            case .top1000: return "1000 từ phổ biến"
            }
        }
    }

    @State private var activeSet: BenchmarkWordSet = .standard50
    @State private var words: [GlideChallengeWord] = GlideBenchmarkStore.default50Words
    @State private var currentIndex: Int = 0
    @State private var selectedCategory: String = "Tất cả"
    @State private var matchUnaccentedOnly: Bool = true
    @State private var autoAdvance: Bool = false

    // Cấu hình Bàn phím động đồng bộ 100% với bàn phím thật
    @State private var heightScale: KeyboardHeightScale = vBoardSettings.shared.keyboardHeightScale
    @State private var isNumberRow: Bool = vBoardSettings.shared.isNumberRowEnabled
    @State private var bottomOffset: Double = vBoardSettings.shared.keyboardBottomOffset

    // Quản lý phiên dữ liệu
    @State private var store = GlideBenchmarkStore.shared
    @State private var sessions: [String: GlideRecordedSession] = [:]

    // Keyboard View dùng chung cho cả tương tác trực tiếp & phát lại
    @State private var keyboardView = KeyboardView(frame: .zero)

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    /// Khoảng đệm an toàn mép dưới thực tế (tương ứng với Home Indicator trên iPhone thật)
    private var effectiveBottomPadding: CGFloat {
        let base: CGFloat = isPad ? 14.0 : 28.0
        return max(4.0, base + CGFloat(bottomOffset))
    }

    /// Chiều cao chuẩn của bàn phím tính theo đúng cấu hình bàn phím thật
    private var currentKeyboardHeight: CGFloat {
        vBoardSettings.shared.calculateKeyboardHeight(
            isPad: isPad,
            isNumberRow: isNumberRow,
            isSuggestionBar: vBoardSettings.shared.isSuggestionBarEnabled,
            customBottomPadding: isPad ? 14.0 : 28.0
        )
    }

    // Trạng thái Playback
    @State private var isPlaying: Bool = false
    @State private var playbackProgress: Double = 0.0
    @State private var playbackSpeed: Double = 1.0
    @State private var isScrubbing: Bool = false

    // Sheets & Alerts
    @State private var showExportSheet: Bool = false
    @State private var showWordListSheet: Bool = false
    @State private var showReevalSheet: Bool = false
    @State private var reevalResults: [GlideReevaluationResult] = []
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false

    private let categories = [
        "Tất cả",
        "Từ 2 ký tự",
        "Từ 3 ký tự",
        "Từ 4 ký tự",
        "Từ 5 ký tự",
        "Từ 6 ký tự",
        "Từ 7 ký tự"
    ]

    var filteredWords: [GlideChallengeWord] {
        if selectedCategory == "Tất cả" {
            return words
        }
        return words.filter { $0.category == selectedCategory }
    }

    var currentWord: GlideChallengeWord {
        let list = filteredWords
        guard !list.isEmpty else { return words[0] }
        let safe = min(max(0, currentIndex), list.count - 1)
        return list[safe]
    }

    var currentSession: GlideRecordedSession? {
        sessions[currentWord.targetWord.lowercased()]
    }

    var recordedCount: Int {
        words.filter { sessions[$0.targetWord.lowercased()] != nil }.count
    }

    var passCount: Int {
        words.filter { word in
            if let sess = sessions[word.targetWord.lowercased()] {
                return sess.isMatch
            }
            return false
        }.count
    }

    var accuracyPercentage: Double {
        guard recordedCount > 0 else { return 0.0 }
        return (Double(passCount) / Double(recordedCount)) * 100.0
    }

    /// Tổng điểm trọng số (Top 1 = 1.0đ, Top 2 = 0.75đ, Top 3 = 0.5đ, ngoài Top 3 = 0.0đ)
    var totalWeightedScore: Double {
        words.reduce(0.0) { sum, word in
            if let sess = sessions[word.targetWord.lowercased()] {
                return sum + sess.weightedScore(matchUnaccented: matchUnaccentedOnly)
            }
            return sum
        }
    }

    /// Tỷ lệ phần trăm điểm trọng số đạt được
    var weightedAccuracyPercentage: Double {
        guard recordedCount > 0 else { return 0.0 }
        return (totalWeightedScore / Double(recordedCount)) * 100.0
    }

    /// Số từ đạt Top 1 (1.0 điểm)
    var top1Count: Int {
        words.filter { word in
            if let sess = sessions[word.targetWord.lowercased()] {
                return sess.targetRank(matchUnaccented: matchUnaccentedOnly) == 1
            }
            return false
        }.count
    }

    /// Số từ đạt Top 2 (0.75 điểm)
    var top2Count: Int {
        words.filter { word in
            if let sess = sessions[word.targetWord.lowercased()] {
                return sess.targetRank(matchUnaccented: matchUnaccentedOnly) == 2
            }
            return false
        }.count
    }

    /// Số từ đạt Top 3 (0.5 điểm)
    var top3Count: Int {
        words.filter { word in
            if let sess = sessions[word.targetWord.lowercased()] {
                return sess.targetRank(matchUnaccented: matchUnaccentedOnly) == 3
            }
            return false
        }.count
    }

    /// Tổng số từ xuất hiện trong Top 3 (thanh gợi ý bàn phím)
    var top3HitCount: Int {
        top1Count + top2Count + top3Count
    }

    /// Tỷ lệ lọt Top 3 (hiển thị trên thanh gợi ý)
    var top3HitPercentage: Double {
        guard recordedCount > 0 else { return 0.0 }
        return (Double(top3HitCount) / Double(recordedCount)) * 100.0
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Phần cuộn phía trên: Chứa thông số, từ mục tiêu, điều hướng, kết quả kiểm tra
            ScrollView {
                VStack(spacing: 12) {
                    // Header: Thống kê & Tiến độ
                    headerStatsSection

                    // Bộ lọc danh mục
                    categoryFilterSection

                    // Thẻ từ mục tiêu cần vuốt
                    targetWordCard

                    // Điều hướng từ trước / từ sau (đặt ngay dưới thẻ từ để dễ bấm)
                    navigationButtons

                    // Kết quả nhận diện & Thông số động học
                    resultAndTelemetryCard

                    // Bộ điều khiển phát lại vệt vuốt (Playback Controller)
                    if let sess = currentSession, !sess.samples.isEmpty {
                        playbackControlsCard(session: sess)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 12)
            }

            Divider()

            // Phần dưới: CỐ ĐỊNH Ở ĐÁY MÀN HÌNH, TOÀN BỘ CHIỀU NGANG
            VStack(spacing: 0) {
                // Thanh điều khiển bàn phím nhanh & đồng bộ kích thước thật
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "keyboard.fill")
                            .foregroundStyle(.blue)
                        Text("Bàn phím thật (\(heightScale.displayName))")
                            .font(.caption2)
                            .bold()
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Menu chỉnh nhanh Size & Nâng mép dưới bàn phím ngay tại phòng thí nghiệm
                    Menu {
                        Section("Kích thước chiều cao (Config)") {
                            ForEach(KeyboardHeightScale.allCases) { item in
                                Button(action: {
                                    heightScale = item
                                    vBoardSettings.shared.keyboardHeightScale = item
                                    vBoardSettings.shared.notifySettingsChanged()
                                    syncSettingsWithKeyboard()
                                }) {
                                    HStack {
                                        Text(item.displayName)
                                        if heightScale == item {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }

                        Section("Độ nâng mép dưới (Bottom Offset)") {
                            Button("Tiêu chuẩn theo máy (0 pt)") {
                                bottomOffset = 0
                                vBoardSettings.shared.keyboardBottomOffset = 0
                                vBoardSettings.shared.notifySettingsChanged()
                                syncSettingsWithKeyboard()
                            }
                            Button("Nâng nhẹ (+8 pt)") {
                                bottomOffset = 8
                                vBoardSettings.shared.keyboardBottomOffset = 8
                                vBoardSettings.shared.notifySettingsChanged()
                                syncSettingsWithKeyboard()
                            }
                            Button("Nâng vừa (+16 pt)") {
                                bottomOffset = 16
                                vBoardSettings.shared.keyboardBottomOffset = 16
                                vBoardSettings.shared.notifySettingsChanged()
                                syncSettingsWithKeyboard()
                            }
                            Button("Nâng cao (+24 pt)") {
                                bottomOffset = 24
                                vBoardSettings.shared.keyboardBottomOffset = 24
                                vBoardSettings.shared.notifySettingsChanged()
                                syncSettingsWithKeyboard()
                            }
                        }

                        Section("Hàng phím số trên cùng") {
                            Button(action: {
                                isNumberRow.toggle()
                                vBoardSettings.shared.isNumberRowEnabled = isNumberRow
                                vBoardSettings.shared.notifySettingsChanged()
                                syncSettingsWithKeyboard()
                            }) {
                                HStack {
                                    Text("Hàng số trên cùng")
                                    if isNumberRow {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Chỉnh size / vị trí")
                        }
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12))
                        .foregroundStyle(.blue)
                        .cornerRadius(6)
                    }

                    // Nút bật/tắt tự chuyển từ
                    Button(action: { autoAdvance.toggle() }) {
                        HStack(spacing: 3) {
                            Image(systemName: autoAdvance ? "checkmark.circle.fill" : "circle")
                            Text("Tự chuyển từ")
                        }
                        .font(.caption2)
                        .foregroundStyle(autoAdvance ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)

                    if currentSession != nil {
                        Button("Xóa vệt") {
                            keyboardView.resetPlaybackView()
                        }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color(.secondarySystemBackground))

                // Bàn phím nhúng full width tràn 2 bên, tự động nâng lên đúng độ cao config
                EmbeddedKeyboardViewRepresentable(
                    keyboardView: keyboardView,
                    height: currentKeyboardHeight,
                    bottomPadding: effectiveBottomPadding
                )
                .frame(maxWidth: .infinity)
                .frame(height: currentKeyboardHeight)
            }
            .background(Color(.systemBackground))
        }
        .navigationTitle("Phòng thí nghiệm vuốt (\(words.count) từ)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Section("Bộ từ kiểm thử") {
                        Button(action: { switchWordSet(to: .standard50) }) {
                            HStack {
                                Text("Bộ 50 từ chuẩn thuần Việt")
                                if activeSet == .standard50 { Image(systemName: "checkmark") }
                            }
                        }
                        Button(action: { switchWordSet(to: .random100) }) {
                            HStack {
                                Text("Bộ 100 từ ngẫu nhiên từ điển")
                                if activeSet == .random100 { Image(systemName: "checkmark") }
                            }
                        }
                        Button(action: { switchWordSet(to: .top1000) }) {
                            HStack {
                                Text("Bộ 1000 từ phổ biến nhất từ điển")
                                if activeSet == .top1000 { Image(systemName: "checkmark") }
                            }
                        }
                        if activeSet == .random100 {
                            Button(action: regenerateRandom100) {
                                Label("Tạo lại 100 từ ngẫu nhiên mới", systemImage: "dice")
                            }
                        }
                    }

                    Section("Tiện ích") {
                        Button(action: { showWordListSheet = true }) {
                            Label("Danh sách \(words.count) từ", systemImage: "list.bullet")
                        }
                        Button(action: runReevaluation) {
                            Label("Chạy lại kiểm thử dữ liệu đã lưu", systemImage: "arrow.triangle.2.circlepath")
                        }
                        Button(action: { showExportSheet = true }) {
                            Label("Xuất / Gửi dữ liệu cho AI", systemImage: "square.and.arrow.up")
                        }
                    }

                    Divider()
                    Button(role: .destructive, action: confirmClearCurrentWord) {
                        Label("Xóa kết quả từ hiện tại", systemImage: "trash")
                    }
                    Button(role: .destructive, action: confirmClearAll) {
                        Label("Xóa toàn bộ dữ liệu", systemImage: "trash.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            syncSettingsWithKeyboard()
            setupKeyboardCallback()
            loadSavedSessions()
        }
        .sheet(isPresented: $showExportSheet) {
            GlideDataExportSheetView(
                words: words,
                sessions: sessions,
                accuracyPercentage: accuracyPercentage,
                totalWeightedScore: totalWeightedScore,
                weightedAccuracyPercentage: weightedAccuracyPercentage,
                top1Count: top1Count,
                top2Count: top2Count,
                top3Count: top3Count,
                top3HitCount: top3HitCount,
                top3HitPercentage: top3HitPercentage,
                matchUnaccented: matchUnaccentedOnly
            )
        }
        .sheet(isPresented: $showWordListSheet) {
            GlideWordListSheetView(
                words: words,
                sessions: sessions,
                currentIndex: $currentIndex,
                selectedCategory: $selectedCategory
            )
        }
        .sheet(isPresented: $showReevalSheet) {
            GlideReevaluationSheetView(results: reevalResults)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Thông báo"), message: Text(alertMessage), dismissButton: .default(Text("Đóng")))
        }
    }

    // MARK: - UI Components

    private var headerStatsSection: some View {
        VStack(spacing: 8) {
            // Thanh chuyển đổi nhanh bộ từ kiểm thử: 50 từ chuẩn vs 100 từ ngẫu nhiên vs 1000 từ phổ biến
            HStack(spacing: 8) {
                Picker("Bộ từ", selection: $activeSet) {
                    ForEach(BenchmarkWordSet.allCases) { item in
                        Text(item.shortTitle).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: activeSet) { newSet in
                    switchWordSet(to: newSet)
                }

                if activeSet == .random100 {
                    Button(action: regenerateRandom100) {
                        Label("Sinh mới", systemImage: "dice.fill")
                            .font(.caption)
                            .bold()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .cornerRadius(8)
                    }
                }
            }

            // Hàng 1: Tiến độ và Điểm trọng số
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tiến độ thu thập")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(recordedCount) / \(words.count) từ")
                        .font(.headline)
                        .bold()
                    ProgressView(value: Double(recordedCount), total: Double(words.count))
                        .tint(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Điểm trọng số (1.0 | 0.75 | 0.5)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text(String(format: "%.2f", totalWeightedScore))
                            .font(.headline)
                            .bold()
                            .foregroundStyle(.blue)
                        Text(String(format: "(%.1f%%)", weightedAccuracyPercentage))
                            .font(.caption)
                            .bold()
                            .foregroundStyle(weightedAccuracyPercentage >= 80 ? .green : (weightedAccuracyPercentage >= 50 ? .orange : .red))
                    }
                    Text("Top 3 (Thanh gợi ý): \(top3HitCount)/\(recordedCount) (\(String(format: "%.1f%%", top3HitPercentage)))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            }

            // Hàng 2: Chi tiết phân bổ Top 1, Top 2, Top 3, Ngoài Top 3
            if recordedCount > 0 {
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text("Top 1: \(top1Count)")
                            .font(.caption2)
                            .bold()
                    }
                    Spacer()
                    HStack(spacing: 3) {
                        Circle().fill(Color.blue).frame(width: 6, height: 6)
                        Text("Top 2: \(top2Count)")
                            .font(.caption2)
                            .bold()
                    }
                    Spacer()
                    HStack(spacing: 3) {
                        Circle().fill(Color.orange).frame(width: 6, height: 6)
                        Text("Top 3: \(top3Count)")
                            .font(.caption2)
                            .bold()
                    }
                    Spacer()
                    HStack(spacing: 3) {
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                        Text("Ngoài Top 3: \(recordedCount - top3HitCount)")
                            .font(.caption2)
                            .bold()
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
        }
    }

    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { cat in
                    Button(action: {
                        selectedCategory = cat
                        currentIndex = 0
                        keyboardView.resetPlaybackView()
                    }) {
                        Text(cat)
                            .font(.caption)
                            .bold(selectedCategory == cat)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedCategory == cat ? Color.accentColor : Color(.secondarySystemBackground))
                            .foregroundStyle(selectedCategory == cat ? .white : .primary)
                            .cornerRadius(14)
                    }
                }
            }
        }
    }

    private var targetWordCard: some View {
        VStack(spacing: 8) {
            HStack {
                Text(currentWord.category)
                    .font(.caption2)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.12))
                    .foregroundStyle(.blue)
                    .cornerRadius(6)

                Spacer()

                // Badge trạng thái đã thu thập kèm thứ hạng và điểm
                if let sess = currentSession {
                    let rank = sess.targetRank(matchUnaccented: matchUnaccentedOnly)
                    let score = sess.weightedScore(matchUnaccented: matchUnaccentedOnly)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(rank == 1 ? Color.green : (rank == 2 ? Color.blue : (rank == 3 ? Color.orange : Color.red)))
                            .frame(width: 8, height: 8)
                        Text(sess.rankLabel(matchUnaccented: matchUnaccentedOnly))
                            .font(.caption2)
                            .bold()
                            .foregroundStyle(rank == 1 ? .green : (rank == 2 ? .blue : (rank == 3 ? .orange : .red)))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((rank == 1 ? Color.green : (rank == 2 ? Color.blue : (rank == 3 ? Color.orange : Color.red))).opacity(0.12))
                    .cornerRadius(6)
                } else {
                    Text("Chưa thu thập")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(6)
                }

                Text("#\(currentIndex + 1)/\(filteredWords.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(currentWord.targetWord)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Lộ trình gợi ý: \(currentWord.hintPath)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !currentWord.note.isEmpty {
                Text(currentWord.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private var resultAndTelemetryCard: some View {
        Group {
            if let sess = currentSession {
                let rank = sess.targetRank(matchUnaccented: matchUnaccentedOnly)
                let score = sess.weightedScore(matchUnaccented: matchUnaccentedOnly)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: rank > 0 ? (rank == 1 ? "crown.fill" : "checkmark.circle.fill") : "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(rank == 1 ? .green : (rank == 2 ? .blue : (rank == 3 ? .orange : .red)))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(rank > 0 ? "Lọt Top gợi ý: \(sess.rankLabel(matchUnaccented: matchUnaccentedOnly))" : "Ngoài Top 3 gợi ý (0 điểm)")
                                .font(.subheadline)
                                .bold()
                                .foregroundStyle(rank == 1 ? .green : (rank == 2 ? .blue : (rank == 3 ? .orange : .red)))
                            Text("Kết quả ra: '\(sess.recognizedWord.isEmpty ? "(Không khớp từ nào)" : sess.recognizedWord)'")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Đề xuất top 3
                        if !sess.topCandidates.isEmpty {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("Top đề xuất:")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(sess.topCandidates.joined(separator: ", "))
                                    .font(.caption2)
                                    .bold()
                            }
                        }
                    }

                    Divider()

                    // Thông số động học
                    HStack(spacing: 12) {
                        Label(String(format: "%.0f ms", sess.durationMs), systemImage: "clock")
                        Label(String(format: "%.0f px/s", sess.avgVelocityPxPerSec), systemImage: "speedometer")
                        Label("\(sess.samples.count) điểm", systemImage: "point.filled.topleft.point.curvedto.point.bottomright.up")
                        Label(String(format: "%.0f px", sess.totalDistancePx), systemImage: "ruler")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    if !sess.primarySeq.isEmpty {
                        Text("Phím trích xuất: \(sess.primarySeq.map { String($0) }.joined(separator: " -> "))")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(12)
                .background((sess.isMatch ? Color.green : Color.red).opacity(0.08))
                .cornerRadius(12)
            }
        }
    }

    private func playbackControlsCard(session: GlideRecordedSession) -> some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "film.fill")
                        .foregroundStyle(.blue)
                    Text("Phát lại vệt vuốt")
                        .font(.caption)
                        .bold()
                }

                Spacer()

                // Chọn tốc độ phát
                Picker("Tốc độ", selection: $playbackSpeed) {
                    Text("0.5x").tag(0.5)
                    Text("1.0x").tag(1.0)
                    Text("2.0x").tag(2.0)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            // Thanh trượt thời gian (Scrubber)
            HStack(spacing: 8) {
                Button(action: togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }

                Slider(value: Binding(
                    get: { playbackProgress },
                    set: { newVal in
                        playbackProgress = newVal
                        isScrubbing = true
                        keyboardView.scrubPlayback(samples: session.samples, progress: newVal)
                    }
                ), in: 0.0...1.0)
                .tint(.blue)

                Text(String(format: "%.0f%%", playbackProgress * 100))
                    .font(.caption2)
                    .monospacedDigit()
                    .frame(width: 35)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            Button(action: prevWord) {
                Label("Từ trước", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(currentIndex == 0)

            Button(action: nextWord) {
                Label("Từ kế tiếp", systemImage: "chevron.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(currentIndex >= filteredWords.count - 1)
        }
    }

    // MARK: - Logic & Actions

    private func syncSettingsWithKeyboard() {
        heightScale = vBoardSettings.shared.keyboardHeightScale
        isNumberRow = vBoardSettings.shared.isNumberRowEnabled
        bottomOffset = vBoardSettings.shared.keyboardBottomOffset

        keyboardView.isNumberRowActive = isNumberRow
        keyboardView.customBottomPadding = effectiveBottomPadding
        keyboardView.refreshLayout()
        keyboardView.setNeedsLayout()
        keyboardView.layoutIfNeeded()
    }

    private func setupKeyboardCallback() {
        keyboardView.onGlideSessionFinished = { samples, primarySeq, fullSeq, matches, stats in
            handleCompletedSwipe(
                samples: samples,
                primarySeq: primarySeq,
                fullSeq: fullSeq,
                matches: matches,
                stats: stats
            )
        }
    }

    private func handleCompletedSwipe(
        samples: [GlideSample],
        primarySeq: [Character],
        fullSeq: [Character],
        matches: [String],
        stats: GlideSessionStats?
    ) {
        let cleanTarget = currentWord.targetWord.lowercased()
        let topWord = matches.first?.lowercased() ?? ""

        let isMatch: Bool
        if matchUnaccentedOnly {
            let recAscii = WordTrie.stripDiacritics(topWord)
            let targetAscii = WordTrie.stripDiacritics(cleanTarget)
            isMatch = (!topWord.isEmpty && recAscii == targetAscii)
        } else {
            isMatch = (topWord == cleanTarget)
        }

        let session = GlideRecordedSession(
            targetWord: currentWord.targetWord,
            category: currentWord.category,
            samples: samples,
            primarySeqChars: primarySeq,
            fullSeqChars: fullSeq,
            recognizedWord: topWord,
            topCandidates: matches,
            durationMs: stats?.durationMs ?? 0,
            totalDistancePx: stats?.totalDistancePx ?? 0,
            avgVelocityPxPerSec: stats?.avgVelocityPxPerSec ?? 0,
            peakVelocityPxPerSec: stats?.peakVelocityPxPerSec ?? 0,
            isMatch: isMatch,
            keyboardWidth: Double(keyboardView.bounds.width),
            keyboardHeight: Double(keyboardView.bounds.height)
        )

        store.saveSession(session)
        sessions[currentWord.targetWord.lowercased()] = session

        // Haptic phản hồi & Tự chuyển từ (chỉ khi người dùng bật "Tự chuyển từ")
        if isMatch && autoAdvance {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if self.currentIndex < self.filteredWords.count - 1 {
                    self.nextWord()
                }
            }
        }
    }

    private func togglePlayPause() {
        guard let sess = currentSession, !sess.samples.isEmpty else { return }

        if isPlaying {
            keyboardView.stopPlayback()
            isPlaying = false
        } else {
            isPlaying = true
            keyboardView.startPlayback(
                samples: sess.samples,
                speedMultiplier: playbackSpeed,
                onProgress: { p in
                    self.playbackProgress = p
                },
                onComplete: {
                    self.isPlaying = false
                    self.playbackProgress = 1.0
                }
            )
        }
    }

    private func nextWord() {
        if currentIndex < filteredWords.count - 1 {
            currentIndex += 1
            resetPlaybackState()
        }
    }

    private func prevWord() {
        if currentIndex > 0 {
            currentIndex -= 1
            resetPlaybackState()
        }
    }

    private func resetPlaybackState() {
        keyboardView.resetPlaybackView()
        isPlaying = false
        playbackProgress = 0.0
    }

    private func switchWordSet(to set: BenchmarkWordSet) {
        activeSet = set
        currentIndex = 0
        selectedCategory = "Tất cả"
        switch set {
        case .standard50:
            words = GlideBenchmarkStore.default50Words
        case .random100:
            words = GlideBenchmarkStore.generateRandom100Words()
        case .top1000:
            words = GlideBenchmarkStore.getTop1000Words()
        }
        resetPlaybackState()
    }

    private func regenerateRandom100() {
        activeSet = .random100
        currentIndex = 0
        selectedCategory = "Tất cả"
        words = GlideBenchmarkStore.generateRandom100Words()
        resetPlaybackState()
    }

    private func loadSavedSessions() {
        sessions = store.getAllSessions()
    }

    private func runReevaluation() {
        let results = store.reevaluateAll(matchUnaccented: matchUnaccentedOnly)
        reevalResults = results
        showReevalSheet = true
        // Tải lại các phiên sau khi tái đánh giá
        loadSavedSessions()
    }

    private func confirmClearCurrentWord() {
        store.deleteSession(for: currentWord.targetWord)
        sessions.removeValue(forKey: currentWord.targetWord.lowercased())
        keyboardView.resetPlaybackView()
    }

    private func confirmClearAll() {
        store.clearAll()
        sessions.removeAll()
        keyboardView.resetPlaybackView()
    }
}

// MARK: - Word List Sheet View

struct GlideWordListSheetView: View {
    let words: [GlideChallengeWord]
    let sessions: [String: GlideRecordedSession]
    @Binding var currentIndex: Int
    @Binding var selectedCategory: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(0..<words.count, id: \.self) { idx in
                    let w = words[idx]
                    let sess = sessions[w.targetWord.lowercased()]
                    Button(action: {
                        selectedCategory = "Tất cả"
                        currentIndex = idx
                        dismiss()
                    }) {
                        HStack {
                            let rank = sess?.targetRank(matchUnaccented: true) ?? 0
                            Circle()
                                .fill(sess == nil ? Color.gray.opacity(0.4) : (rank == 1 ? Color.green : (rank == 2 ? Color.blue : (rank == 3 ? Color.orange : Color.red))))
                                .frame(width: 10, height: 10)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(idx + 1). \(w.targetWord)")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("\(w.hintPath) (\(w.category))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let s = sess {
                                Text(s.rankLabel(matchUnaccented: true))
                                    .font(.caption)
                                    .bold()
                                    .foregroundStyle(rank == 1 ? .green : (rank == 2 ? .blue : (rank == 3 ? .orange : .red)))
                            } else {
                                Text("Chưa thu thập")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Danh sách \(words.count) từ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Reevaluation Comparison Sheet View

struct GlideReevaluationSheetView: View {
    let results: [GlideReevaluationResult]
    @Environment(\.dismiss) var dismiss

    var improvedCount: Int {
        results.filter { !$0.oldMatch && $0.newMatch }.count
    }

    var regressedCount: Int {
        results.filter { $0.oldMatch && !$0.newMatch }.count
    }

    var totalPassed: Int {
        results.filter { $0.newMatch }.count
    }

    var totalWeightedScore: Double {
        results.reduce(0.0) { $0 + $1.newWeightedScore }
    }

    var top1Count: Int {
        results.filter { $0.newRank == 1 }.count
    }

    var top2Count: Int {
        results.filter { $0.newRank == 2 }.count
    }

    var top3Count: Int {
        results.filter { $0.newRank == 3 }.count
    }

    var top3HitCount: Int {
        results.filter { $0.newRank > 0 }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Thống kê Thang điểm Trọng số") {
                    HStack {
                        Text("Tổng điểm trọng số:")
                        Spacer()
                        let pct = results.isEmpty ? 0.0 : (totalWeightedScore / Double(results.count)) * 100.0
                        Text("\(String(format: "%.2f", totalWeightedScore)) / \(results.count)đ (\(String(format: "%.1f%%", pct)))")
                            .bold()
                            .foregroundStyle(.blue)
                    }
                    HStack {
                        Text("Lọt Top 3 gợi ý:")
                        Spacer()
                        let hitPct = results.isEmpty ? 0.0 : (Double(top3HitCount) / Double(results.count)) * 100.0
                        Text("\(top3HitCount) / \(results.count) (\(String(format: "%.1f%%", hitPct)))")
                            .bold()
                            .foregroundStyle(.green)
                    }
                    HStack {
                        Text("Phân bố thứ hạng:")
                        Spacer()
                        Text("Top 1: \(top1Count) | Top 2: \(top2Count) | Top 3: \(top3Count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Tổng quan tái đánh giá") {
                    HStack {
                        Text("Số từ đã kiểm tra:")
                        Spacer()
                        Text("\(results.count)")
                            .bold()
                    }
                    HStack {
                        Text("Tổng từ ĐẠT mới:")
                        Spacer()
                        Text("\(totalPassed) / \(results.count)")
                            .bold()
                            .foregroundStyle(.green)
                    }
                    HStack {
                        Text("Cải thiện (FAIL ➔ PASS):")
                        Spacer()
                        Text("+\(improvedCount)")
                            .bold()
                            .foregroundStyle(.green)
                    }
                    if regressedCount > 0 {
                        HStack {
                            Text("Thụt lùi (PASS ➔ FAIL):")
                            Spacer()
                            Text("-\(regressedCount)")
                                .bold()
                                .foregroundStyle(.red)
                        }
                    }
                }

                Section("Chi tiết từng từ") {
                    ForEach(results) { r in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(r.targetWord)
                                    .font(.headline)
                                Spacer()
                                Text(r.newRankLabel)
                                    .font(.caption)
                                    .bold()
                                    .foregroundStyle(r.newRank == 1 ? .green : (r.newRank == 2 ? .blue : (r.newRank == 3 ? .orange : .red)))
                            }
                            HStack {
                                Text("Cũ: '\(r.oldRecognizedWord)' ➔ Mới: '\(r.newRecognizedWord)'")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(r.statusChange)
                                    .font(.caption2)
                                    .foregroundStyle(r.newMatch ? .green : .secondary)
                            }
                            if !r.newTopCandidates.isEmpty {
                                Text("Đề xuất: \(r.newTopCandidates.joined(separator: ", "))")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Kết quả Tái đánh giá Engine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Export Sheet View

struct GlideDataExportSheetView: View {
    let words: [GlideChallengeWord]
    let sessions: [String: GlideRecordedSession]
    let accuracyPercentage: Double
    let totalWeightedScore: Double
    let weightedAccuracyPercentage: Double
    let top1Count: Int
    let top2Count: Int
    let top3Count: Int
    let top3HitCount: Int
    let top3HitPercentage: Double
    let matchUnaccented: Bool
    @Environment(\.dismiss) var dismiss

    var jsonExportString: String {
        GlideBenchmarkStore.shared.exportJSON() ?? "{}"
    }

    var reportSummaryString: String {
        var str = "=== BÁO CÁO THU THẬP DỮ LIỆU VUỐT PHÍM (\(words.count) TỪ) ===\n"
        str += "Thời gian: \(Date())\n"
        str += "Tiêu chí chấm: \(matchUnaccented ? "Bỏ dấu thanh" : "Chính xác cả dấu")\n"
        str += "Tổng số từ đã thu thập: \(sessions.count) / \(words.count)\n"
        str += "--- THANG ĐIỂM TRỌNG SỐ GỢI Ý ---\n"
        str += "  • Điểm tổng: \(String(format: "%.2f", totalWeightedScore)) / \(sessions.count) điểm (\(String(format: "%.1f%%", weightedAccuracyPercentage)))\n"
        str += "  • Lọt Top 3 gợi ý: \(top3HitCount) / \(sessions.count) (\(String(format: "%.1f%%", top3HitPercentage)))\n"
        str += "  • Top 1 (1.0 điểm): \(top1Count) từ\n"
        str += "  • Top 2 (0.75 điểm): \(top2Count) từ\n"
        str += "  • Top 3 (0.5 điểm): \(top3Count) từ\n"
        let outOfTop3 = sessions.count - top3HitCount
        str += "  • Ngoài Top 3 (0 điểm): \(outOfTop3) từ\n\n"
        str += "--- CHI TIẾT TỪNG TỪ ĐÃ GHI NHẬN ---\n"
        for w in words {
            if let s = sessions[w.targetWord.lowercased()] {
                let rank = s.targetRank(matchUnaccented: matchUnaccented)
                let score = s.weightedScore(matchUnaccented: matchUnaccented)
                let rankText = rank > 0 ? "[TOP \(rank) - \(score)đ]" : "[NGOÀI TOP 3 - 0đ]"
                str += "\(rankText) '\(w.targetWord)' ➔ '\(s.recognizedWord)' (\(w.category))\n"
                str += "       ↳ \(String(format: "%.0fms | TB: %.0fpx/s | Điểm: %d", s.durationMs, s.avgVelocityPxPerSec, s.samples.count))\n"
                str += "       ↳ Đề xuất: \(s.topCandidates.joined(separator: ", "))\n"
            } else {
                str += "[CHƯA THU THẬP] '\(w.targetWord)' (\(w.category))\n"
            }
        }
        return str
    }

    @State private var exportMode: Int = 1 // Mặc định mở Dữ liệu thô JSON để tiện gửi AI
    @State private var showCopiedAlert: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                // Hướng dẫn cách gửi dữ liệu
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.blue)
                        .font(.headline)
                    Text("Dữ liệu này chứa vệt tọa độ thực tế từ ngón tay. Bạn chỉ cần nhấn **'Sao chép để gửi AI'** rồi dán vào khung chat với AI để phân tích và tối ưu độ chuẩn xác vuốt phím.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top, 4)

                Picker("Định dạng xuất", selection: $exportMode) {
                    Text("Dữ liệu thô JSON (cho AI)").tag(1)
                    Text("Báo cáo tóm tắt").tag(0)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                TextEditor(text: .constant(exportMode == 0 ? reportSummaryString : jsonExportString))
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .padding(.horizontal)

                // Thanh hành động dưới cùng
                VStack(spacing: 6) {
                    if showCopiedAlert {
                        Text("✅ Đã sao chép! Hãy dán vào khung chat với AI.")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }

                    HStack(spacing: 12) {
                        Button(action: {
                            UIPasteboard.general.string = (exportMode == 0 ? reportSummaryString : jsonExportString)
                            withAnimation { showCopiedAlert = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                withAnimation { showCopiedAlert = false }
                            }
                        }) {
                            Label("Sao chép để gửi AI", systemImage: "doc.on.doc.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        ShareLink(item: exportMode == 0 ? reportSummaryString : jsonExportString) {
                            Label("Chia sẻ file", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("Xuất / Gửi dữ liệu vuốt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}

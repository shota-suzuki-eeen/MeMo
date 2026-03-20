//
//  PetMaster.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import Foundation

// MARK: - Master Item

struct PetMasterItem: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let personality: String   // MVPは文字列でOK（genki/ottori/tsundere/majime）

    // 将来的に「好物/大好物」倍率を入れる可能性があるので枠だけ用意（現状ロジック未使用）
    // 既存の .init(id:name:personality:) を壊さないためデフォルト値を付与
    // Codable 警告回避のため let + 初期値 ではなく var にする
    var favoriteFoodKind: FoodKind? = nil
    var superFavoriteFoodKind: FoodKind? = nil
}

// MARK: - Care / Friendship (Spec v6)

enum FriendshipSpec {
    static let maxPoint: Int = 100

    static let cardThreshold: Int = 100

    static let foodNormal: Int = 10
    static let foodFavorite: Int = 20
    static let foodSuperFavorite: Int = 30

    static let bathGain: Int = 15
    static let bathCooldownHours: Int = 8
    static let bathAdReduceHoursPerWatch: Int = 4
    static let bathAdLimitPerDay: Int = 2

    static let toiletNormal: Int = 10
    static let toiletWithin1h: Int = 20
    static let toiletBonusWindowSeconds: TimeInterval = 60 * 60
}

enum FoodKind: String, Codable, CaseIterable {
    case normal
    case favorite
    case superFavorite

    var gainPoint: Int {
        switch self {
        case .normal: return FriendshipSpec.foodNormal
        case .favorite: return FriendshipSpec.foodFavorite
        case .superFavorite: return FriendshipSpec.foodSuperFavorite
        }
    }
}

enum FoodTimeSlot: String, Codable, CaseIterable {
    case morning
    case noon
    case night
}

// MARK: - Master List

enum PetMaster {

    static let all: [PetMasterItem] = [
        .init(id: "pet_000", name: "パーポー", personality: "genki"),
        .init(id: "pet_001", name: "ビート", personality: "ottori"),
        .init(id: "pet_002", name: "ビニキ", personality: "tsundere"),
        .init(id: "pet_003", name: "ヒメイ", personality: "majime"),
        .init(id: "pet_004", name: "カッケ", personality: "tsundere"),
        .init(id: "pet_005", name: "ケピョン", personality: "tsundere"),
        .init(id: "pet_006", name: "ニンジン", personality: "genki"),
        .init(id: "pet_007", name: "オバオル", personality: "ottori"),
        .init(id: "pet_008", name: "スン", personality: "ottori"),
        .init(id: "pet_009", name: "ワニゲータ", personality: "majime"),
        .init(id: "pet_010", name: "ワレワレ", personality: "genki"),
        .init(id: "pet_011", name: "今後記載予定", personality: "majime"),
    ]

    // ✅ ペットID → アセット名（修正版）
    static func assetName(for petID: String) -> String {
        switch petID {
        case "pet_000": return "purpor"
        case "pet_001": return "beat"
        case "pet_002": return "biniki"
        case "pet_003": return "himei"
        case "pet_004": return "kakke"
        case "pet_005": return "kepyon"
        case "pet_006": return "ninjin"
        case "pet_007": return "obaoru"
        case "pet_008": return "sun"
        case "pet_009": return "wanigeeta"
        case "pet_010": return "wareware"
        default:
            return "purpor" // 安全フォールバック
        }
    }

    // MARK: - ✅ Super Favorite (Master)

    /// ✅ 各キャラの「大好物」名称（マスタ）
    static func superFavoriteFoodName(for petID: String) -> String {
        switch petID {
        case "pet_000": return "おにぎり"
        case "pet_001": return "ラーメン"
        case "pet_002": return "ソフトクリーム"
        case "pet_003": return "ハンバーガー"
        case "pet_004": return "コーラ"
        case "pet_005": return "ヨーグルト"
        case "pet_006": return "サラダ"
        case "pet_007": return "コーヒー"
        case "pet_008": return "お鍋"
        case "pet_009": return "ステーキ"
        case "pet_010": return "ピザ"
        default:
            return "？？？"
        }
    }

    /// ✅ 説明文の本文（大好物行は別で付与する）
    private static func baseDescriptionText(for petID: String) -> String {
        switch petID {
        case "pet_000":
            return "一般パーポー。\nThe・スタンダードなカロペット。\n筋トレが嫌い。"
        case "pet_001":
            return "ブレイクダンスで愛情を表現するカロペット。\nハマっていることにはとことんのめり込むタイプ。"
        case "pet_002":
            return "色気がすんごいカロペット。\nSNSでも大変な人気があり、親衛隊がいる。"
        case "pet_003":
            return "なぜだか怖がられるカロペット。\nとても温厚な性格でほぼ⚪︎ンスター・ズ・⚪︎ンクだけど許して。"
        case "pet_004":
            return "自己肯定感高めなカロペット。\nカッケーものは全て自分のために存在していると信じている。\nこのぐらい強く生きたい。"
        case "pet_005":
            return "カエルのようなカロペット。\n夜中に田んぼで大声で歌うことが好き。\n普通に迷惑。\n俺は好き。"
        case "pet_006":
            return "うさぎのようなカロペット。\n作者はキャロットラペ大好き。\nいつもジャンプしている。\n多動症の恐れがあるので気をつけましょう。"
        case "pet_007":
            return "おしゃれ好きなカロペット。\nオーバーオールが似合う子はまじで憎めない優しい性格をしている。\n異論は認めない。"
        case "pet_008":
            return "いつも明るいカロペット。本当はサンなのにみんなからスンと読まれてしまうことが多く改名した。\n元気出して。"
        case "pet_009":
            return "ワニのようなカロペット。\n歯の手入れが大変すぎて歯磨きで1日が終わってしまうことが多々あるようで気の毒。"
        case "pet_010":
            return "宇宙から来たカロペット。\n触ると分裂する特徴があり、普通に困っている。"
        default:
            return "今後記載予定"
        }
    }

    // MARK: - Description API

    /// ✅ 既存互換：stateを渡さない場合は常に「？？？」表示（初期状態と同じ）
    static func description(for petID: String) -> String {
        let base = baseDescriptionText(for: petID)
        return base + "\n\n【大好物】？？？"
    }

    /// ✅ 追加：図鑑の表示用（判明済みなら大好物名を表示）
    static func description(for petID: String, state: AppState) -> String {
        let base = baseDescriptionText(for: petID)

        let revealed = state.isSuperFavoriteRevealed(petID: petID)
        let foodText = revealed ? superFavoriteFoodName(for: petID) : "？？？"

        return base + "\n\n【大好物】" + foodText
    }
}

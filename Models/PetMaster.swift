//
//  PetMaster.swift
//  MeMo
//
//  Updated for フードガチャ / もじゃガチャ character assets.
//

import Foundation

// MARK: - Master Item

struct PetMasterItem: Identifiable, Codable, Equatable {
    let id: String
    let name: String
}

// MARK: - Master List

enum PetMaster {

    static let happinessRewardPetIDs: [String] = [
        "reward_000",
        "reward_001",
        "reward_002",
        "reward_003",
        "reward_004",
        "reward_005",
        "reward_006",
        "reward_007"
    ]

    static let happinessRewardCasualPetIDs: [String] = [
        "reward_000_casual",
        "reward_001_casual",
        "reward_002_casual",
        "reward_003_casual",
        "reward_004_casual",
        "reward_005_casual",
        "reward_006_casual",
        "reward_007_casual"
    ]

    /// 幸せ報酬でのみ獲得できるキャラクターID。
    /// 通常報酬キャラに加えて、各報酬キャラの幸せLv.10で解放されるカジュアル版も含める。
    /// いつでもガチャの抽選候補・排出リストから除外する判定にも使う。
    static var happinessRewardExclusivePetIDs: [String] {
        happinessRewardPetIDs + happinessRewardCasualPetIDs
    }

    /// ベースの幸せ報酬キャラかどうか。
    static func isBaseHappinessRewardPetID(_ petID: String) -> Bool {
        happinessRewardPetIDs.contains(petID)
    }

    /// 幸せ報酬限定キャラかどうか。
    /// 注意: カジュアル版も「報酬限定」のため true を返す。
    /// これにより `PetMaster.all` に存在していても、いつでもガチャのラインナップには入らない。
    static func isHappinessRewardPetID(_ petID: String) -> Bool {
        happinessRewardExclusivePetIDs.contains(petID)
    }

    static func isHappinessRewardExclusivePetID(_ petID: String) -> Bool {
        happinessRewardExclusivePetIDs.contains(petID)
    }

    static func isHappinessRewardCasualPetID(_ petID: String) -> Bool {
        happinessRewardCasualPetIDs.contains(petID)
    }

    static func happinessMeterOwnerPetID(for petID: String) -> String? {
        switch petID {
        case "reward_000", "reward_000_casual": return "reward_000"
        case "reward_001", "reward_001_casual": return "reward_001"
        case "reward_002", "reward_002_casual": return "reward_002"
        case "reward_003", "reward_003_casual": return "reward_003"
        case "reward_004", "reward_004_casual": return "reward_004"
        case "reward_005", "reward_005_casual": return "reward_005"
        case "reward_006", "reward_006_casual": return "reward_006"
        case "reward_007", "reward_007_casual": return "reward_007"
        default: return nil
        }
    }

    static func sharesHappinessMeterWithRewardPet(_ petID: String) -> Bool {
        happinessMeterOwnerPetID(for: petID) != nil
    }

    static let all: [PetMasterItem] = [
        .init(id: "pet_000", name: "パーソン"),
        .init(id: "pet_001", name: "イヌ"),
        .init(id: "pet_002", name: "ネコ"),
        .init(id: "pet_003", name: "ニワトリ"),
        .init(id: "pet_004", name: "サル"),
        .init(id: "pet_005", name: "ウサギ"),
        .init(id: "pet_006", name: "カエル"),
        .init(id: "pet_007", name: "ペンギン"),
        .init(id: "pet_008", name: "ヒツジ"),
        .init(id: "pet_009", name: "サメ"),
        .init(id: "pet_010", name: "カメ"),
        .init(id: "pet_011", name: "イルカ"),
        .init(id: "pet_012", name: "ナマケモノ"),
        .init(id: "pet_013", name: "バク"),
        .init(id: "pet_014", name: "クロテナガザル"),
        .init(id: "pet_015", name: "ブルドッグ"),
        .init(id: "pet_016", name: "シカ"),
        .init(id: "pet_017", name: "キツネ"),
        .init(id: "pet_018", name: "エリマキトカゲ"),
        .init(id: "pet_019", name: "キリン"),
        .init(id: "pet_020", name: "コアラ"),
        .init(id: "pet_021", name: "オカピ"),
        .init(id: "pet_022", name: "カモノハシ"),
        .init(id: "pet_023", name: "アライグマ"),
        .init(id: "pet_024", name: "ハシビロコウ"),
        .init(id: "pet_025", name: "トリケラトプス"),
        .init(id: "pet_026", name: "ハチ"),
        .init(id: "pet_027", name: "アメリカンショートヘア"),
        .init(id: "pet_028", name: "バリニーズ"),
        .init(id: "pet_029", name: "ロシアンブルー"),
        .init(id: "pet_030", name: "シバケン"),
        .init(id: "pet_031", name: "ゴリラ"),
        .init(id: "pet_032", name: "トカゲ"),
        .init(id: "pet_033", name: "ミーアキャット"),
        .init(id: "pet_034", name: "カワウソ"),
        .init(id: "pet_035", name: "フクロウ"),
        .init(id: "pet_036", name: "インコ"),
        .init(id: "pet_037", name: "クジャク"),
        .init(id: "pet_038", name: "ブタ"),
        .init(id: "pet_039", name: "タヌキ"),
        .init(id: "pet_040", name: "レッサーパンダ"),
        .init(id: "pet_041", name: "アザラシ"),
        .init(id: "pet_043", name: "スカンク"),
        .init(id: "pet_044", name: "ツバメ"),
        .init(id: "pet_045", name: "トラ"),
        .init(id: "pet_046", name: "チーター"),
        .init(id: "pet_047", name: "シマウマ"),
        .init(id: "pet_048", name: "オオカミ"),
        .init(id: "reward_000", name: "ガール（A）"),
        .init(id: "reward_001", name: "ボーイ（A）"),
        .init(id: "reward_002", name: "ガール（B）"),
        .init(id: "reward_003", name: "ボーイ（B）"),
        .init(id: "reward_004", name: "ガール（C）"),
        .init(id: "reward_005", name: "ボーイ（C）"),
        .init(id: "reward_006", name: "ガール（D）"),
        .init(id: "reward_007", name: "ボーイ（D）"),
        .init(id: "reward_000_casual", name: "ガール / カジュアル（A）"),
        .init(id: "reward_001_casual", name: "ボーイ / カジュアル（A）"),
        .init(id: "reward_002_casual", name: "ガール / カジュアル（B）"),
        .init(id: "reward_003_casual", name: "ボーイ / カジュアル（B）"),
        .init(id: "reward_004_casual", name: "ガール / カジュアル（C）"),
        .init(id: "reward_005_casual", name: "ボーイ / カジュアル（C）"),
        .init(id: "reward_006_casual", name: "ガール / カジュアル（D）"),
        .init(id: "reward_007_casual", name: "ボーイ / カジュアル（D）"),
        .init(id: "food_taiyaki", name: "たい焼き"),
        .init(id: "food_soft_cream", name: "ソフトクリーム"),
        .init(id: "food_hotdog", name: "ホットドッグ"),
        .init(id: "food_macaron", name: "マカロン"),
        .init(id: "food_bao", name: "小籠包"),
        .init(id: "food_cherry", name: "チェリー"),
        .init(id: "food_coffee", name: "コーヒー"),
        .init(id: "food_donut", name: "ドーナツ"),
        .init(id: "food_egg", name: "目玉焼き"),
        .init(id: "food_gyoza", name: "餃子"),
        .init(id: "food_hamburger", name: "ハンバーガー"),
        .init(id: "food_juice", name: "オレンジジュース"),
        .init(id: "food_maguro", name: "マグ郎"),
        .init(id: "food_pancake", name: "パンケーキ"),
        .init(id: "food_pizza", name: "ピザ"),
        .init(id: "food_poteto", name: "ポテト"),
        .init(id: "food_satumaimo", name: "さつまいも"),
        .init(id: "food_shumai", name: "焼売"),
        .init(id: "food_tacos", name: "タコス"),
        .init(id: "food_takoyaki", name: "たこ焼き"),
        .init(id: "moja_purpor", name: "パーポー"),
        .init(id: "moja_beat", name: "ビート"),
        .init(id: "moja_biniki", name: "ビニキ"),
        .init(id: "moja_himei", name: "ヒメイ"),
        .init(id: "moja_kakke", name: "カッケ"),
        .init(id: "moja_kepyon", name: "ケピョン"),
        .init(id: "moja_ninjin", name: "ニンジン"),
        .init(id: "moja_obaoru", name: "オバオル"),
        .init(id: "moja_sun", name: "スン"),
        .init(id: "moja_wanigeeta", name: "ワニゲータ"),
        .init(id: "moja_wareware", name: "ワレワレ")
    ]

    static func assetName(for petID: String) -> String {
        switch petID {
        case "pet_000": return "person"
        case "pet_001": return "dog"
        case "pet_002": return "cat"
        case "pet_003": return "chicken"
        case "pet_004": return "monkey"
        case "pet_005": return "rabbit"
        case "pet_006": return "frog"
        case "pet_007": return "penguin"
        case "pet_008": return "sheep"
        case "pet_009": return "shark"
        case "pet_010": return "turtle"
        case "pet_011": return "dolphin"
        case "pet_012": return "Sloth"
        case "pet_013": return "baku"
        case "pet_014": return "blackGibbon"
        case "pet_015": return "bulldog"
        case "pet_016": return "deer"
        case "pet_017": return "fox"
        case "pet_018": return "frilledLizard"
        case "pet_019": return "giraffe"
        case "pet_020": return "koala"
        case "pet_021": return "okapi"
        case "pet_022": return "platypus"
        case "pet_023": return "raccoon"
        case "pet_024": return "Shoebill"
        case "pet_025": return "Triceratops"
        case "pet_026": return "bee"
        case "pet_027": return "amesho"
        case "pet_028": return "barinys"
        case "pet_029": return "blue"
        case "pet_030": return "shiba"
        case "pet_031": return "gorilla"
        case "pet_032": return "lizard"
        case "pet_033": return "meerkat"
        case "pet_034": return "otter"
        case "pet_035": return "owl"
        case "pet_036": return "parakeet"
        case "pet_037": return "peacock"
        case "pet_038": return "pig"
        case "pet_039": return "raccoonDog"
        case "pet_040": return "redPanda"
        case "pet_041": return "seal"
        case "pet_043": return "skunk"
        case "pet_044": return "swallow"
        case "pet_045": return "tiger"
        case "pet_046": return "cheetah"
        case "pet_047": return "zebra"
        case "pet_048": return "wolf"
        case "reward_000": return "girl_A"
        case "reward_001": return "boy_A"
        case "reward_002": return "girl_B"
        case "reward_003": return "boy_B"
        case "reward_004": return "girl_C"
        case "reward_005": return "boy_C"
        case "reward_006": return "girl_D"
        case "reward_007": return "boy_D"
        case "reward_000_casual": return "girl_A_casual"
        case "reward_001_casual": return "boy_A_casual"
        case "reward_002_casual": return "girl_B_casual"
        case "reward_003_casual": return "boy_B_casual"
        case "reward_004_casual": return "girl_C_casual"
        case "reward_005_casual": return "boy_C_casual"
        case "reward_006_casual": return "girl_D_casual"
        case "reward_007_casual": return "boy_D_casual"
        case "food_taiyaki": return "taiyaki"
        case "food_soft_cream": return "soft_cream"
        case "food_hotdog": return "hotdog"
        case "food_macaron": return "macaron"
        case "food_bao": return "bao"
        case "food_cherry": return "cherry"
        case "food_coffee": return "coffee"
        case "food_donut": return "donut"
        case "food_egg": return "egg"
        case "food_gyoza": return "gyoza"
        case "food_hamburger": return "hamburger"
        case "food_juice": return "juice"
        case "food_maguro": return "magurou"
        case "food_pancake": return "pancake"
        case "food_pizza": return "pizza"
        case "food_poteto": return "poteto"
        case "food_satumaimo": return "satumaimo"
        case "food_shumai": return "shumai"
        case "food_tacos": return "tacos"
        case "food_takoyaki": return "takoyaki"
        case "moja_purpor": return "purpor"
        case "moja_beat": return "beat"
        case "moja_biniki": return "biniki"
        case "moja_himei": return "himei"
        case "moja_kakke": return "kakke"
        case "moja_kepyon": return "kepyon"
        case "moja_ninjin": return "ninjin"
        case "moja_obaoru": return "obaoru"
        case "moja_sun": return "sun"
        case "moja_wanigeeta": return "wanigeeta"
        case "moja_wareware": return "wareware"
        default: return "person"
        }
    }

    static func wcAssetName(for petID: String) -> String {
        let base = assetName(for: petID)
        switch petID {
        case let id where id.hasPrefix("food_"):
            return "\(base)_wc"
        case let id where id.hasPrefix("reward_"):
            return "\(base)_wc"
        case let id where id.hasPrefix("moja_"):
            return "\(base)_wc"
        default:
            return base
        }
    }

    static func idleBlinkAssetNames(for petID: String) -> [String] {
        let base = assetName(for: petID)
        switch petID {
        case let id where id.hasPrefix("food_"):
            return ["\(base)_idle_blink_0001", "\(base)_idle_blink_0002"]
        case let id where id.hasPrefix("reward_"):
            return ["\(base)_idle_blink_0001", "\(base)_idle_blink_0002"]
        case let id where id.hasPrefix("moja_"):
            return ["\(base)_idle_blink_0001", "\(base)_idle_blink_0002"]
        default:
            return []
        }
    }

    private static func baseDescriptionText(for petID: String) -> String {
        switch petID {
        case "pet_000": return "人は道具を使い、協力して暮らすのが得意。"
        case "pet_001": return "イヌの嗅覚は人間よりとても鋭い。"
        case "pet_002": return "ネコはヒゲで狭い場所を通れるか測る。"
        case "pet_003": return "ニワトリは朝だけでなく一日中鳴くことがある。"
        case "pet_004": return "サルは道具を使うほど器用な種類もいる。"
        case "pet_005": return "ウサギの歯は一生伸び続ける。"
        case "pet_006": return "カエルは皮ふからも水分を吸収する。"
        case "pet_007": return "ペンギンは水中を飛ぶように泳ぐ。"
        case "pet_008": return "ヒツジは仲間の顔を覚えられる。"
        case "pet_009": return "サメは鋭い感覚で獲物を探す。"
        case "pet_010": return "カメの甲羅は背骨や肋骨とつながっている。"
        case "pet_011": return "イルカは音で周りを探るのが得意。"
        case "pet_012": return "ナマケモノは木の上でゆっくり暮らす。"
        case "pet_013": return "バクは短い鼻を器用に動かして食べる。"
        case "pet_014": return "テナガザルは長い腕で枝から枝へ移動する。"
        case "pet_015": return "ブルドッグはがっしりした体つきが特徴。"
        case "pet_016": return "シカの角は毎年生え替わる種類が多い。"
        case "pet_017": return "キツネは耳がよく小さな音も聞き分ける。"
        case "pet_018": return "エリマキトカゲは襟を広げて威嚇する。"
        case "pet_019": return "キリンの首の骨は人間と同じ7個。"
        case "pet_020": return "コアラはユーカリの葉を主食にする。"
        case "pet_021": return "オカピは森に暮らすキリンの仲間。"
        case "pet_022": return "カモノハシは卵を産む珍しい哺乳類。"
        case "pet_023": return "アライグマは前足を器用に使う。"
        case "pet_024": return "ハシビロコウはじっと待つ狩りが得意。"
        case "pet_025": return "トリケラトプスは3本の角を持つ草食恐竜。"
        case "pet_026": return "ハチは仲間に花の場所を知らせる。"
        case "pet_027": return "アメリカンショートヘアは丈夫で活発な猫。"
        case "pet_028": return "バリニーズは長い毛並みのシャム系の猫。"
        case "pet_029": return "ロシアンブルーは青みがかった銀色の毛が特徴。"
        case "pet_030": return "シバケンは日本原産の小型犬。"
        case "pet_031": return "ゴリラは群れで穏やかに暮らすことが多い。"
        case "pet_032": return "トカゲはしっぽを切って逃げる種類がいる。"
        case "pet_033": return "ミーアキャットは見張り役を立てる。"
        case "pet_034": return "カワウソは泳ぎが得意で遊び好き。"
        case "pet_035": return "フクロウは首を大きく回せる。"
        case "pet_036": return "インコは音まねが得意な種類もいる。"
        case "pet_037": return "クジャクのオスは美しい羽で求愛する。"
        case "pet_038": return "ブタは鼻で地面を探るのが得意。"
        case "pet_039": return "タヌキは日本の昔話にもよく登場する。"
        case "pet_040": return "レッサーパンダは長いしっぽでバランスをとる。"
        case "pet_041": return "アザラシは厚い脂肪で寒さから身を守る。"
        case "pet_043": return "スカンクは強いにおいで身を守る。"
        case "pet_044": return "ツバメは春に日本へ渡ってくる。"
        case "pet_045": return "トラのしま模様は個体ごとに違う。"
        case "pet_046": return "チーターは陸上で最速級の動物。"
        case "pet_047": return "シマウマのしま模様は仲間同士で見分けに役立つ。"
        case "pet_048": return "オオカミは群れで協力して行動する。"
        case "reward_000": return "幸せLv.5の報酬で仲間になる特別なキャラクター。"
        case "reward_001": return "幸せLv.10の報酬で仲間になる特別なキャラクター。"
        case "reward_002": return "幸せLv.15の報酬で仲間になる特別なキャラクター。"
        case "reward_003": return "幸せLv.20の報酬で仲間になる特別なキャラクター。"
        case "reward_004": return "幸せLv.25の報酬で仲間になる特別なキャラクター。"
        case "reward_005": return "幸せLv.30の報酬で仲間になる特別なキャラクター。"
        case "reward_006": return "幸せLv.35の報酬で仲間になる特別なキャラクター。"
        case "reward_007": return "幸せLv.40の報酬で仲間になる特別なキャラクター。"
        case "reward_000_casual": return "ガール（A）の幸せLv.10到達報酬でのみ獲得できる特別なカジュアル衣装。幸せ度メーターはガール（A）と共通。"
        case "reward_001_casual": return "ボーイ（A）の幸せLv.10到達報酬でのみ獲得できる特別なカジュアル衣装。幸せ度メーターはボーイ（A）と共通。"
        case "reward_002_casual": return "ガール（B）の幸せLv.10到達報酬でのみ獲得できる特別なカジュアル衣装。幸せ度メーターはガール（B）と共通。"
        case "reward_003_casual": return "ボーイ（B）の幸せLv.10到達報酬でのみ獲得できる特別なカジュアル衣装。幸せ度メーターはボーイ（B）と共通。"
        case "reward_004_casual": return "ガール（C）の幸せLv.10到達報酬でのみ獲得できる特別なカジュアル衣装。幸せ度メーターはガール（C）と共通。"
        case "reward_005_casual": return "ボーイ（C）の幸せLv.10到達報酬でのみ獲得できる特別なカジュアル衣装。幸せ度メーターはボーイ（C）と共通。"
        case "reward_006_casual": return "ガール（D）の幸せLv.10到達報酬でのみ獲得できる特別なカジュアル衣装。幸せ度メーターはガール（D）と共通。"
        case "reward_007_casual": return "ボーイ（D）の幸せLv.10到達報酬でのみ獲得できる特別なカジュアル衣装。幸せ度メーターはボーイ（D）と共通。"
        case "moja_purpor": return "紫のもじゃ界では王道のスタンダード。派手な色なのに、本人はいたって普通のつもり。"
        case "moja_beat": return "特技はブレイクダンス。回り始めると、もじゃまで遠心力で少し伸びる。"
        case "moja_biniki": return "ビキニ姿でセクシー担当を自称している。季節は問わないし、寒さにも強いらしい。"
        case "moja_himei": return "人を怖がらせるのが大好き。でも可愛すぎて、悲鳴より黄色い声援が返ってくる。"
        case "moja_kakke": return "特技はスケボー。技が決まっても失敗しても、本人だけはずっとまじでカッケー。"
        case "moja_kepyon": return "カエル姿の歌好きもじゃ。雨の日は絶好調だが、サビになるとだいたいケロケロになる。"
        case "moja_ninjin": return "うさぎ姿なのに、にんじんはあまり好きじゃない。名前のせいで毎日すすめられて少し困っている。"
        case "moja_obaoru": return "オーバーオールを一年分所有している。毎日着替えているのに、誰にも気づいてもらえない。"
        case "moja_sun": return "太陽の形をしたもじゃ。名前はスンなのに、今日も元気よくサンと呼び間違えられている。"
        case "moja_wanigeeta": return "歯磨きが大好きなワニのもじゃ。ただし歯の半分には歯ブラシが届かず、毎晩ちょっと悔しい。"
        case "moja_wareware": return "宇宙から来たもじゃ。話している内容は誰にもわからないが、本人は会話が弾んでいると思っている。"
        case let id where id.hasPrefix("food_"):
            let name = all.first(where: { $0.id == id })?.name ?? "フードキャラクター"
            return "フードガチャで仲間になる「\(name)」のキャラクター。"
        default:
            return "今後記載予定"
        }
    }

    static func description(for petID: String) -> String {
        baseDescriptionText(for: petID)
    }
}

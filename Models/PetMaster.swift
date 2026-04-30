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
}

// MARK: - Master List

enum PetMaster {

    static let happinessRewardPetIDs: [String] = [
        "reward_000",
        "reward_001",
        "reward_002",
        "reward_003"
    ]

    static func isHappinessRewardPetID(_ petID: String) -> Bool {
        happinessRewardPetIDs.contains(petID)
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
        .init(id: "reward_000", name: "ヘヤギ"),
        .init(id: "reward_001", name: "スクール"),
        .init(id: "reward_002", name: "シェフ"),
        .init(id: "reward_003", name: "プライベート"),
    ]

    // ✅ ペットID → アセット名（修正版）
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
        case "reward_000": return "person_room"
        case "reward_001": return "girl_school"
        case "reward_002": return "person_chef"
        case "reward_003": return "girl_private"
        default:
            return "purson" // 安全フォールバック
        }
    }

    /// ✅ 説明文の本文
    private static func baseDescriptionText(for petID: String) -> String {
        switch petID {
        case "pet_000":
            return "人は道具を使い、協力して暮らすのが得意。"
        case "pet_001":
            return "イヌの嗅覚は人間よりとても鋭い。"
        case "pet_002":
            return "ネコはヒゲで狭い場所を通れるか測る。"
        case "pet_003":
            return "ニワトリは朝だけでなく一日中鳴くことがある。"
        case "pet_004":
            return "サルは道具を使うほど器用な種類もいる。"
        case "pet_005":
            return "ウサギの歯は一生伸び続ける。"
        case "pet_006":
            return "カエルは皮ふからも水分を吸収する。"
        case "pet_007":
            return "ペンギンは水中を飛ぶように泳ぐ。"
        case "pet_008":
            return "ヒツジは仲間の顔を覚えられる。"
        case "pet_009":
            return "サメは鋭い感覚で獲物を探す。"
        case "pet_010":
            return "カメの甲羅は背骨や肋骨とつながっている。"
        case "pet_011":
            return "イルカは音で周りを探るのが得意。"
        case "pet_012":
            return "ナマケモノは木の上でゆっくり暮らす。"
        case "pet_013":
            return "バクは短い鼻を器用に動かして食べる。"
        case "pet_014":
            return "テナガザルは長い腕で枝から枝へ移動する。"
        case "pet_015":
            return "ブルドッグはがっしりした体つきが特徴。"
        case "pet_016":
            return "シカの角は毎年生え替わる種類が多い。"
        case "pet_017":
            return "キツネは耳がよく小さな音も聞き分ける。"
        case "pet_018":
            return "エリマキトカゲは襟を広げて威嚇する。"
        case "pet_019":
            return "キリンの首の骨は人間と同じ7個。"
        case "pet_020":
            return "コアラはユーカリの葉を主食にする。"
        case "pet_021":
            return "オカピは森に暮らすキリンの仲間。"
        case "pet_022":
            return "カモノハシは卵を産む珍しい哺乳類。"
        case "pet_023":
            return "アライグマは前足を器用に使う。"
        case "pet_024":
            return "ハシビロコウはじっと待つ狩りが得意。"
        case "pet_025":
            return "トリケラトプスは3本の角を持つ草食恐竜。"
        case "pet_026":
            return "ハチは仲間に花の場所を知らせる。"
        case "pet_027":
            return "アメリカンショートヘアは丈夫で活発な猫。"
        case "pet_028":
            return "バリニーズは長い毛並みのシャム系の猫。"
        case "pet_029":
            return "ロシアンブルーは青みがかった銀色の毛が特徴。"
        case "pet_030":
            return "シバケンは日本原産の小型犬。"
        case "pet_031":
            return "ゴリラは群れで穏やかに暮らすことが多い。"
        case "pet_032":
            return "トカゲはしっぽを切って逃げる種類がいる。"
        case "pet_033":
            return "ミーアキャットは見張り役を立てる。"
        case "pet_034":
            return "カワウソは泳ぎが得意で遊び好き。"
        case "pet_035":
            return "フクロウは首を大きく回せる。"
        case "pet_036":
            return "インコは音まねが得意な種類もいる。"
        case "pet_037":
            return "クジャクのオスは美しい羽で求愛する。"
        case "pet_038":
            return "ブタは鼻で地面を探るのが得意。"
        case "pet_039":
            return "タヌキは日本の昔話にもよく登場する。"
        case "pet_040":
            return "レッサーパンダは長いしっぽでバランスをとる。"
        case "pet_041":
            return "アザラシは厚い脂肪で寒さから身を守る。"
        case "pet_043":
            return "スカンクは強いにおいで身を守る。"
        case "pet_044":
            return "ツバメは春に日本へ渡ってくる。"
        case "pet_045":
            return "トラのしま模様は個体ごとに違う。"
        case "pet_046":
            return "チーターは陸上で最速級の動物。"
        case "pet_047":
            return "シマウマのしま模様は仲間同士で見分けに役立つ。"
        case "pet_048":
            return "オオカミは群れで協力して行動する。"
        case "reward_000":
            return "幸せLv.5の報酬で仲間になる特別なキャラクター。"
        case "reward_001":
            return "幸せLv.10の報酬で仲間になる特別なキャラクター。"
        case "reward_002":
            return "幸せLv.15の報酬で仲間になる特別なキャラクター。"
        case "reward_003":
            return "幸せLv.20の報酬で仲間になる特別なキャラクター。"
        default:
            return "今後記載予定"
        }
    }

    // MARK: - Description API

    static func description(for petID: String) -> String {
        baseDescriptionText(for: petID)
    }
}

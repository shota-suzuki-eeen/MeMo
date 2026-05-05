//
//  MemoOnboardingScreen.swift
//  MeMo
//
//  Mandatory onboarding flow definitions.
//  iOS 18.6+
//

import Foundation

enum MemoOnboardingTarget: String, Codable, Hashable {
    case foodButton
    case normalFood
    case rareFoodTab
    case rareFood
    case fullnessMeter
    case gachaButton
    case zukanButton
    case freeTenGachaButton
    case zukanSwitchButton
}

enum MemoOnboardingFoodInteractionPhase: String, Codable, Hashable {
    case choosing
    case pendingSwipe
}

enum MemoOnboardingScreen: String, CaseIterable, Identifiable, Codable, Hashable {
    // MARK: - Mandatory first-run tutorial
    case appPurpose
    case foodButton
    case foodGiveNormal
    case foodNormalResult
    case foodButtonForRare
    case foodRareTab
    case foodGiveRare
    case foodRareResult
    case foodFullnessReminder
    case gachaButton
    case gachaCharacterResult
    case zukanButton
    case tutorialFinished

    // MARK: - Lightweight first-visit explanations kept for existing hooks
    case home
    case step
    case gacha
    case zukan
    case memories
    case settings
    case foodTutorialIntro
    case foodTutorialNormalResult
    case foodTutorialRareResult
    case foodTutorialDone
    case toiletTutorialIntro
    case toiletTutorialScratch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appPurpose:
            return "ミーモへようこそ"
        case .foodButton:
            return "お腹が減っているみたい"
        case .foodGiveNormal:
            return "まずはNのごはん"
        case .foodNormalResult:
            return "満腹度が上がったよ"
        case .foodButtonForRare:
            return "次はRのごはん"
        case .foodRareTab:
            return "Rに切り替えよう"
        case .foodGiveRare:
            return "Rのごはんをあげよう"
        case .foodRareResult:
            return "幸せ度も上がったね"
        case .foodFullnessReminder:
            return "こまめにごはんをあげよう"
        case .gachaButton:
            return "ガチャを引いてみよう"
        case .gachaCharacterResult:
            return "キャラクターをゲット"
        case .zukanButton:
            return "図鑑へ行ってみよう"
        case .tutorialFinished:
            return "チュートリアル完了"
        case .home:
            return "ミーモへようこそ"
        case .step:
            return "歩くことが力になるよ"
        case .gacha:
            return "はじめてのガチャだね"
        case .zukan:
            return "図鑑を見てみよう"
        case .memories:
            return "思い出を残せるよ"
        case .settings:
            return "設定を整えよう"
        case .foodTutorialIntro:
            return "ごはんをあげてみよう"
        case .foodTutorialNormalResult:
            return "Nのごはん、上手にできたね"
        case .foodTutorialRareResult:
            return "Rのごはんは特別だよ"
        case .foodTutorialDone:
            return "ごはんの基本はばっちり"
        case .toiletTutorialIntro:
            return "おそうじの時間だよ"
        case .toiletTutorialScratch:
            return "こすってきれいにしよう"
        }
    }

    var message: String {
        switch self {
        case .appPurpose:
            return "ミーモは、歩くことをちょっと楽しくする健康管理アプリだよ。\n歩数をためてガチャを引き、ごはんやキャラクターを集めながら、お気に入りのミーモをお世話していこうね。"
        case .foodButton:
            return "あれ？お腹が減っているみたい！"
        case .foodGiveNormal:
            return "まずはN（ノーマル）のごはんをタップして仮決定しよう。"
        case .foodNormalResult:
            return "いいね！Nのごはんで満腹度が上がったよ。"
        case .foodButtonForRare:
            return "次はR（レア）のごはんだよ。もう一度ごはんボタンをタップしてみよう。"
        case .foodRareTab:
            return "Rのごはんに切り替えてみよう。"
        case .foodGiveRare:
            return "Rのごはんをタップしてあげる準備しよう。"
        case .foodRareResult:
            return "すごい！Rのごはんは満腹度に加えて、幸せ度も上がるよ。"
        case .foodFullnessReminder:
            return "満腹度が0のままだと、少しずつ幸せ度が下がってしまうよ。\nお腹が空いていたら、こまめにごはんをあげてね。"
        case .gachaButton:
            return "ごはんやミーモはガチャで手に入るよ。ガチャ画面に移動してみよう！"
        case .gachaCharacterResult:
            return "すごい！ミーモをゲットしたみたい！\n早速お世話してみよう！"
        case .zukanButton:
            return "図鑑でミーモを確認できるよ。ゲットしたミーモに切り替えてみよう！"
        case .tutorialFinished:
            return "チュートリアルはここまで！\n他にもたくさんの機能やミーモがいるからお楽しみに。\n毎日歩いて、楽しく健康管理をしよう！"
        case .home:
            return "このアプリでは、歩数がコインのような役割になるよ。歩いて、ガチャをして、ごはんやキャラクターを集めながら、楽しく健康管理していこうね。"
        case .step:
            return "今日の歩数を見られるよ。歩いたぶんだけ、ミーモで使える通貨が増えていくよ。"
        case .gacha:
            return "歩数を使って、ごはんやキャラクターが手に入るよ。"
        case .zukan:
            return "出会ったキャラクターをここで見返したり、お世話するミーモを切り替えられるよ！\nたくさん集めて図鑑を完成させよう！"
        case .memories:
            return "撮影した思い出を見返すことができるよ！\nお気に入りのミーモとたくさんお出かけしよう！"
        case .settings:
            return "通知や音などを調整できるよ。\n自分なりにカスタマイズしてみよう。"
        case .foodTutorialIntro:
            return "まずはごはんをあげてみよう。N（ノーマル）のごはんとR（レア）のごはんを1つずつ用意しておいたよ。"
        case .foodTutorialNormalResult:
            return "Nのごはんは、満腹度が増えるよ。おなかがすいている時に使ってあげようね。"
        case .foodTutorialRareResult:
            return "Rのごはんは、満腹度に加えて幸せ度も増えるよ。ガチャで手に入る特別なごはんだよ。"
        case .foodTutorialDone:
            return "ごはんはガチャで手に入るよ。歩いて、集めて、好きなキャラクターをお世話していこうね。"
        case .toiletTutorialIntro:
            return "トイレのマークが出たら、おそうじが必要だよ。きれいにしてあげると、また気持ちよく過ごせるね。"
        case .toiletTutorialScratch:
            return "汚れは指こすって、お掃除してあげよう。"
        }
    }

    var primaryButtonTitle: String {
        switch self {
        case .appPurpose:
            return "はじめる"
        case .foodNormalResult:
            return "次はRのごはん"
        case .foodRareResult:
            return "わかった"
        case .foodFullnessReminder:
            return "ガチャへ進む"
        case .gachaCharacterResult:
            return "お世話してみる"
        case .tutorialFinished:
            return "ミーモをはじめる"
        case .home, .step, .zukan, .memories, .settings:
            return "わかった"
        case .gacha:
            return "わかった"
        case .foodTutorialIntro:
            return "ごはんをあげる"
        case .foodTutorialNormalResult:
            return "次はRをあげる"
        case .foodTutorialRareResult:
            return "入手方法を見る"
        case .foodTutorialDone:
            return "ばっちり"
        case .toiletTutorialIntro:
            return "おそうじする"
        case .toiletTutorialScratch:
            return "やってみる"
        case .foodButton, .foodButtonForRare, .foodRareTab, .foodGiveNormal, .foodGiveRare, .gachaButton, .zukanButton:
            return "タップしてみよう！"
        }
    }

    var shouldRememberAsScreenVisit: Bool {
        switch self {
        case .home, .step, .gacha, .zukan, .memories, .settings:
            return true
        case .appPurpose, .foodButton, .foodGiveNormal, .foodNormalResult, .foodButtonForRare, .foodRareTab,
             .foodGiveRare, .foodRareResult, .foodFullnessReminder, .gachaButton, .gachaCharacterResult,
             .zukanButton, .tutorialFinished, .foodTutorialIntro, .foodTutorialNormalResult,
             .foodTutorialRareResult, .foodTutorialDone, .toiletTutorialIntro, .toiletTutorialScratch:
            return false
        }
    }

    var isMandatoryTutorialStep: Bool {
        switch self {
        case .appPurpose, .foodButton, .foodGiveNormal, .foodNormalResult, .foodButtonForRare, .foodRareTab,
             .foodGiveRare, .foodRareResult, .foodFullnessReminder, .gachaButton, .gachaCharacterResult,
             .zukanButton, .tutorialFinished:
            return true
        default:
            return false
        }
    }

    var spotlightTarget: MemoOnboardingTarget? {
        switch self {
        case .foodButton, .foodButtonForRare:
            return .foodButton
        case .foodGiveNormal:
            return .normalFood
        case .foodNormalResult:
            return .fullnessMeter
        case .foodRareTab:
            return .rareFoodTab
        case .foodGiveRare:
            return .rareFood
        case .gachaButton:
            return .gachaButton
        case .zukanButton:
            return .zukanButton
        default:
            return nil
        }
    }

    var usesSpotlight: Bool {
        spotlightTarget != nil
    }

    var waitsForActualOperation: Bool {
        switch self {
        case .foodGiveNormal, .foodGiveRare:
            return true
        default:
            return false
        }
    }

    var spotlightAllowsPassThroughToRealControl: Bool {
        switch self {
        case .foodButton, .foodButtonForRare, .foodRareTab, .foodGiveNormal, .foodGiveRare:
            return true
        default:
            return false
        }
    }

    var spotlightNeedsPrimaryButton: Bool {
        switch self {
        case .foodNormalResult:
            return true
        default:
            return false
        }
    }
}

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
    case happinessMeter
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

    // MARK: - First-visit / first-event explanations after mandatory tutorial
    case zukan
    case memories
    case settings
    case workFocusRewardIntro
    case workRouteRecordIntro
    case cameraCapture
    case toiletTutorialIntro
    case toiletTutorialScratch

    // MARK: - Legacy lightweight screens kept for compatibility with existing saved flags/hooks
    case home
    case step
    case gacha
    case foodTutorialIntro
    case foodTutorialNormalResult
    case foodTutorialRareResult
    case foodTutorialDone

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
        case .zukan:
            return "図鑑を見てみよう"
        case .memories:
            return "思い出を残せるよ"
        case .settings:
            return "設定を整えよう"
        case .workFocusRewardIntro:
            return "集中時間で部屋をゲットしよう！"
        case .workRouteRecordIntro:
            return "ウォーキング・ランを記録しよう！"
        case .cameraCapture:
            return "ミーモと思い出写真を撮ろう！"
        case .toiletTutorialIntro:
            return "おそうじの時間だよ"
        case .toiletTutorialScratch:
            return "こすってきれいにしよう"
        case .home:
            return "ミーモへようこそ"
        case .step:
            return "歩くことが力になるよ"
        case .gacha:
            return "はじめてのガチャだね"
        case .foodTutorialIntro:
            return "ごはんをあげてみよう"
        case .foodTutorialNormalResult:
            return "Nのごはん、上手にできたね"
        case .foodTutorialRareResult:
            return "Rのごはんは特別だよ"
        case .foodTutorialDone:
            return "ごはんの基本はばっちり"
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
            return "すごい！Rのごはんは満腹度に加えて、幸せ度も上がるよ。\n「幸せ度」が上がると特別なキャラクターがもらえるみたい！"
        case .foodFullnessReminder:
            return "満腹度が0のままだと、少しずつ幸せ度が下がってしまうよ。\nお腹が空いていたら、こまめにごはんをあげてね。"
        case .gachaButton:
            return "ごはんやミーモはガチャで手に入るよ。ガチャ画面に移動してみよう！"
        case .gachaCharacterResult:
            return "すごい！ミーモをゲットしたみたい！\n早速お世話してみよう！"
        case .zukanButton:
            return "図鑑でミーモを確認できるよ。\nゲットしたミーモに切り替えてみよう！"
        case .tutorialFinished:
            return "チュートリアルはここまで！\n他にもたくさんの機能やミーモがいるからお楽しみに。\n毎日歩いて、楽しく健康管理をしよう！"
        case .zukan:
            return "出会ったキャラクターをここで見返したり、お世話するミーモを切り替えられるよ！\nたくさん集めて図鑑を完成させよう！"
        case .memories:
            return "撮影した思い出を見返すことができるよ！\nお気に入りのミーモとたくさんお出かけしよう！"
        case .settings:
            return "通知や音などを調整できるよ。\n自分なりにカスタマイズしてみよう。"
        case .workFocusRewardIntro:
            return "タイマーが動いた累計集中時間（読書・勉強・仕事など）に応じて新しい部屋をゲットできるよ！\nコツコツ集中していろんなお部屋をゲットしてね！"
        case .workRouteRecordIntro:
            return "位置情報の共有をONにして「スタート」すると、移動したコース（ルート）が記録されるよ！\n記録したコースでミーモと一緒に写真を撮って頑張りを保存しよう！"
        case .cameraCapture:
            return "お世話中のミーモと一緒に写真を撮って思い出を記録しよう！\n撮影した写真は「思い出」に保存されるよ！\n位置情報の共有をONにすると撮影場所もわかるようになるよ！"
        case .toiletTutorialIntro:
            return "おっと！\nトイレのマークが出たら、おそうじが必要だよ！"
        case .toiletTutorialScratch:
            return "汚れは指こすって、お掃除してあげよう。\nキレイにしてあげると、「幸せ度」が増加するよ。"
        case .home:
            return "このアプリでは、歩数がコインのような役割になるよ。\n歩いて、ガチャをして、ごはんやキャラクターを集めながら、楽しく健康管理していこう！"
        case .step:
            return "今日の歩数を見られるよ。歩いたぶんだけ、ミーモで使える通貨が増えていくよ。"
        case .gacha:
            return "歩数を使って、ごはんやキャラクターが手に入るよ。"
        case .foodTutorialIntro:
            return "まずはごはんをあげてみよう。N（ノーマル）のごはんとR（レア）のごはんを1つずつ用意しておいたよ。"
        case .foodTutorialNormalResult:
            return "Nのごはんは、満腹度が増えるよ。おなかがすいている時に使ってあげようね。"
        case .foodTutorialRareResult:
            return "Rのごはんは、満腹度に加えて幸せ度も増えるよ。ガチャで手に入る特別なごはんだよ。"
        case .foodTutorialDone:
            return "ごはんはガチャで手に入るよ。歩いて、集めて、好きなキャラクターをお世話していこうね。"
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
        case .zukan, .memories, .settings, .workFocusRewardIntro, .workRouteRecordIntro, .cameraCapture:
            return "わかった"
        case .home, .step, .gacha:
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
        case .zukan, .memories, .settings, .workFocusRewardIntro, .workRouteRecordIntro, .cameraCapture:
            return true
        case .home, .step, .gacha:
            // Legacy screens are no longer requested by the updated hooks, but keeping the flag behavior
            // prevents repeated display if older code paths still request them.
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
        case .foodRareResult:
            return .happinessMeter
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
        case .foodNormalResult, .foodRareResult:
            return true
        default:
            return false
        }
    }
}

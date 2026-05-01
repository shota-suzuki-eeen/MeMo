//
//  MemoOnboardingIntegrationNotes.swift
//  MeMo
//
//  This file intentionally contains comments only.
//  It documents the onboarding connection points for future maintenance.
//

/*
 Mandatory onboarding flow implemented by this file set:

 1. RootView attaches .memoOnboardingRoot(state:viewModel:).
 2. MemoOnboardingRootModifier starts the mandatory onboarding after Health authorization.
 3. The first card has only 「はじめる」. There is no 「あとで」 button.
 4. The first tutorial state forces the food flag and gives one random N food and one random R food.
 5. The user is guided by spotlight overlays.
    - The instruction bubble's 「タップしてみよう！」 text is not a button.
    - For food-related steps, taps inside the highlighted area are passed through to the real HomeView controls.
    - Taps outside the highlighted area are blocked so the user does not get lost.
 6. The N/R food tutorial is designed to use the actual HomeView food button and food selector.
    - If HomeView calls MemoOnboardingHomeHooks.foodBubbleTapped(state:) when the existing food_button is tapped,
      the flow moves immediately from the food button guide to the selector guide.
    - If HomeView calls MemoOnboardingHomeHooks.foodDidFeed(foodID:) after feeding,
      the flow moves immediately to the result explanation.
    - Even without the foodDidFeed hook, MemoOnboardingRootModifier observes ownedFoodCountsData and detects
      when the tutorial food count decreased from the prepared count.
 7. After N food is given, the fullness meter is highlighted before moving to the R food tutorial.
 8. Tutorial gacha is displayed by MemoTutorialGachaView.
    It is ad-free, does not consume steps, performs 10 draws, and always awards one random gacha character.
 9. Tutorial character switching is displayed by MemoTutorialZukanSwitchView.
    The first switch is applied directly without an interstitial ad.
 10. The tutorial finishes back on Home with the closing teacher message.

 Recommended HomeView hook points for the most exact behavior:

 - Existing food_button action:
     MemoOnboardingHomeHooks.foodBubbleTapped(state: state)

 - Existing feed completion action, after the real feed succeeds:
     MemoOnboardingHomeHooks.foodDidFeed(foodID: foodID)

 These hooks do not replace the real controls. They only notify the onboarding coordinator that the real action happened.
 */

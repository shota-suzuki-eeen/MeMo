//
//  PhotoPrintShaders.metal
//  MeMo
//
//  SwiftUI distortionEffect用の軽量なポラロイド紙湾曲シェーダー。
//  アプリ本体ターゲットだけをTarget Membershipへ追加してください。
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static inline float memoSaturate(float value) {
    return clamp(value, 0.0, 1.0);
}

[[ stitchable ]]
float2 polaroidPaperBend(
    float2 position,
    float2 size,
    float progress,
    float bendAmount,
    float releaseAmount
) {
    float2 safeSize = max(size, float2(1.0));
    float2 uv = position / safeSize;

    float normalizedY = memoSaturate(uv.y);
    float normalizedX = memoSaturate(uv.x);
    float clampedProgress = memoSaturate(progress);

    // 排出口に拘束される上端はほぼ固定し、中央から下端だけを緩やかに変形する。
    float lowerPaperWeight = smoothstep(0.08, 1.0, normalizedY);
    float lowerPaperSquared = lowerPaperWeight * lowerPaperWeight;

    // 排出中盤で最大、開始時と終了時に0へ近づく再現可能な包絡線。
    float progressEnvelope = sin(clampedProgress * M_PI_F);
    float bend = bendAmount * progressEnvelope;

    // 下端側を縦方向へ押し出し、わずかな横方向の絞りで紙の反りを補助する。
    float verticalOffset = bend
        * safeSize.y
        * 0.034
        * lowerPaperSquared;

    float centeredX = normalizedX - 0.5;
    float horizontalOffset = -centeredX
        * abs(bend)
        * safeSize.x
        * 0.010
        * lowerPaperWeight;

    // 排出口から離れる瞬間だけ、逆方向へ小さく戻して紙の反動を表現する。
    float release = releaseAmount
        * safeSize.y
        * 0.012
        * lowerPaperWeight
        * (1.0 - lowerPaperWeight * 0.28);

    return position + float2(horizontalOffset, verticalOffset - release);
}

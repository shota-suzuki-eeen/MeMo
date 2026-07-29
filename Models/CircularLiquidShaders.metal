//
//  CircularLiquidShaders.metal
//  MeMo
//
//  円形メーター内の液体部分だけを描画するMetalシェーダーです。
//  アセット画像へのマスク処理は行いません。
//
//  2026/07/29 update:
//  iPhoneとApple Watchのメーター表現を統一するため、描画を
//  「2つの波・3色グラデーション・薄い白波・軽いハイライト」へ
//  簡略化しました。
//  気泡、コースティクス、液面フォーム、側面ライティングの
//  ピクセル計算を廃止し、既存のMetal基盤と省電力制御は維持します。
//

#include <metal_stdlib>
using namespace metal;

struct CircularLiquidUniforms {
    float time;
    float fillFraction;
    float2 padding;
    float4 mainColor;
    float4 deepColor;
    float4 highlightColor;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut circularLiquidVertex(
    uint vertexID [[vertex_id]]
) {
    float2 positions[6] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0, -1.0),
        float2( 1.0,  1.0),
        float2(-1.0,  1.0)
    };

    float2 position = positions[vertexID];

    VertexOut out;
    out.position = float4(position, 0.0, 1.0);
    out.uv = float2(
        (position.x + 1.0) * 0.5,
        1.0 - ((position.y + 1.0) * 0.5)
    );
    return out;
}

static inline float saturateValue(float value) {
    return clamp(value, 0.0, 1.0);
}

static inline float watchStyleWave(
    float normalizedX,
    float phase,
    float amplitude
) {
    constexpr float primaryFrequency =
        6.91150384; // 2π × 1.10
    constexpr float secondaryFrequency =
        13.5088484; // 2π × 2.15

    float primary =
        sin(
            normalizedX * primaryFrequency +
            phase
        ) *
        amplitude;

    float secondary =
        sin(
            normalizedX * secondaryFrequency -
            phase * 0.76 +
            1.4
        ) *
        amplitude *
        0.45;

    return primary + secondary;
}

fragment float4 circularLiquidFragment(
    VertexOut in [[stage_in]],
    constant CircularLiquidUniforms& u [[buffer(0)]]
) {
    float2 uv = in.uv;
    float fill =
        saturateValue(u.fillFraction);

    // Renderer側のrenderedTimeは実時間差分で進み、
    // 低電力・温度状態に応じたmotionScaleも反映済みです。
    float phase = u.time * 1.35;
    constexpr float amplitude = 0.045;

    float surface =
        1.0 -
        fill +
        watchStyleWave(
            uv.x,
            phase,
            amplitude
        );

    float liquidAlpha =
        smoothstep(
            surface - 0.012,
            surface + 0.008,
            uv.y
        );

    if (liquidAlpha <= 0.001) {
        return float4(0.0);
    }

    float depth =
        saturateValue(
            (uv.y - surface) /
            max(1.0 - surface, 0.001)
        );

    // Watch版と同じ、上部・中央・下部の
    // 3色による縦方向グラデーションです。
    float4 color =
        mix(
            u.highlightColor,
            u.mainColor,
            smoothstep(
                0.02,
                0.34,
                depth
            )
        );

    color =
        mix(
            color,
            u.deepColor,
            smoothstep(
                0.48,
                1.0,
                depth
            )
        );

    // Watch版の2枚目の白い波レイヤーを、
    // 追加のShapeを生成せず同一Fragment内で再現します。
    float secondaryFill =
        max(0.0, fill - 0.02);

    float secondarySurface =
        1.0 -
        secondaryFill +
        watchStyleWave(
            uv.x,
            phase + 1.65,
            amplitude * 1.35
        );

    float secondaryAlpha =
        smoothstep(
            secondarySurface - 0.012,
            secondarySurface + 0.008,
            uv.y
        ) *
        liquidAlpha;

    color.rgb =
        mix(
            color.rgb,
            float3(1.0),
            secondaryAlpha * 0.10
        );

    // Watch版のRadialGradient相当。
    // 気泡やコースティクスより大幅に軽い1回の距離計算のみです。
    float radialHighlight =
        1.0 -
        smoothstep(
            0.0,
            0.72,
            distance(
                uv,
                float2(0.24, 0.18)
            )
        );

    color.rgb +=
        u.highlightColor.rgb *
        radialHighlight *
        0.055 *
        liquidAlpha;

    color.rgb =
        saturate(color.rgb);
    color.a *= liquidAlpha;

    return color;
}

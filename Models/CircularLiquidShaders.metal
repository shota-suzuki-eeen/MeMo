//
//  CircularLiquidShaders.metal
//  MeMo
//
//  円形メーター内の液体部分だけを描画するMetalシェーダーです。
//  アセット画像へのマスク処理は行いません。
//

#include <metal_stdlib>
using namespace metal;

struct CircularLiquidUniforms {
    float time;
    float fillFraction;
    float aspectRatio;
    float motionScale;
    float4 mainColor;
    float4 deepColor;
    float4 highlightColor;
    float4 foamColor;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut circularLiquidVertex(uint vertexID [[vertex_id]]) {
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
    out.uv = float2((position.x + 1.0) * 0.5, 1.0 - ((position.y + 1.0) * 0.5));
    return out;
}

static inline float saturateValue(float value) {
    return clamp(value, 0.0, 1.0);
}

static inline float hash11(float seed) {
    return fract(sin(seed) * 43758.5453123);
}

fragment float4 circularLiquidFragment(VertexOut in [[stage_in]], constant CircularLiquidUniforms& u [[buffer(0)]]) {
    float2 uv = in.uv;
    float fill = saturateValue(u.fillFraction);
    float motion = max(u.motionScale, 0.0);
    float time = u.time * motion;

    float surface = 1.0 - fill;
    surface += sin(uv.x * 7.25 + time * 1.40) * 0.036;
    surface += sin(uv.x * 13.75 - time * 0.88 + 1.20) * 0.018;
    surface += sin((uv.x + uv.y * 0.18) * 21.0 + time * 0.58) * 0.007;

    float alpha = smoothstep(surface - 0.020, surface + 0.010, uv.y);
    if (alpha <= 0.001) {
        return float4(0.0);
    }

    float depth = saturateValue((uv.y - surface) / max(1.0 - surface, 0.001));
    float4 color = mix(u.highlightColor, u.mainColor, smoothstep(0.02, 0.32, depth));
    color = mix(color, u.deepColor, smoothstep(0.50, 1.0, depth));

    float surfaceFoam = exp(-abs(uv.y - surface) * 72.0);
    color.rgb += u.foamColor.rgb * surfaceFoam * 0.24;

    float shimmerA = sin((uv.x * 32.0 + uv.y * 18.0) + time * 2.0) * 0.5 + 0.5;
    float shimmerB = sin((uv.x * 17.0 - uv.y * 29.0) - time * 1.25) * 0.5 + 0.5;
    float caustics = pow(shimmerA * shimmerB, 3.0) * 0.13 * smoothstep(0.08, 0.78, depth);
    color.rgb += u.highlightColor.rgb * caustics;

    float bubbleAmount = 0.0;
    for (int i = 0; i < 8; i++) {
        float seed = float(i) + 1.0;
        float bx = hash11(seed * 14.31);
        float radius = mix(0.010, 0.026, hash11(seed * 2.17));
        float speed = mix(0.045, 0.120, hash11(seed * 7.77)) * max(motion, 0.18);
        float start = hash11(seed * 19.83);
        float by = fract(1.0 + start - time * speed);
        by = mix(surface + 0.065, 0.98, by);

        float2 delta = uv - float2(bx, by);
        delta.x *= u.aspectRatio;
        float distanceToBubble = length(delta);
        float bubble = 1.0 - smoothstep(radius * 0.68, radius, distanceToBubble);
        float ring = smoothstep(radius, radius * 0.72, distanceToBubble) * smoothstep(radius * 0.38, radius * 0.62, distanceToBubble);
        float insideLiquid = smoothstep(surface + 0.030, surface + 0.060, by);
        bubbleAmount += (bubble * 0.34 + ring * 0.58) * insideLiquid;
    }

    color.rgb = mix(color.rgb, u.foamColor.rgb, saturateValue(bubbleAmount) * 0.45);

    float sideLight = smoothstep(0.0, 0.25, uv.x) * smoothstep(1.0, 0.75, uv.x);
    color.rgb *= mix(0.86, 1.05, sideLight);

    color.a *= alpha;
    return color;
}

#include "ReShade.fxh"

//========================================================
// Shader: NaRKoM_Fix_Contrast
// Author: NaRKoMaNko & DeepSeek
//
// Description:
//   Automatically adjusts black and white levels to fix washed-out images
//   and make them consistently contrasty without crushing blacks or clipping whites.
//   To protect against over-darkening or over-brightening, you need to lower the white level
//   and raise the black level with another shader before this one.
//   For convenience, I created the shader "NaRKoM_protection_BlackWhite_Levels" –
//   just enable it and place it before this shader.
//   If the game's UI already has maximum black or white levels, the shader will stop working
//   and the image will become gray, so you can crop the input data area for analysis.
//========================================================

// Textures
texture BackBufferTex : COLOR;
sampler BackBuffer { Texture = BackBufferTex; };

texture LumaTex {
    Format = RGBA32F;
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
};
sampler LumaSampler { Texture = LumaTex; };

// For black level
texture MinLumaTex {
    Format = RGBA32F;
    Width = 1;
    Height = 1;
};
sampler MinLumaSampler { Texture = MinLumaTex; };

texture PrevMinLumaTex {
    Format = RGBA32F;
    Width = 1;
    Height = 1;
};
sampler PrevMinLumaSampler { Texture = PrevMinLumaTex; };

// For white level
texture MaxLumaTex {
    Format = RGBA32F;
    Width = 1;
    Height = 1;
};
sampler MaxLumaSampler { Texture = MaxLumaTex; };

texture PrevMaxLumaTex {
    Format = RGBA32F;
    Width = 1;
    Height = 1;
};
sampler PrevMaxLumaSampler { Texture = PrevMaxLumaTex; };

// Uniforms (User interface)

// Black channel
uniform float Intensity <
    ui_type = "drag";
    ui_label = "Intensity (Black)";
    ui_min = 0.0; ui_max = 2.0;
> = 1.075;

uniform float BlackThreshold <
    ui_type = "drag";
    ui_label = "Black Protection Threshold";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
    ui_tooltip = "If the real black level is above this value, the effect weakens.";
> = 0.9;

uniform float AdaptationTime <
    ui_type = "drag";
    ui_label = "Black Adaptation Time";
    ui_min = 0.0; ui_max = 2000000.0; ui_step = 5000.0;
    ui_tooltip = "Higher values = slower changes.";
> = 500000.0;

// White channel
uniform float IntensityWhite <
    ui_type = "drag";
    ui_label = "Intensity (White)";
    ui_min = 0.0; ui_max = 2.0;
> = 0.85;

uniform float WhiteThreshold <
    ui_type = "drag";
    ui_label = "White Activation Threshold";
    ui_min = -1.0; ui_max = 1.0; ui_step = 0.05;
    ui_tooltip = "White correction only works if the maximum brightness exceeds this value.";
> = 0.0;

uniform float AdaptationTimeWhite <
    ui_type = "drag";
    ui_label = "White Adaptation Time";
    ui_min = 0.0; ui_max = 2000000.0; ui_step = 5000.0;
    ui_tooltip = "Higher values = slower changes.";
> = 750000.0;

// Analysis parameters
uniform int SampleCount <
    ui_type = "drag";
    ui_label = "Analysis Precision";
    ui_min = 4; ui_max = 512; ui_step = 4;
> = 512;

// Crop area for sampling (in fractions of screen)
uniform float SampleOffsetLeft <
    ui_type = "drag";
    ui_label = "Crop Left";
    ui_min = 0.0; ui_max = 0.5; ui_step = 0.01;
> = 0.0;

uniform float SampleOffsetRight <
    ui_type = "drag";
    ui_label = "Crop Right";
    ui_min = 0.0; ui_max = 0.5; ui_step = 0.01;
> = 0.0;

uniform float SampleOffsetTop <
    ui_type = "drag";
    ui_label = "Crop Top";
    ui_min = 0.0; ui_max = 0.5; ui_step = 0.01;
> = 0.0;

uniform float SampleOffsetBottom <
    ui_type = "drag";
    ui_label = "Crop Bottom";
    ui_min = 0.0; ui_max = 0.5; ui_step = 0.01;
> = 0.0;

uniform float FrameTime < source = "frametime"; >;

// Helper functions
float RGBToLuma(float3 rgb) {
    return 0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b;
}

// Generate random point inside a given rectangle
float2 RandomInRect(float2 uv, float2 areaMin, float2 areaSize, int i) {
    return areaMin + float2(
        frac(sin(i * 12.9898 + uv.y * 78.233) * 43758.5453),
        frac(cos(i * 78.233 + uv.x * 12.9898) * 29729.3765)
    ) * areaSize;
}

// Pass: convert RGB to luma
float4 PS_Analyze(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    return float4(RGBToLuma(tex2D(BackBuffer, uv).rgb), 0, 0, 1);
}

// Pass: find minimum luma (black level)
float4 PS_FindMinLuma(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    float minLuma = 1.0;

    float left = SampleOffsetLeft;
    float right = 1.0 - SampleOffsetRight;
    float top = SampleOffsetTop;
    float bottom = 1.0 - SampleOffsetBottom;
    float2 areaMin = float2(left, top);
    float2 areaMax = float2(right, bottom);
    float2 areaSize = areaMax - areaMin;

    [loop]
    for (int i = 0; i < SampleCount; i++) {
        float2 sampleUV = RandomInRect(uv, areaMin, areaSize, i);
        // Clamp to be safe (though RandomInRect already gives values inside)
        sampleUV = clamp(sampleUV, areaMin, areaMax);
        float luma = tex2D(LumaSampler, sampleUV).r;
        minLuma = min(minLuma, luma);
    }

    // Temporal smoothing
    float prev = tex2Dlod(PrevMinLumaSampler, float4(0.5, 0.5, 0, 0)).r;
    float alpha = FrameTime / (AdaptationTime * 0.001 + FrameTime);
    minLuma = lerp(prev, minLuma, alpha);

    return float4(minLuma, 0, 0, 1);
}

// Pass: find maximum luma (white level)
float4 PS_FindMaxLuma(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    float maxLuma = 0.0;

    float left = SampleOffsetLeft;
    float right = 1.0 - SampleOffsetRight;
    float top = SampleOffsetTop;
    float bottom = 1.0 - SampleOffsetBottom;
    float2 areaMin = float2(left, top);
    float2 areaMax = float2(right, bottom);
    float2 areaSize = areaMax - areaMin;

    [loop]
    for (int i = 0; i < SampleCount; i++) {
        float2 sampleUV = RandomInRect(uv, areaMin, areaSize, i);
        sampleUV = clamp(sampleUV, areaMin, areaMax);
        float luma = tex2D(LumaSampler, sampleUV).r;
        maxLuma = max(maxLuma, luma);
    }

    // Temporal smoothing
    float prev = tex2Dlod(PrevMaxLumaSampler, float4(0.5, 0.5, 0, 0)).r;
    float alpha = FrameTime / (AdaptationTimeWhite * 0.001 + FrameTime);
    maxLuma = lerp(prev, maxLuma, alpha);

    return float4(maxLuma, 0, 0, 1);
}

// Pass: save previous min luma
float4 PS_SavePrevMin(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    return tex2D(MinLumaSampler, float2(0.5, 0.5));
}

// Pass: save previous max luma
float4 PS_SavePrevMax(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    return tex2D(MaxLumaSampler, float2(0.5, 0.5));
}

// Final pass: apply corrections
float4 PS_ApplyFix(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
    float3 color = tex2D(BackBuffer, uv).rgb;

    float minLuma = tex2D(MinLumaSampler, float2(0.5, 0.5)).r;
    float maxLuma = tex2D(MaxLumaSampler, float2(0.5, 0.5)).r;

    // Protection factors based on thresholds
    float blackFactor = saturate(1.0 - (minLuma / BlackThreshold));        // weaker when minLuma is high
    float whiteFactor = saturate((maxLuma - WhiteThreshold) / (1.0 - WhiteThreshold + 1e-6)); // active only above threshold

    // Black correction
    float blackBoost = 1.0 / (1.0 - minLuma + 1e-6);
    float3 afterBlack = lerp(color, (color - minLuma) * blackBoost, Intensity * blackFactor);
    afterBlack = max(afterBlack, 0.0);

    // White correction: stretch so that the current maximum (after black fix) becomes 1.0
    float maxAfterBlack = (maxLuma - minLuma) / (1.0 - minLuma + 1e-6);
    maxAfterBlack = clamp(maxAfterBlack, 0.0, 1.0);
    float whiteBoost = 1.0 / (maxAfterBlack + 1e-6);
    float3 finalColor = lerp(afterBlack, afterBlack * whiteBoost, IntensityWhite * whiteFactor);

    return float4(finalColor, 1.0);
}

// Technique
technique NaRKoM_Fix_Contrast
{
    pass Analyze
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Analyze;
        RenderTarget = LumaTex;
    }

    pass FindMinLuma
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_FindMinLuma;
        RenderTarget = MinLumaTex;
    }

    pass SavePrevMin
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_SavePrevMin;
        RenderTarget = PrevMinLumaTex;
    }

    pass FindMaxLuma
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_FindMaxLuma;
        RenderTarget = MaxLumaTex;
    }

    pass SavePrevMax
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_SavePrevMax;
        RenderTarget = PrevMaxLumaTex;
    }

    pass ApplyFix
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_ApplyFix;
    }
}
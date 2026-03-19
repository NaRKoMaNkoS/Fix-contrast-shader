#include "ReShade.fxh"

//========================================================
// Shader: NaRKoM_protection_BlackWhite_Levels
// Author: NaRKoMaNko & DeepSeek
//
// Description:
//   This shader helps protect the image from crushing blacks or clipping whites.
//   By default, it makes the image less contrasty.
//   Use "Black Raise" to lift shadows, and "White Lower" to reduce highlights.
//   Place this shader BEFORE the main auto-adjustment shader to create headroom.
//========================================================

texture BackBufferTex : COLOR;
sampler BackBuffer { Texture = BackBufferTex; };

uniform float BlackRaise <
    ui_type = "drag";
    ui_label = "Black Raise";
    ui_min = 0.0; ui_max = 0.5; ui_step = 0.01;
    ui_tooltip = "Raise black level (0 = no change, 0.5 = maximum raise).";
> = 0.35;

uniform float WhiteLower <
    ui_type = "drag";
    ui_label = "White Lower";
    ui_min = 0.0; ui_max = 0.5; ui_step = 0.01;
    ui_tooltip = "Lower white level (0 = no change, 0.5 = maximum lowering).";
> = 0.35;

float4 PS_Protect(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float3 color = tex2D(BackBuffer, uv).rgb;

    // Scale down sensitivity by factor 5 (so max 0.5 gives effect of 0.1)
    float blackRaise = BlackRaise * 0.2;   // max 0.1
    float whiteLower = WhiteLower * 0.2;   // max 0.1

    // Raise black: color = color * (1 - blackRaise) + blackRaise
    float3 raised = color * (1.0 - blackRaise) + blackRaise;
    // Lower white: color = color * (1 - whiteLower)
    float3 lowered = raised * (1.0 - whiteLower);

    // Clamp to safe range
    float3 result = saturate(lowered);

    return float4(result, 1.0);
}

technique NaRKoM_protection_BlackWhite_Levels
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Protect;
    }
}
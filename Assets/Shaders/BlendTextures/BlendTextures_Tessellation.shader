//variant of heightmap-texture-blending shader that uses tessellation to displace vertices based on heightmap heights,
//rather than any kind of parallax mapping
Shader "Custom/BlendTextures_Tessellation"
{
	Properties
	{
		//texture colours
		_BaseTexColour("Base texture colour", Color) = (1,1,1,1)
		_Tex1Colour("Texture 1 colour", Color) = (1,1,1,1)
		_Tex2Colour("Texture 2 colour", Color) = (1,1,1,1)
		_Tex3Colour("Texture 3 colour", Color) = (1,1,1,1)

		//texture maps
		_BaseTex("Base albedo", 2D) = "red" {}
		[Normal] _BaseTexNormal("Base normal", 2D) = "white" {}
		_BaseTexHRMA("Base HRMA", 2D) = "white" {}
		_MainTex1("Tex 1", 2D) = "green" {}
		[Normal] _Tex1Normal("Tex 1 normal", 2D) = "white" {}
		_Tex1HRMA("Tex 1 HRMA", 2D) = "white" {}
		_MainTex2("Tex 2", 2D) = "green" {}
		[Normal] _Tex2Normal("Tex 2 normal", 2D) = "white" {}
		_Tex2HRMA("Tex 2 HRMA", 2D) = "white" {}
		_MainTex3("Tex 3", 2D) = "green" {}
		[Normal] _Tex3Normal("Tex 3 normal", 2D) = "white" {}
		_Tex3HRMA("Tex 3 HRMA", 2D) = "white" {}

		[KeywordEnum(Texture, VertexColours)] _BlendSource("Source of blend weights", Float) = 0
		_BlendTex("Blend texture (Black = base tex, RGB = textures 1, 2 and 3", 2D) = "black" {}

		//blend properties
		[PowerSlider(3)] _HeightBlendFactor("Blend smoothness", Range(0.01, 1)) = 0.5
		[KeywordEnum(BlendAll, AddToBase, AddAll)] _HeightBlendMode("Height blend mode", Float) = 0
		_BaseTexHeightMult("Base heightmap intensity", Float) = 0
		_H1Mult("Tex 1 heightmap intensity", Float) = 0
		_H2Mult("Tex 2 heightmap intensity", Float) = 0
		_H3Mult("Tex 3 heightmap intensity", Float) = 0
		_BaseHeightOffset("Base heightmap offset", Float) = 0
		_H1Offset("Tex 1 heightmap offset", Float) = 0
		_H2Offset("Tex 2 heightmap offset", Float) = 0
		_H3Offset("Tex 3 heightmap offset", Float) = 0

		//tessellation properties
		[Header(Tessellation)]
		[IntRange] _Tessellation("Amount", Range(1, 20)) = 2
		_TessMinDist ("LOD start distance", Float) = 10
		_TessMaxDist ("LOD end distance", Float) = 50
		_DispAmount("Displacement amount", Float) = 0.1

		//other surface properties
		_AOStrength("AO strength", Range(0,1)) = 1.0
	}
		SubShader
		{
			Tags { "RenderType" = "Opaque" }
			LOD 200

			CGPROGRAM
			#pragma surface surf Standard fullforwardshadows vertex:disp tessellate:tessDistance addshadow
			#pragma target 4.6
			#pragma shader_feature _ _BLENDSOURCE_VERTEXCOLOURS 

			#include "Tessellation.cginc"
			#include "blends.cginc"

			struct Input
			{
				float2 uv_BaseTex;
				float2 uv_BlendTex; //separate UV so blend tex doesn't tile with other textures
				float3 viewDir;
				half3 colour : COLOR;
			};

			//textures
			sampler2D _BaseTex, _BaseTexNormal, _BaseTexHRMA;
			sampler2D _MainTex1, _Tex1Normal, _Tex1HRMA;
			sampler2D _MainTex2, _Tex2Normal, _Tex2HRMA;
			sampler2D _MainTex3, _Tex3Normal, _Tex3HRMA;

			//blending
			float _BlendSource;
			sampler2D _BlendTex;
			float _HeightBlendFactor;

			//heightmap adjustment params
			float _BaseTexHeightMult, _H1Mult, _H2Mult, _H3Mult;
			float _BaseHeightOffset, _H1Offset, _H2Offset, _H3Offset;

			//tessellation params
			float _Tessellation;
			float _TessMinDist, _TessMaxDist;
			float _DispAmount;

			float4 _Tex1Colour, _Tex2Colour, _Tex3Colour, _Tex4Colour;
			half _AOStrength;

			// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
			// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
			// #pragma instancing_options assumeuniformscaling
			UNITY_INSTANCING_BUFFER_START(Props)
				// put more per-instance properties here
			UNITY_INSTANCING_BUFFER_END(Props)

			float4 tessDistance(appdata_full v0, appdata_full v1, appdata_full v2) {
				return UnityDistanceBasedTess(v0.vertex, v1.vertex, v2.vertex, _TessMinDist, _TessMaxDist, _Tessellation);
			}

			void disp(inout appdata_full v)
			{
				float4 uv = float4(v.texcoord.xy, 0, 0);
				float hBase = getAdjustedHeight(tex2Dlod(_BaseTexHRMA, uv).r, _BaseTexHeightMult, _BaseHeightOffset);
				float h1 = getAdjustedHeight(tex2Dlod(_Tex1HRMA, uv).r, _H1Mult, _H1Offset);
				float h2 = getAdjustedHeight(tex2Dlod(_Tex2HRMA, uv).r, _H2Mult, _H2Offset);
				float h3 = getAdjustedHeight(tex2Dlod(_Tex3HRMA, uv).r, _H3Mult, _H3Offset);
				half3 blend = tex2Dlod(_BlendTex, uv);
				blend = getBlendAmounts(hBase, h1, h2, h3, blend, _HeightBlendFactor);
				
				half height = max(max(h1 * blend.r, h2 * blend.g), max(h3 * blend.b, hBase * (1 - (blend.r + blend.g + blend.b)))) * _DispAmount;
				
				v.vertex.xyz += v.normal * height * _DispAmount;
			}
			
			void surf(Input IN, inout SurfaceOutputStandard o)
			{
				float2 uv = IN.uv_BaseTex;

				float hBase = tex2D(_BaseTexHRMA, uv).r;
				float h1 = tex2D(_Tex1HRMA, uv).r;
				float h2 = tex2D(_Tex2HRMA, uv).r;
				float h3 = tex2D(_Tex3HRMA, uv).r;

				half3 blendTex = tex2D(_BlendTex, IN.uv_BlendTex).rgb;
				//https://forum.unity.com/threads/shaders-and-the-mystery-of-multitude-of-different-conditional-define-checks.319112/
				#if defined(_BLENDSOURCE_VERTEXCOLOURS) //use vertex colours for blend weights
					blendTex = IN.colour.rgb;
				#else //use blend texture
					blendTex = tex2D(_BlendTex, IN.uv_BlendTex).rgb;
				#endif

				//calculate blend amounts and store them in rgb values (base = 1 - (r + g + b)) so we don't have to calculate it for each map type
				half3 blendAmounts = getBlendAmounts(hBase * _BaseTexHeightMult, h1 * _H1Mult, h2 * _H2Mult, h3 * _H3Mult, blendTex, _HeightBlendFactor);

				half4 cBase = tex2D(_BaseTex, uv) * _Tex1Colour;
				half4 c1 = tex2D(_MainTex1, uv) * _Tex2Colour;
				half4 c2 = tex2D(_MainTex2, uv) * _Tex3Colour;
				half4 c3 = tex2D(_MainTex3, uv) * _Tex4Colour;

				half3 nBase = UnpackNormal(tex2D(_BaseTexNormal, uv));
				half3 n1 = UnpackNormal(tex2D(_Tex1Normal, uv));
				half3 n2 = UnpackNormal(tex2D(_Tex2Normal, uv));
				half3 n3 = UnpackNormal(tex2D(_Tex3Normal, uv));

				//r/m/ao maps
				//don't need height anymore so it becomes r = roughness, g = metallic, b = AO
				half3 rmaBase = tex2D(_BaseTexHRMA, uv).gba;
				half3 rma1 = tex2D(_Tex1HRMA, uv).gba;
				half3 rma2 = tex2D(_Tex2HRMA, uv).gba;
				half3 rma3 = tex2D(_Tex3HRMA, uv).gba;

				/* Debug albedos */
				//o.Albedo = getColFromBlendAmounts(hBase, h1, h2, h3, blendAmounts); //blended heightmaps
				//o.Albedo = getColFromBlendAmounts(hBase * _BaseTexHeightMult, h1 * _H1Mult, h2 * _H2Mult, h3 * _H3Mult, blendAmounts); //blended heightmaps with intensity multiplier
				//o.Albedo = blendTex; //initial blend weights
				//o.Albedo = blendAmounts; //blend weights after heightmap blending
				//o.Albedo = getColFromBlendAmounts(half4(hBase, rmaBase), half4(h1, rma1), half4(h2, rma2), half4(h3, rma3), blendAmounts); //HRMA maps

				o.Albedo = getColFromBlendAmounts(cBase, c1, c2, c3, blendAmounts);
				o.Normal = getColFromBlendAmounts(nBase, n1, n2, n3, blendAmounts);
				o.Smoothness = getColFromBlendAmounts(1 - rmaBase.r, 1 - rma1.r, 1 - rma2.r, 1 - rma3.r, blendAmounts);
				o.Metallic = getColFromBlendAmounts(rmaBase.g, rma1.g, rma2.g, rma3.g, blendAmounts);
				o.Occlusion = (getColFromBlendAmounts(rmaBase.b, rma1.b, rma2.b, rma3.b, blendAmounts) * _AOStrength) + (1 - _AOStrength);

				//TEST: "rain"
				/*
				float rainHeight = _BaseMetallic;
				float3 rain = float3(0, 0.5f, 0.5f);
				o.Albedo = blendHeights(o.Albedo, blendedHeight, rain, rainHeight, 0.01);
				o.Normal = blendHeights(o.Normal, blendedHeight, half3(1,1,1), rainHeight, 0.01);
				*/
			}
			ENDCG
		}
			FallBack "Diffuse"
}

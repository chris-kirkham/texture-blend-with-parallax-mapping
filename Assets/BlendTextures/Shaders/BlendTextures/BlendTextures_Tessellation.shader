Shader "BlendTextures/BlendTextures_Tessellated" {
	Properties{
		//Colours
		_BaseTexColour("Base texture colour", Color) = (1,1,1,1)
		_Tex1Colour("Texture 1 colour", Color) = (1,1,1,1)
		_Tex2Colour("Texture 2 colour", Color) = (1,1,1,1)
		_Tex3Colour("Texture 3 colour", Color) = (1,1,1,1)

		//Textures
		[MainTexture] _BaseTex("Base albedo", 2D) = "red" {}
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

		//[KeywordEnum(None, Add, Multiply)] _Overlay("Overlay mode", Float) = 0 //consider using KeywordEnum for more than on/off keywords
		//see https://docs.unity3d.com/ScriptReference/MaterialPropertyDrawer.html - Unity turns KeywordEnums into keyword names in this format: 
		//"property name" (including trailing underscore) + "_" + "enum name" (all names become ALLCAPS)

		[KeywordEnum(Texture, VertexColours)] _BlendSource("Source of blend weights", Float) = 0
		_BlendTex("Blend map", 2D) = "black" {}

		//Blend parameters
		[PowerSlider(3)] _HeightBlendFactor("Blend smoothness", Range(0.01, 1)) = 0.5
		[KeywordEnum(BlendAll, AddToBase, AddAll)] _HeightBlendMode("Height blend mode", Float) = 0
		_BaseTexHeightMult("Base heightmap intensity", Float) = 0
		_H1Mult("Tex 1 heightmap intensity", Float) = 0
		_H2Mult("Tex 2 heightmap intensity", Float) = 0
		_H3Mult("Tex 3 heightmap intensity", Float) = 0
		[Range] _BaseHeightOffset("Base heightmap offset", Range(-1, 1)) = 0
		[Range] _H1Offset("Tex 1 heightmap offset", Range(-1, 1)) = 0
		[Range] _H2Offset("Tex 2 heightmap offset", Range(-1, 1)) = 0
		[Range] _H3Offset("Tex 3 heightmap offset", Range(-1, 1)) = 0

		//Surface properties
		_AOStrength("AO strength", Range(0,1)) = 1.0

		//Tessellation
		_TessellationFactor ("Tessellation factor", Range(1, 32)) = 4
		_VertDisplacement ("Displacement", Float) = 0.25
		_DisplacementOffset ("Displacement offset", Range(-1, 0)) = 0
	}
		SubShader{
			Tags { "RenderType" = "Opaque" }
			LOD 200

			CGPROGRAM
			
			#pragma surface surf Standard fullforwardshadows vertex:vert tessellate:tess
			#pragma target 4.6
			#include "parallax.cginc"
			#include "Tessellation.cginc"

			#pragma shader_feature _HEIGHTBLENDMODE_BLENDALL _HEIGHTBLENDMODE_ADDTOBASE _HEIGHTBLENDMODE_ADDALL //height blend modes

			struct Input {
				float2 uv_BaseTex;
			};

			/* textures */
			sampler2D _BaseTex, _BaseTexNormal, _BaseTexHRMA;
			sampler2D _MainTex1, _Tex1Normal, _Tex1HRMA;
			sampler2D _MainTex2, _Tex2Normal, _Tex2HRMA;
			sampler2D _MainTex3, _Tex3Normal, _Tex3HRMA;

			/* heightmap adjust params */
			float _BaseTexHeightMult, _H1Mult, _H2Mult, _H3Mult;
			float _BaseHeightOffset, _H1Offset, _H2Offset, _H3Offset;

			/* heightmap texture blending */
			float _BlendSource;
			sampler2D _BlendTex;
			float _HeightBlendFactor;

			/* surface properties */
			float4 _BaseTexColour, _Tex1Colour, _Tex2Colour, _Tex3Colour;
			half _AOStrength;

			/* tessellation */
			float _TessellationFactor;
			float _VertDisplacement;
			float _DisplacementOffset;

			float4 tess (appdata_full v0, appdata_full v1, appdata_full v2) {
				float minDist = 10.0;
                float maxDist = 25.0;
                return UnityDistanceBasedTess(v0.vertex, v1.vertex, v2.vertex, minDist, maxDist, _TessellationFactor);
			}

			float getBlendedHeight_Vert(float2 uv)
			{
				float4 uvLod = float4(uv.xy, 0.0f, 0.0f);

				float hBase = getAdjustedHeight(tex2Dlod(_BaseTexHRMA, uvLod).r, _BaseTexHeightMult, _BaseHeightOffset);
				float h1 = getAdjustedHeight(tex2Dlod(_Tex1HRMA, uvLod).r, _H1Mult, _H1Offset);
				float h2 = getAdjustedHeight(tex2Dlod(_Tex2HRMA, uvLod).r, _H2Mult, _H2Offset);
				float h3 = getAdjustedHeight(tex2Dlod(_Tex3HRMA, uvLod).r, _H3Mult, _H3Offset);
				float heights[4] = {hBase, h1, h2, h3};

				sampler2D hmaps[4] = { _BaseTexHRMA, _Tex1HRMA, _Tex2HRMA, _Tex3HRMA };
				half3 blendTex = tex2Dlod(_BlendTex, uvLod).rgb;
				half3 blendAmounts = getBlendAmounts(hBase, h1, h2, h3, blendTex, _HeightBlendFactor);
				
				return getBlendedHeight(heights, 4, blendAmounts);
			}

			void vert(inout appdata_full IN) {
				float2 uv = IN.texcoord;
				float blendedHeight = getBlendedHeight_Vert(uv);

				/*
				//Get height-adjusted normals - TODO: WRONG - seems to shade wrong side of things sometimes
				//https://www.alanzucconi.com/2019/07/03/interactive-map-shader-terrain-shading/
				const float offset = 0.01f;
				float blendedHeight_PlusX = getBlendedHeight_Vert(uv + float2(offset, 0.0f));
				float blendedHeight_PlusZ = getBlendedHeight_Vert(uv + float2(0.0f, offset));
				float4 offsetVertex = IN.vertex + float4(0, blendedHeight, 0, 0);
				float4 bitangent = IN.vertex + float4(offset, blendedHeight_PlusX, 0, 0);
				float4 tangent = IN.vertex + float4(0, blendedHeight_PlusZ, offset, 0);
				float3 newBitangent = (bitangent - offsetVertex).xyz;
				float3 newTangent = (tangent - offsetVertex).xyz;
				float3 normal = normalize(cross(newTangent, newBitangent));
				*/

                IN.vertex.xyz += (IN.normal * blendedHeight * _VertDisplacement) + (IN.normal * _DisplacementOffset * _VertDisplacement);
				//IN.normal = normal;
			}

			void surf(Input IN, inout SurfaceOutputStandard o) {
				float2 uv = IN.uv_BaseTex;

				//need to use the initial (non-parallax-offset) uv for the height; r/m/ao uses parallax uv
				float hBase = getAdjustedHeight(tex2D(_BaseTexHRMA, uv).r, _BaseTexHeightMult, _BaseHeightOffset);
				float h1 = getAdjustedHeight(tex2D(_Tex1HRMA, uv).r, _H1Mult, _H1Offset);
				float h2 = getAdjustedHeight(tex2D(_Tex2HRMA, uv).r, _H2Mult, _H2Offset);
				float h3 = getAdjustedHeight(tex2D(_Tex3HRMA, uv).r, _H3Mult, _H3Offset);
				float heights[4] = {hBase, h1, h2, h3};
				
				sampler2D hmaps[4] = { _BaseTexHRMA, _Tex1HRMA, _Tex2HRMA, _Tex3HRMA };
				float hmapMults[4] = { _BaseTexHeightMult, _H1Mult, _H2Mult, _H3Mult };
				float hmapOffsets[4] = { _BaseHeightOffset, _H1Offset, _H2Offset, _H3Offset };
				half3 blendTex = tex2D(_BlendTex, uv).rgb;
				half3 blendAmounts = getBlendAmounts(hBase, h1, h2, h3, blendTex, _HeightBlendFactor);

				/* get other textures using parallax-mapped UVs */
				half4 cBase = tex2D(_BaseTex, uv) * _BaseTexColour;
				half4 c1 = tex2D(_MainTex1, uv) * _Tex1Colour;
				half4 c2 = tex2D(_MainTex2, uv) * _Tex2Colour;
				half4 c3 = tex2D(_MainTex3, uv) * _Tex3Colour;

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

				o.Albedo = getColFromBlendAmounts(cBase, c1, c2, c3, blendAmounts);
				//o.Normal = getColFromBlendAmounts(nBase, n1, n2, n3, blendAmounts);
				o.Smoothness = getColFromBlendAmounts(1 - rmaBase.r, 1 - rma1.r, 1 - rma2.r, 1 - rma3.r, blendAmounts);
				o.Metallic = getColFromBlendAmounts(rmaBase.g, rma1.g, rma2.g, rma3.g, blendAmounts);
				o.Occlusion = (getColFromBlendAmounts(rmaBase.b, rma1.b, rma2.b, rma3.b, blendAmounts) * _AOStrength) + (1 - _AOStrength);
			}

			ENDCG
		}
			FallBack "Diffuse"
			//CustomEditor "BlendTexturesTessellatedInspector"
}
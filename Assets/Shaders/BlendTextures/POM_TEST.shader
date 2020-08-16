Shader "Custom/POM_TEST" {
	Properties{
		//[Header(Colours)]
		_BaseTexColour("Base texture colour", Color) = (1,1,1,1)
		_Tex1Colour("Texture 1 colour", Color) = (1,1,1,1)
		_Tex2Colour("Texture 2 colour", Color) = (1,1,1,1)
		_Tex3Colour("Texture 3 colour", Color) = (1,1,1,1)

		//[Header(Textures)]
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

		//[KeywordEnum(None, Add, Multiply)] _Overlay("Overlay mode", Float) = 0 //consider using KeywordEnum for more than on/off keywords
		//see https://docs.unity3d.com/ScriptReference/MaterialPropertyDrawer.html - Unity turns KeywordEnums into keyword names in this format: 
		//"property name" (including trailing underscore) + "_" + "enum name" (all names become ALLCAPS)

		//[Toggle(USE_VERTEX_COLOURS_FOR_BLEND_WEIGHTS)]
		[KeywordEnum(Texture, VertexColours)] _BlendSource("Source of blend weights", Float) = 0
		_BlendTex("Blend map", 2D) = "black" {}

		//[Header(Blend parameters)]
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

		//[Header(Parallax mapping)]
		[KeywordEnum(Offset, IterativeOffset, Occlusion)] _PlxType("Parallax mapping method", Float) = 0
		[PowerSlider(4)] _ParallaxAmt("Parallax amount", Range(0, 0.5)) = 0.08
		[IntRange] _Iterations("Iterations", Range(0, 10)) = 2
		[IntRange] _OcclusionMinSamples("Minimum samples", Range(2, 100)) = 10
		[IntRange] _OcclusionMaxSamples("Maximum samples", Range(2, 100)) = 20

		//[Header(Surface properties)]
		_AOStrength("AO strength", Range(0,1)) = 1.0
	}
		SubShader{
			Tags { "RenderType" = "Opaque" }
			LOD 200

			CGPROGRAM
			#pragma surface surf Standard fullforwardshadows vertex:vert
			#pragma target 3.0
			//#include "blends.cginc" //don't include this here if it's included in parallax.cginc
			#include "parallax.cginc"

			#pragma shader_feature _HEIGHTBLENDMODE_BLENDALL _HEIGHTBLENDMODE_ADDTOBASE _HEIGHTBLENDMODE_ADDALL //height blend modes
			#pragma shader_feature _PLXTYPE_OFFSET _PLXTYPE_ITERATIVEOFFSET _PLXTYPE_OCCLUSION //parallax offset methods

			struct Input {
				float2 texcoord;
				float3 tangentViewDir;
				float sampleRatio;
			};

			/* textures */
			sampler2D _BaseTex, _BaseTexNormal, _BaseTexHRMA;
			sampler2D _MainTex1, _Tex1Normal, _Tex1HRMA;
			sampler2D _MainTex2, _Tex2Normal, _Tex2HRMA;
			sampler2D _MainTex3, _Tex3Normal, _Tex3HRMA;

			/* heightmap adjust params */
			float _BaseTexHeightMult, _H1Mult, _H2Mult, _H3Mult;
			//float _BaseHeightOffset, _H1Offset, _H2Offset, _H3Offset;

			/* heightmap texture blending */
			float _BlendSource;
			sampler2D _BlendTex;
			float _HeightBlendFactor;
			

			/* parallax mapping */
			float _PlxType;
			float _ParallaxAmt;
			float _Iterations;
			int _OcclusionMinSamples, _OcclusionMaxSamples;

			float4 _BaseTexColour, _Tex1Colour, _Tex2Colour, _Tex3Colour;
			half _BaseMetallic, _Tex1Metallic, _Tex2Metallic, _Tex3Metallic;
			half _AOStrength;

			void parallax_vert(
				float4 vertex,
				float3 normal,
				float4 tangent,
				out float3 tangentViewDir,
				out float sampleRatio
			) {
				float4x4 mW = unity_ObjectToWorld;
				float3 binormal = cross(normal, tangent.xyz) * tangent.w;
				float3 EyePosition = _WorldSpaceCameraPos;

				// Need to do it this way for W-normalisation and.. stuff.
				float4 localCameraPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
				float3 eyeLocal = vertex - localCameraPos;
				float4 eyeGlobal = mul(float4(eyeLocal, 1), mW);
				float3 E = eyeGlobal.xyz;

				float3x3 tangentToWorldSpace;

				tangentToWorldSpace[0] = mul(normalize(tangent), mW);
				tangentToWorldSpace[1] = mul(normalize(binormal), mW);
				tangentToWorldSpace[2] = mul(normalize(normal), mW);

				float3x3 worldToTangentSpace = transpose(tangentToWorldSpace);

				tangentViewDir = mul(E, worldToTangentSpace);
				sampleRatio = 1 - dot(normalize(E), -normal);
			}

			void vert(inout appdata_full IN, out Input OUT) {
				parallax_vert(IN.vertex, IN.normal, IN.tangent, OUT.tangentViewDir, OUT.sampleRatio);
				OUT.texcoord = IN.texcoord;
			}

			/*
			float getAdjustedHeight(float height, float intensity, float offset)
			{
				return saturate(height + ((height - 0.5) * intensity) + offset);
			}
			*/
			
			void surf(Input IN, inout SurfaceOutputStandard o) {

				float2 uv = IN.texcoord;

				//need to use the initial (non-parallax-offset) uv for the height; r/m/ao uses parallax uv
				float hBase = getAdjustedHeight(tex2D(_BaseTexHRMA, uv).r, _BaseTexHeightMult);
				float h1 = getAdjustedHeight(tex2D(_Tex1HRMA, uv).r, _H1Mult);
				float h2 = getAdjustedHeight(tex2D(_Tex2HRMA, uv).r, _H2Mult);
				float h3 = getAdjustedHeight(tex2D(_Tex3HRMA, uv).r, _H3Mult);
				
				sampler2D hmaps[4] = { _BaseTexHRMA, _Tex1HRMA, _Tex2HRMA, _Tex3HRMA };
				float hmapMults[4] = { _BaseTexHeightMult, _H1Mult, _H2Mult, _H3Mult };
				half3 blendTex = tex2D(_BlendTex, IN.texcoord).rgb;
				half3 blendAmounts = getBlendAmounts(hBase, h1, h2, h3, blendTex, _HeightBlendFactor);

				/* get UV offset based on selected parallax method */
				//get UV offset
				float2 offset = float2(0, 0);
				#if defined(_PLXTYPE_OFFSET)
					offset = ParallaxOffsetLimited(GetBlendedHeight(hmaps, hmapMults, 4, uv, blendAmounts), _ParallaxAmt, IN.tangentViewDir);
				#elif defined(_PLXTYPE_ITERATIVEOFFSET)
					offset = IterativeParallaxOffset(uv, blendAmounts, hmaps, hmapMults, 4, _ParallaxAmt, _Iterations, IN.tangentViewDir);
				#elif defined(_PLXTYPE_OCCLUSION)
					offset = POM(_ParallaxAmt, IN.tangentViewDir, IN.sampleRatio, IN.texcoord,
						hmaps, hmapMults, _BlendTex, _HeightBlendFactor, _OcclusionMinSamples, _OcclusionMaxSamples);
				#endif
				uv += offset;

				//update blendAmounts with parallax-mapped uv coords
				blendTex = tex2D(_BlendTex, uv).rgb;
				hBase = getAdjustedHeight(tex2D(_BaseTexHRMA, uv).r, _BaseTexHeightMult);
				h1 = getAdjustedHeight(tex2D(_Tex1HRMA, uv).r, _H1Mult);
				h2 = getAdjustedHeight(tex2D(_Tex2HRMA, uv).r, _H2Mult);
				h3 = getAdjustedHeight(tex2D(_Tex3HRMA, uv).r, _H3Mult);
				blendAmounts = getBlendAmounts(hBase, h1, h2, h3, blendTex, _HeightBlendFactor);

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
				o.Normal = getColFromBlendAmounts(nBase, n1, n2, n3, blendAmounts);
				o.Smoothness = getColFromBlendAmounts(1 - rmaBase.r, 1 - rma1.r, 1 - rma2.r, 1 - rma3.r, blendAmounts);
				o.Metallic = getColFromBlendAmounts(rmaBase.g, rma1.g, rma2.g, rma3.g, blendAmounts);
				o.Occlusion = (getColFromBlendAmounts(rmaBase.b, rma1.b, rma2.b, rma3.b, blendAmounts) * _AOStrength) + (1 - _AOStrength);
			}

			ENDCG
		}
			FallBack "Diffuse"
			CustomEditor "POM_TEST_Shader_Editor"
}
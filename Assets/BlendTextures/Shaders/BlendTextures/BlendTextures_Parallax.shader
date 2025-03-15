Shader "BlendTextures/BlendTextures_Parallax" {
	Properties{
		//Colours
		_BaseTexColour("Base texture colour", Color) = (1,1,1,1)
		_Tex1Colour("Texture 1 colour", Color) = (1,1,1,1)
		_Tex2Colour("Texture 2 colour", Color) = (1,1,1,1)
		_Tex3Colour("Texture 3 colour", Color) = (1,1,1,1)

		//Textures
		_BaseTex("Base albedo", 2D) = "red" {}
		[Normal] _BaseTexNormal("Base normal", 2D) = "white" {}
		_BaseTexHRMA("Base HRMA", 2D) = "white" {}
		_BaseTexTiling("Base tiling", Float) = 1
		_MainTex1("Tex 1", 2D) = "green" {}
		[Normal] _Tex1Normal("Tex 1 normal", 2D) = "white" {}
		_Tex1HRMA("Tex 1 HRMA", 2D) = "white" {}
		_Tex1Tiling("Tex 1 tiling", Float) = 1
		_MainTex2("Tex 2", 2D) = "green" {}
		[Normal] _Tex2Normal("Tex 2 normal", 2D) = "white" {}
		_Tex2HRMA("Tex 2 HRMA", 2D) = "white" {}
		_Tex2Tiling("Tex 2 tiling", Float) = 1
		_MainTex3("Tex 3", 2D) = "green" {}
		[Normal] _Tex3Normal("Tex 3 normal", 2D) = "white" {}
		_Tex3HRMA("Tex 3 HRMA", 2D) = "white" {}
		_Tex3Tiling("Tex 3 tiling", Float) = 1

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

		//Parallax mapping)
		[KeywordEnum(Offset, IterativeOffset, Occlusion)] _PlxType("Parallax mapping method", Float) = 0
		[PowerSlider(4)] _ParallaxAmt("Parallax amount", Range(0, 0.5)) = 0.08
		[IntRange] _Iterations("Iterations", Range(0, 10)) = 2
		[IntRange] _OcclusionMinSamples("Minimum samples", Range(2, 100)) = 10
		[IntRange] _OcclusionMaxSamples("Maximum samples", Range(2, 100)) = 20
		[Toggle(CLIP_SILHOUETTE)] _ClipSilhouette("Clip silhouette", Float) = 0

		//Surface properties
		_AOStrength("AO strength", Range(0,1)) = 1.0
	}
		SubShader{
			Tags { "RenderType" = "Opaque" }
			LOD 200

			CGPROGRAM
			#pragma surface surf Standard fullforwardshadows vertex:vert
			#pragma target 4.6
			#include "HLSLSupport.cginc"
			#include "parallax.cginc"

			#pragma shader_feature _HEIGHTBLENDMODE_BLENDALL _HEIGHTBLENDMODE_ADDTOBASE _HEIGHTBLENDMODE_ADDALL //height blend modes
			#pragma shader_feature _PLXTYPE_OFFSET _PLXTYPE_ITERATIVEOFFSET _PLXTYPE_OCCLUSION //parallax offset methods
			#pragma shader_feature CLIP_SILHOUETTE

			struct Input {
				float2 texcoord;
				float3 tangentViewDir;
				float sampleRatio;
			};

			/* textures */
			UNITY_DECLARE_TEX2D(_BaseTex);
			UNITY_DECLARE_TEX2D_NOSAMPLER(_BaseTexNormal);
			UNITY_DECLARE_TEX2D_NOSAMPLER(_BaseTexHRMA);
			
			UNITY_DECLARE_TEX2D(_MainTex1);
			UNITY_DECLARE_TEX2D_NOSAMPLER(_Tex1Normal);
			UNITY_DECLARE_TEX2D_NOSAMPLER(_Tex1HRMA);
			
			UNITY_DECLARE_TEX2D(_MainTex2);
			UNITY_DECLARE_TEX2D_NOSAMPLER(_Tex2Normal);
			UNITY_DECLARE_TEX2D_NOSAMPLER(_Tex2HRMA);

			UNITY_DECLARE_TEX2D(_MainTex3);
			UNITY_DECLARE_TEX2D_NOSAMPLER(_Tex3Normal);
			UNITY_DECLARE_TEX2D_NOSAMPLER(_Tex3HRMA);

			/* texture tiling */
			float _BaseTexTiling, _Tex1Tiling, _Tex2Tiling, _Tex3Tiling;

			/* heightmap adjust params */
			float _BaseTexHeightMult, _H1Mult, _H2Mult, _H3Mult;
			float _BaseHeightOffset, _H1Offset, _H2Offset, _H3Offset;

			/* heightmap texture blending */
			float _BlendSource;
			sampler2D _BlendTex;
			float _HeightBlendFactor;

			/* parallax mapping */
			float _PlxType;
			float _ParallaxAmt;
			float _Iterations;
			int _OcclusionMinSamples, _OcclusionMaxSamples;
			float _ClipSilhouette;

			/* surface properties */
			float4 _BaseTexColour, _Tex1Colour, _Tex2Colour, _Tex3Colour;
			half _AOStrength;

			void parallax_vert(
				float4 vertex,
				float3 normal,
				float4 tangent,
				out float3 tangentViewDir,
				out float sampleRatio
			) {
				//get world-to-tangent matrix
				float4x4 mW = unity_ObjectToWorld;
				float3 binormal = cross(normal, tangent.xyz) * tangent.w;
				float3x3 tangentToWorldSpace;
				tangentToWorldSpace[0] = mul(normalize(tangent), mW);
				tangentToWorldSpace[1] = mul(normalize(binormal), mW);
				tangentToWorldSpace[2] = mul(normalize(normal), mW);
				float3x3 worldToTangentSpace = transpose(tangentToWorldSpace);

				//get view direction
				// Need to do it this way for W-normalisation and.. stuff.
				float3 EyePosition = _WorldSpaceCameraPos;
				float4 localCameraPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
				float3 eyeLocal = vertex - localCameraPos;
				float4 eyeGlobal = mul(float4(eyeLocal, 1), mW);
				float3 E = eyeGlobal.xyz;

				tangentViewDir = mul(E, worldToTangentSpace);
				sampleRatio = 1 - dot(normalize(E), -normal);
			}

			void vert(inout appdata_full IN, out Input OUT) {
				parallax_vert(IN.vertex, IN.normal, IN.tangent, OUT.tangentViewDir, OUT.sampleRatio);
				OUT.texcoord = IN.texcoord;
			}

			void surf(Input IN, inout SurfaceOutputStandard o) {

				//get raw and scaled UVs
				float2 uv = IN.texcoord;
				float2 baseUV = uv * _BaseTexTiling;
				float2 tex1UV = uv * _Tex1Tiling;
				float2 tex2UV = uv * _Tex2Tiling;
				float2 tex3UV = uv * _Tex3Tiling;

				//need to use the initial (non-parallax-offset) uv for the height; r/m/ao uses parallax uv
				float hBase = getAdjustedHeight(UNITY_SAMPLE_TEX2D_SAMPLER(_BaseTexHRMA, _BaseTex, baseUV).r, _BaseTexHeightMult, _BaseHeightOffset);
				float h1 = getAdjustedHeight(UNITY_SAMPLE_TEX2D_SAMPLER(_Tex1HRMA, _MainTex1, tex1UV).r, _H1Mult, _H1Offset);
				float h2 = getAdjustedHeight(UNITY_SAMPLE_TEX2D_SAMPLER(_Tex2HRMA, _MainTex2, tex2UV).r, _H2Mult, _H2Offset);
				float h3 = getAdjustedHeight(UNITY_SAMPLE_TEX2D_SAMPLER(_Tex3HRMA, _MainTex3, tex3UV).r, _H3Mult, _H3Offset);
				float heights[4] = { hBase, h1, h2, h3 };

				sampler2D hmaps[4] = { _BaseTexHRMA, _Tex1HRMA, _Tex2HRMA, _Tex3HRMA };
				float hmapMults[4] = { _BaseTexHeightMult, _H1Mult, _H2Mult, _H3Mult };
				float hmapOffsets[4] = { _BaseHeightOffset, _H1Offset, _H2Offset, _H3Offset };
				half3 blendTex = tex2D(_BlendTex, uv).rgb;
				half3 blendAmounts = getBlendAmounts(hBase, h1, h2, h3, blendTex, _HeightBlendFactor);

				//get parallax-mapped UV offset based on selected parallax method
				float2 offset = float2(0, 0);
				#if defined(_PLXTYPE_OFFSET)
					offset = ParallaxOffsetLimited(getBlendedHeight(heights, 4, blendAmounts), _ParallaxAmt, IN.tangentViewDir);
//				#elif defined(_PLXTYPE_ITERATIVEOFFSET)
//					offset = IterativeParallaxOffset(uv, blendAmounts, hmaps, hmapMults, hmapOffsets, 4, _ParallaxAmt, _Iterations, IN.tangentViewDir);
//				#elif defined(_PLXTYPE_OCCLUSION)
//					offset = POM(_ParallaxAmt, IN.tangentViewDir, IN.sampleRatio, IN.texcoord,
//						hmaps, hmapMults, hmapOffsets, _BlendTex, _HeightBlendFactor, _OcclusionMinSamples, _OcclusionMaxSamples);
				#endif
				uv += offset;

				//update tiled UVs
				baseUV = uv * _BaseTexTiling;
				tex1UV = uv * _Tex1Tiling;
				tex2UV = uv * _Tex2Tiling;
				tex3UV = uv * _Tex3Tiling;

				//resample textures using parallax-mapped UVs
				fixed4 hrmaBase = UNITY_SAMPLE_TEX2D_SAMPLER(_BaseTexHRMA, _BaseTex, baseUV);
				fixed4 hrma1 = UNITY_SAMPLE_TEX2D_SAMPLER(_Tex1HRMA, _MainTex1, tex1UV);
				fixed4 hrma2 = UNITY_SAMPLE_TEX2D_SAMPLER(_Tex2HRMA, _MainTex2, tex2UV);
				fixed4 hrma3 = UNITY_SAMPLE_TEX2D_SAMPLER(_Tex3HRMA, _MainTex3, tex3UV);

				hBase = getAdjustedHeight(hrmaBase.r, _BaseTexHeightMult, _BaseHeightOffset);
				h1 = getAdjustedHeight(hrma1.r, _H1Mult, _H1Offset);
				h2 = getAdjustedHeight(hrma2.r, _H2Mult, _H2Offset);
				h3 = getAdjustedHeight(hrma3.r, _H3Mult, _H3Offset);

				half4 cBase = UNITY_SAMPLE_TEX2D(_BaseTex, baseUV) * _BaseTexColour;
				half4 c1 = UNITY_SAMPLE_TEX2D(_MainTex1, tex1UV) * _Tex1Colour;
				half4 c2 = UNITY_SAMPLE_TEX2D(_MainTex2, tex2UV) * _Tex2Colour;
				half4 c3 = UNITY_SAMPLE_TEX2D(_MainTex3, tex3UV) * _Tex3Colour;

				half3 nBase = UnpackNormal(UNITY_SAMPLE_TEX2D_SAMPLER(_BaseTexNormal, _BaseTex, baseUV));
				half3 n1 = UnpackNormal(UNITY_SAMPLE_TEX2D_SAMPLER(_Tex1Normal, _MainTex1, tex1UV));
				half3 n2 = UnpackNormal(UNITY_SAMPLE_TEX2D_SAMPLER(_Tex2Normal, _MainTex2, tex2UV));
				half3 n3 = UnpackNormal(UNITY_SAMPLE_TEX2D_SAMPLER(_Tex3Normal, _MainTex3, tex3UV));

				//update blend amounts with parallax-mapped UVs
				blendTex = tex2D(_BlendTex, uv).rgb;
				blendAmounts = getBlendAmounts(hBase, h1, h2, h3, blendTex, _HeightBlendFactor);

				o.Albedo = getColFromBlendAmounts(cBase, c1, c2, c3, blendAmounts);
				o.Normal = blendNormalMaps(nBase, n1, n2, n3, blendAmounts);
				//o.Smoothness = getColFromBlendAmounts(1 - hrmaBase.g, 1 - hrma1.g, 1 - hrma2.g, 1 - hrma3.g, blendAmounts);
				//o.Metallic = getColFromBlendAmounts(hrmaBase.b, hrma1.b, hrma2.b, hrma3.b, blendAmounts);
				//o.Occlusion = (getColFromBlendAmounts(hrmaBase.a, hrma1.a, hrma2.a, hrma3.a, blendAmounts) * _AOStrength) + (1 - _AOStrength);

				//silhouette clipping - clip uv positions <0 and >1
				#if defined(CLIP_SILHOUETTE)
					clip(uv);
					clip(1 - uv);
				#endif
			}

			ENDCG
		}
			FallBack "Diffuse"
			//CustomEditor "BlendTextures_Parallax_Shader_Editor"
}
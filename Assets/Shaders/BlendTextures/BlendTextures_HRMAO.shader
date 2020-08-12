//variant of heightmap-texture-blending shader that uses combined height/roughness/metallic/AO maps
//(r/g/b/a) to eliminate the need for using Texture2DArrays or whatever to get around sampler limits,
//and to reduce wasted texture channels
Shader "Custom/BlendTextures_HRMA"
{
	Properties
	{
		[Header(Colours)]
		_Tex1Colour("Texture 1 colour", Color) = (1,1,1,1)
		_Tex2Colour("Texture 2 colour", Color) = (1,1,1,1)
		_Tex3Colour("Texture 3 colour", Color) = (1,1,1,1)
		_Tex4Colour("Texture 4 colour", Color) = (1,1,1,1)

		[Header(Textures)]
		_BaseTex("Base texture", 2D) = "red" {}
		[Normal] _BaseTexNormal("Base texture normal map", 2D) = "white" {}
		_BaseTexHRMA("Base height/roughness/metalness/AO map", 2D) = "white" {}
		_MainTex1("Texture 1", 2D) = "green" {}
		[Normal] _Tex1Normal("Texture 1 normal map", 2D) = "white" {}
		_Tex1HRMA("Tex 1 height/roughness/metalness/AO map", 2D) = "white" {}
		_MainTex2("Texture 2", 2D) = "green" {}
		[Normal] _Tex2Normal("Texture 2 normal map", 2D) = "white" {}
		_Tex2HRMA ("Tex 2 height/roughness/metalness/AO map", 2D) = "white" {}
		_MainTex3("Texture 3", 2D) = "green" {}
		[Normal] _Tex3Normal("Texture 3 normal map", 2D) = "white" {}
		_Tex3HRMA("Tex 3 height/roughness/metalness/AO map", 2D) = "white" {}

		//[KeywordEnum(None, Add, Multiply)] _Overlay("Overlay mode", Float) = 0 //consider using KeywordEnum for more than on/off keywords
		//see https://docs.unity3d.com/ScriptReference/MaterialPropertyDrawer.html - Unity turns KeywordEnums into keyword names in this format: 
		//"property name" (including trailing underscore) + "_" + "enum name" (all names become ALLCAPS)

		//[Toggle(USE_VERTEX_COLOURS_FOR_BLEND_WEIGHTS)]
		[KeywordEnum(Texture, VertexColours)] _BlendSource("Source of blend weights", Float) = 0
		_BlendTex("Blend texture (Black = base tex, RGB = textures 1, 2 and 3", 2D) = "black" {}

		[Header(Blend parameters)]
		[PowerSlider(3)] _HeightBlendFactor("Blend smoothness", Range(0.01, 1)) = 0.5
		_BaseTexHeightMult("Base heightmap intensity", Float) = 1
		_H1Mult("Tex 1 heightmap intensity", Float) = 1
		_H2Mult("Tex 2 heightmap intensity", Float) = 1
		_H3Mult("Tex 3 heightmap intensity", Float) = 1

		[Header(Parallax mapping)]
		[KeywordEnum(Offset, IterativeOffset, Occlusion)] _PlxType("Parallax mapping method", Float) = 0
		[IntRange] _Iterations("Iterations", Range(0, 10)) = 2
		[PowerSlider(3)] _ParallaxAmt("Parallax amount", Range(0, 0.25)) = 0.1

		[Header(Surface properties)]
		/*
		_BaseMetallic("Base tex metallic", Range(0,1)) = 0.0
		_Tex1Metallic("Tex 1 metallic", Range(0,1)) = 0.0
		_Tex2Metallic("Tex 2 metallic", Range(0,1)) = 0.0
		_Tex3Metallic("Tex 3 metallic", Range(0,1)) = 0.0
		*/
		_AOStrength("AO strength", Range(0,1)) = 1.0

		//[Header(Weather effects)]
		//dropdown for selecting rain/snow etc. effects here?
	}
		SubShader
		{
			Tags { "RenderType" = "Opaque" }
			LOD 200

			CGPROGRAM
			#pragma surface surf Standard fullforwardshadows
			#pragma target 3.0 // Use shader model 3.0 target, to get nicer looking lighting
			#pragma shader_feature _ _BLENDSOURCE_VERTEXCOLOURS 
			#pragma shader_feature _PLXTYPE_OFFSET _PLXTYPE_ITERATIVEOFFSET _PLXTYPE_OCCLUSION 

			#include "blends.cginc"

			struct Input
			{
				float2 uv_BaseTex;
				float2 uv_BlendTex; //separate UV so blend tex doesn't tile with other textures
				float3 viewDir;
				half3 colour : COLOR;

			};

			sampler2D _BaseTex, _BaseTexNormal, _BaseTexHRMA;
			sampler2D _MainTex1, _Tex1Normal, _Tex1HRMA;
			sampler2D _MainTex2, _Tex2Normal, _Tex2HRMA;
			sampler2D _MainTex3, _Tex3Normal, _Tex3HRMA;

			float _BlendSource;
			sampler2D _BlendTex;
			float _HeightBlendFactor;
			float _BaseTexHeightMult, _H1Mult, _H2Mult, _H3Mult;

			/* parallax mapping */
			float _PlxType;
			float _Iterations;
			float _ParallaxAmt;

			float4 _Tex1Colour, _Tex2Colour, _Tex3Colour, _Tex4Colour;
			half _BaseMetallic, _Tex1Metallic, _Tex2Metallic, _Tex3Metallic;
			half _AOStrength;


			// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
			// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
			// #pragma instancing_options assumeuniformscaling
			UNITY_INSTANCING_BUFFER_START(Props)
				// put more per-instance properties here
			UNITY_INSTANCING_BUFFER_END(Props)

			//variant of Unity's ParallaxOffset function (from UnityCG.cginc) that implements offset limiting
			//by not dividing normalised viewDir.xy by viewDir.z, as per http://old.cescg.org/CESCG-2006/papers/TUBudapest-Premecz-Matyas.pdf
			float ParallaxOffsetLimited(half heightmapHeight, half parallaxHeight, half3 tangentViewDir)
			{
				heightmapHeight = heightmapHeight * parallaxHeight - parallaxHeight / 2.0;
				//v.z += 0.42;
				return heightmapHeight * tangentViewDir.xy; //normal ParallaxOffset is heightmapHeight * (viewDir.xy / viewDir.z);
			}

			/*
			void vert(inout appdata_full v, out Input o)
			{
				UNITY_INITIALIZE_OUTPUT(Input, o);
				float3 wNormal = UnityObjectToWorldNormal(v.normal);
				float3 wTangent = UnityObjectToWorldDir(v.tangent);
				float3 wBinormal = cross(wNormal, wTangent);
				o.tbn = floatx3(wTangent, wBinormal, wNormal);
			}
			*/

			//convenience function to get blended height with calculated blend amounts and specified UV coordinate (for iterative parallax/POM)
			float getBlendedHeightBlendAll(float2 uv, half3 blendAmounts)
			{
				float hBase = tex2D(_BaseTexHRMA, uv).r;
				float h1 = tex2D(_Tex1HRMA, uv).r;
				float h2 = tex2D(_Tex2HRMA, uv).r;
				float h3 = tex2D(_Tex3HRMA, uv).r;
				return getColFromBlendAmounts(hBase, h1, h2, h3, blendAmounts);
			}

			/*
			float2 parallaxOcclusionMapping(half heightmapHeight, float2 heightmapUV, half3 blendAmounts, out float parallaxHeight, float3 viewDir)
			{
				// determine optimal number of layers
				const float minLayers = 10;
				const float maxLayers = 15;
				float numLayers = lerp(maxLayers, minLayers, abs(dot(float3(0, 0, 1), viewDir))); //should this be (0, 1, 0)?

				float layerHeight = 1 / numLayers;
				float currLayerHeight = 0;
				// shift of texture coordinates for each layer
				float2 offsetPerLayer = parallaxHeight * viewDir.xy / viewDir.z / numLayers;

				float2 currUV = heightmapUV; //current texture coordinates

				float currHeightmapHeight = heightmapHeight;

				//while point is above the surface
				while (currHeightmapHeight > currLayerHeight)
				{
					currLayerHeight += layerHeight; //to the next layer
					currUV -= offsetPerLayer; //shift of texture coordinates
					currHeightmapHeight = getBlendedHeightBlendAll(currUV, blendAmounts); //new depth from heightmap
				}

				float2 prevUV = currUV + offsetPerLayer; //previous texture coordinates

				//heights for linear interpolation
				float nextH = currHeightmapHeight - currLayerHeight;
				float prevH = getBlendedHeightBlendAll(prevUV, blendAmounts) - currLayerHeight + layerHeight;

				float weight = nextH / (nextH - prevH); //proportions for linear interpolation
				float2 finalTexCoords = prevUV * weight + currUV * (1.0 - weight); //interpolation of texture coordinates
				parallaxHeight = currLayerHeight + prevH * weight + nextH * (1.0 - weight); //interpolation of depth values

				return finalTexCoords;
			}
			*/

			void surf(Input IN, inout SurfaceOutputStandard o)
			{
				float2 uv = IN.uv_BaseTex;

				//need to use the initial (non-parallax-offset) uv for the height; r/m/ao uses parallax uv
				float hBase = tex2D(_BaseTexHRMA, uv).r;
				float h1 = tex2D(_Tex1HRMA, uv).r * _H1Mult;
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

				/* parallax mapping */
				float blendedHeight = getColFromBlendAmounts(hBase, h1, h2, h3, blendAmounts);
				#if defined(_PLXTYPE_OFFSET)
					/*
					//convert world space view direction to tangent space
					float3 tangentViewDir = mul(IN.tbn, IN.viewDir);
					float2 offset = ParallaxOffsetLimited(blendedHeight, _ParallaxAmt, tangentViewDir);
					*/

					float2 offset = ParallaxOffset(blendedHeight, _ParallaxAmt, IN.viewDir);
					uv += offset;
				#elif defined(_PLXTYPE_ITERATIVEOFFSET) //iterated offset mapping (just do offset mapping _Iterations more times)
					for (int i = 0; i < _Iterations; i++)
					{
						blendedHeight = getBlendedHeightBlendAll(uv, blendAmounts);
						float2 offset = ParallaxOffset(blendedHeight, _ParallaxAmt, IN.viewDir);
						uv += offset;
					}
				#elif defined(_PLXTYPE_OCCLUSION)
					float parallaxHeight;
					//uv = parallaxOcclusionMapping(blendedHeight, uv, blendAmounts, parallaxHeight, IN.viewDir);
				#endif

				/* get other textures using parallax-mapped UVs */
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

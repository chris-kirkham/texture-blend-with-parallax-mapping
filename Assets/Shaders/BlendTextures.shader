Shader "Custom/BlendTextures"
{
    Properties
    {
        [Header(Colours)]
		_Tex1Colour ("Texture 1 colour", Color) = (1,1,1,1)
        _Tex2Colour ("Texture 2 colour", Color) = (1,1,1,1)
        _Tex3Colour ("Texture 3 colour", Color) = (1,1,1,1)
        _Tex4Colour ("Texture 4 colour", Color) = (1,1,1,1)
		
		[Header(Textures)]
        _BaseTex ("Base texture", 2D) = "red" {}
		_BaseTexHeight("Base texture heightmap", 2D) = "white" {}
		[Normal] _BaseTexNormal("Base texture normal map", 2D) = "white" {}
		//_BaseTexAO("Texture 1 AO map", 2D) = "white" {}
		_MainTex1("Texture 1", 2D) = "green" {}
		_Tex1Height("Texture 1 heightmap", 2D) = "black" {}
		[Normal] _Tex1Normal("Texture 1 normal map", 2D) = "white" {}
		//_Tex1AO("Texture 2 AO map", 2D) = "white" {}
		_MainTex2("Texture 2", 2D) = "green" {}
		_Tex2Height("Texture 2 heightmap", 2D) = "black" {}
		[Normal] _Tex2Normal("Texture 2 normal map", 2D) = "white" {}
		//_Tex2AO("Texture 3 AO map", 2D) = "white" {}
		_MainTex3("Texture 3", 2D) = "green" {}
		_Tex3Height("Texture 3 heightmap", 2D) = "black" {}
		[Normal] _Tex3Normal("Texture 3 normal map", 2D) = "white" {}
		//_Tex3AO("Texture 3 AO map", 2D) = "white" {}

		_BlendTex("Blend texture (Black = base tex, RGB = textures 1, 2 and 3", 2D) = "black" {}
		
		[Header(Blend parameters)]
		_HeightBlendFactor("Blend smoothness", Range(0.01, 1)) = 0.5
		_BaseTexHeightMult("Base heightmap intensity", Float) = 1
		_H1Mult("Tex 1 heightmap intensity", Float) = 1
		_H2Mult("Tex 2 heightmap intensity", Float) = 1
		_H3Mult("Tex 3 heightmap intensity", Float) = 1

		[Header(Parallax mapping)]
		_ParallaxAmt("Parallax amount", Float) = 0.1

		[Header(Surface properties)]
        _BaseMetallic ("Base tex metallic", Range(0,1)) = 0.0
        _Tex1Metallic ("Tex 1 metallic", Range(0,1)) = 0.0
        _Tex2Metallic ("Tex 2 metallic", Range(0,1)) = 0.0
        _Tex3Metallic ("Tex 3 metallic", Range(0,1)) = 0.0
		
		//[Header(Weather effects)]
		//dropdown for selecting rain/snow etc. effects here?
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows // Physically based Standard lighting model, and enable shadows on all light types
        #pragma target 3.0 // Use shader model 3.0 target, to get nicer looking lighting

		#include "blends.cginc"
        
		struct Input
        {
            float2 uv_BaseTex;
			float3 viewDir;
        };

		sampler2D _BaseTex, _BaseTexHeight, _BaseTexNormal;
		sampler2D _MainTex1, _Tex1Height, _Tex1Normal;
		sampler2D _MainTex2, _Tex2Height, _Tex2Normal;
		sampler2D _MainTex3, _Tex3Height, _Tex3Normal;
		
		sampler2D _BlendTex;
        float4 _Tex1Colour, _Tex2Colour, _Tex3Colour, _Tex4Colour;
		float _HeightBlendFactor;
		float _BaseTexHeightMult, _H1Mult, _H2Mult, _H3Mult;

		float _ParallaxAmt;

		half _BaseMetallic, _Tex1Metallic, _Tex2Metallic, _Tex3Metallic;


        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)


        float3 blendHeights(float3 in1, float height1, float3 in2, float height2, float blendFactor)
		{
			float height_start = max(height1, height2) - blendFactor; 
			float level1 = max(height1 - height_start, 0); 
			float level2 = max(height2 - height_start, 0);
			return ((in1 * level1) + (in2 * level2)) / (level1 + level2); //divide by total levels so result = 1
		}

		//blends two colours based on height. if the higher colour's height >= lower height + maxDiff, the result will be entirely the higher colour
		float3 blend(float3 c1, float h1, float3 c2, float h2, float maxDiff)
		{
			/*
			//return h1 > h1 ? lerp(c1, c1, min((h1 - h1) / maxDiff, 1)) : lerp(c1, c1, min((h1 - h1) / maxDiff, 1));
			float diff = min(abs(h1 - h1) / maxDiff, 1);
			if (h1 > h1)
			{
				return c1 + (c1 * diff)
			}
			*/
			return (((c1 * h1) + (c1 * h1)) / (h1 + h1)) * 2;
		}

		fixed3 blend2(half3 c1, float h1, half3 c2, float h2, half3 blend, float blendFactor)
		{
			float heightStart = max(h1, h1) - blendFactor;
			float level1 = max(h1 - heightStart, 0);
			float level2 = max(h1 - heightStart, 0);
			c1 *= blend.r * level1;
			c1 *= blend.g * level2;

			return ((c1 + c1) / ((blend.r * level1) + (blend.g * level2)));
		}

		void surf (Input IN, inout SurfaceOutputStandard o)
        {
			float2 uv = IN.uv_BaseTex;

			float hBase = tex2D(_BaseTexHeight, uv).r;
			float h1 = tex2D(_Tex1Height, uv).r;
			float h2 = tex2D(_Tex2Height, uv).r;
			float h3 = tex2D(_Tex3Height, uv).r;

			half3 blendTex = tex2D(_BlendTex, uv).rgb;

			//calculate blend amounts and store them in rgb values (base = 1 - (r + g + b)) so we don't have to calculate it for each
			//type of texture
			half3 blendAmounts = getBlendAmounts(hBase * _BaseTexHeightMult, h1 * _H1Mult, h2 * _H2Mult, h3 * _H3Mult, blendTex, _HeightBlendFactor);

			//parallax mapping
			//float blendedHeight = blend4(hBase, hBase * _BaseTexHeightMult, h1, h1 * _H1Mult, h2, h2 * _H2Mult, h3, h3 * _H3Mult, blendTex, _HeightBlendFactor);
			float blendedHeight = getColFromBlendAmounts(hBase, h1, h2, h3, blendAmounts);
			float2 offset = ParallaxOffset(blendedHeight, _ParallaxAmt, IN.viewDir);
			uv += offset;

			half4 cBase = tex2D (_BaseTex, uv) * _Tex1Colour;
			half4 c1 = tex2D (_MainTex1, uv) * _Tex2Colour;
			half4 c2 = tex2D (_MainTex2, uv) * _Tex3Colour;
			half4 c3 = tex2D (_MainTex3, uv) * _Tex4Colour;
			
			half3 nBase = UnpackNormal(tex2D(_BaseTexNormal, uv));
			half3 n1 = UnpackNormal(tex2D(_Tex1Normal, uv));
			half3 n2 = UnpackNormal(tex2D(_Tex2Normal, uv));
			half3 n3 = UnpackNormal(tex2D(_Tex3Normal, uv));

			/*
			half3 aoBase = tex2D(_BaseTexAO, uv);
			half3 ao1 = tex2D(_Tex1AO, uv);
			half3 ao2 = tex2D(_Tex2AO, uv);
			half3 ao3 = tex2D(_Tex3AO, uv);
			*/

			//o.Albedo = blendAmounts;
			o.Albedo = getColFromBlendAmounts(cBase, c1, c2, c3, blendAmounts);
			o.Normal = getColFromBlendAmounts(nBase, n1, n2, n3, blendAmounts);
			o.Smoothness = getColFromBlendAmounts(_BaseMetallic, _Tex1Metallic, _Tex2Metallic, _Tex3Metallic, blendAmounts);
			//o.Occlusion = getColFromBlendAmounts(aoBase, ao1, ao2, ao3, blendAmounts);

			//TEST: "rain"
			/*
			float rainHeight = _BaseMetallic;
			float3 rain = float3(0, 0.5f, 0.5f);
			o.Albedo = blendHeights(o.Albedo, blendedHeight, rain, rainHeight, 0.01);
			o.Normal = blendHeights(o.Normal, blendedHeight, half3(1,1,1), rainHeight, 0.01);
			*/

            //o.Smoothness = _Glossiness;
        }
        ENDCG
    }
    FallBack "Diffuse"
}

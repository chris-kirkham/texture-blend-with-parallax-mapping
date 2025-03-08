Shader "Custom/TriplanarMappingBlend"
{
    Properties
    {
        [Header(Textures)]
        _XTex ("X Albedo (RGB)", 2D) = "red" {}
		[Normal] _XNormal("X normal", 2D) = "bump" {}
		_XHeight("X height", 2D) = "white" {}
		_YTex ("Y Albedo (RGB)", 2D) = "green" {}
		[Normal] _YNormal("Y normal", 2D) = "bump" {}
		_YHeight("Y height", 2D) = "white" {}
		_ZTex ("Z Albedo (RGB)", 2D) = "blue" {}
		[Normal] _ZNormal("Z normal", 2D) = "bump" {}
		_ZHeight("Z height", 2D) = "white" {}

		[Header(Texture properties)]
		_XScale("X texture scale", Float) = 1
		_XColour("X Color", Color) = (1,1,1,1)
		_XGlossiness("X Smoothness", Range(0,1)) = 0.5
		_XMetallic("X Metallic", Range(0,1)) = 0.0
		_YScale("Y texture scale", Float) = 1
		_YColour("Y Color", Color) = (1,1,1,1)
		_YGlossiness("Y Smoothness", Range(0,1)) = 0.5
		_YMetallic("Y Metallic", Range(0,1)) = 0.0
		_ZScale("Z texture scale", Float) = 1
		_ZColour("Z Color", Color) = (1,1,1,1)
        _ZGlossiness ("Z Smoothness", Range(0,1)) = 0.5
        _ZMetallic ("Z Metallic", Range(0,1)) = 0.0

		[Header(Blend parameters)]
		_TriplanarBlendSharpness("Triplanar blend sharpness (exponent)", Range(1, 64)) = 1
		_HeightBlendFactor("Heightmap blend smoothness", Range(0.01, 1)) = 0.5
		_HXMult("X texture heightmap intensity", Float) = 1
		_HYMult("Y texture heightmap intensity", Float) = 1
		_HZMult("Z texture heightmap intensity", Float) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows vertex:vert

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        struct Input
        {
			float3 localPos;
			float3 localNormal;
			float3 worldPos;
			float3 worldNormal;
			float3 viewDir;
			INTERNAL_DATA
		};

		sampler2D _XTex, _YTex, _ZTex;
		sampler2D _XNormal, _YNormal, _ZNormal;
		sampler2D _XHeight, _YHeight, _ZHeight;

		half _XScale, _YScale, _ZScale;
        half _XGlossiness, _YGlossiness, _ZGlossiness;
        half _XMetallic, _YMetallic, _ZMetallic;
        fixed4 _XColour, _YColour, _ZColour;

		float _TriplanarBlendSharpness, _HeightBlendFactor;
		float _HXMult, _HYMult, _HZMult;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

		half3 blend(half3 cX, float hX, half3 cY, float hY, half3 c2, float hZ, half3 blend, float blendFactor)
		{
			float heightStart = max(max(hX * blend.r, hY * blend.g), hZ * blend.b) - blendFactor;

			hX = max(hX - heightStart, 0);
			hY = max(hY - heightStart, 0);
			hZ = max(hZ - heightStart, 0);

			cX *= blend.r * hX;
			cY *= blend.g * hY;
			c2 *= blend.b * hZ;

			return (cX + cY + c2) / ((blend.r * hX) + (blend.g * hY) + (blend.b * hZ));
		}

		void vert(inout appdata_full v, out Input input)
		{
			UNITY_INITIALIZE_OUTPUT(Input, input);
			input.localPos = v.vertex.xyz;
			input.localNormal = v.normal.xyz;
		}

		//triplanar normal mapping: https://medium.com/@bgolus/normal-mapping-for-a-triplanar-shader-10bf39dca05a#d715
        void surf (Input IN, inout SurfaceOutputStandard o)
        {
			float2 uvX = IN.worldPos.yz / _XScale;
			float2 uvY = IN.worldPos.zx / _YScale;
			float2 uvZ = IN.worldPos.xy / _ZScale;

			fixed hX = tex2D(_XHeight, uvX).r * _HXMult;
			fixed hY = tex2D(_YHeight, uvY).r * _HYMult;
			fixed hZ = tex2D(_ZHeight, uvZ).r * _HZMult;
			
			//weights for each triplanar axis
			half3 weights = pow(abs(WorldNormalVector(IN, o.Normal)), _TriplanarBlendSharpness);
			weights /= (weights.x + weights.y + weights.z); //make (weights.x + .y + .z) = 1

			half3 cX = tex2D (_XTex, uvX) * _XColour;
            half3 cY = tex2D (_YTex, uvY) * _YColour;
            half3 cZ = tex2D (_ZTex, uvZ) * _ZColour;
			
			half3 nX = UnpackNormal(tex2D(_XNormal, uvX));
			half3 nY = UnpackNormal(tex2D(_YNormal, uvY));
			half3 nZ = UnpackNormal(tex2D(_ZNormal, uvZ));

			//o.Albedo = blend(cX, hX, cY, hY, cZ, hZ, weights, _HeightBlendFactor);
			o.Albedo = nX;
			//o.Normal = blend(nX, hX, nY, hY, nZ, hZ, weights, _HeightBlendFactor);
			o.Normal = nX;
			//o.Albedo = cos(weights * _Time.y);
			//o.Albedo = weights;
        }
        ENDCG
    }
    FallBack "Diffuse"
}

Shader "Custom/S_Standard_HRMA"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        [Normal] _Normal ("Normal", 2D) = "black" {}
        _HRMA ("HRMA (height, roughness, metallic, AO)", 2D) = "black"
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        fixed4 _Color;
        sampler2D _MainTex;
        sampler2D _Normal;
        sampler2D _HRMA;

        struct Input
        {
            float2 uv_MainTex;
        };


        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
            fixed3 normal = UnpackNormal(tex2D(_Normal, IN.uv_MainTex));
            half4 hrma = tex2D(_HRMA, IN.uv_MainTex);
            
            o.Albedo = c.rgb;
            o.Metallic = hrma.b;
            o.Smoothness = 1 - hrma.g;
            o.Occlusion = hrma.a;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}

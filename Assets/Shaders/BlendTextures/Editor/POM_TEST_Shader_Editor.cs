using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

/// <summary>
/// Custom inspector GUI for parallax texture blend shader. Based on unity's standard shader GUI
/// (https://github.com/TwoTailsGames/Unity-Built-in-Shaders/blob/master/Editor/StandardShaderGUI.cs)
/// </summary>
internal class POM_TEST_Shader_Editor : ShaderGUI
{
    MaterialEditor materialEditor;
    MaterialProperty[] materialProperties;

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] materialProperties)
    {
        this.materialEditor = materialEditor;
        this.materialProperties = materialProperties;
        DoTexMaps();
        EditorGUILayout.Space();
        DoBlendParams();
        EditorGUILayout.Space();
        DoParallaxParams();
        EditorGUILayout.Space();
        DoSurfaceProperties();
    }

    private void DoTexMaps()
    {
        GUILayout.Label("Texture maps", EditorStyles.boldLabel);

        /* get relevant material properties */
        //texture colours
        MaterialProperty baseTexColour = FindProperty("_BaseTexColour");
        MaterialProperty tex1Colour = FindProperty("_Tex1Colour");
        MaterialProperty tex2Colour = FindProperty("_Tex2Colour");
        MaterialProperty tex3Colour = FindProperty("_Tex3Colour");

        //base tex maps
        MaterialProperty baseAlbedo = FindProperty("_BaseTex");
        MaterialProperty baseNormal = FindProperty("_BaseTexNormal");
        MaterialProperty baseHRMA = FindProperty("_BaseTexHRMA");

        //tex 1 maps
        MaterialProperty tex1Albedo = FindProperty("_MainTex1");
        MaterialProperty tex1Normal = FindProperty("_Tex1Normal");
        MaterialProperty tex1HRMA = FindProperty("_Tex1HRMA");

        //tex 2 maps
        MaterialProperty tex2Albedo = FindProperty("_MainTex2");
        MaterialProperty tex2Normal = FindProperty("_Tex2Normal");
        MaterialProperty tex2HRMA = FindProperty("_Tex2HRMA");

        //tex 3 maps
        MaterialProperty tex3Albedo = FindProperty("_MainTex3");
        MaterialProperty tex3Normal = FindProperty("_Tex3Normal");
        MaterialProperty tex3HRMA = FindProperty("_Tex3HRMA");

        //blend map
        MaterialProperty blendTex = FindProperty("_BlendTex");

        //heightmap parameters
        MaterialProperty baseHeightIntensity = FindProperty("_BaseTexHeightMult");
        MaterialProperty tex1HeightIntensity = FindProperty("_H1Mult");
        MaterialProperty tex2HeightIntensity = FindProperty("_H2Mult");
        MaterialProperty tex3HeightIntensity = FindProperty("_H3Mult");

        MaterialProperty baseHeightOffset = FindProperty("_BaseHeightOffset");
        MaterialProperty tex1HeightOffset = FindProperty("_H1Offset");
        MaterialProperty tex2HeightOffset = FindProperty("_H2Offset");
        MaterialProperty tex3HeightOffset = FindProperty("_H3Offset");

        /* set GUI content */
        GUIContent baseAlbedoLabel = new GUIContent(baseAlbedo.displayName, "Base albedo");
        GUIContent baseNormalLabel = new GUIContent(baseNormal.displayName, "Base normal");
        GUIContent baseHRMALabel = new GUIContent(baseHRMA.displayName, "Base HRMA (height, roughness, metallic, AO)");

        GUIContent tex1AlbedoLabel = new GUIContent(tex1Albedo.displayName, "Tex 1 albedo");
        GUIContent tex1NormalLabel = new GUIContent(tex1Normal.displayName, "Tex 1 normal");
        GUIContent tex1HRMALabel = new GUIContent(tex1HRMA.displayName, "Tex 1 HRMA (height, roughness, metallic, AO)");

        GUIContent tex2AlbedoLabel = new GUIContent(tex2Albedo.displayName, "Tex 2 albedo");
        GUIContent tex2NormalLabel = new GUIContent(tex2Normal.displayName, "Tex 2 normal");
        GUIContent tex2HRMALabel = new GUIContent(tex2HRMA.displayName, "Tex 2 HRMA (height, roughness, metallic, AO)");

        GUIContent tex3AlbedoLabel = new GUIContent(tex3Albedo.displayName, "Tex 3 albedo");
        GUIContent tex3NormalLabel = new GUIContent(tex3Normal.displayName, "Tex 3 normal");
        GUIContent tex3HRMALabel = new GUIContent(tex3HRMA.displayName, "Tex 3 HRMA (height, roughness, metallic, AO)");

        GUIContent blendTexLabel = new GUIContent(blendTex.displayName, "Blend map (Black = base tex, RGB = textures 1, 2 and 3)");

        GUIContent heightIntensityLabel = new GUIContent("Increase intensity");
        GUIContent heightOffsetLabel = new GUIContent("Height offset");

        //base tex
        //materialEditor.TexturePropertySingleLine(baseAlbedoLabel, baseAlbedo, baseTexColour);
        materialEditor.TexturePropertySingleLine(baseAlbedoLabel, baseAlbedo);
        materialEditor.TexturePropertySingleLine(baseNormalLabel, baseNormal);
        materialEditor.TexturePropertySingleLine(baseHRMALabel, baseHRMA);

        //base heightmap params
        EditorGUI.indentLevel += 2;
        materialEditor.ShaderProperty(baseHeightIntensity, heightIntensityLabel);
        materialEditor.ShaderProperty(baseHeightOffset, heightOffsetLabel);
        EditorGUI.indentLevel -= 2;

        //tex 1
        materialEditor.TexturePropertySingleLine(tex1AlbedoLabel, tex1Albedo);
        materialEditor.TexturePropertySingleLine(tex1NormalLabel, tex1Normal);
        materialEditor.TexturePropertySingleLine(tex1HRMALabel, tex1HRMA);
        
        //tex 1 heightmap params
        EditorGUI.indentLevel += 2;
        materialEditor.ShaderProperty(tex1HeightIntensity, heightIntensityLabel);
        materialEditor.ShaderProperty(tex1HeightOffset, heightOffsetLabel);
        EditorGUI.indentLevel -= 2;

        //tex 2
        materialEditor.TexturePropertySingleLine(tex2AlbedoLabel, tex2Albedo);
        materialEditor.TexturePropertySingleLine(tex2NormalLabel, tex2Normal);
        materialEditor.TexturePropertySingleLine(tex2HRMALabel, tex2HRMA);
        
        //tex 2 heightmap params
        EditorGUI.indentLevel += 2;
        materialEditor.ShaderProperty(tex2HeightIntensity, heightIntensityLabel);
        materialEditor.ShaderProperty(tex2HeightOffset, heightOffsetLabel);
        EditorGUI.indentLevel -= 2;

        //tex 3
        materialEditor.TexturePropertySingleLine(tex3AlbedoLabel, tex3Albedo);
        materialEditor.TexturePropertySingleLine(tex3NormalLabel, tex3Normal);
        materialEditor.TexturePropertySingleLine(tex3HRMALabel, tex3HRMA);
        
        //tex 3 heightmap params
        EditorGUI.indentLevel += 2;
        materialEditor.ShaderProperty(tex3HeightIntensity, heightIntensityLabel);
        materialEditor.ShaderProperty(tex3HeightOffset, heightOffsetLabel);
        EditorGUI.indentLevel -= 2;

        //blend map
        materialEditor.TexturePropertySingleLine(blendTexLabel, blendTex);
    }

    private void DoBlendParams()
    {
        GUILayout.Label("Texture blend parameters", EditorStyles.boldLabel);

        MaterialProperty blendSmoothness = FindProperty("_HeightBlendFactor");
        MaterialProperty blendMode = FindProperty("_HeightBlendMode");

        materialEditor.ShaderProperty(blendSmoothness, new GUIContent("Blend smoothness"));
        materialEditor.ShaderProperty(blendMode, new GUIContent("Blend mode"));
    }

    private void DoParallaxParams()
    {
        GUILayout.Label("Parallax parameters", EditorStyles.boldLabel);

        MaterialProperty parallaxType = FindProperty("_PlxType");
        MaterialProperty parallaxAmount = FindProperty("_ParallaxAmt");
        MaterialProperty iterativeParallaxNumIterations = FindProperty("_Iterations");
        MaterialProperty pomMinSamples = FindProperty("_OcclusionMinSamples");
        MaterialProperty pomMaxSamples = FindProperty("_OcclusionMaxSamples");

        materialEditor.ShaderProperty(parallaxType, new GUIContent("Parallax type"));
        materialEditor.ShaderProperty(parallaxAmount, new GUIContent("Parallax amount"));
        if(parallaxType.floatValue == 1) //if using iterative  
        {
            materialEditor.ShaderProperty(iterativeParallaxNumIterations, new GUIContent("Iterations"));
        }
        else if(parallaxType.floatValue == 2) //if using POM
        {
            materialEditor.ShaderProperty(pomMinSamples, new GUIContent("Min samples"));
            materialEditor.ShaderProperty(pomMaxSamples, new GUIContent("Max samples"));
        }
    }

    private void DoSurfaceProperties()
    {
        GUILayout.Label("Surface properties", EditorStyles.boldLabel);
        MaterialProperty aoStrength = FindProperty("_AOStrength");
        materialEditor.ShaderProperty(aoStrength, new GUIContent("AO strength"));
    }

    //convenience method to find a property using this material's MaterialProperties (stored as a member variable)
    private MaterialProperty FindProperty(string propertyName)
    {
        return FindProperty(propertyName, materialProperties);
    }
}


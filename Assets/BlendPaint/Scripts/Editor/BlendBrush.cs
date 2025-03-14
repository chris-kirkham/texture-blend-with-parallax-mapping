﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System;

namespace BlendPaint
{
    /// <summary>
    /// ScriptableObject to hold/change brush properties
    /// Adapted from https://codeartist.mx/dynamic-texture-painting/
    /// </summary>
    [CreateAssetMenu(fileName = "BlendPaintBrush", menuName = "ScriptableObjects/BlendPaint/BlendPaintBrush")]
    public class BlendBrush : ScriptableObject
    {
        public Texture2D BrushTex { get; private set; }
        private Texture2D brushTexCopy; //use a copy of the brush texture when changing its colour to avoid overriding the original 

        public Color ActiveCol { get; private set; } = Color.black;

        public int Size { get; private set; } = 32;
        public int HalfSize { get; private set; }

        public float Strength { get; private set; } = 1;

        public BrushMode Mode { get; private set; } = BrushMode.Normal;

        public void LoadDefaultBrush()
        {
            BrushTex = AssetDatabase.LoadAssetAtPath<Texture2D>("Assets/BlendPaint/Brushes/Textures/Circle_Soft.png");
            brushTexCopy = BrushTex;
            if (BrushTex == null)
            {
                Debug.LogError("BlendPaint: default brush sprite" +
                 " Assets/BlendPaint/Brushes/Textures/Circle_Soft.png not found. Did you delete, move or rename it?");
            }
            if (BrushTex != brushTexCopy) Graphics.CopyTexture(BrushTex, brushTexCopy);
        }

        public void SetBrushTex(Texture2D tex)
        {
            BrushTex = tex;
            if (BrushTex != brushTexCopy) Graphics.CopyTexture(BrushTex, brushTexCopy);
        }

        public void SetBrushSize(int size)
        {
            if (size < 1)
            {
                Size = 1;
                HalfSize = 1;
            }
            else
            {
                Size = size;
                HalfSize = size / 2;
            }
        }

        //sets the brush colour for the copy of the brush texture 
        public void SetBrushColour(Color c)
        {
            ActiveCol = c;

            Color[] pixels = brushTexCopy.GetPixels();
            for (int i = 0; i < pixels.Length; i++)
            {
                pixels[i] = new Color(c.r, c.g, c.b, pixels[i].a); //use brush alpha to preserve softness
            }

            brushTexCopy.SetPixels(pixels);
            brushTexCopy.Apply();
        }

        public void SetBrushStrength(float strength)
        {
            strength = Mathf.Clamp01(strength);
            Strength = strength;
        }

        public void SetBrushMode(BrushMode mode)
        {
            Mode = mode;
        }
    }
}
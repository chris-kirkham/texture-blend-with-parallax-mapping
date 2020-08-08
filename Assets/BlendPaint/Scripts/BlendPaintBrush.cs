using System.Collections;
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
    public class BlendPaintBrush : ScriptableObject
    {
        public Texture2D BrushTex { get; private set; }
        private Texture2D brushTexCopy; //use a copy of the brush texture when changing its colour to avoid overriding the original 

        public Color ActiveCol { get; private set; } = Color.black;

        public int BrushSize { get; private set; } = 32;
        public int HalfBrushSize { get; private set; }

        public float BrushStrength { get; private set; } = 1;

        //[SerializeField] public int BrushSize { get; private set; }
        //[SerializeField] public int HalfBrushSize { get; private set; }

        //Calling the Resources.Load operations from BlendPaintUI's OnEnable() via this function stops it complaining about serialization,
        //but the serialization still doesn't work
        public void LoadBrush()
        {
            BrushTex = Resources.Load<Texture2D>("BlendPaint/Brushes/Textures/Circle_Soft");
            brushTexCopy = BrushTex;
            if (BrushTex == null)
            {
                Debug.LogError("BlendPaint: default brush sprite" +
                 " Assets/Resources/BlendPaint/Brushes/Circle_Soft not found. Did you delete, move or rename it?");
            }
            if (BrushTex != brushTexCopy) Graphics.CopyTexture(BrushTex, brushTexCopy);
        }

        /*
        public void DrawOnTex(Vector2 uvPos, Texture2D tex)
        {
            Vector2Int brushCentreTexel = new Vector2Int(Mathf.FloorToInt(uvPos.x * tex.width), Mathf.FloorToInt(uvPos.y * tex.height));

            for(int x = brushCentreTexel.x - HalfBrushSize; x <= brushCentreTexel.x + HalfBrushSize; x++)
            {
                for (int y = brushCentreTexel.y - HalfBrushSize; y <= brushCentreTexel.y + HalfBrushSize; y++)
                {
                    Color brushCol = brushTex.GetPixel(x, y);
                    Color col = Color.Lerp(tex.GetPixel(x, y), brushCol, brushCol.a);
                    tex.SetPixel(x, y, col);
                }
            }
        }
        */

        public void SetBrushTex(Texture2D tex)
        {
            BrushTex = tex;
            if (BrushTex != brushTexCopy) Graphics.CopyTexture(BrushTex, brushTexCopy);
        }

        public void SetBrushSize(int size)
        {
            if (size < 1)
            {
                BrushSize = 1;
                HalfBrushSize = 1;
            }
            else
            {
                BrushSize = size;
                HalfBrushSize = size / 2;
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
            BrushStrength = strength;
        }
    }
}
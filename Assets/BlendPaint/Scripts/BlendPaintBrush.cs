using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

/// <summary>
/// 
/// Adapted from https://codeartist.mx/dynamic-texture-painting/
/// </summary>
[ExecuteInEditMode]
public class BlendPaintBrush
{
    private BlendPaintCanvas canvas;
    private RenderTexture blendTex; //texture on which to paint r/g/b blend weights

    //Brush
    public GameObject BrushObj { get; private set; }
    public Texture2D brushTex;
    public Texture2D brushTexCopy; //use a copy of the brush texture when changing its colour to avoid overriding the original 
    public Color32 activeCol = Color.black;
    public int brushSize;
    public int halfBrushSize;

    public int BrushSize { get; private set; }
    public int HalfBrushSize { get; private set; }

    private GameObject selection; //only paint on selected object

    private Vector2 uvPos;
    private bool uvPosValid;

    public BlendPaintBrush()
    {
        BrushObj = Resources.Load<GameObject>("BlendPaint/Brushes/DefaultBrushObj");
        if (BrushObj == null)
        {
            Debug.LogError("BlendPaint: default brush GameObject" +
             " Assets/Resources/BlendPaint/Brushes/DefaultBrushObj not found. Did you delete, move or rename it?");
        }

        brushTex = Resources.Load<Texture2D>("BlendPaint/Brushes/Circle_Soft");
        brushTexCopy = brushTex;
        if (brushTex == null)
        {
            Debug.LogError("BlendPaint: default brush sprite" +
             " Assets/Resources/BlendPaint/Brushes/Circle_Soft not found. Did you delete, move or rename it?");
        }
        Graphics.CopyTexture(brushTex, brushTexCopy);

        uvPos = Vector2.zero;
        uvPosValid = false;
    }

    /*
    //Sets current UV coordinate (to paint on) from given ray
    void SetUVPos(Ray worldSpaceRay)
    {
        RaycastHit hit;
        if(Physics.Raycast(worldSpaceRay, out hit))
        {
            Renderer r = hit.transform.GetComponent<Renderer>();
            //Collider c = hit.collider;

            if (r != null)
            {
                uvPos = hit.textureCoord;
                uvPosValid = true;
            }
        }

        uvPosValid = false;
    }
    */
    
    /*
    void DrawOnTex(Vector2 uvPos)
    {
        RenderTexture.active = blendTex;
        GL.PushMatrix();
            GL.LoadPixelMatrix(0, blendTex.width, blendTex.height, 0);
            Graphics.DrawTexture(new Rect(uvPos.x - halfBrushSize, uvPos.y - halfBrushSize, brushSize, brushSize), brush);
        GL.PopMatrix();
        RenderTexture.active = null;
    }
    */

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

    /*
    public void SetBrushTexture(Texture2D brushTex)
    {
        brushObj.GetComponent<SpriteRenderer>().sprite = brushTex;
    }
    */

    public void SetBrushSize(int brushSize)
    {
        this.BrushSize = brushSize;
        HalfBrushSize = brushSize / 2;
    }

    //sets the brush colour for the copy of the brush texture 
    public void SetBrushColour(Color c)
    {
        Color[] pixels = brushTexCopy.GetPixels();
        for (int i = 0; i < pixels.Length; i++)
        {
            pixels[i] = new Color(c.r, c.g, c.b, pixels[i].a); //use brush alpha to preserve softness
        }

        brushTexCopy.SetPixels(pixels);
        brushTexCopy.Apply();
    }
}

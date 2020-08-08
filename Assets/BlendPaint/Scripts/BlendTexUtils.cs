using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

namespace BlendPaint
{
    public class BlendTexUtils
    {
        public Texture2D CreateTex(int width, int height)
        {
            Texture2D tex = new Texture2D(width, height);
            
            //initialise with black?
            for(int x = 0; x < width; x++)
            {
                for(int y = 0; y < height; y++)
                {
                    tex.SetPixel(x, y, Color.black);
                }
            }

            return tex;
        }

        public void SaveTexToFile(Texture2D tex, string filePath, string fileName)
        {
            if (!System.IO.Directory.Exists(filePath))
            {
                Debug.LogError("Save directory " + filePath + " doesn't exist! Texture will not be saved");
            }
            else
            {
                System.IO.File.WriteAllBytes(filePath + "/" + fileName, tex.EncodeToPNG());
                Debug.Log("Texture saved: " + filePath + "/" + fileName);
                AssetDatabase.Refresh(); //if saving to the asset folder, need to scan for modified assets
            }
        }
    }
}
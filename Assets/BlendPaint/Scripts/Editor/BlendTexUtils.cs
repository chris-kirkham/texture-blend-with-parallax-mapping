using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

namespace BlendPaint
{
    public class BlendTexUtils
    {
        //Creates a new black texture with appropriate import settings for a paintable blend texture,
        //and saves it to the given file path. Returns the full asset path of the texture
        public string CreateAndSaveNewBlendTex(int width, int height, string directory, string fileName)
        {
            //Make full asset path from file path and filename
            string assetPath = directory + "/" + fileName;

            //Create texture
            Texture2D tex = new Texture2D(width, height);

            //initialise with black
            for (int x = 0; x < width; x++)
            {
                for (int y = 0; y < height; y++)
                {
                    tex.SetPixel(x, y, Color.black);
                }
            }

            SaveTexToFile(tex, directory, fileName);

            //Need to import texture from assets in order to change its import settings
            TextureImporter texImporter = (TextureImporter)TextureImporter.GetAtPath(assetPath);
            texImporter.isReadable = true;
            texImporter.wrapMode = TextureWrapMode.Clamp;
            texImporter.textureCompression = TextureImporterCompression.Uncompressed; //Texture2D.SetPixel gives an "unsupported format" error if used on a compressed texture
            //texImporter.textureFormat = TextureImporterFormat.RGBA32; //setting texture format to this also resolves SetPixel error, but is deprecated

            AssetDatabase.ImportAsset(assetPath);
            AssetDatabase.Refresh();

            return assetPath;
        }

        public void SaveTexToFile(Texture2D tex, string directory, string fileName)
        {
            if (!System.IO.Directory.Exists(directory))
            {
                Debug.LogError("Save directory " + directory + " doesn't exist! Texture will not be saved");
            }
            else
            {
                System.IO.File.WriteAllBytes(directory + "/" + fileName, tex.EncodeToPNG());
                Debug.Log("Texture saved: " + directory + "/" + fileName);
                AssetDatabase.Refresh(); //if saving to the asset folder, need to scan for modified assets
            }
        }
    }
}
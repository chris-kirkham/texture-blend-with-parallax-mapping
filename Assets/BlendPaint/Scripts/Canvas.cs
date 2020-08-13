using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace BlendPaint
{
    /// <summary>
    /// Handles creation, updating and saving of textures for BlendPaint. 
    /// Attached to the "Canvas" prefab, an instance of which is initialised when the blend paint UI is opened.
    /// The canvas is destroyed on UI close, but the painted blend texture is saved to disk.
    /// Adapted from https://codeartist.mx/dynamic-texture-painting/
    /// </summary>
    [ExecuteInEditMode]
    public class Canvas : MonoBehaviour
    {
        private Camera canvasCam;
        private RenderTexture renderTex;
        //string fullFilePath = System.IO.Directory.GetCurrentDirectory();

        //selected object; should never be null, as this script (and the canvas it's attached to)
        //should only be created when a blend-paintable object is selected
        public GameObject selection;

        List<GameObject> instantiatedBrushes; //holds sprites before merging
        int spriteCount = 0;
        const int spriteLimit = 1000; //maximum number of sprites that can be instantiated before being merged into the texture

        private void OnEnable()
        {
            canvasCam = GetComponent<Camera>();
        }

        public void TryGetBlendTex()
        {
            //attempt to get existing blend texture from selection; create new (black) blend texture if not found
            Texture2D blendTex = (Texture2D)selection.GetComponent<Renderer>().material.GetTexture("_BlendTex");
            if (blendTex == null)
            {
                Debug.Log("Selection " + selection.ToString() + " has no blend texture; creating empty one");
                blendTex = new Texture2D(1024, 1024); //TODO: allow user to choose size and/or get size from selection's main texture

                //initialise new blend texture pixels to black
                Color[] pixels = blendTex.GetPixels();
                for (int i = 0; i < pixels.Length; i++) pixels[i] = Color.black;
                blendTex.SetPixels(pixels);
                blendTex.Apply();
            }
        }

        public void AddPaintSprite(GameObject brush, Vector2 uvPos, float brushSize)
        {
            //instantiatedSprites.Add(Instantiate(Sprite.Create(sprite, new Rect(uvPos, new Vector2(brushSize, brushSize)), Vector2.zero)));
            brush.transform.localPosition = UVToLocal(uvPos);
            brush.transform.localScale = Vector3.one * brushSize;
            instantiatedBrushes.Add(Instantiate(brush, transform)); //instantiate brush as child of canvas

            spriteCount++;
            Debug.Log("sprite count = " + spriteCount);

            if (spriteCount > spriteLimit) MergePaintSprites();
        }

        private Vector3 UVToLocal(Vector2 uvPos)
        {
            return new Vector3(uvPos.x - canvasCam.orthographicSize, uvPos.y - canvasCam.orthographicSize, 0f);
        }

        private void MergePaintSprites()
        {
            RenderTexture.active = renderTex;

            int w = renderTex.width;
            int h = renderTex.height;
            Texture2D tex = new Texture2D(w, h, TextureFormat.RGB24, false);
            tex.ReadPixels(new Rect(0, 0, w, h), 0, 0);
            tex.Apply();

            RenderTexture.active = null;

            //destroy instantiated brushes now they've been merged; reset sprite counter
            foreach (GameObject s in instantiatedBrushes) Destroy(s);
            spriteCount = 0;
        }

        /*
        //Saves texture to file using given fullFilePath and fileName. Called as a coroutine so we can save in background during editing 
        IEnumerator SaveTexToFile(Texture2D tex, string fileName, string fullFilePath)
        {
            if(!System.IO.Directory.Exists(fullFilePath))
            {
                Debug.LogError("Save directory " + fullFilePath + " doesn't exist! Texture painting will not be saved");
                yield return null;
            }

            System.IO.File.WriteAllBytes(fullFilePath + fileName, tex.EncodeToPNG());
            yield return null;
        }
        */

        //Saves texture to file using given fullFilePath and fileName.
        public void SaveTexToFile(Texture2D tex, string fileName, string fullFilePath)
        {
            if (!System.IO.Directory.Exists(fullFilePath))
            {
                Debug.LogError("Save directory " + fullFilePath + " doesn't exist! Texture painting will not be saved");
            }
            else
            {
                System.IO.File.WriteAllBytes(fullFilePath + fileName, tex.EncodeToPNG());
            }
        }

        public void SetSelection(GameObject selection)
        {
            this.selection = selection;
        }
    }
}
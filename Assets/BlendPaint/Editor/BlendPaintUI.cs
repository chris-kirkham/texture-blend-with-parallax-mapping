using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System;
using System.IO;
using Unity.Jobs;

namespace BlendPaint
{
    public class BlendPaintUI : EditorWindow
    {
        private BlendPaintBrush brush;
        private GameObject selection; //selected object
        private Material selectionMaterial;
        private BlendTexUtils texUtils = new BlendTexUtils();

        private enum BrushMode { Normal, Add };
        private BrushMode brushMode = BrushMode.Normal;

        ComputeShader drawOnTexCompute;
        int drawOnTexKernelHandle;

        /* GUI LAYOUT PARAMETERS */
        private readonly GUILayoutOption[] textureButtonParams = new GUILayoutOption[]
{
        GUILayout.MinWidth(64),
        GUILayout.MinWidth(64),
        GUILayout.MaxWidth(128),
        GUILayout.MaxHeight(128),
        GUILayout.ExpandWidth(false)
};

        private readonly GUILayoutOption[] brushTexObjectFieldParams = new GUILayoutOption[]
        {
        GUILayout.MinWidth(32),
        GUILayout.MinWidth(32),
        GUILayout.MaxWidth(128),
        GUILayout.MaxHeight(128),
        };

        private readonly GUILayoutOption[] brushSizeIntFieldParams = new GUILayoutOption[]
        {
        };

        /* GUI LABEL STYLES */
        //these can't be initialised inline because they're ScriptableObjects??
        private GUIStyle headerLabelStyle = new GUIStyle();
        private void InitHeaderLabelStyle()
        {
            headerLabelStyle.fontSize = 14;
            //headerLabelStyle.fontStyle = FontStyle.Bold;
        }

        /*
        private GUIStyle subheaderLabelStyle = new GUIStyle();
        private void InitSubheaderLabelStyle()
        {
            headerLabelStyle.fontSize = 12;
            //headerLabelStyle.fontStyle = FontStyle.Bold;
        }
        */

        [MenuItem("Window/BlendPaint")]
        public static void OpenUI()
        {
            GetWindow<BlendPaintUI>("Blend Painter");
        }

        void OnEnable()
        {
            
            SceneView.duringSceneGui += OnSceneGUI;
            InitHeaderLabelStyle();
            //InitSubheaderLabelStyle();
            
            //init compute shader
            drawOnTexCompute = AssetDatabase.LoadAssetAtPath<ComputeShader>("Assets/BlendPaint/Scripts/DrawOnTexSoftRoundBrushCompute.compute");
            drawOnTexKernelHandle = drawOnTexCompute.FindKernel("DrawOnTex");

            brush = Resources.Load<BlendPaintBrush>("BlendPaint/Brushes/Brush ScriptableObjects/BlendPaintBrush");
            brush.LoadBrush();
            OnSelectionChange();
        }

        private void OnDisable()
        {
            SceneView.duringSceneGui -= OnSceneGUI;
        }

        void OnSelectionChange()
        {
            //if user has selected multiple objects, find the first one with a compatible shader (if any)
            //TODO: allow multiple selections if they all use the same textures?
            if (Selection.gameObjects.Length > 1)
            {
                foreach (GameObject obj in Selection.gameObjects)
                {
                    Renderer r = obj.GetComponent<Renderer>();
                    if (r != null)
                    {
                        Material m = r.sharedMaterial;
                        if (IsPaintable(m))
                        {
                            selection = obj;
                            selectionMaterial = m;
                            break;
                        }
                    }

                }
            }
            else if (Selection.gameObjects.Length == 1)
            {
                Renderer r = Selection.activeTransform.GetComponent<Renderer>();
                if (r != null)
                {
                    Material m = r.sharedMaterial;
                    if (IsPaintable(m))
                    {
                        selection = Selection.activeTransform.gameObject;
                        selectionMaterial = m;
                    }
                }

            }

            Repaint(); //need to repaint here or it doesn't update the UI immediately
        }

        void OnGUI()
        {
            EditorGUIUtility.labelWidth = 100;
            EditorGUIUtility.fieldWidth = 10;
            minSize = new Vector2(264, 512);

            if (selectionMaterial == null)
            {
                EditorGUILayout.LabelField("No compatible object selected", headerLabelStyle);
            }
            else
            {
                EditorGUILayout.LabelField("Texture selection", headerLabelStyle);
                EditorGUILayout.BeginHorizontal();
                { 
                    if (GUILayout.Button(selectionMaterial.GetTexture("_BaseTex"), textureButtonParams))
                    {
                        brush.SetBrushColour(Color.black);
                    }
                    if (GUILayout.Button(selectionMaterial.GetTexture("_MainTex1"), textureButtonParams))
                    {
                        brush.SetBrushColour(Color.red);
                    }
                    EditorGUILayout.EndHorizontal();
                    EditorGUILayout.BeginHorizontal();
                    if (GUILayout.Button(selectionMaterial.GetTexture("_MainTex2"), textureButtonParams))
                    {
                        brush.SetBrushColour(Color.green);
                    }
                    if (GUILayout.Button(selectionMaterial.GetTexture("_MainTex3"), textureButtonParams))
                    {
                        brush.SetBrushColour(Color.blue);
                    }
                }
                EditorGUILayout.EndHorizontal();

                EditorGUILayout.Space();

                /* Set/create blend texture */
                EditorGUILayout.LabelField("Blend map", headerLabelStyle);
                EditorGUILayout.BeginHorizontal();
                {
                    //select existing blend tex
                    selectionMaterial.SetTexture("_BlendTex", (Texture2D)EditorGUILayout.ObjectField("Select blend map", selectionMaterial.GetTexture("_BlendTex"), typeof(Texture2D), true));

                    //create new blend tex
                    if (GUILayout.Button("Create new"))
                    {
                        //create and save new (black i.e. all base texture) blend texture
                        string newBlendTexPath = EditorUtility.SaveFilePanelInProject("Save new blend map", "BlendTex.png", "png", "");
                        string newBlendTexName = Path.GetFileName(newBlendTexPath);
                        string newBlendTexDirectory = Path.GetDirectoryName(newBlendTexPath);
                        string newBlendTexAsset = texUtils.CreateAndSaveNewBlendTex
                        (
                            selectionMaterial.GetTexture("_BaseTex").width,
                            selectionMaterial.GetTexture("_BaseTex").height,
                            newBlendTexDirectory,
                            newBlendTexName
                        );

                        //set it as the selected blend texture
                        selectionMaterial.SetTexture("_BlendTex", AssetDatabase.LoadAssetAtPath<Texture2D>(newBlendTexAsset));
                    }
                }
                EditorGUILayout.EndHorizontal();

                EditorGUILayout.Space();

                /* Brush properties */
                //brush picker
                brush.SetBrushTex((Texture2D)EditorGUILayout.ObjectField("Brush", brush.BrushTex, typeof(Texture2D), true));

                //brush size
                brush.SetBrushSize(EditorGUILayout.IntField("Size", brush.BrushSize));

                //brush strength
                brush.SetBrushStrength(EditorGUILayout.FloatField("Strength", brush.BrushStrength));

                //brush mode
                //brushMode = (BrushMode)EditorGUILayout.EnumPopup("Brush mode", brushMode);
            }
        }

        void OnSceneGUI(SceneView sceneView)
        {
            Event e = Event.current;
            if (e != null && e.keyCode == KeyCode.P)
            {
                //If started painting, begin recording undo group
                if (e.type == EventType.KeyDown) Undo.SetCurrentGroupName("Paint on " + selection);

                Vector2 uvPos = Vector2.zero;
                if (TryGetUVPosFromCursorPos(ref uvPos))
                {
                    //(Texture painting undo is recorded in DrawOnTex)
                    DrawOnTex_Compute(uvPos, (Texture2D)selection.GetComponent<Renderer>().sharedMaterial.GetTexture("_BlendTex"));
                }
            }

            //if stopped painting, end recording undo group
            if (e.type == EventType.KeyUp && e.keyCode == KeyCode.P) Undo.CollapseUndoOperations(Undo.GetCurrentGroup());
        }

        /*
        //THIS DOESN'T WORK 
        public void DrawOnTex(Vector2 uvPos, Texture2D tex)
        {
            //texel on target texture that will be the brush's least corner (0, 0)
            //Subtracting half the brush size means the texel corresponding to the given UV position will be the centre of the brush
            Vector2Int brushStartTexel = new Vector2Int(Mathf.FloorToInt(uvPos.x * tex.width) - brush.halfBrushSize, Mathf.FloorToInt(uvPos.y * tex.height) - brush.halfBrushSize);

            //loop through each brush texel
            for (int x = 0; x <= brush.brushSize; x++)
            {
                for (int y = 0; y <= brush.brushSize; y++)
                {
                    //get brush colour at this brush texel
                    Color brushCol = brush.brushTex.GetPixel(x, y);

                    //get target texture texel
                    Vector2Int targetTexel = new Vector2Int(brushStartTexel.x + x, brushStartTexel.y + y);

                    //get colour after painting; add brush centre to (x, y) to get current brush texel's position on the target texture
                    Color col = Color.Lerp(tex.GetPixel(targetTexel.x, targetTexel.y), brushCol, brushCol.a * brush.brushStrength);
                    tex.SetPixel(targetTexel.x, targetTexel.y, col);
                }
            }

            tex.Apply();
        }
        */

        //draws on the texture with a soft brush
        public void DrawOnTex(Vector2 uvPos, Texture2D tex)
        {
            Vector2Int brushCentre = new Vector2Int(Mathf.FloorToInt(uvPos.x * tex.width), Mathf.FloorToInt(uvPos.y * tex.height));
            /*
            Vector2Int brushStart = new Vector2Int(Mathf.Max(0, brushCentreTexel.x - brush.HalfBrushSize), Mathf.Max(0, brushCentreTexel.y - brush.HalfBrushSize));
            Vector2Int brushEnd = new Vector2Int(Mathf.Min(tex.width, brushCentreTexel.x + brush.HalfBrushSize), Mathf.Min(tex.height, brushCentreTexel.y + brush.HalfBrushSize));
            //Debug.Log("Brush start: " + brushStart + ", brush end: " + brushEnd);
            int brushRectWidth = brushEnd.x - brushStart.x;
            int brushRectHeight = brushEnd.y - brushStart.y;

            //https://docs.unity3d.com/ScriptReference/Texture2D.GetPixels.html
            Color[] texPixels = tex.GetPixels(brushStart.x, brushStart.y, brushRectWidth, brushRectHeight);
            Color[] newPixels = new Color[texPixels.Length];
            for(int i = 0; i < texPixels.Length; i++)
            {
                int x = i % brushRectWidth;
                int y = i / brushRectWidth;
                float opacity = 1 - Vector2.Distance(new Vector2(x, y), brushCentreTexel) / brush.HalfBrushSize;
                newPixels[i] = Color.Lerp(tex.GetPixel(x, y), brush.ActiveCol, opacity * brush.BrushStrength);
            }

            tex.SetPixels(brushStart.x, brushStart.y, brushRectWidth, brushRectHeight, newPixels);
            */
            
            for (int x = brushCentre.x - brush.HalfBrushSize; x <= brushCentre.x + brush.HalfBrushSize; x++)
            {
                for (int y = brushCentre.y - brush.HalfBrushSize; y <= brushCentre.y + brush.HalfBrushSize; y++)
                {
                    float opacity = 1 - Vector2.Distance(new Vector2(x, y), brushCentre) / brush.HalfBrushSize;
                    /*
                    //get new colour based on brush mode
                    Color col;
                    switch(brushMode)
                    {
                        case BrushMode.Add:
                            //col = tex.GetPixel(x, y) + (brush.ActiveCol * (opacity * brush.BrushStrength));
                            break;
                        case BrushMode.Normal:
                        default:
                            col = Color.Lerp(tex.GetPixel(x, y), brush.ActiveCol, opacity * brush.BrushStrength);
                            break;
                    }
                    */
                    Color col = Color.Lerp(tex.GetPixel(x, y), brush.ActiveCol, opacity * brush.BrushStrength);

                    //assign new colour to tex pixel
                    tex.SetPixel(x, y, col);
                }
            }
            
            Undo.RegisterCompleteObjectUndo(tex, "Paint on blend texture");
            tex.Apply();
            Repaint();
        }

        //compute shader version of DrawOnTex
        public void DrawOnTex_Compute(Vector2 uvPos, Texture2D tex)
        {
            
            //brush position info
            int[] brushCentre = new int[2] { Mathf.FloorToInt(uvPos.x * tex.width), Mathf.FloorToInt(uvPos.y * tex.height) };
            //int[] brushStart = new int[2] { brushCentre[0] - brush.HalfBrushSize, brushCentre[1] - brush.HalfBrushSize };
            //int[] brushEnd = new int[2] { brushCentre[0] + brush.HalfBrushSize, brushCentre[1] + brush.HalfBrushSize };

            //threads
            const int GROUP_SIZE = 8; //must be same as in the compute shader
            int threadGroupsX = tex.width / GROUP_SIZE;
            int threadGroupsY = tex.height / GROUP_SIZE;

            //RenderTexture to write result to
            RenderTexture result = new RenderTexture(tex.width, tex.height, 1);
            result.enableRandomWrite = true;
            result.Create();
            
            drawOnTexCompute.SetFloats("brushColour", new float[4] { brush.ActiveCol[0], brush.ActiveCol[1], brush.ActiveCol[2], brush.ActiveCol[3] });
            drawOnTexCompute.SetInt("brushHalfSize", brush.HalfBrushSize);
            drawOnTexCompute.SetFloat("brushStrength", brush.BrushStrength);
            drawOnTexCompute.SetInts("brushCentre", brushCentre);
            drawOnTexCompute.SetTexture(drawOnTexKernelHandle, "inputTex", tex);
            drawOnTexCompute.SetTexture(drawOnTexKernelHandle, "Result", result);

            drawOnTexCompute.Dispatch(drawOnTexKernelHandle, threadGroupsX, threadGroupsY, 1);
            
            //write result render texture to blend tex
            RenderTexture.active = result;
            tex.ReadPixels(new Rect(0, 0, tex.width, tex.height), 0, 0);
            Undo.RegisterCompleteObjectUndo(tex, "Paint on blend texture");
            tex.Apply();
            Repaint();
        }


        bool IsPaintable(Material m)
        {
            //all shaders compatible with BlendPaint should have a _BlendTex property for storing the blend weights texture
            return m.HasProperty("_BlendTex");
        }

        //Casts a ray from camera to mouse position; returns true and assigns UV coordinates of hit object to uvPos
        //(if hit object == selection)
        bool TryGetUVPosFromCursorPos(ref Vector2 uvPos)
        {
            //cast a ray from the camera to the mouse position and see if it hits 
            //Camera sceneCam = SceneView.lastActiveSceneView.camera;
            Camera sceneCam = Camera.current;
            Debug.DrawRay(sceneCam.transform.position, HandleUtility.GUIPointToWorldRay(Event.current.mousePosition).direction * 10f, Color.cyan);
            Debug.DrawRay(sceneCam.transform.position, Vector3.up, Color.yellow);
            RaycastHit hit;
            if (Physics.Raycast(HandleUtility.GUIPointToWorldRay(Event.current.mousePosition), out hit))
            {
                Debug.DrawRay(hit.point, Vector3.up, Color.magenta);
                Renderer r = hit.transform.GetComponent<Renderer>();
                //Collider c = hit.collider;

                if (r != null)
                {
                    uvPos = hit.textureCoord; //gets the texture coord at the hit point
                    return true;
                }
            }

            return false;
        }


    }
}
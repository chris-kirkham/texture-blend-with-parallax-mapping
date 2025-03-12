using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System;
using System.IO;
using Unity.Jobs;
using UnityEditor.SceneManagement;

namespace BlendPaint
{
    public class BlendPaintUI : EditorWindow
    {
        private struct SelectedObject
        {
            public GameObject obj;
            public Material mat;
        }

        private BlendBrush brush;
        private BakeBlendScript bake;

        private List<SelectedObject> selectedObjects;
        private GameObject selection; //selected object
        private Material selectionMaterial;
        private BlendTexUtils texUtils = new BlendTexUtils();

        private ComputeShader drawOnTexCompute;
        private ComputeShader drawPreviewCompute;

        //the texture drawing preview overwrites the selected material's blend map; the blend map is cached here after drawing so we can revert changes the preview made
        //private Texture2D drawPreviewCachedBlendTex;

        //render texture to write the compute paint output to
        private RenderTexture resultRenderTex;

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
            
            drawOnTexCompute = AssetDatabase.LoadAssetAtPath<ComputeShader>("Assets/BlendPaint/Scripts/Editor/DrawOnTexSoftRoundBrushCompute.compute");
            drawPreviewCompute = AssetDatabase.LoadAssetAtPath<ComputeShader>("Assets/BlendPaint/Scripts/Editor/DrawPreview.compute");

            //initialise blend baking script
            bake = new BakeBlendScript(AssetDatabase.LoadAssetAtPath<ComputeShader>("Assets/BlendPaint/Scripts/Editor/BakeBlend.compute"));

            brush = AssetDatabase.LoadAssetAtPath<BlendBrush>("Assets/BlendPaint/Brush ScriptableObjects/BlendPaintBrush.asset");
            brush.LoadDefaultBrush();
            
            OnSelectionChange();
        }

        private void OnDisable()
        {
            SceneView.duringSceneGui -= OnSceneGUI;
        }

        void OnSelectionChange()
        {
            var numSelected = Selection.gameObjects.Length;

            //if user has selected multiple objects, find the first one with a compatible shader (if any)
            //TODO: allow multiple selections if they all use the same textures?
            if (numSelected > 1)
            {
                if(selectedObjects != null)
                {
                    selectedObjects.Clear();
                }
                else
                {
                    selectedObjects = new List<SelectedObject>(numSelected);
                }

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
                            selectedObjects.Add(new SelectedObject()
                            {
                                obj = obj,
                                mat = m
                            });
                        }
                    }

                }
            }
            else if (numSelected == 1)
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
                return;
            }

            UI_DoSelectTexture();
            EditorGUILayout.Space();
            UI_DoSetOrCreateBlendTex();                
            EditorGUILayout.Space();
            UI_DoSetBrushProperties();
            EditorGUILayout.Space();
            UI_DoBakeTextureMaps();
        }

        private void UI_DoSelectTexture()
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
        }

        private void UI_DoSetOrCreateBlendTex()
        {
            EditorGUILayout.LabelField("Blend map", headerLabelStyle);
            
            EditorGUI.BeginChangeCheck();
            EditorGUILayout.BeginHorizontal();
            {
                //select existing blend tex
                selectionMaterial.SetTexture("_BlendTex", (Texture2D)EditorGUILayout.ObjectField("Select blend map", selectionMaterial.GetTexture("_BlendTex"), typeof(Texture2D), true));

                //create new blend tex
                if (GUILayout.Button("Create new"))
                {
                    //get blend tex dimensons from first valid albedo texture in material
                    bool dimensionsFound = TryGetTexDimensions(out Vector2Int texDimensions);
                    if (dimensionsFound)
                    {
                        //create and save new (black i.e. all base texture) blend texture
                        string newBlendTexPath = EditorUtility.SaveFilePanelInProject("Save new blend map", "BlendTex.png", "png", "");
                        string newBlendTexName = Path.GetFileName(newBlendTexPath);
                        string newBlendTexDirectory = Path.GetDirectoryName(newBlendTexPath);

                        string newBlendTexAsset = texUtils.CreateAndSaveNewBlendTex
                        (
                            texDimensions.x,
                            texDimensions.y,
                            newBlendTexDirectory,
                            newBlendTexName
                        );

                        //set it as the selected blend texture
                        selectionMaterial.SetTexture("_BlendTex", AssetDatabase.LoadAssetAtPath<Texture2D>(newBlendTexAsset));
                    }
                }
            }
            EditorGUILayout.EndHorizontal();
            if(EditorGUI.EndChangeCheck())
            {
                //if blend texture changed, remake compute output render texture
                var blendTex = selectionMaterial.GetTexture("_BlendTex");
                CreateOutputRenderTexture(blendTex.width, blendTex.height);
            }
        }

        private void CreateOutputRenderTexture(int width, int height)
        {
            resultRenderTex = new RenderTexture(width, height, 1);
            resultRenderTex.enableRandomWrite = true;
            resultRenderTex.Create();
        }

        private void UI_DoSetBrushProperties()
        {
            //brush picker
            brush.SetBrushTex((Texture2D)EditorGUILayout.ObjectField("Brush", brush.BrushTex, typeof(Texture2D), true));

            //brush size
            brush.SetBrushSize(EditorGUILayout.IntField("Size", brush.Size));

            //brush strength
            brush.SetBrushStrength(EditorGUILayout.FloatField("Strength", brush.Strength));

            //brush mode
            brush.SetBrushMode((BrushMode)EditorGUILayout.EnumPopup("Brush mode", brush.Mode));
        }

        private void UI_DoBakeTextureMaps()
        {
            if (GUILayout.Button("Bake blended texture maps"))
            {
                string savePath = EditorUtility.SaveFilePanelInProject("Save new blend map", "texture", "png", "");
                string saveName = Path.GetFileName(savePath);
                string saveDirectory = Path.GetDirectoryName(savePath);

                bake.DoBlendBake
                (
                    //save path
                    saveDirectory,
                    saveName,
                    //albedos
                    (Texture2D)selectionMaterial.GetTexture("_BaseTex"),
                    (Texture2D)selectionMaterial.GetTexture("_MainTex1"),
                    (Texture2D)selectionMaterial.GetTexture("_MainTex2"),
                    (Texture2D)selectionMaterial.GetTexture("_MainTex3"),
                    //HRMA maps
                    (Texture2D)selectionMaterial.GetTexture("_BaseTexHRMA"),
                    (Texture2D)selectionMaterial.GetTexture("_Tex1HRMA"),
                    (Texture2D)selectionMaterial.GetTexture("_Tex2HRMA"),
                    (Texture2D)selectionMaterial.GetTexture("_Tex3HRMA"),
                    //normal maps
                    (Texture2D)selectionMaterial.GetTexture("_BaseTexNormal"),
                    (Texture2D)selectionMaterial.GetTexture("_Tex1Normal"),
                    (Texture2D)selectionMaterial.GetTexture("_Tex2Normal"),
                    (Texture2D)selectionMaterial.GetTexture("_Tex3Normal"),
                    //blend map
                    (Texture2D)selectionMaterial.GetTexture("_BlendTex"),
                    //blend factor
                    selectionMaterial.GetFloat("_HeightBlendFactor")
                );
            }
        }

        void OnSceneGUI(SceneView sceneView)
        {
            Event e = Event.current;
            if(e != null)
            {
                //if cursor is over the scene view, focus on it (instead of the BlendPaint UI);
                //this means user doesn't have to click on the window to focus before they can paint
                if (e.type == EventType.MouseEnterWindow)
                {
                    sceneView.Focus();
                }

                //if painting, draw on texture
                if (e.keyCode == KeyCode.P)
                {
                    Vector2 uvPos = Vector2.zero;
                    if (TryGetUVPosFromCursorPos(ref uvPos))
                    {
                        Texture2D tex = (Texture2D)selectionMaterial.GetTexture("_BlendTex");

                        //If started painting, begin recording undo group (DOESN'T WORK)
                        if (e.type == EventType.KeyDown)
                        {
                            Undo.SetCurrentGroupName("Paint on " + selection);
                            Undo.RegisterCompleteObjectUndo(tex, "Paint on blend texture");
                        }

                        if (tex != null)
                        {
                           DrawOnTex(uvPos, tex);
                        }
                    }
                }
                
                if (e.type == EventType.KeyUp && e.keyCode == KeyCode.P) //if stopped painting, end recording undo group and save texture changes
                {
                    Undo.CollapseUndoOperations(Undo.GetCurrentGroup()); //DOESN'T WORK

                    //save updated texture - TODO: Save texture only when scene saved
                    Texture2D tex = (Texture2D)selectionMaterial.GetTexture("_BlendTex");
                    if (tex != null)
                    {
                        string path = AssetDatabase.GetAssetPath(tex);
                        Debug.Log("path = " + path);
                        string name = Path.GetFileName(path);
                        string directory = Path.GetDirectoryName(path);
                        texUtils.SaveTexToFile(tex, directory, name);
                    }

                    //update cached blend texture for draw preview
                    //UpdateDrawPreviewCachedTexture();
                }

                /*
                if (e.type == EventType.MouseMove && e.keyCode != KeyCode.P) //preview drawing 
                {
                    Vector2 uvPos = Vector2.zero;
                    if (TryGetUVPosFromCursorPos(ref uvPos))
                    {
                        Texture2D tex = (Texture2D)selectionMaterial.GetTexture("_BlendTex");
                        Debug.Log("Drawing preview");
                        if (tex != null) DrawPreview(uvPos, tex);
                    }
                }
                */
            }
        }

        public void DrawOnTex(Vector2 uvPos, Texture2D tex)
        {
            //get kernel handle corresponding to brush mode
            int drawOnTexKernelHandle;
            switch(brush.Mode)
            {
                case BrushMode.Add:
                    drawOnTexKernelHandle = drawOnTexCompute.FindKernel("DrawOnTex_Additive");
                    break;
                case BrushMode.Subtract:
                    drawOnTexKernelHandle = drawOnTexCompute.FindKernel("DrawOnTex_Subtractive");
                    break;
                case BrushMode.Normal:
                default:
                    drawOnTexKernelHandle = drawOnTexCompute.FindKernel("DrawOnTex_Normal");
                    break;
            }

            //create render texture if none exists
            if(!resultRenderTex || !resultRenderTex.IsCreated())
            {
                CreateOutputRenderTexture(tex.width, tex.height);
            }

            //set compute shader parameters
            drawOnTexCompute.SetFloats("brushColour", new float[4] { brush.ActiveCol[0], brush.ActiveCol[1], brush.ActiveCol[2], brush.ActiveCol[3] });
            drawOnTexCompute.SetInt("brushHalfSize", brush.HalfSize);
            drawOnTexCompute.SetFloat("brushStrength", brush.Strength);
            int[] brushCentre = new int[2] 
            { 
                Mathf.FloorToInt(uvPos.x * tex.width),
                Mathf.FloorToInt(uvPos.y * tex.height) 
            };
            int[] brushMin = new int[2]
            {
                Mathf.Max(0, brushCentre[0] - brush.HalfSize),
                Mathf.Max(0, brushCentre[1] - brush.HalfSize)
            };
            drawOnTexCompute.SetInts("brushCentre", brushCentre);
            drawOnTexCompute.SetInts("brushMin", brushMin);
            drawOnTexCompute.SetTexture(drawOnTexKernelHandle, "inputTex", tex);
            drawOnTexCompute.SetInts("texWidth", tex.width);
            drawOnTexCompute.SetInts("texHeight", tex.height);
            drawOnTexCompute.SetTexture(drawOnTexKernelHandle, "Result", resultRenderTex);

            //threads
            const int GROUP_SIZE = 8; //must be same as in the compute shader
            //int threadGroupsX = tex.width / GROUP_SIZE;
            //int threadGroupsY = tex.height / GROUP_SIZE;
            int threadGroupsX = Mathf.Max(1, brush.Size / GROUP_SIZE);
            int threadGroupsY = Mathf.Max(1, brush.Size / GROUP_SIZE);

            //dispatch
            drawOnTexCompute.Dispatch(drawOnTexKernelHandle, threadGroupsX, threadGroupsY, 1);
            
            //write result render texture to blend tex
            RenderTexture.active = resultRenderTex;

            //TODO: WRONG
            /*
            var rectMinX = Mathf.Max(0, brushCentre[0] - brush.HalfSize);
            var rectMinY = Mathf.Max(0, brushCentre[1] - brush.HalfSize);
            var rectMaxX = Mathf.Min(tex.width, brushCentre[0] + brush.HalfSize);
            var rectMaxY = Mathf.Min(tex.height, brushCentre[1] + brush.HalfSize);
            tex.ReadPixels(new Rect(rectMinX, rectMinY, rectMaxX, rectMaxY), rectMinX, rectMinY); 
            */
            tex.ReadPixels(new Rect(0, 0, tex.width, tex.height), 0, 0);
            tex.Apply();
            Repaint();
        }

        /*
        public void DrawPreview(Vector2 uvPos, Texture2D tex)
        {
            int kernel;
            if (brush.Mode == BrushMode.Normal)
            {
                kernel = drawPreviewCompute.FindKernel("DrawPreview_Normal");
            }
            else if (brush.Mode == BrushMode.Add)
            {
                kernel = drawPreviewCompute.FindKernel("DrawPreview_Additive");
            }
            else
            {
                kernel = drawPreviewCompute.FindKernel("DrawPreview_Subtractive");
            }

            uint groupSizeX, groupSizeY;
            drawPreviewCompute.GetKernelThreadGroupSizes(kernel, out groupSizeX, out groupSizeY, out _);

            RenderTexture result = new RenderTexture(tex.width, tex.height, 1);
            result.enableRandomWrite = true;
            result.Create();

            //set compute shader parameters
            drawPreviewCompute.SetFloats("brushColour", new float[4] { brush.ActiveCol[0], brush.ActiveCol[1], brush.ActiveCol[2], brush.ActiveCol[3] });
            drawPreviewCompute.SetInt("brushHalfSize", brush.HalfSize);
            drawPreviewCompute.SetFloat("brushStrength", brush.Strength);
            int[] brushCentre = new int[2] { Mathf.FloorToInt(uvPos.x * tex.width), Mathf.FloorToInt(uvPos.y * tex.height) };
            drawPreviewCompute.SetInts("brushCentre", brushCentre);
            drawPreviewCompute.SetTexture(kernel, "previousState", drawPreviewCachedBlendTex);
            drawPreviewCompute.SetTexture(kernel, "Result", result);

            int threadGroupsX = Mathf.Max(1, tex.width / (int)groupSizeX);
            int threadGroupsY = Mathf.Max(1, tex.height / (int)groupSizeY);
            drawPreviewCompute.Dispatch(kernel, threadGroupsX, threadGroupsY, 1);

            //apply to texture
            RenderTexture.active = result;
            tex.ReadPixels(new Rect(0, 0, tex.width, tex.height), 0, 0);
            tex.Apply();
            Repaint();
        }
        */

        bool IsPaintable(Material m)
        {
            //all shaders compatible with BlendPaint should have a _BlendTex property for storing the blend weights texture
            return m.HasProperty("_BlendTex");
        }

        bool TryGetTexDimensions(out Vector2Int texDimensions)
        {
            Texture tex = new Texture2D(0, 0);
            bool texDimensionsFound = false;

            if (selectionMaterial.GetTexture("_BaseTex") != null)
            {
                tex = selectionMaterial.GetTexture("_BaseTex");
                texDimensionsFound = true;
            }
            else if (selectionMaterial.GetTexture("_MainTex1") != null)
            {
                tex = selectionMaterial.GetTexture("_MainTex1");
                texDimensionsFound = true;
            }
            else if (selectionMaterial.GetTexture("_MainTex2") != null)
            {
                tex = selectionMaterial.GetTexture("_MainTex2");
                texDimensionsFound = true;
            }
            else if (selectionMaterial.GetTexture("_MainTex3") != null)
            {
                tex = selectionMaterial.GetTexture("_MainTex3");
                texDimensionsFound = true;
            }
            else //no valid albedo
            {
                Debug.LogError("Trying to create a new blend texture, " +
                    "but no albedo texture found to get its dimensions from! Make sure your material has at least one albedo selected.");
            }

            texDimensions = new Vector2Int(tex.width, tex.height);
            return texDimensionsFound;
        }

        //Casts a ray from camera to mouse position; returns true and assigns UV coordinates of hit object to uvPos
        //(if hit object == selection)
        bool TryGetUVPosFromCursorPos(ref Vector2 uvPos)
        {
            //cast a ray from the camera to the mouse position and see if it hits 
            RaycastHit hit;
            if (Physics.Raycast(HandleUtility.GUIPointToWorldRay(Event.current.mousePosition), out hit) && hit.transform.gameObject == selection)
            {
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

        /*
        void UpdateDrawPreviewCachedTexture()
        {
            if(selectionMaterial != null) Graphics.CopyTexture(selectionMaterial.GetTexture("_BlendTex"), drawPreviewCachedBlendTex);
        }
        */
    }
}
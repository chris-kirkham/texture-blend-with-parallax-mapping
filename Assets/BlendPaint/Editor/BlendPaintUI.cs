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
        private BlendBrush brush;
        private GameObject selection; //selected object
        private Material selectionMaterial;
        private BlendTexUtils texUtils = new BlendTexUtils();

        ComputeShader drawOnTexCompute;

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

            brush = Resources.Load<BlendBrush>("BlendPaint/Brushes/Brush ScriptableObjects/BlendPaintBrush");
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
                brush.SetBrushSize(EditorGUILayout.IntField("Size", brush.Size));

                //brush strength
                brush.SetBrushStrength(EditorGUILayout.FloatField("Strength", brush.Strength));

                //brush mode
                brush.SetBrushMode((BrushMode)EditorGUILayout.EnumPopup("Brush mode", brush.Mode));
            }
        }

        void OnSceneGUI(SceneView sceneView)
        {
            Event e = Event.current;
            if (e != null && e.keyCode == KeyCode.P)
            {
                //If started painting, begin recording undo group (DOESN'T WORK)
                if (e.type == EventType.KeyDown) Undo.SetCurrentGroupName("Paint on " + selection);

                Vector2 uvPos = Vector2.zero;
                if (TryGetUVPosFromCursorPos(ref uvPos))
                {
                    //(Texture painting undo is recorded in DrawOnTex)
                    DrawOnTex_Compute(uvPos, (Texture2D)selection.GetComponent<Renderer>().sharedMaterial.GetTexture("_BlendTex"));
                }
            }

            //if stopped painting, end recording undo group and svae texture changes
            if (e.type == EventType.KeyUp && e.keyCode == KeyCode.P)
            {
                Undo.CollapseUndoOperations(Undo.GetCurrentGroup()); //DOESN'T WORK

                //save updated texture - TODO: Save texture only when scene saved
                Texture2D tex = (Texture2D)selection.GetComponent<Renderer>().sharedMaterial.GetTexture("_BlendTex");
                string path = AssetDatabase.GetAssetPath(tex);
                Debug.Log("path = " + path);
                string name = Path.GetFileName(path);
                string directory = Path.GetDirectoryName(path);
                texUtils.SaveTexToFile(tex, directory, name);
            }
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

        //compute shader version of DrawOnTex
        public void DrawOnTex_Compute(Vector2 uvPos, Texture2D tex)
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
            
            //threads
            const int GROUP_SIZE = 8; //must be same as in the compute shader
            int threadGroupsX = tex.width / GROUP_SIZE;
            int threadGroupsY = tex.height / GROUP_SIZE;

            //RenderTexture to write result to
            RenderTexture result = new RenderTexture(tex.width, tex.height, 1);
            result.enableRandomWrite = true;
            result.Create();
            
            //set compute shader parameters
            drawOnTexCompute.SetFloats("brushColour", new float[4] { brush.ActiveCol[0], brush.ActiveCol[1], brush.ActiveCol[2], brush.ActiveCol[3] });
            drawOnTexCompute.SetInt("brushHalfSize", brush.HalfSize);
            drawOnTexCompute.SetFloat("brushStrength", brush.Strength);
            int[] brushCentre = new int[2] { Mathf.FloorToInt(uvPos.x * tex.width), Mathf.FloorToInt(uvPos.y * tex.height) };
            drawOnTexCompute.SetInts("brushCentre", brushCentre);
            drawOnTexCompute.SetTexture(drawOnTexKernelHandle, "inputTex", tex);
            drawOnTexCompute.SetTexture(drawOnTexKernelHandle, "Result", result);

            //dispatch
            drawOnTexCompute.Dispatch(drawOnTexKernelHandle, threadGroupsX, threadGroupsY, 1);
            
            //write result render texture to blend tex
            RenderTexture.active = result;
            tex.ReadPixels(new Rect(0, 0, tex.width, tex.height), 0, 0);
            
            //apply
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
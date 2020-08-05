using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System;

//[Serializable]
public class BlendPaintUI : EditorWindow
{
    [SerializeField] private BlendPaintBrush brush; 
    private GameObject selection; //selected object
    private Material selectionMaterial;

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

    [MenuItem("Window/BlendPaint")]
    public static void OpenUI()
    {
        EditorWindow.GetWindow<BlendPaintUI>("Blend Painter");
    }
    void OnEnable()
    {
        SceneView.duringSceneGui += this.OnSceneGUI;

        brush = new BlendPaintBrush();
        brush.LoadBrush();
        OnSelectionChange(); 
    }

    private void OnDisable()
    {
        SceneView.duringSceneGui -= this.OnSceneGUI;
    }

    void OnSelectionChange()
    {
        //if user has selected multiple objects, find the first one with a compatible shader (if any)
        //TODO: allow multiple selections if they all use the same textures?
        if(Selection.gameObjects.Length > 1)
        {
            foreach (GameObject obj in Selection.gameObjects)
            {
                Renderer r = obj.GetComponent<Renderer>();
                if(r != null)
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
        else if(Selection.gameObjects.Length == 1)
        {
            Renderer r = Selection.activeTransform.GetComponent<Renderer>();
            if(r != null)
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
        this.minSize = new Vector2(264, 512);

        if(selectionMaterial == null)
        {
            EditorGUILayout.LabelField("No compatible object selected");
        }
        else
        {
            EditorGUILayout.LabelField("Texture selection");
            EditorGUILayout.BeginHorizontal();
            if (GUILayout.Button(selectionMaterial.GetTexture("_BaseTex"), textureButtonParams))
            {
                brush.activeCol = Color.black;
                brush.SetBrushColour(brush.activeCol);
            }
            if (GUILayout.Button(selectionMaterial.GetTexture("_MainTex1"), textureButtonParams))
            {
                brush.activeCol = Color.red;
                brush.SetBrushColour(brush.activeCol);
            }
            EditorGUILayout.EndHorizontal();
            EditorGUILayout.BeginHorizontal();
            if (GUILayout.Button(selectionMaterial.GetTexture("_MainTex2"), textureButtonParams))
            {
                brush.activeCol = Color.green;
                brush.SetBrushColour(brush.activeCol);
            }
            if (GUILayout.Button(selectionMaterial.GetTexture("_MainTex3"), textureButtonParams))
            {
                brush.activeCol = Color.blue;
                brush.SetBrushColour(brush.activeCol);
            }
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.Space();

            /* Brush parameters */
            //brush picker
            EditorGUI.BeginChangeCheck();
            brush.brushTex = (Texture2D)EditorGUILayout.ObjectField("Brush", brush.brushTex, typeof(Texture2D), true);
            if (brush.brushTex != brush.brushTexCopy) Graphics.CopyTexture(brush.brushTex, brush.brushTexCopy);

            //brush size
            EditorGUI.BeginChangeCheck();
            brush.brushSize = EditorGUILayout.IntField("Brush size", brush.brushSize);
            if (EditorGUI.EndChangeCheck())
            {
                if (brush.brushSize < 1) brush.brushSize = 1;
                brush.halfBrushSize = brush.brushSize / 2;
            }

            //brush strength
            brush.brushStrength = EditorGUILayout.FloatField("Brush strength", brush.brushStrength);
        }
    }

    void OnSceneGUI(SceneView sceneView)
    {
        Event e = Event.current;
        if (e != null && e.keyCode == KeyCode.P)
        {
            Vector2 uvPos = Vector2.zero;
            if (TryGetUVPosFromCursorPos(ref uvPos))
            {
                DrawOnTex(uvPos, (Texture2D)selection.GetComponent<Renderer>().sharedMaterial.GetTexture("_BlendTex"));
            }
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

    //draws on the texture with a soft brush
    public void DrawOnTex(Vector2 uvPos, Texture2D tex)
    {
        Vector2Int brushCentreTexel = new Vector2Int(Mathf.FloorToInt(uvPos.x * tex.width), Mathf.FloorToInt(uvPos.y * tex.height));
        
        for(int x = brushCentreTexel.x - brush.halfBrushSize; x <= brushCentreTexel.x + brush.halfBrushSize; x++)
        {
            for (int y = brushCentreTexel.y - brush.halfBrushSize; y <= brushCentreTexel.y + brush.halfBrushSize; y++)
            {
                float opacity = 1 - (Vector2.Distance(new Vector2(x, y), brushCentreTexel) / brush.halfBrushSize);
                Color brushCol = brush.activeCol;
                brushCol.a = opacity;

                Color col = Color.Lerp(tex.GetPixel(x, y), brushCol, brushCol.a * brush.brushStrength);
                tex.SetPixel(x, y, col);
            }
        }

        tex.Apply();
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

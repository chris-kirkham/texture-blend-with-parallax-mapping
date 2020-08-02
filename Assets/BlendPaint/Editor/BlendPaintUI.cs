using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public class BlendPaintUI : EditorWindow
{
    //private Texture2D baseTex, tex1, tex2, tex3;
    
    /* BRUSH INFO */


    private GameObject canvasObj;
    private BlendPaintCanvas canvas; //component of canvasObj
    private BlendPaintBrush brush; //component of canvasObj
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

    void OnEnable()
    {
        SceneView.duringSceneGui += this.OnSceneGUI;

        brush = new BlendPaintBrush();

        //create canvas (RenderTexture camera/texture quad) prefab and get 
        //GameObject canvasObj = Instantiate((GameObject)Resources.Load("BlendPaint/Prefabs/Canvas"));
        //canvas = canvasObj.GetComponent<BlendPaintCanvas>();

        //need to call this after creating painter and canvas components, since it changes painter/canvas params
        OnSelectionChange(); 
    }

    private void OnDisable()
    {
        SceneView.duringSceneGui -= this.OnSceneGUI;
        DestroyImmediate(canvasObj);
    }

    void OnSelectionChange()
    {
        //if user has selected multiple objects, find the first one with a compatible shader (if any)
        //TODO: allow multiple selections if they all use the same textures?
        if(Selection.gameObjects.Length > 1)
        {
            foreach (GameObject o in Selection.gameObjects)
            {
                Material m = o.GetComponent<Renderer>().sharedMaterial;
                if (IsPaintable(m))
                {
                    selection = o;
                    selectionMaterial = m;
                    //canvas.SetSelection(o);
                    break;
                }
            }
        }
        else if(Selection.gameObjects.Length == 1)
        {
            Material m = Selection.activeTransform.GetComponent<Renderer>().sharedMaterial;
            if (IsPaintable(m))
            {
                selection = Selection.activeTransform.gameObject;
                selectionMaterial = m;
                //canvas.SetSelection(Selection.activeTransform.gameObject);
            }
        }

        Repaint(); //need to repaint here or it doesn't update the UI immediately
    }

    void OnGUI()
    {
        EditorGUIUtility.labelWidth = 100;
        EditorGUIUtility.fieldWidth = 10;
        this.minSize = new Vector2(264, 512);

        EditorGUILayout.LabelField("Texture selection");
        EditorGUILayout.BeginHorizontal();
        if (GUILayout.Button(selectionMaterial.GetTexture("_BaseTex"), textureButtonParams)) //TODO: replace strings with texture images
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

        //brush picker
        EditorGUI.BeginChangeCheck();
        brush.brushTex = (Texture2D)EditorGUILayout.ObjectField("Brush", brush.brushTex, typeof(Texture2D), true);
        if(brush.brushTex != brush.brushTexCopy) Graphics.CopyTexture(brush.brushTex, brush.brushTexCopy);


        EditorGUI.BeginChangeCheck();
        brush.brushSize = EditorGUILayout.IntField("Brush size", brush.brushSize);
        if(EditorGUI.EndChangeCheck())
        {
            if (brush.brushSize < 1) brush.brushSize = 1;
            brush.halfBrushSize = brush.brushSize / 2;
        }
    }

    void OnSceneGUI(SceneView sceneView)
    {
        Debug.Log("Scene GUI event!");

        //https://docs.unity3d.com/ScriptReference/HandleUtility.GUIPointToWorldRay.html 
        //get worldspace ray from mouse position on click event
        if (Event.current.type == EventType.MouseDown)
        {
            Ray r = HandleUtility.GUIPointToWorldRay(Event.current.mousePosition);
            //painter.SetUVPos(r);
        }

        Event e = Event.current;
        if (e != null && e.keyCode == KeyCode.P)
        {
            Debug.Log("Paint key pressed");
            Vector2 uvPos = Vector2.zero;
            if (TryGetUVPosFromCursorPos(ref uvPos))
            {
                //canvas.AddPaintSprite(brush.BrushObj, uvPos, brush.brush.brushSize / 2);
                Debug.Log(selection.GetComponent<Renderer>().material.GetTexture("_BlendTex"));
                DrawOnTex(uvPos, (Texture2D)selection.GetComponent<Renderer>().material.GetTexture("_BlendTex"));
            }
        }
    }

    public void DrawOnTex(Vector2 uvPos, Texture2D tex)
    {
        Vector2Int brushCentreTexel = new Vector2Int(Mathf.FloorToInt(uvPos.x * tex.width), Mathf.FloorToInt(uvPos.y * tex.height));

        for (int x = brushCentreTexel.x - brush.halfBrushSize; x <= brushCentreTexel.x + brush.halfBrushSize; x++)
        {
            for (int y = brushCentreTexel.y - brush.halfBrushSize; y <= brushCentreTexel.y + brush.halfBrushSize; y++)
            {
                Color brushCol = brush.brushTex.GetPixel(x, y);
                Color col = Color.Lerp(tex.GetPixel(x, y), brushCol, brushCol.a);
                tex.SetPixel(x, y, col);
            }
        }
    }

    bool IsPaintable(Material m)
    {
        //all shaders compatible with BlendPaint should have a _BlendTex property for storing the blend weights texture
        return m.HasProperty("_BlendTex");
    }

    [MenuItem("Window/BlendPaint")]
    public static void OpenUI()
    {
        EditorWindow.GetWindow<BlendPaintUI>("Blend Painter");
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
            Debug.Log("Raycast hit object: " + hit.transform.gameObject.name);
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

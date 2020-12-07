﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;

//Singleton class to contain all user input and map it to gameplay functions
//see https://gamedev.stackexchange.com/questions/116009/in-unity-how-do-i-correctly-implement-the-singleton-pattern 
public class ControlInputs : MonoBehaviour
{
    private static ControlInputs instance;
    public static ControlInputs Instance { get { return instance; } }

    //camera movement
    public float moveHorizontal, moveVertical;

    //camera rotation
    public bool useMouseLook;
    public float rotationX, rotationY;
    private float lookSpeedX = 1.0f, lookSpeedY = 1.0f;

    //spatial hash debug visualisers
    public bool drawCellOutlines, drawCellCentres, highlightActiveCells;

    private bool debug = false;

    void Awake()
    {
        //destroy this object if there is already another one in the scene
        if(instance != null && instance != this)
        {
            Debug.LogWarning("Instance of this singleton object already exists, destroying this object");
            Destroy(this.gameObject);
        }
        else
        {
            instance = this;
        }
    }

    // Start is called before the first frame update
    void Start()
    {
        //camera behaviour
        useMouseLook = false;
        moveHorizontal = Input.GetAxis("Horizontal");
        moveVertical = Input.GetAxis("Vertical");

        //camera rotation
        rotationX = 0.0f;
        rotationY = 0.0f;

        //spatial hash debug visualisers
        drawCellOutlines = false;
        drawCellCentres = false;
        highlightActiveCells = false;
    }

    void OnDrawGizmos()
    {
        Gizmos.color = Color.red;
        Gizmos.DrawCube(transform.position, new Vector3(0.2f, 0.2f, 0.2f));
    }

    // Update is called once per frame
    void Update()
    {
        //camera movement
        moveHorizontal = Input.GetAxis("Horizontal");
        moveVertical = Input.GetAxis("Vertical");

        //camera rotation
        useMouseLook = Input.GetKey(KeyCode.Mouse1);
        if(useMouseLook)
        {
            rotationX += Input.GetAxis("Mouse X") * lookSpeedX;
            rotationY += Input.GetAxis("Mouse Y") * lookSpeedY;
        }

        //spatial hash debug visualisers
        if (Input.GetKeyDown(KeyCode.H)) drawCellOutlines = !drawCellOutlines;
        if (Input.GetKeyDown(KeyCode.J)) highlightActiveCells = !highlightActiveCells;

    }
}

using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Rigidbody))]
public class CameraController : MonoBehaviour
{
    private Rigidbody rb;

    public float moveSpeed;
    private Quaternion initialRotation;
    
    // Start is called before the first frame update
    void Start()
    {
        rb = GetComponent<Rigidbody>();

        initialRotation = transform.localRotation;
    }

    // Update is called once per frame
    void FixedUpdate()
    {
        if (ControlInputs.Instance.useMouseLook) transform.localRotation = initialRotation * CalcMouseLook();
        rb.AddForce(CalcMovement(), ForceMode.VelocityChange);
    }

    Vector3 CalcMovement()
    {
        float moveHorizontal = ControlInputs.Instance.moveHorizontal;
        float moveVertical = ControlInputs.Instance.moveVertical;

        Vector3 movement = new Vector3(moveHorizontal, 0.0f, moveVertical);
        movement = transform.TransformDirection(movement); //transform movement input so its direction is relative to the camera's rotation

        return movement * moveSpeed;
    }

    Quaternion CalcMouseLook()
    {
        Quaternion xQ = Quaternion.AngleAxis(ControlInputs.Instance.rotationX, Vector3.up);
        Quaternion yQ = Quaternion.AngleAxis(ControlInputs.Instance.rotationY, Vector3.left);

        return xQ * yQ;
    }
}

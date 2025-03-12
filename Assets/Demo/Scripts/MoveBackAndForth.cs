using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MoveBackAndForth : MonoBehaviour
{
    [SerializeField] private Vector3 min = Vector3.zero;
    [SerializeField] private Vector3 max = Vector3.one;
    [SerializeField] private float moveTime = 1f;
    private float currMoveTime = 0f;

    private bool direction = false; //false = moving from min to max, true = moving from max to min

    void LateUpdate()
    {
        currMoveTime += Time.deltaTime;
        if(currMoveTime >= moveTime)
        {
            currMoveTime = 0;
            direction = !direction;
        }

        if (direction)
        {
            transform.position = Vector3.Lerp(min, max, currMoveTime / moveTime);
        }
        else
        {
            transform.position = Vector3.Lerp(max, min, currMoveTime / moveTime);
        }
    }
}

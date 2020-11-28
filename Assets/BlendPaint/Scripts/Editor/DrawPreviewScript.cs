using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace BlendPaint
{
    public class DrawPreviewScript : MonoBehaviour
    {
        public ComputeShader drawPreviewCompute;

        public void DrawPreview(Vector2 uvPos, BlendBrush brush, Texture2D tex)
        {
            int kernel;
            if(brush.Mode == BrushMode.Normal)
            {
                kernel = drawPreviewCompute.FindKernel("DrawPreview_Normal");
            }
            else if(brush.Mode == BrushMode.Add)
            {
                kernel = drawPreviewCompute.FindKernel("DrawPreview_Add");
            }
            else
            {
                kernel = drawPreviewCompute.FindKernel("DrawPreview_Subtract");
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
            drawPreviewCompute.SetTexture(kernel, "inputTex", tex);
            drawPreviewCompute.SetTexture(kernel, "Result", result);

            int threadGroupsX = Mathf.Max(1, tex.width / (int)groupSizeX);
            int threadGroupsY = Mathf.Max(1, tex.height / (int)groupSizeY);
            drawPreviewCompute.Dispatch(kernel, threadGroupsX, threadGroupsY, 1);

            RenderTexture.active = result;
            tex.ReadPixels(new Rect(0, 0, tex.width, tex.height), 0, 0);
        }
    }
}
using System.Collections;
using System.Collections.Generic;
using System.IO;
using Unity.Rendering;
using UnityEditor;
using UnityEngine;

namespace BlendPaint
{
    public class BakeBlend
    {
        private ComputeShader bakeBlendCompute;
        private int bakeBlendKernel;
        private const int GROUP_SIZE = 8;

        private BlendTexUtils texUtils;

        public BakeBlend(ComputeShader bakeBlendCompute)
        {
            texUtils = new BlendTexUtils();

            this.bakeBlendCompute = bakeBlendCompute;
            bakeBlendKernel = bakeBlendCompute.FindKernel("BakeBlend");
        }

        public void DoBlendBake
        (
            string directory,
            string bakedTextureName,
            Texture2D baseAlbedo, Texture2D tex1Albedo, Texture2D tex2Albedo, Texture2D tex3Albedo,
            Texture2D baseHRMA, Texture2D tex1HRMA, Texture2D tex2HRMA, Texture2D tex3HRMA,
            Texture2D baseNormal, Texture2D tex1Normal, Texture2D tex2Normal, Texture2D tex3Normal,
            Texture2D blendMap,
            float blendFactor
        )
        {
            //inputs
            bakeBlendCompute.SetTexture(bakeBlendKernel, "baseAlbedo", baseAlbedo);
            bakeBlendCompute.SetTexture(bakeBlendKernel, "tex1Albedo", tex1Albedo);
            bakeBlendCompute.SetTexture(bakeBlendKernel, "tex2Albedo", tex2Albedo);
            bakeBlendCompute.SetTexture(bakeBlendKernel, "tex3Albedo", tex3Albedo);

            bakeBlendCompute.SetTexture(bakeBlendKernel, "baseHRMA", baseHRMA);
            bakeBlendCompute.SetTexture(bakeBlendKernel, "tex1HRMA", tex1HRMA);
            bakeBlendCompute.SetTexture(bakeBlendKernel, "tex2HRMA", tex2HRMA);
            bakeBlendCompute.SetTexture(bakeBlendKernel, "tex3HRMA", tex3HRMA);

            bakeBlendCompute.SetTexture(bakeBlendKernel, "baseNormal", baseNormal);
            bakeBlendCompute.SetTexture(bakeBlendKernel, "tex1Normal", tex1Normal);
            bakeBlendCompute.SetTexture(bakeBlendKernel, "tex2Normal", tex2Normal);
            bakeBlendCompute.SetTexture(bakeBlendKernel, "tex3Normal", tex3Normal);

            bakeBlendCompute.SetTexture(bakeBlendKernel, "blendMap", blendMap);

            bakeBlendCompute.SetFloat("blendFactor", blendFactor);

            //outputs
            //width and height of output textures (taken from base input albedo) 
            int w = baseAlbedo.width;
            int h = baseAlbedo.height;

            RenderTextureDescriptor desc = new RenderTextureDescriptor(w, h);
            desc.enableRandomWrite = true;

            RenderTexture blendedAlbedo = new RenderTexture(desc);
            RenderTexture blendedHRMA = new RenderTexture(desc);
            RenderTexture blendedNormal = new RenderTexture(desc);

            bakeBlendCompute.SetTexture(bakeBlendKernel, "BlendedAlbedo", blendedAlbedo);
            bakeBlendCompute.SetTexture(bakeBlendKernel, "BlendedHRMA", blendedHRMA);
            bakeBlendCompute.SetTexture(bakeBlendKernel, "BlendedNormal", blendedNormal);

            //dispatch shader
            int numGroupsX = Mathf.Max(1, blendedAlbedo.width / GROUP_SIZE);
            int numGroupsY = Mathf.Max(1, blendedAlbedo.height / GROUP_SIZE);
            bakeBlendCompute.Dispatch(bakeBlendKernel, numGroupsX, numGroupsY, 1);
            Debug.Log("num groups = (" + numGroupsX + ", " + numGroupsY + ")");

            //read blended RenderTextures to Texture2Ds
            Texture2D blendedAlbedoTex2D = new Texture2D(w, h);
            Texture2D blendedHRMATex2D = new Texture2D(w, h);
            Texture2D blendedNormalTex2D = new Texture2D(w, h);

            RenderTexture.active = blendedAlbedo;
            blendedAlbedoTex2D.ReadPixels(new Rect(0, 0, w, h), 0, 0);

            RenderTexture.active = blendedHRMA;
            blendedHRMATex2D.ReadPixels(new Rect(0, 0, w, h), 0, 0);

            RenderTexture.active = blendedNormal;
            blendedNormalTex2D.ReadPixels(new Rect(0, 0, w, h), 0, 0);

            //save textures according to given directory/name
            string name = Path.GetFileNameWithoutExtension(bakedTextureName);
            string albedoName = name + "_Albedo.png";
            string hrmaName = name + "_HRMA.png";
            string normalName = name + "_Normal.png";

            texUtils.SaveTexToFile(blendedAlbedoTex2D, directory, albedoName);
            texUtils.SaveTexToFile(blendedHRMATex2D, directory, hrmaName);
            texUtils.SaveTexToFile(blendedNormalTex2D, directory, normalName);
        }
    }
}
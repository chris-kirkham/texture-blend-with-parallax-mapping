#include "blends.cginc"

//variant of Unity's ParallaxOffset function (from UnityCG.cginc) that implements offset limiting
//by not dividing normalised viewDir.xy by viewDir.z, as per http://old.cescg.org/CESCG-2006/papers/TUBudapest-Premecz-Matyas.pdf
float2 ParallaxOffsetLimited(half heightmapHeight, half parallaxHeight, half3 tangentViewDir)
{
	heightmapHeight = heightmapHeight * parallaxHeight - parallaxHeight / 2.0;
	return heightmapHeight * (tangentViewDir.xy / tangentViewDir.z);
}

float2 IterativeParallaxOffset(float2 uv, half3 blendAmounts, sampler2D hmaps[4], float hmapMults[4], float hmapOffsets[4], int numHmaps, uniform float parallaxAmt, uniform int iterations, float3 tangentViewDir)
{
	float2 totalOffset = 0;

	for (int i = 0; i < iterations; i++)
	{
		float2 offset = ParallaxOffsetLimited(GetBlendedHeight(hmaps, hmapMults, hmapOffsets, numHmaps, uv, blendAmounts), parallaxAmt, tangentViewDir);
		totalOffset += offset;
		uv += offset;
	}

	return totalOffset;
}

float2 POM(
	float fHeightMapScale,
	float3 tangentViewDir,
	float sampleRatio,
	float2 texcoord,
	sampler2D heightMaps[4],
	float heightMapMults[4],
	float heightMapOffsets[4],
	sampler2D blendTex,
	float blendFactor,
	int nMinSamples,
	int nMaxSamples
) {

	float fParallaxLimit = -length(tangentViewDir.xy) / tangentViewDir.z;
	fParallaxLimit *= fHeightMapScale;

	float2 vOffsetDir = normalize(tangentViewDir.xy);
	float2 vMaxOffset = vOffsetDir * fParallaxLimit;

	int nNumSamples = (int)lerp(nMinSamples, nMaxSamples, saturate(sampleRatio));

	float fStepSize = 1.0 / (float)nNumSamples;

	float2 dx = ddx(texcoord);
	float2 dy = ddy(texcoord);

	float fCurrRayHeight = 1.0;
	float2 vCurrOffset = float2(0, 0);
	float2 vLastOffset = float2(0, 0);

	float fLastSampledHeight = 1;
	float fCurrSampledHeight = 1;

	int nCurrSample = 0;

	while (nCurrSample < nNumSamples)
	{
		float hBase = tex2Dgrad(heightMaps[0], texcoord + vCurrOffset, dx, dy).r;
		float h1 = tex2Dgrad(heightMaps[1], texcoord + vCurrOffset, dx, dy).r;
		float h2 = tex2Dgrad(heightMaps[2], texcoord + vCurrOffset, dx, dy).r;
		float h3 = tex2Dgrad(heightMaps[3], texcoord + vCurrOffset, dx, dy).r;
		half3 blendAmounts = getBlendAmounts(hBase, h1, h2, h3, tex2Dgrad(blendTex, texcoord + vCurrOffset, dx, dy), blendFactor);

		//get blended height based on height blend mode
#if defined(_HEIGHTBLENDMODE_ADDTOBASE)
		fCurrSampledHeight = pomGetBlendedHeightAddToBase(heightMaps, heightMapMults, heightMapOffsets, 4, texcoord + vCurrOffset, dx, dy, blendAmounts).r;
#elif defined(_HEIGHTBLENDMODE_ADDALL)
		fCurrSampledHeight = pomGetBlendedHeightAddAll(heightMaps, heightMapMults, heightMapOffsets, 4, texcoord + vCurrOffset, dx, dy).r;
#else //blend all
		fCurrSampledHeight = pomGetBlendedHeightBlendAll(heightMaps, heightMapMults, heightMapOffsets, 4, texcoord + vCurrOffset, dx, dy, blendAmounts).r;
#endif 

		if (fCurrSampledHeight > fCurrRayHeight)
		{
			float delta1 = fCurrSampledHeight - fCurrRayHeight;
			float delta2 = (fCurrRayHeight + fStepSize) - fLastSampledHeight;

			float ratio = delta1 / (delta1 + delta2);

			vCurrOffset = (ratio)*vLastOffset + (1.0 - ratio) * vCurrOffset;

			nCurrSample = nNumSamples + 1;
		}
		else
		{
			nCurrSample++;

			fCurrRayHeight -= fStepSize;

			vLastOffset = vCurrOffset;
			vCurrOffset += fStepSize * vMaxOffset;

			fLastSampledHeight = fCurrSampledHeight;
		}
	}

	return vCurrOffset;
}

/*
float POMCalcShadow(float2 uv, float3 tangentLightDir, float sampleRatio, int minSamples, int maxSamples)
{
	int numSamples = (int) lerp(minSamples, maxSamples, saturate(sampleRatio));
	float stepSize = 1.0 / numSamples;

}
*/



float2 POM_test1
(
	float heightmapHeight,
	sampler2D hmaps[4],
	float hmapMults[4],
	float hmapOffsets[4],
	int numHmaps,
	float2 heightmapUV,
	float parallaxAmt,
	half3 blendAmounts,
	float minSamples,
	float maxSamples,
	float3 tangentViewDir
)
{
	float parallaxLimit = (-length(tangentViewDir.xy) / tangentViewDir.z) * parallaxAmt;

	float2 offsetDir = normalize(tangentViewDir.xy);
	float2 maxOffset = offsetDir * parallaxLimit;

	//int numSamples = (int)lerp(minSamples, maxSamples, saturate(dot(tangentViewDir, float3(0, 0, 1))));
	int numSamples = maxSamples;
	float stepSize = 1 / (float)numSamples;

	float currRayHeight = 1;
	float2 currOffset = float2(0, 0);
	float2 lastOffset = float2(0, 0);

	float currSampledHeight = 1;
	float lastSampledHeight = 1;

	float2 dx = ddx(heightmapUV);
	float2 dy = ddy(heightmapUV);

	int currSample = 0;
	
	while (currSample < numSamples)
	{
		//currSampledHeight = pomGetBlendedHeightBlendAll(heightmapUV + currOffset, dx, dy, blendAmounts);
		currSampledHeight = pomGetBlendedHeightBlendAll(hmaps, hmapMults, hmapOffsets, numHmaps, heightmapUV + currOffset, dx, dy, blendAmounts);
		if (currSampledHeight > currRayHeight)
		{
			float delta1 = currSampledHeight - currRayHeight;
			float delta2 = (currRayHeight + stepSize) - lastSampledHeight;
			float ratio = delta1 / (delta1 + delta2);

			currOffset = ratio * lastOffset + (1 - ratio) * currOffset;
			currSample = numSamples + 1;
		}
		else
		{
			currSample++;
			currRayHeight -= stepSize;
			lastOffset = currOffset;
			currOffset += stepSize * maxOffset;
			lastSampledHeight = currSampledHeight;
		}
	}

	/*
	while (currSampledHeight < currRayHeight && currSample < numSamples)
	{
		currSampledHeight = pomGetBlendedHeightBlendAll(heightmapUV + currOffset, blendAmounts, dx, dy);
		currSample++;
		currRayHeight -= stepSize;
		lastOffset = currOffset;
		currOffset += stepSize * maxOffset;
		lastSampledHeight = currSampledHeight;
	}

	float delta1 = currSampledHeight - currRayHeight;
	float delta2 = (currRayHeight + stepSize) - lastSampledHeight;
	float ratio = delta1 / (delta1 + delta2);

	currOffset = ratio * lastOffset + (1 - ratio) * currOffset;
	currSample = numSamples + 1;
	*/

	return currOffset;
}

float2 POM_test2
(
	float heightmapHeight,
	sampler2D hmaps[4],
	float hmapMults[4],
	float hmapOffsets[4],
	float numHmaps,
	float2 heightmapUV,
	half3 blendAmounts,
	float parallaxHeight,
	float minSamples,
	float maxSamples,
	float3 tangentViewDir
)
{
	// determine optimal number of layers
	float numLayers = lerp(maxSamples, minSamples, abs(dot(float3(0, 0, -1), tangentViewDir))); //should this be (0, 1, 0)?
	numLayers = maxSamples;
	float layerHeight = 1 / numLayers;
	float currLayerHeight = 0;
	float2 offsetPerLayer = parallaxHeight * tangentViewDir.xy / tangentViewDir.z / numLayers; //shift of texture coordinates for each layer
	float2 currUV = heightmapUV; //current texture coordinates
	float currHeightmapHeight = heightmapHeight;

	float dx = ddx(heightmapUV);
	float dy = ddy(heightmapUV);

	//while point is above the surface
	while (currHeightmapHeight > currLayerHeight)
	{
		currLayerHeight += layerHeight; //to the next layer
		currUV -= offsetPerLayer; //shift of texture coordinates
		//currHeightmapHeight = 1 - pomGetBlendedHeightBlendAll(currUV, dx, dy, blendAmounts); //new depth from heightmap
		currHeightmapHeight = 1 - pomGetBlendedHeightBlendAll(hmaps, hmapMults, hmapOffsets, numHmaps, currUV, dx, dy, blendAmounts);
	}

	float2 prevUV = currUV + offsetPerLayer; //previous texture coordinates

	//heights for linear interpolation
	float nextH = currHeightmapHeight - currLayerHeight;
	//float nextH = currHeightmapHeight + currLayerHeight;
	float prevH = (1 - getBlendedHeightBlendAll(hmaps, hmapMults, hmapOffsets, numHmaps, prevUV, blendAmounts)) - currLayerHeight + layerHeight;

	float weight = nextH / (nextH - prevH); //proportions for linear interpolation
	float2 finalTexCoords = (prevUV * weight) + (currUV * (1.0 - weight)); //interpolation of texture coordinates
	parallaxHeight = currLayerHeight + prevH * weight + nextH * (1.0 - weight); //interpolation of depth values

	//return finalTexCoords;
	return currUV;
}

float2 steepParallaxMapping
(
	//float heightmapHeight,
	sampler2D hmaps[4],
	float hmapMults[4],
	float hmapOffsets[4],
	float numHmaps,
	float2 heightmapUV,
	half3 blendAmounts,
	float parallaxAmt,
	float minSamples,
	float maxSamples,
	float3 tangentViewDir
)
{
	//float numLayers = lerp(maxSamples, minSamples, minLayers, abs(dot(float3(0, 0, 1), tangentViewDir)));
	float numLayers = maxSamples;

	float layerHeight = 1 / numLayers;
	float currLayerHeight = 0;
	float2 offsetPerLayer = parallaxAmt * (tangentViewDir.xy / tangentViewDir.z) / numLayers;

	float2 currUV = heightmapUV;
	float dx = ddx(heightmapUV);
	float dy = ddy(heightmapUV);
	//float currHeightmapHeight = heightmapHeight;
	float currHeightmapHeight = pomGetBlendedHeightBlendAll(hmaps, hmapMults, hmapOffsets, numHmaps, currUV, dx, dy, blendAmounts);

	float inc = 0;
	while (currHeightmapHeight > currLayerHeight && inc++ < numLayers)
	{
		currLayerHeight += layerHeight;
		currUV += offsetPerLayer;
		currHeightmapHeight = pomGetBlendedHeightBlendAll(hmaps, hmapMults, hmapOffsets, numHmaps, currUV, dx, dy, blendAmounts);
	}

	//parallaxAmt = currLayerHeight
	return currUV;
}
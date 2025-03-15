/*----getBlendAmounts----*/
//calculates the amount of each texture (base, 1, 2, 3) for given heightmap texels, blend texture
//(r = tex 1, g = tex 2, b = tex 3, "remaining black" i.e (1 - (r + g + b)) = base tex),
//and blend sharpness factor (0 < factor <= 1; lower is sharper blend) 
//returns the amounts as r = 1, g = 2, b = 3, (1 - (r + g + b)) = base

//2 textures
half3 getBlendAmounts(float hBase, float h1, half3 blend, float blendFactor)
{
	//base tex blend amount is "remaining black" after adding other channels together (cannot go below zero)
	float blendBase = 1 - blend.r;
	float minHeightThreshold = max(hBase * blendBase, h1 * blend.r) - blendFactor;

	hBase = max(hBase - minHeightThreshold, 0);
	h1 = max(h1 - minHeightThreshold, 0);

	return half3(blend.r * h1, 0, 0) / ((blendBase * hBase) + (blend.r * h1));
}

//3 textures
half3 getBlendAmounts(float hBase, float h1, float h2, half3 blend, float blendFactor)
{
	//base tex blend amount is "remaining black" after adding other channels together (cannot go below zero)
	float blendBase = max(0, 1 - (blend.r + blend.g));
	float minHeightThreshold = max(max(hBase * blendBase, h1 * blend.r), h2 * blend.g) - blendFactor;

	hBase = max(hBase - minHeightThreshold, 0);
	h1 = max(h1 - minHeightThreshold, 0);
	h2 = max(h2 - minHeightThreshold, 0);

	return half3(blend.r * h1, blend.g * h2, 0) / ((blendBase * hBase) + (blend.r * h1) + (blend.g * h2));
}

//4 textures
half3 getBlendAmounts(float hBase, float h1, float h2, float h3, half3 blend, float blendFactor)
{
	//base tex blend amount is "remaining black" after adding other channels together (cannot go below zero)
	float blendBase = max(0, 1 - (blend.r + blend.g + blend.b));
	float minHeightThreshold = max(max(max(hBase * blendBase, h1 * blend.r), h2 * blend.g), h3 * blend.b) - blendFactor;

	hBase = max(hBase - minHeightThreshold, 0);
	h1 = max(h1 - minHeightThreshold, 0);
	h2 = max(h2 - minHeightThreshold, 0);
	h3 = max(h3 - minHeightThreshold, 0);

	float r = blend.r * h1;
	float g = blend.g * h2;
	float b = blend.b * h3;

	return half3(r, g, b) / ((blendBase * hBase) + (blend.r * h1) + (blend.g * h2) + (blend.b * h3));
}

half3 getBlendAmountsHeightStartTest(float hBase, float h1, float h2, float h3, half3 blend, float blendFactor)
{
	float blendBase = max(0, 1 - (blend.r + blend.g + blend.b));
	float minHeightThreshold = max(max(max(hBase * blendBase, h1 * blend.r), h2 * blend.g), h3 * blend.b) - blendFactor;

	return half3(minHeightThreshold, minHeightThreshold, minHeightThreshold);
}

//hard blend amounts
/*
half3 getBlendAmounts(float hBase, float h1, float h2, float h3, half3 blend, float blendFactor)
{
	half blendBase = max(0, 1 - (blend.r + blend.g + blend.b));
	blendBase *= hBase;
	blend.r *= h1;
	blend.g *= h2;
	blend.b *= h3;

	half maxBlend = max(max(blendBase, blend.r), max(blend.g, blend.b));
	return half3(maxBlend == blend.r, maxBlend == blend.g, maxBlend == blend.b);
}
*/

/*----getColFromBlendAmounts----*/
//adds each input colour together proportional to their respective blend amounts (as per getBlendAmounts())

//4 textures
float4 getColFromBlendAmounts(float4 cBase, float4 c1, float4 c2, float4 c3, float3 blendAmounts)
{
	return (cBase * (1 - (blendAmounts.r + blendAmounts.g + blendAmounts.b))) 
		+ (c1 * blendAmounts.r) + (c2 * blendAmounts.g) + (c3 * blendAmounts.b);
}

//texture array (up to 4 textures)
half3 getColFromBlendAmounts(half3 cols[4], int numCols, half3 blendAmounts)
{
	half3 c = half3(0, 0, 0);

	c += cols[0] * (1 - (blendAmounts.r + blendAmounts.g + blendAmounts.b)); //get colour for base tex
	
	[unroll]
	for (int i = 1; i < numCols; i++)
	{
		c += cols[i] * blendAmounts[i - 1];
	}

	return c;
}
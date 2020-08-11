//blendFactor controls smoothness of blending between the two colours. The lower the number, the harder the falloff proportional to heights;
//0.001 is essentially a hard edge, with exclusively the higher colour making it through 
half3 blend2Base(half3 cBase, float hBase, half3 c1, float h1, half3 blend, float blendFactor)
{
	//(1 - blend.r) sets base to everything that's not red (colour corresponding to c1)
	float blendBase = (1 - blend.r);
	float heightStart = max(hBase * blendBase, h1 * blend.r) - blendFactor;
	float levelBase = max(hBase - heightStart, 0);
	float level1 = max(h1 - heightStart, 0);
	cBase *= blendBase * levelBase;
	c1 *= blend.r * level1;

	return (cBase + c1) / ((blendBase * levelBase) + (blend.r * level1));
}

half3 blend3(half3 cBase, float hBase, half3 c1, float h1, half3 c2, float h2, half3 blend, float blendFactor)
{
	float blendBase = max(0, 1 - (blend.r + blend.g));
	float heightStart = max(max(hBase * blendBase, h1 * blend.r), h2 * blend.g) - blendFactor;

	hBase = max(hBase - heightStart, 0);
	h1 = max(h1 - heightStart, 0);
	h2 = max(h2 - heightStart, 0);

	cBase *= blendBase * hBase; //base is whatever isn't red or green
	c1 *= blend.r * h1;
	c2 *= blend.g * h2;

	return (cBase + c1 + c2) / ((blendBase * hBase) + (blend.r * h1) + (blend.g * h2));
}

half3 blend4(half3 cBase, float hBase, half3 c1, float h1, half3 c2, float h2, half3 c3, float h3, half3 blend, float blendFactor)
{
	//base tex blend amount is "remaining black" after adding other channels together (cannot go below zero)
	float blendBase = max(0, 1 - (blend.r + blend.g + blend.b));
	float heightStart = max(max(max(hBase * blendBase, h1 * blend.r), h2 * blend.g), h3 * blend.b) - blendFactor;

	hBase = max(hBase - heightStart, 0);
	h1 = max(h1 - heightStart, 0);
	h2 = max(h2 - heightStart, 0);
	h3 = max(h3 - heightStart, 0);

	cBase *= blendBase * hBase;
	c1 *= blend.r * h1;
	c2 *= blend.g * h2;
	c3 *= blend.b * h3;

	return (cBase + c1 + c2 + c3) / ((blendBase * hBase) + (blend.r * h1) + (blend.g * h2) + (blend.b * h3));
}

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
	float heightStart = max(hBase * blendBase, h1 * blend.r) - blendFactor;

	hBase = max(hBase - heightStart, 0);
	h1 = max(h1 - heightStart, 0);

	return half3(blend.r * h1, 0, 0) / ((blendBase * hBase) + (blend.r * h1));
}

//3 textures
half3 getBlendAmounts(float hBase, float h1, float h2, half3 blend, float blendFactor)
{
	//base tex blend amount is "remaining black" after adding other channels together (cannot go below zero)
	float blendBase = max(0, 1 - (blend.r + blend.g));
	float heightStart = max(max(hBase * blendBase, h1 * blend.r), h2 * blend.g) - blendFactor;

	hBase = max(hBase - heightStart, 0);
	h1 = max(h1 - heightStart, 0);
	h2 = max(h2 - heightStart, 0);

	return half3(blend.r * h1, blend.g * h2, 0) / ((blendBase * hBase) + (blend.r * h1) + (blend.g * h2));
}

//4 textures
half3 getBlendAmounts(float hBase, float h1, float h2, float h3, half3 blend, float blendFactor)
{
	//base tex blend amount is "remaining black" after adding other channels together (cannot go below zero)
	float blendBase = max(0, 1 - (blend.r + blend.g + blend.b));
	float heightStart = max(max(max(hBase * blendBase, h1 * blend.r), h2 * blend.g), h3 * blend.b) - blendFactor;

	hBase = max(hBase - heightStart, 0);
	h1 = max(h1 - heightStart, 0);
	h2 = max(h2 - heightStart, 0);
	h3 = max(h3 - heightStart, 0);

	float r = blend.r * h1;
	float g = blend.g * h2;
	float b = blend.b * h3;

	return half3(r, g, b) / ((blendBase * hBase) + (blend.r * h1) + (blend.g * h2) + (blend.b * h3));
}

half3 getBlendAmountsHeightStartTest(float hBase, float h1, float h2, float h3, half3 blend, float blendFactor)
{
	float blendBase = max(0, 1 - (blend.r + blend.g + blend.b));
	float heightStart = max(max(max(hBase * blendBase, h1 * blend.r), h2 * blend.g), h3 * blend.b) - blendFactor;

	return half3(heightStart, heightStart, heightStart);
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

//2 textures
half3 getColFromBlendAmounts(half3 cBase, half3 c1, half3 blendAmounts)
{
	return (cBase * (1 - (blendAmounts.r))) + (c1 * blendAmounts.r);
}

//3 textures
half3 getColFromBlendAmounts(half3 cBase, half3 c1, half3 c2, half3 blendAmounts)
{
	return (cBase * (1 - (blendAmounts.r + blendAmounts.g))) + (c1 * blendAmounts.r) + (c2 * blendAmounts.g);
}

//4 textures
half3 getColFromBlendAmounts(half3 cBase, half3 c1, half3 c2, half3 c3, half3 blendAmounts)
{
	return (cBase * (1 - (blendAmounts.r + blendAmounts.g + blendAmounts.b))) 
		+ (c1 * blendAmounts.r) + (c2 * blendAmounts.g) + (c3 * blendAmounts.b);
}

half3 getColFromBlendAmounts(half3 cols[4], int numCols, half3 blendAmounts)
{
	half3 c = half3(0, 0, 0);

	c += cols[0] * (1 - (blendAmounts.r + blendAmounts.g + blendAmounts.b)); //get colour for base tex
	
	for (int i = 1; i < numCols; i++)
	{
		c += cols[i] * blendAmounts[i - 1];
	}

	return c;
}

/*----getBlendedHeightBlendAll/pomGetBlendedHeightBlendAll----*/
//getBlendedHeightBlendAll - function to get blended height with calculated blend amounts and specified UV coordinate
//pomGetBlendedHeightBlendAll - gets blended height using tex2Dgrad and partial derivatives dx and dy, to avoid "unable to unroll loop..." 
//error in POM etc. (see https://www.gamedev.net/forums/topic/621519-why-cant-i-use-tex2d-in-loop-with-hlsl/)

float getBlendedHeightBlendAll
(
	sampler2D heightmapBase, float baseHMult,
	sampler2D heightmap1, float h1Mult,
	sampler2D heightmap2, float h2Mult,
	sampler2D heightmap3, float h3Mult,
	float2 uv, 
	half3 blendAmounts
)
{
	float hBase = tex2D(heightmapBase, uv).r * baseHMult;
	float h1 = tex2D(heightmap1, uv).r * h1Mult;
	float h2 = tex2D(heightmap2, uv).r * h2Mult;
	float h3 = tex2D(heightmap3, uv).r * h3Mult;
	half bBase = 1 - (blendAmounts.r + blendAmounts.g + blendAmounts.b);
	return (hBase * bBase) + (h1 * blendAmounts.r) + (h2 * blendAmounts.g) + (h3 * blendAmounts.b);
}

float getBlendedHeightBlendAll(sampler2D hmaps[4], float hmapMults[4], int numHmaps, float2 uv, half3 blendAmounts)
{
	//initialise with base height
	float blendedHeight = (tex2D(hmaps[0], uv).r * hmapMults[0]) * (1 - (blendAmounts.r + blendAmounts.g + blendAmounts.b));

	for (int i = 1; i < numHmaps; i++)
	{
		blendedHeight += (tex2D(hmaps[i], uv).r * hmapMults[i]) * blendAmounts[i - 1];
	}

	return blendedHeight;
}

float getBlendedHeightAddToBase(sampler2D hmaps[4], float hmapMults[4], int numHmaps, float2 uv, half3 blendAmounts)
{
	//initialise with base height
	float blendedHeight = (tex2D(hmaps[0], uv).r * hmapMults[0]);

	for (int i = 1; i < numHmaps; i++)
	{
		blendedHeight += (tex2D(hmaps[i], uv).r * hmapMults[i]) * blendAmounts[i - 1];
	}

	return blendedHeight;
}

float getBlendedHeightAddAll(sampler2D hmaps[4], float hmapMults[4], int numHmaps, float2 uv, half3 blendAmounts)
{
	//initialise with base height
	float blendedHeight = (tex2D(hmaps[0], uv).r * hmapMults[0]);

	for (int i = 1; i < numHmaps; i++)
	{
		blendedHeight += (tex2D(hmaps[i], uv).r * hmapMults[i]) * blendAmounts[i - 1];
	}

	return blendedHeight;
}

/*
float pomGetBlendedHeightBlendAll
(
	sampler2D heightmapBase, float baseHMult,
	sampler2D heightmap1, float h1Mult,
	sampler2D heightmap2, float h2Mult,
	sampler2D heightmap3, float h3Mult,
	float2 uv,
	float dx, float dy,
	half3 blendAmounts
)
{
	float hBase = tex2Dgrad(heightmapBase, uv, dx, dy).r * baseHMult;
	float h1 = tex2Dgrad(heightmap1, uv, dx, dy).r * h1Mult;
	float h2 = tex2Dgrad(heightmap2, uv, dx, dy).r * h2Mult;
	float h3 = tex2Dgrad(heightmap3, uv, dx, dy).r * h3Mult;
	half bBase = 1 - (blendAmounts.r + blendAmounts.g + blendAmounts.b);
	return (hBase * bBase) + (h1 * blendAmounts.r) + (h2 * blendAmounts.g) + (h3 * blendAmounts.b);
}
*/


//gets blended height using tex2Dgrad and partial derivatives dx and dy, to avoid "unable to unroll loop..." 
float pomGetBlendedHeightBlendAll(sampler2D hmaps[4], float hmapMults[4], int numHmaps, float2 uv, float dx, float dy, half3 blendAmounts)
{
	//initialise with base height
	float blendedHeight = (tex2Dgrad(hmaps[0], uv, dx, dy).r * hmapMults[0]);
	
	for (int i = 1; i < numHmaps; i++)
	{
		blendedHeight += (tex2Dgrad(hmaps[i], uv, dx, dy).r * hmapMults[i]);
	}

	return blendedHeight;
}

//gets blended height, blending heights 1 to 3 and adding them to the base texture height, regardless of whether the base is showing or not.
//good for when you want the base height to remain even if it's not visible, e.g adding moss and other natural accumulations on top of rock
float pomGetBlendedHeightAddToBase(sampler2D hmaps[4], float hmapMults[4], int numHmaps, float2 uv, float dx, float dy, half3 blendAmounts)
{
	//initialise with base height
	float blendedHeight = (tex2Dgrad(hmaps[0], uv, dx, dy).r * hmapMults[0]);
	
	for (int i = 1; i < numHmaps; i++)
	{
		blendedHeight += (tex2Dgrad(hmaps[i], uv, dx, dy).r * hmapMults[i]) * blendAmounts[i - 1];
	}

	return blendedHeight;
}

//adds all heights together, without blend amounts. Be careful not to hit the height limit!
float pomGetBlendedHeightAddAll(sampler2D hmaps[4], float hmapMults[4], int numHmaps, float2 uv, float dx, float dy)
{
	//initialise with base height
	float blendedHeight = (tex2Dgrad(hmaps[0], uv, dx, dy).r * hmapMults[0]);

	for (int i = 1; i < numHmaps; i++)
	{
		blendedHeight += (tex2Dgrad(hmaps[i], uv, dx, dy).r * hmapMults[i]);
	}

	return blendedHeight;
}

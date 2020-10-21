# Texture Blend Shader with Parallax Mapping

## About
This is a Unity implementation of a shader and complementary editor tool which allows for heightmap-based blending of up to four PBR textures on a single material. The shader also includes options for parallax mapping, including parallax occlusion mapping.

The BlendPaint editor utility allows the user to blend textures from within the unity editor using a painting tool.

## Directions for use
### Texture blending
#### Blend maps
Blend maps tell the shader how to blend each texture. Each colour channel represents one texture, in this format:
* Red - texture 1
* Green - texture 2
* Blue - texture 3
* "Remaining black" - base texture

Any pixel which is not wholly red, green, or blue (or a combination) will allow some of the base texture to appear. For example, a completely black (0, 0, 0) blend map will only show the base texture; a completely red (1, 0, 0) blend map will only show texture 1;
a half-red blend map (0.5, 0, 0) will blend the base texture and texture 1 in equal proportion (taking into account their heightmaps).
#### HRMA maps
The texture blending shader uses HRMA (Height, Roughness, Metallic, AO) maps to save on space and GPU sampler usage. Since each of these maps uses only one colour channel, they are packed into a single texture in the following channel order:
* Red - height
* Green - roughness
* Blue - metallic
* Alpha - AO

PBR maps for use with the shader must be packed in this format.

### Parallax mapping
Three types of parallax mapping are supported, each increasing in quality and performance cost:

#### Parallax offset mapping
The simplest type of parallax mapping; cheap but low-quality. Noticeable artifacts at shallow viewing angles

#### Iterative parallax mapping
Parallax offset mapping applied multiple times. May produce "good enough" results on textures with small height differences. Again, noticeable artifacts at shallow viewing angles.

#### Parallax occlusion mapping
Much more computationally expensive, but far nicer results than either of the other methods. Produces a convincing impression of depth even with relatively strong height differences and at shallow viewing angles. Artifacts still noticeable at extreme angles and close up.

  
### BlendPaint
The BlendPaint UI can be found at Window->BlendPaint. From here, you can create a blend map for compatible materials (or use an existing one) and 

#### Controls
When a compatible material is selected, the BlendPaint UI can be used to select the desired texture to paint, adjust the brush size and mode, and select or create a blend map to paint on.
To paint on an object in the scene view, hold P while the cursor is over it (object must be selected and use a compatible material). If you have just used the BlendPaint UI, you will need to refocus the scene view by clicking on it before painting. 

#### Paint modes
##### Normal 
Overwrites the colour(s) in the brush area.

##### Additive
Adds the selected colour to those in the brush area.

##### Subtractive
Subtracts the selected colour from those in the brush area.


## Implementation details

### Texture blending
#### Blend maps

### Parallax mapping
#### Parallax offset mapping

#### Iterative parallax mapping

#### Parallax occlusion mapping


###### Christopher Kirkham, 2020
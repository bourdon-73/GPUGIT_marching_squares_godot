#[compute]
#version 460
// #------ NOISE VALUES ------#


struct Noise {
    float scale;
    float frequency;
    float amplitude;
    float offset;
    // style of noise : 1d, 2d, worlin, wtv...
};


// scale : Detail size
// frequency : Pattern repetition
// amplitude : Height variation

// offset : Horizontal shift

Noise base_terrain = Noise(
    10.0, // scale
    .0003, // frequency
    3.0, // amplitude
    0.0 // offset
);

Noise hill_terrain = Noise(
    5.0, // scale
    .05, // frequency
    .5, // amplitude
    0.2 // offset
);

Noise mountain_terrain = Noise(
    1.0, // scale
    .05, // frequency
    .7, // amplitude
    0.8 // offset
);

Noise noises[2] = Noise[](
    base_terrain,
    hill_terrain
    //mountain_terrain
);



// #------ SIMPLEX NOISE ------#

// Description : Array and textureless GLSL 2D simplex noise function.
//      Author : Ian McEwan, Ashima Arts.
//  Maintainer : stegu
//     Lastmod : 20110822 (ijm)
//     License : Copyright (C) 2011 Ashima Arts. All rights reserved.
//               Distributed under the MIT License. See LICENSE file.
//               https://github.com/ashima/webgl-noise
//               https://github.com/stegu/webgl-noise
// 

vec3 mod289(vec3 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec2 mod289(vec2 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec3 permute(vec3 x) {
  return mod289(((x*34.0)+10.0)*x);
}

float snoise(vec2 v)
  {
  const vec4 C = vec4(0.211324865405187,  // (3.0-sqrt(3.0))/6.0
                      0.366025403784439,  // 0.5*(sqrt(3.0)-1.0)
                     -0.577350269189626,  // -1.0 + 2.0 * C.x
                      0.024390243902439); // 1.0 / 41.0
  // First corner
  vec2 i  = floor(v + dot(v, C.yy) );
  vec2 x0 = v -   i + dot(i, C.xx);

  // Other corners
  vec2 i1;
  //i1.x = step( x0.y, x0.x ); // x0.x > x0.y ? 1.0 : 0.0
  //i1.y = 1.0 - i1.x;
  i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  // x0 = x0 - 0.0 + 0.0 * C.xx ;
  // x1 = x0 - i1 + 1.0 * C.xx ;
  // x2 = x0 - 1.0 + 2.0 * C.xx ;
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;

  // Permutations
  i = mod289(i); // Avoid truncation effects in permutation
  vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
		+ i.x + vec3(0.0, i1.x, 1.0 ));

  vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
  m = m*m ;
  m = m*m ;

  // Gradients: 41 points uniformly over a line, mapped onto a diamond.
  // The ring size 17*17 = 289 is close to a multiple of 41 (41*7 = 287)

  vec3 x = 2.0 * fract(p * C.www) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;

  // Normalise gradients implicitly by scaling m
  // Approximation of: m *= inversesqrt( a0*a0 + h*h );
  m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );

  // Compute final noise value at P
  vec3 g;
  g.x  = a0.x  * x0.x  + h.x  * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
  return 130.0 * dot(m, g);
}

// #------ PERLIN NOISE ------#

//
// GLSL textureless classic 2D noise "cnoise",
// with an RSL-style periodic variant "pnoise".
// Author:  Stefan Gustavson (stefan.gustavson@liu.se)
// Version: 2011-08-22
//
// Many thanks to Ian McEwan of Ashima Arts for the
// ideas for permutation and gradient selection.
//
// Copyright (c) 2011 Stefan Gustavson. All rights reserved.
// Distributed under the MIT license. See LICENSE file.
// https://github.com/stegu/webgl-noise
//

vec4 mod289(vec4 x)
{
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x)
{
  return mod289(((x*34.0)+10.0)*x);
}

vec4 taylorInvSqrt(vec4 r)
{
  return 1.79284291400159 - 0.85373472095314 * r;
}

vec2 fade(vec2 t) {
  return t*t*t*(t*(t*6.0-15.0)+10.0);
}

// Classic Perlin noise
float cnoise(vec2 P)
{
  vec4 Pi = floor(P.xyxy) + vec4(0.0, 0.0, 1.0, 1.0);
  vec4 Pf = fract(P.xyxy) - vec4(0.0, 0.0, 1.0, 1.0);
  Pi = mod289(Pi); // To avoid truncation effects in permutation
  vec4 ix = Pi.xzxz;
  vec4 iy = Pi.yyww;
  vec4 fx = Pf.xzxz;
  vec4 fy = Pf.yyww;

  vec4 i = permute(permute(ix) + iy);

  vec4 gx = fract(i * (1.0 / 41.0)) * 2.0 - 1.0 ;
  vec4 gy = abs(gx) - 0.5 ;
  vec4 tx = floor(gx + 0.5);
  gx = gx - tx;

  vec2 g00 = vec2(gx.x,gy.x);
  vec2 g10 = vec2(gx.y,gy.y);
  vec2 g01 = vec2(gx.z,gy.z);
  vec2 g11 = vec2(gx.w,gy.w);

  vec4 norm = taylorInvSqrt(vec4(dot(g00, g00), dot(g01, g01), dot(g10, g10), dot(g11, g11)));
  g00 *= norm.x;  
  g01 *= norm.y;  
  g10 *= norm.z;  
  g11 *= norm.w;  

  float n00 = dot(g00, vec2(fx.x, fy.x));
  float n10 = dot(g10, vec2(fx.y, fy.y));
  float n01 = dot(g01, vec2(fx.z, fy.z));
  float n11 = dot(g11, vec2(fx.w, fy.w));

  vec2 fade_xy = fade(Pf.xy);
  vec2 n_x = mix(vec2(n00, n01), vec2(n10, n11), fade_xy.x);
  float n_xy = mix(n_x.x, n_x.y, fade_xy.y);
  return 2.3 * n_xy;
}

// Classic Perlin noise, periodic variant
float pnoise(vec2 P, vec2 rep)
{
  vec4 Pi = floor(P.xyxy) + vec4(0.0, 0.0, 1.0, 1.0);
  vec4 Pf = fract(P.xyxy) - vec4(0.0, 0.0, 1.0, 1.0);
  Pi = mod(Pi, rep.xyxy); // To create noise with explicit period
  Pi = mod289(Pi);        // To avoid truncation effects in permutation
  vec4 ix = Pi.xzxz;
  vec4 iy = Pi.yyww;
  vec4 fx = Pf.xzxz;
  vec4 fy = Pf.yyww;

  vec4 i = permute(permute(ix) + iy);

  vec4 gx = fract(i * (1.0 / 41.0)) * 2.0 - 1.0 ;
  vec4 gy = abs(gx) - 0.5 ;
  vec4 tx = floor(gx + 0.5);
  gx = gx - tx;

  vec2 g00 = vec2(gx.x,gy.x);
  vec2 g10 = vec2(gx.y,gy.y);
  vec2 g01 = vec2(gx.z,gy.z);
  vec2 g11 = vec2(gx.w,gy.w);

  vec4 norm = taylorInvSqrt(vec4(dot(g00, g00), dot(g01, g01), dot(g10, g10), dot(g11, g11)));
  g00 *= norm.x;  
  g01 *= norm.y;  
  g10 *= norm.z;  
  g11 *= norm.w;  

  float n00 = dot(g00, vec2(fx.x, fy.x));
  float n10 = dot(g10, vec2(fx.y, fy.y));
  float n01 = dot(g01, vec2(fx.z, fy.z));
  float n11 = dot(g11, vec2(fx.w, fy.w));

  vec2 fade_xy = fade(Pf.xy);
  vec2 n_x = mix(vec2(n00, n01), vec2(n10, n11), fade_xy.x);
  float n_xy = mix(n_x.x, n_x.y, fade_xy.y);
  return 2.3 * n_xy;
}


struct Triangle {
	vec2 a;
	vec2 b;
	vec2 c;
	//#vec4 norm;
};

struct Line {
	vec2 a;
	vec2 b;
	//#vec4 norm;
};

// #------ Marching Cubes ------#

const int cornerIndexAFromEdge[8] = {0, 0, 0, 0, 2, 0, 7, 0};
const int cornerIndexBFromEdge[8] = {0, 2, 0, 5, 7, 0, 5, 0};

//surface lenghts
//0,2,2,2,2,4,2,2,2,2,4,2,2,2,2,4
//num of verts for surfaces

// EDGES
//   0----1----2----
//   |         |
//   3         4
//   |         |
//   5----6----7----


const int surfaceLut_offsets[16] = {
  0, 
  0, 2, 4, 6, 8, 12, 14, 
  16, 18, 20, 24, 26, 28, 30, 32
};

const int offsets[16] = {
  0, 
  0, 3, 6, 12, 15, 27, 33, 
  42, 45, 51, 63, 72, 78, 87, 96
};

const int lengths[16] = {
  0, 
  1, 1, 2, 1, 4, 2, 3,
  1, 2, 4, 3, 2, 3, 3, 2
};

layout(set = 0, binding = 0, std430) restrict buffer TriangleBuffer
{
	Triangle data[];
}
triangleBuffer;

layout(set = 0, binding = 1, std430) restrict buffer ParamsBuffer
{
	float time;
	float noiseScale;
	float isoLevel;
	float numVoxelsPerAxis;
	float scale;
	float posX;
	float posY;
	float noiseOffsetX;
	float noiseOffsetY;
}
params;

layout(set = 0, binding = 2, std430) coherent buffer Counter
{
	uint counter;
};

layout(set = 0, binding = 3, std430) restrict buffer LutBuffer
{
	int data[];
}
lut;

layout(set = 0, binding = 4, std430) restrict buffer MatrixBuffer
{
	vec4 data[];
}
matrix;

layout(set = 0, binding = 5, std430) restrict buffer SurfaceBuffer
{
    Line data[];
}
surface_verts;

layout(set = 0, binding = 6, std430) restrict buffer SurfaceLutBuffer
{
	int data[];
}
Surface_lut;

layout(set = 0, binding = 7, std430) coherent buffer Surface_Counter
{
	uint Surfcounter;
};
// surf_count;

// layout(set = 0, binding = 5, std430) coherent buffer MATCounter
// {
// 	uint matcounter;
// };
// vec4 evaluate(vec2 coord)
// {
//     float cellSize = 1.0 / params.numVoxelsPerAxis * params.scale;
//     float cx = int(params.posX / cellSize + 0.5 * sign(params.posX)) * cellSize;
//     float cy = int(params.posY / cellSize + 0.5 * sign(params.posY)) * cellSize;
//     vec2 centreSnapped = vec2(cx, cy);

//     vec2 posNorm = coord / vec2(params.numVoxelsPerAxis) - vec2(0.5);
//     vec2 worldPos = posNorm * params.scale + centreSnapped;

//     float threshold = 0.3; // Adjust this value to change the terrain shape
//     float noise = -worldPos.y < threshold ? 1.0 : 0.0;//snoise(worldPos * 50.0) : 0.0;
//     noise = (worldPos.y - 100) / 300 + noise;

//     return vec4(worldPos, noise, 0);
// }


// evaluate function but for trees
//vec4 tree_evaluate(vec2 coord)

// vec4 evaluate(vec2 coord)
// {   
// 	float cellSize = 1.0 / params.numVoxelsPerAxis * params.scale;
// 	float cx = int(params.posX / cellSize + 0.5 * sign(params.posX)) * cellSize;
// 	float cy = int(params.posY / cellSize + 0.5 * sign(params.posY)) * cellSize;
// 	vec2 centreSnapped = vec2(cx, cy);

// 	vec2 posNorm = coord / vec2(params.numVoxelsPerAxis) - vec2(0.5);
// 	vec2 worldPos = posNorm * params.scale;// + centreSnapped;
// 	vec2 noiseOffset = vec2(params.noiseOffsetX, params.noiseOffsetY);
// 	vec2 samplePos = (worldPos + noiseOffset) * params.noiseScale / params.scale;

// 	float sum = 0;
// 	float amplitude = 1;
// 	float weight = 1;
	
// 	for (int i = 0; i < 4; i ++)
// 	{
// 		float noise = snoise(samplePos) * 2 - 1;
// 		noise = 1 - abs(noise);
// 		noise *= noise;
// 		noise *= weight;
// 		weight = max(0, min(1, noise * 10));
// 		sum += noise * amplitude;
// 		samplePos *= 2;
// 		amplitude *= 0.5;
// 	}
// 	float density = sum;
// 	//density = -(worldPos.y+100)/300 + density;

// 	return vec4(worldPos, density, 0);
// }
// vec4 evaluate(vec2 coord)
// {   
//   float terrain_type = 0.0;
// 	float cellSize = 1.0 / params.numVoxelsPerAxis * params.scale;
// 	float cx = int(params.posX / cellSize + 0.5 * sign(params.posX)) * cellSize;
// 	float cy = int(params.posY / cellSize + 0.5 * sign(params.posY)) * cellSize;
// 	vec2 centreSnapped = vec2(cx, cy);

// 	vec2 posNorm = coord / vec2(params.numVoxelsPerAxis) - vec2(0.5);
// 	vec2 worldPos = posNorm * params.scale + centreSnapped;
// 	vec2 noiseOffset = vec2(params.noiseOffsetX, params.noiseOffsetY);

//   float perlinNoise = cnoise(vec2(worldPos.x * 0.0015 + noiseOffset.x, 0)) * 2.0 - 1.0;
//   float simplexNoise = snoise(vec2(worldPos.x * 0.01 + noiseOffset.x, worldPos.y * 0.01 + noiseOffset.y));

//   float noise = perlinNoise; // Add Simplex noise to Perlin noise base
//   noise = noise * 18.0 + worldPos.y * 0.1; // Add some vertical offset

//   //float density = noise > 0.0 ? 1.0 : 0.0; // Create a solid terrain

//   // To create holes, subtract the simplex noise from the density
//   //density += simplexNoise * 0.5; // Adjust the value to control the hole size

//   // MATCH terrain_types:
//   // 1 : type rocks
//   // 2 : type water
//   // 3 : type brickwall

//   return vec4(worldPos, noise, terrain_type);

// // worldPos.x * 0.1: This controls the frequency of the noise. A smaller value will result in a more gradual, sweeping terrain, while a larger value will create a more detailed, choppy terrain.
// // noiseOffset.x: This controls the offset of the noise, which can be used to create a different terrain shape each time the program is run.
// // * 2.0 - 1.0: This scales and shifts the noise value to create a more pronounced terrain shape.
// // * 10.0: This controls the amplitude of the noise, which affects the overall height of the terrain.
// // + worldPos.y * 0.1: This adds a vertical offset to the noise, which can be used to create a more varied terrain shape.

// }




vec4 evaluate(vec2 coord)
{   
    float terrain_type = 0.0;
    float cellSize = 1.0 / params.numVoxelsPerAxis * params.scale;
    float cx = int(params.posX / cellSize + 0.5 * sign(params.posX)) * cellSize;
    float cy = int(params.posY / cellSize + 0.5 * sign(params.posY)) * cellSize;
    vec2 centreSnapped = vec2(cx, cy);

    vec2 posNorm = coord / vec2(params.numVoxelsPerAxis) - vec2(0.5);
    vec2 worldPos = posNorm * params.scale + centreSnapped;
    vec2 noiseOffset = vec2(params.noiseOffsetX, params.noiseOffsetY);

    float noise = 0.0;
    float frequency = 1.0;
    float amplitude = 1.0;

    for (int i = 0; i < noises.length(); i++) {
        Noise n = noises[i];
        noise += cnoise(vec2(worldPos.x * n.frequency + noiseOffset.x, worldPos.y * n.frequency + noiseOffset.y)) 
               * n.amplitude 
               * amplitude;
        frequency *= 2.0; // octave multiplier
        amplitude *= 0.5; // amplitude decrease per octave
    }

    noise = noise * 18.0 + worldPos.y * 0.1;

    return vec4(worldPos, noise, terrain_type);
}


// vec4 interpolateVerts(vec4 v1, vec4 v2, float isoLevel)
// {
// 	//return (v1 + v2) * 0.5;
// 	float t = (isoLevel - v1.z) / (v2.z - v1.z);
// 	return v1 + t * (v2 - v1);
// }


vec2 interpolateVerts(vec4 v1, vec4 v2, float isoLevel)
{
	//return (v1 + v2) * 0.5;
	float t = (isoLevel - v1.z) / (v2.z - v1.z);
	return v1.xy + t * (v2.xy - v1.xy);
}



void genTree(vec2 chunkPos) {
  // Calculate the center of the chunk
  vec2 center = chunkPos + vec2(0.5, 0.5);
  
  // Add a point density of 1 to the center of the chunk
  //evaluate(center).z = 1.0;
}



layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void main(){
  vec3 id = gl_GlobalInvocationID;
    //vec3 id = vec3(4, 5, 0);
	//uint idx = uint(gl_GlobalInvocationID.x + gl_GlobalInvocationID.y * params.numVoxelsPerAxis);
   

  //# 4 corners of the current cell
  vec4 cellCorners[4] = {
      evaluate(vec2(id.x + 0, id.y + 0)),
      evaluate(vec2(id.x + 1, id.y + 0)),
      evaluate(vec2(id.x + 0, id.y + 1)),
      evaluate(vec2(id.x + 1, id.y + 1))
  };

  //# EDGES
  //float voxscale = 32;
  float voxscale =( 1.0 / params.numVoxelsPerAxis * params.scale)/2;
  vec2 cellEdges[4] = {
      interpolateVerts(cellCorners[0], cellCorners[1], params.isoLevel),
      interpolateVerts(cellCorners[2], cellCorners[0], params.isoLevel),
      interpolateVerts(cellCorners[1], cellCorners[3], params.isoLevel),
      interpolateVerts(cellCorners[2], cellCorners[3], params.isoLevel)
    // vec2(cellCorners[0].xy+vec2(voxscale, 0)),
    // vec2(cellCorners[0].xy+vec2(0, voxscale)),
    // vec2(cellCorners[3].xy-vec2(0, voxscale)),
    // vec2(cellCorners[3].xy-vec2(voxscale, 0))
  };

  // Points
  //   0----1----2
  //   |         |
  //   3         4
  //   |         |
  //   5----6----7
  // all of em
  vec2 SquarePoints[8] = {
      vec2(cellCorners[0].xy), // 0
      vec2(cellEdges[0].xy),   // 1
      vec2(cellCorners[1].xy), // 2
      vec2(cellEdges[1].xy),   // 3
      vec2(cellEdges[2].xy),   // 4
      vec2(cellCorners[2].xy), // 5
      vec2(cellEdges[3].xy),   // 6
      vec2(cellCorners[3].xy)  // 7
  };


	//triangleBuffer.data[0] = 5555;
	// uint ind = atomicAdd(matcounter, 1u);
	// //matrix.data[0] = cellCorners[3];


  // find bit 0000 -> 1111
  uint cellIndex = 0;
  float isoLevel = params.isoLevel;
  if (cellCorners[0].z > isoLevel) cellIndex |= 8;
  if (cellCorners[1].z > isoLevel) cellIndex |= 4;
  if (cellCorners[2].z > isoLevel) cellIndex |= 1;
  if (cellCorners[3].z > isoLevel) cellIndex |= 2;

  //cellIndex = 13;
  // find Number of triangles + where we start searching in the lut at 
  int numIndices = lengths[cellIndex];
  int offset = offsets[cellIndex];
  // gen trees


  // vec2 treePos = vec2(id.x + 0.5, id.y + 0.5); // Position of the tree
  // for (int i = 0; i < 2; i++)
  // {
  //   // config 11
  //   int off = 96;
  //   // 3 triangles
  //   // these vert 0,1,4;0,4,5;4,5,7 -> get from LUT
	// 	int v0 = lut.data[off + (i*3)]; //0
	// 	int v1 = lut.data[off + 1 + (i*3)];//8
	// 	int v2 = lut.data[off + 2 + (i*3)];//3

  //   Triangle currTri;
  //   currTri.a = SquarePoints[v0];
  //   currTri.b = SquarePoints[v1];
  //   currTri.c = SquarePoints[v2];

  //   uint index = atomicAdd(counter, 1u);
	// 	triangleBuffer.data[index] = currTri;

  // }

  // gen terrain
  for (int i = 0; i < numIndices; i++)
  {
    // config 11
    // 3 triangles
    // these vert 0,1,4;0,4,5;4,5,7 -> get from LUT
		int v0 = lut.data[offset + (i*3)]; //0
		int v1 = lut.data[offset + 1 + (i*3)];//8
		int v2 = lut.data[offset + 2 + (i*3)];//3

    Triangle currTri;
    currTri.a = SquarePoints[v0];
    currTri.b = SquarePoints[v1];
    currTri.c = SquarePoints[v2];

    uint index = atomicAdd(counter, 1u);
		triangleBuffer.data[index] = currTri;


  }

// EDGES
//   0----1----2----
//   |         |
//   3         4
//   |         |
//   5----6----7----
  // get the surface
  int num_surface_verts = 2;
  int surfaceLut_offset = surfaceLut_offsets[4];
  //int surfaceLut_offset = surfaceLut_offsets[cellIndex];

  for (int i = 0; i < 1; i++)
  {

      // wrong code
      // int p0 = Surface_lut.data[surfaceLut_offset ]; //0
      // int p1 = Surface_lut.data[surfaceLut_offset + 1 ]; //0

      //check lut
      // not lines Points
      int p0 = Surface_lut.data[surfaceLut_offset]; //0
      int p1 = Surface_lut.data[surfaceLut_offset + 1]; //0
      //line_b surface_lut.data[doe];
      Line currLine;
      currLine.a = SquarePoints[p0];
      currLine.b = SquarePoints[p1];
      // then append to the surface_verts


      //surface_verts.data[int(id.x + params.posX)] = float(5.0);
      // if(cellIndex != 16 || cellIndex != 0)
      // {
      uint index = atomicAdd(Surfcounter, 1u);
      surface_verts.data[index] = currLine;
    // }

  }
  uint idx = uint(gl_GlobalInvocationID.x + gl_GlobalInvocationID.y * params.numVoxelsPerAxis);
	matrix.data[idx] = vec4(evaluate(vec2(id.x + 0, id.y + 0)));
}


  // Triangle currTri1;
  // currTri1.a = vec2(cellCorners[0]);
  // currTri1.b = vec2(cellCorners[1]);
  // currTri1.c = vec2(cellCorners[3]);

  // uint index1 = atomicAdd(counter, 1u);
  // triangleBuffer.data[index1] = currTri1;

  // Triangle currTri2;
  // currTri2.a = vec2(cellCorners[0]);
  // currTri2.b = vec2(cellCorners[3]);
  // currTri2.c = vec2(cellCorners[2]);

  // uint index2 = atomicAdd(counter, 1u);
  // //triangleBuffer.data[index2] = currTri2;
  // // }



// // Define noise functions
// float perlin1D(float x);
// float perlin2D(vec2 pos);
// float simplexNoise(vec2 pos);

// // Define terrain types
// enum TerrainType { WATER, ROCK, BRICKS, WOOD };

// // Define a structure to hold the data
// struct TerrainData {
//   vec2 position;
//   float density;
//   TerrainType type;
// };

// // Function to generate terrain data
// TerrainData generateTerrainData(vec2 position) {
//   // Perlin noise for terrain height
//   float terrainHeight = perlin1D(position.x);
  
//   // Perlin noise for mineral distribution
//   float mineralDistribution = perlin2D(position);
  
//   // Simplex noise for water density
//   float waterDensity = simplexNoise(position);
  
//   // Determine terrain type based on noise values
//   TerrainType type;
//   if (waterDensity > 0.5) {
//     type = WATER;
//   } else if (terrainHeight > 0.3) {
//     type = ROCK;
//   } else if (mineralDistribution > 0.7) {
//     type = BRICKS;
//   } else {
//     type = WOOD;
//   }
  
//   // Return terrain data
//   return TerrainData(position, terrainHeight, type);
// }

// // Example usage
// void main() {
//   vec2 position = gl_FragCoord.xy;
//   TerrainData data = generateTerrainData(position);
//   // Use data.density and data.type to color the pixel or perform other operations
// }
// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/InteriorMap"
{
	Properties
	{
		// Float for the height of a building's floor
		_FloorHeight("Floor Height", float) = 2
		// Float between 0 and 1
		_DefaultReflection("Reflection", float) = 0.5
		// Reduces or increasing the chance of lighting occuring.
		_LightingOffset("Lighting Offset", float) = 0
		// Float between 0 and 24
		_SimTime("Time of Day", float) = 12
		_NoiseTexture("Noise Texture", 2D) = "white" {}
		_BackWall("BackWall", 2D) = "white" {}
		_Window("Window", 2D) = "black" {}
		_Furniture("Furniture", 2D) = "" {}
		_Ground("Ground", 2D) = "black" {}
		_Ceiling("Ceiling", 2D) = "black" {}
		_Cube("Cubemap", Cube) = "_Skybox" {}
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert // Define function 'vert' as vertex shader
			#pragma fragment frag // Define function 'frag' as fragment shader
			// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
				float3 pos : TEXCOORD1;
				float3 normal : NORMAL;
			};
			// Textures and cubemaps
			sampler2D _BackWall;
			sampler2D _Window;
			sampler2D _Ground;
			sampler2D _Furniture;
			sampler2D _Ceiling;
			samplerCUBE _Cube;
			sampler2D _NoiseTexture;

			float4 _MainTex_ST;

			// Variables 
			float _FloorHeight;
			// Default reflection contribution
			float _DefaultReflection;
			// Reduces or increasing the chance of lighting occuring.
			float _LightingOffset;
			// Time of day
			float _SimTime;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = mul(unity_ObjectToWorld, v.vertex);
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.normal = mul(unity_ObjectToWorld, float4(v.normal, 0)).xyz;
				//o.normal = v.normal.xyz;
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}
			

			// Assumes normalised directions
			bool IntersectionAgainstPlane(float3 rayOrigin, float3 rayDirection, float3 planePos, float3 planeNormal, out float3 intersection) {
				float rDotn = dot(rayDirection, planeNormal);

				if (abs(rDotn) > 0.000001) {
					float s = dot((planePos - rayOrigin), planeNormal) / rDotn;
					intersection = rayOrigin + s * rayDirection; 

					return (s != 0);
				}

				return false;
			}

			float DistanceToPlane(float3 p1, float3 planePoint, float3 planeNormal) {
				float3 inter;
				IntersectionAgainstPlane(p1, planeNormal, p1, planeNormal, inter);
				return length(p1 - inter);
			}

			float3 XIntercept(float3 dir, float3 pointOnPlane) {
				float m = pointOnPlane.z / dir.z;
				return float3(pointOnPlane.x + (m * dir.x), 0, 0);
			}

			float3 ZIntercept(float3 dir, float3 pointOnPlane) {
				float m = pointOnPlane.x / dir.x;
				return float3(0, 0, pointOnPlane.z + (m * dir.z));
			}

			float3 AxisIntercept(float3 dir, float3 pointOnPlane) {
				if (dir.z == 0) {
					return ZIntercept(dir, pointOnPlane);
				}else {
					return XIntercept(dir, pointOnPlane);
				}
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				/* Wall intersection and rendering part */
				float ceilHeight = (ceil(i.pos.y / _FloorHeight) * _FloorHeight);
				float3 rayDirection = normalize(i.pos - _WorldSpaceCameraPos.xyz);

				// if negative, intersect with floor by moving plane down a level
				float3 ceilNormal = float3(0, 1, 0);
				float3 planePos = float3(0, ceilHeight, 0);
				if (i.pos.y < _WorldSpaceCameraPos.y) {
					planePos.y -= _FloorHeight;
				}
				float3 inter;
				bool didIntersect = IntersectionAgainstPlane(i.pos.xyz, rayDirection, planePos, ceilNormal, inter);

				float3 backinter;
				IntersectionAgainstPlane(i.pos.xyz, rayDirection, i.pos - i.normal * 2, i.normal, backinter);
				float4 col;
				/* Interior */
				// Use backwall its intersection is closer
				if (length(backinter - i.pos) > length(inter - i.pos)) {
					// Use ground for this plane if it's below us
					if (i.pos.y < _WorldSpaceCameraPos.y) {
						col = tex2D(_Ground, inter.xz / _FloorHeight);
					} else {
						col = tex2D(_Ceiling, inter.xz / _FloorHeight);
					}
				} else {
					col = tex2D(_BackWall, backinter.xy / _FloorHeight);
				}
				if (abs(i.pos.y - ceilHeight) < _FloorHeight / 20) {
					col = tex2D(_BackWall, i.uv / _FloorHeight);
				}
				float3 furInter;
				IntersectionAgainstPlane(i.pos.xyz, rayDirection, i.pos - i.normal * 1, i.normal, furInter);
				float fx = dot(-i.normal.xz, normalize(furInter.xz - i.pos.xz)) * length(furInter.xz - i.pos.xz);
				float4 furCol = tex2D(_Furniture, float2(furInter.x - fx, furInter.y));
				if (length(furInter - i.pos) < length(inter - i.pos) && furCol.a != 0) {
					col.rgb = furCol.rgb;
				}
				/* Lighting and Reflection / Exterior */
				// Round the xz coords to large chunks for the noise function
				float2 roundPos = (ceil(i.pos.xz / (_FloorHeight * 2)) * _FloorHeight);
				float2 noiseVars = float2(roundPos.x / 100, ceilHeight / 10);
				float4 noiseColour = tex2D(_NoiseTexture, noiseVars);

				// Pick a random value to use as a threshold
				float c = lerp(noiseColour.r, noiseColour.g, clamp(abs(roundPos.y) / 100, 0, 1));
				c += abs(sin(((_SimTime + 12) * noiseColour.b) + (noiseColour.b * 20)) * noiseColour.b * 0.5);
				// 0 to 1 float of distance to midnight. 0 at 5pm, 1 at midnight, 0 at 7am
				float timeFromMidnight = clamp((abs(_SimTime - 12) - 4) / 6, 0, 1);

				// Idea: use last var as part of a slight flicker over time? sine wave of time * (z - 0.5)
				// If the value is less than the time to midnight, turn the light on
				if (c - _LightingOffset < timeFromMidnight) {
					// Make the window kinda yellowy if night, else white. Also reduces reflection
					_DefaultReflection = 0.05;
					col.rgb += float3(0.9, 0.7, 0.3) * clamp(noiseColour.z, 0.1, 0.9); // Yellowy colour
				}else {
					// Maker darker closer to midnight
					col.rgb -= timeFromMidnight * 0.8;
				}
				// Reflection colour
				float4 refl = texCUBE(_Cube, reflect(rayDirection, i.normal));
				float4 windowCol = tex2D(_Window, i.pos.xy / _FloorHeight);
				
				// Use a part of the window
				col.rgb = lerp(col.rgb, windowCol.rgb, 0.4);
				// Use x of the reflection
				col.rgb = lerp(col.rgb, refl.rgb, _DefaultReflection);
				//col.rgb = noiseVars.y;
				//col.rgb = abs(sin(_Time.y + (noiseColour.b * 20)) * noiseColour.b) * 0.4;
				return col;
			}

			ENDCG
		}
	}
}

Shader "Unlit/Clustering"
{
	Properties
	{
		_Tint ("Tint", Color) = (1, 1, 1, 1)
		_MainTex ("Albedo", 2D) = "white" {}
		[Gamma] _Metallic ("Metallic", Range(0, 1)) = 0
		_Smoothness ("Smoothness", Range(0, 1)) = 0.1
	}
	SubShader
	{
		Tags {
			"RenderType"="Opaque"
			"LightMode" = "ForwardBase"
		}

		LOD 400

		Pass
		{
			CGPROGRAM
			#pragma target 4.5
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			// #pragma multi_compile_fog
			
			#include "UnityPBSLighting.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;

			float4 _Tint;
			float _Metallic;
			float _Smoothness;

			struct v2f
			{
				float depth:		DEPTH;
				float2 uv:		TEXCOORD0;
				float3 normal:	TEXCOORD1;
				float3 worldPos:TEXCOORD2;
				// UNITY_FOG_COORDS(1)
			};

			v2f vert (appdata_base v, out float4 outpos : SV_POSITION)
			{
				v2f o;
				outpos = UnityObjectToClipPos(v.vertex);
				o.depth = COMPUTE_DEPTH_01;
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.normal = UnityObjectToWorldNormal(v.normal);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				// UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			struct lightListIndex
			{
				uint listsize;
				uint index;
			};

			StructuredBuffer<float4x4> _LightParams;
			int _LightParamsSize;

			StructuredBuffer<uint> _LightLists;
			StructuredBuffer<lightListIndex> _Clusters;
			int _Cellsx;
			int _Cellsy;
			int _Cellsz;
			int _TileSize;
			int _LightListsSize;
			
			float4 frag (v2f i, UNITY_VPOS_TYPE vpos : VPOS ) : SV_Target
			{
				float depth = i.depth;
				//depth = trunc(depth * 32.0) / 32.0;
				lightListIndex cluster = _Clusters[(int)((_ScreenParams.x - 1 - vpos.x) * (1.0 / _TileSize)) * _Cellsy * _Cellsz
												 + (int)((_ScreenParams.y - 1 - vpos.y) * (1.0 / _TileSize)) * _Cellsz
												 + (int)(depth * (float)(_Cellsz - 1))];
				//clip(depth);
				//if (cluster.listsize == 0) return float4(depth, depth, depth, 1);
				uint lgtindex = _LightLists[cluster.index];
				float numLightf = cluster.listsize / 16.0;
				float4 acccol = float4(0, 0, 0, 1);
				float3 specularTint = float3(0, 0, 0);
				i.normal = normalize(i.normal);
				float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
				float3 albedo = tex2D(_MainTex, i.uv).rgb * _Tint.rgb;
				for (uint j = 0; j<= cluster.listsize; ++j)
				{
					float4x4 lightParams = _LightParams[lgtindex + j];
					float lrange = lightParams._m30;
					float3 lpos = lightParams._m00_m10_m20;
					float3 ldir = lpos - i.worldPos;
					if ( length(ldir) < lrange )
					{

						UnityIndirect indirectLight;
						indirectLight.diffuse = 0;
						indirectLight.specular = specularTint;

						//acccol.xyz = ((acccol.xyz * (i + 1)) + lightColor) / (i + 2);

						float oneMinusReflectivity;
						albedo = DiffuseAndSpecularFromMetallic(
							albedo, _Metallic, specularTint, oneMinusReflectivity
						);

						UnityLight light;
						light.color = lightParams._m01_m11_m21;
						light.dir = normalize(ldir);

						acccol = UNITY_BRDF_PBS(
							albedo, specularTint,
							oneMinusReflectivity, _Smoothness,
							i.normal, viewDir,
							light, indirectLight
						);
					}
				}
				// acccol.w = 1;
				// UNITY_APPLY_FOG(i.fogCoord, col);
				//return float4(depth, depth, depth, 1);
				float4 numcol = float4(acccol.r, acccol.g, numLightf, 1);
				return numcol;
				//return light;
			}
			ENDCG

		}
	}
}

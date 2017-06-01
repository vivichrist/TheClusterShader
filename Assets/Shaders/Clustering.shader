Shader "Unlit/Clustering"
{
	Properties
	{

	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 400

		Pass
		{
			CGPROGRAM
// Upgrade NOTE: excluded shader from DX11; has structs without semantics (struct v2f members zed)
#pragma exclude_renderers d3d11
			#pragma target 4.5
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			// #pragma multi_compile_fog
			
			#include "UnityCG.cginc"


			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv	  : TEXCOORD0;
			};

			struct v2f
			{
				float2 pos		 : TEXCOORD0;
				//float2 uv		 : TEXCOORD1;
				// UNITY_FOG_COORDS(1)
			};

			v2f vert (appdata v, out float4 outpos : SV_POSITION)
			{
				v2f o;
				outpos = UnityObjectToClipPos(v.vertex);
				o.pos = outpos.zw;
				//o.uv = v.uv;
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
				float2 pos;
				pos.x = i.pos.x / i.pos.y;
				pos.y = i.pos.y;
				float depth = Linear01Depth(pos.x);
				lightListIndex cluster = _Clusters[(int)((float)vpos.x / (float)_TileSize) * _Cellsy * _Cellsz
												 + (int)((float)vpos.y / (float)_TileSize) * _Cellsz
												 + depth * _Cellsz];
				if (cluster.listsize == 0) return float4(0.0, 0.0, 0.0, 1.0);
				uint lgtindex = _LightLists[cluster.index];
				float4 light = _LightParams[lgtindex]._m01_m11_m21_m31;
//				float4 acccol;
				float4 col;
//				for (int i = 0; i< cluster.listsize; ++i)
//				{
					col.w = 1;
					col.xyz = light.xyz;
//					acccol = ((acccol * i) + col) / i + 1;
//				}
				// apply fog
				// UNITY_APPLY_FOG(i.fogCoord, col);
//				if (depth < 0.01) 
//					return float4(1.0, 0.0, depth, 1.0);
//				else if (depth > 0.9) 
//					return float4(0.0, 1.0, depth, 1.0);
//				else
//					return float4(vpos.x / _ScreenParams.x, vpos.y / _ScreenParams.y, 0.0, 1.0);
				return light;
			}
			ENDCG

		}
	}
}

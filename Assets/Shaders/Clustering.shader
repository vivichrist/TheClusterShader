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
				float2 zdepth	 : TEXCOORD0;
				// UNITY_FOG_COORDS(1)
			};

			v2f vert (appdata v, out float4 outpos : SV_POSITION)
			{
				v2f o;
				outpos = UnityObjectToClipPos(v.vertex);
				o.zdepth = outpos.zw;
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
				float depth = Linear01Depth(i.zdepth.x / i.zdepth.y);
				lightListIndex cluster = _Clusters[((int)(vpos.x / _TileSize) * _Cellsy * _Cellsz)
												 + ((int)((_ScreenParams.y - vpos.y) / _TileSize) * _Cellsz)
												 + (depth * _Cellsz)];
				if (cluster.listsize == 0) return float4(depth, depth, depth, 1.0);
				uint lgtindex = _LightLists[cluster.index];
				float4 acccol = float4(depth, depth, depth, 1.0);
				float3 col;
				for (int i = 0; i< min(cluster.listsize, 5); ++i)
				{
					col = _LightParams[lgtindex + i]._m01_m11_m21;
					acccol.xyz = ((acccol.xyz * (i + 1)) + col) / (i + 2);
				}
				acccol.w = 1;
				// UNITY_APPLY_FOG(i.fogCoord, col);
				return acccol;
				//return light;
			}
			ENDCG

		}
	}
}

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
			
			#include "UnityPBSLighting.cginc"

			float4 _Tint;
			sampler2D _MainTex;
			float4 _MainTex_ST;

			float _Metallic;
			float _Smoothness;


			struct appdata
			{
				float4 vertex : POSITION;
				float4 normal : NORMAL;
				float2 uv	  : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv:		TEXCOORD0;
				float3 normal:	TEXCOORD1;
				float3 worldPos:TEXCOORD2;
				float2 zdepth:	TEXCOORD3;
				// UNITY_FOG_COORDS(1)
			};

			v2f vert (appdata v, out float4 outpos : SV_POSITION)
			{
				v2f o;
				outpos = UnityObjectToClipPos(v.vertex);
				o.zdepth = outpos.zw;
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.normal = UnityObjectToWorldNormal(v.normal);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
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
				i.normal = normalize(i.normal);
				float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
				float depth = Linear01Depth(i.zdepth.x);
				lightListIndex cluster = _Clusters[(int)(vpos.x / _TileSize) * _Cellsy * _Cellsz
												 + (int)(vpos.y / _TileSize) * _Cellsz
												 + ceil(depth * _Cellsz)];
				if (cluster.listsize == 0) return float4(depth, depth, depth, 1.0);
				uint lgtindex = _LightLists[cluster.index];
				float4 acccol = float4(0, 0, 0, 1);
				float3 specularTint = 0;
				float3 albedo = tex2D(_MainTex, i.uv).rgb * _Tint.rgb;
				for (uint j = 0; j< min(cluster.listsize, 5); ++j)
				{
					float4x4 lightParams = _LightParams[lgtindex + j];
					float lrange = lightParams._m33;
					float3 lpos = lightParams._m00_m10_m20;
					if ( distance(lpos, i.worldPos) > lrange ) continue;

					UnityIndirect indirectLight;
					indirectLight.diffuse = acccol;
					indirectLight.specular = specularTint;

					//acccol.xyz = ((acccol.xyz * (i + 1)) + lightColor) / (i + 2);

					float oneMinusReflectivity;
					albedo = DiffuseAndSpecularFromMetallic(
						albedo, _Metallic, specularTint, oneMinusReflectivity
					);

					UnityLight light;
					light.color = lightParams._m01_m11_m21;
					light.dir = normalize(lpos - i.worldPos);

					acccol = UNITY_BRDF_PBS(
						albedo, specularTint,
						oneMinusReflectivity, _Smoothness,
						i.normal, viewDir,
						light, indirectLight
					);
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

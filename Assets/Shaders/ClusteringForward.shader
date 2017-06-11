Shader "Standard/ClusteringPhong"
{
	Properties
	{
		_Color("Color", Color) = (1,1,1,1)
		_MainTex("Albedo", 2D) = "white" {}
		
		_Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

		_Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5
		_GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0
		[Enum(Metallic Alpha,0,Albedo Alpha,1)] _SmoothnessTextureChannel ("Smoothness texture channel", Float) = 0

		[Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
		_MetallicGlossMap("Metallic", 2D) = "white" {}

		[ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
		[ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0

		_BumpScale("Scale", Float) = 1.0
		_BumpMap("Normal Map", 2D) = "bump" {}

		_Parallax ("Height Scale", Range (0.005, 0.08)) = 0.02
		_ParallaxMap ("Height Map", 2D) = "black" {}

		_OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
		_OcclusionMap("Occlusion", 2D) = "white" {}

		_EmissionColor("Color", Color) = (0,0,0)
		_EmissionMap("Emission", 2D) = "white" {}
		
		_DetailMask("Detail Mask", 2D) = "white" {}

		_DetailAlbedoMap("Detail Albedo x2", 2D) = "grey" {}
		_DetailNormalMapScale("Scale", Float) = 1.0
		_DetailNormalMap("Normal Map", 2D) = "bump" {}

		[Enum(UV0,0,UV1,1)] _UVSec ("UV Set for secondary textures", Float) = 0


		// Blending state
		[HideInInspector] _Mode ("__mode", Float) = 0.0
		[HideInInspector] _SrcBlend ("__src", Float) = 1.0
		[HideInInspector] _DstBlend ("__dst", Float) = 0.0
		[HideInInspector] _ZWrite ("__zw", Float) = 1.0
	}
	SubShader
	{
		Name "FORWARD_CLUSTERING"
		Tags { "RenderType"="Opaque" "PerformanceChecks"="False" }

		LOD 300

		Pass {
			ZWrite On
			ColorMask 0
		}

		Pass
		{
			Tags {
				"LightMode" = "ForwardBase"
			}
			Blend [_SrcBlend] [_DstBlend]
			ZWrite Off
			CGPROGRAM
			#pragma target 4.5

			#include "UnityCG.cginc"
			#include "UnityStandardConfig.cginc"
			#include "UnityStandardInput.cginc"
			#include "UnityPBSLighting.cginc"
			#include "UnityStandardUtils.cginc"
			#include "UnityGBuffer.cginc"
			#include "UnityStandardBRDF.cginc"

			#include "AutoLight.cginc"
			#include "UnityStandardCore.cginc"

			#pragma shader_feature _NORMALMAP
			#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
			#pragma shader_feature _EMISSION
			#pragma shader_feature _METALLICGLOSSMAP
			#pragma shader_feature ___ _DETAIL_MULX2
			#pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
			#pragma shader_feature _ _SPECULARHIGHLIGHTS_OFF
			#pragma shader_feature _ _GLOSSYREFLECTIONS_OFF
			#pragma shader_feature _PARALLAXMAP
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fwdbase
			#pragma multi_compile_fwdbase_fullshadows
			#pragma multi_compile_fog
			#pragma multi_compile_instancing

			struct v2f // vertex shader function to fragment shader function 
			{
				float4 pos                          : POSITION1;
			    float4 tex                          : TEXCOORD0;
			    half3 eyeVec                        : TEXCOORD1;
			    half4 tangentToWorldAndPackedData[3]: TEXCOORD2;    // [3x3:tangentToWorld | 1x3:viewDirForParallax or worldPos]
			    half4 ambientOrLightmapUV           : TEXCOORD5;    // SH or Lightmap UV
			    UNITY_SHADOW_COORDS(6)
			    UNITY_FOG_COORDS(7)
			    // next ones would not fit into SM2.0 limits, but they are always for SM3.0+
			    #if UNITY_REQUIRE_FRAG_WORLDPOS && !UNITY_PACK_WORLDPOS_WITH_TANGENT
			        float3 posWorld                 : TEXCOORD8;
			    #endif
			    #if defined(_PARALLAXMAP)
				    half3 viewDirForParallax        : TEXCOORD9;
				#endif

			    UNITY_VERTEX_INPUT_INSTANCE_ID
			    UNITY_VERTEX_OUTPUT_STEREO
			};

			v2f vert (VertexInput v, out float4 pos : SV_POSITION)
			{
				UNITY_SETUP_INSTANCE_ID(v);
			    v2f o;
			    UNITY_INITIALIZE_OUTPUT(v2f, o);
			    UNITY_TRANSFER_INSTANCE_ID(v, o);
			    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

			    float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
			    #if UNITY_REQUIRE_FRAG_WORLDPOS
			        #if UNITY_PACK_WORLDPOS_WITH_TANGENT
			            o.tangentToWorldAndPackedData[0].w = posWorld.x;
			            o.tangentToWorldAndPackedData[1].w = posWorld.y;
			            o.tangentToWorldAndPackedData[2].w = posWorld.z;
			        #else
			            o.posWorld = posWorld.xyz;
			        #endif
			    #endif
			    pos = UnityObjectToClipPos(v.vertex);
			    o.pos = pos;

			    o.tex = TexCoords(v);
			    o.eyeVec = NormalizePerVertexNormal(posWorld.xyz - _WorldSpaceCameraPos);
			    float3 normalWorld = UnityObjectToWorldNormal(v.normal);
			    #ifdef _TANGENT_TO_WORLD
			        float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);

			        float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);
			        o.tangentToWorldAndPackedData[0].xyz = tangentToWorld[0];
			        o.tangentToWorldAndPackedData[1].xyz = tangentToWorld[1];
			        o.tangentToWorldAndPackedData[2].xyz = tangentToWorld[2];
			    #else
			        o.tangentToWorldAndPackedData[0].xyz = 0;
			        o.tangentToWorldAndPackedData[1].xyz = 0;
			        o.tangentToWorldAndPackedData[2].xyz = normalWorld;
			    #endif

			    //We need this for shadow receving
			    UNITY_TRANSFER_SHADOW(o, v.uv1);

			    o.ambientOrLightmapUV = VertexGIForward(v, posWorld, normalWorld);

			    #ifdef _PARALLAXMAP
			        TANGENT_SPACE_ROTATION;
			        half3 viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));
			        o.tangentToWorldAndPackedData[0].w = viewDirForParallax.x;
			        o.tangentToWorldAndPackedData[1].w = viewDirForParallax.y;
			        o.tangentToWorldAndPackedData[2].w = viewDirForParallax.z;
			    #endif

			    UNITY_TRANSFER_FOG(o,o.pos);
			    return o;
			}

			sampler2D_float _CameraDepthTexture;
        	float4 _CameraDepthTexture_TexelSize;

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

			lightListIndex getCluster( in float4 vpos )
			{
				float4 suv = vpos;
				suv.xy /= _ScreenParams.xy;
				float depth = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(suv));
            	depth = Linear01Depth(suv.zw);
				return _Clusters[(int)((_ScreenParams.x - vpos.x) / _TileSize) * _Cellsy * _Cellsz
												 + (int)((_ScreenParams.y - vpos.y) / _TileSize) * _Cellsz
												 + (int)(depth * (float)(_Cellsz))];
			}

			static const float Pi_2     = 1.570796327f;
			half4 frag (v2f i, UNITY_VPOS_TYPE vpos : VPOS ) : SV_Target
			{
				FRAGMENT_SETUP(s)

			    UNITY_SETUP_INSTANCE_ID(i);
			    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

			    UnityLight mainLight = MainLight ();
			    UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld);

			    half occlusion = Occlusion(i.tex.xy);
			    UnityGI gi = FragmentGI (s, occlusion, i.ambientOrLightmapUV, atten, mainLight);

			    half4 maincol = UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity,
			    							   s.smoothness, s.normalWorld, -s.eyeVec,
			    							   gi.light, gi.indirect);
			    maincol.rgb += Emission(i.tex.xy);
			    lightListIndex cluster = getCluster( vpos );
				
				#if defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON)
			        maincol.a = s.alpha;
			    #else
			        UNITY_OPAQUE_ALPHA(maincol.a);
			    #endif
				maincol *= atten;
				// if no other lights affect this pixel.
				if (cluster.listsize == 0)
					return maincol;
				half4 col = maincol;
				half attn;
				half3 specularTint;
				float oneMinusReflectivity;
				uint lgtindex;
				for (uint j = 0; j< cluster.listsize; ++j)
				{
					lgtindex = _LightLists[cluster.index + j];
					float4x4 lightParams = _LightParams[lgtindex];
					float lrange = lightParams._m30;
					float3 ldir = lightParams._m00_m10_m20 - s.posWorld;
					float ldist = length(ldir);
					if ( ldist < lrange )
					{
//						half3 lVec = ldir / lrange;
//			            half attn = saturate(1.0 - dot(lVec,lVec));
						attn = cos ((Pi_2 / lrange) * ldist);
			            //spot cone attenuation:
        				half rho = max(0.0, dot(normalize(ldir), lightParams._m02_m12_m22));
		            	half spattn = saturate((rho - lightParams._m03) * lightParams._m13);

						UnityIndirect indirLight;
						indirLight.diffuse = col.rgb;
						indirLight.specular = i.ambientOrLightmapUV;

						col.rgb = DiffuseAndSpecularFromMetallic(
							s.diffColor, _Metallic, specularTint, oneMinusReflectivity
						);

						UnityLight light;
						light.color = lightParams._m01_m11_m21;
						light.dir = normalize(ldir);

						half4 c = UNITY_BRDF_PBS(
							half4(col.rgb, 1), specularTint,
							oneMinusReflectivity, s.smoothness,
							s.normalWorld,-s.eyeVec,
							light, indirLight
						);
						col = half4( min(max(c.r * attn, indirLight.diffuse.r), col.r),
									 min(max(c.g * attn, indirLight.diffuse.g), col.g),
									 min(max(c.b * attn, indirLight.diffuse.b), col.b), 1);
					}
				}
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col + i.ambientOrLightmapUV;
			}
			ENDCG
		}
		// ------------------------------------------------------------------
		//  Shadow rendering pass
		Pass {
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }

			ZWrite On ZTest LEqual

			CGPROGRAM
			#pragma target 3.0
			// -------------------------------------
			#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
			#pragma shader_feature _METALLICGLOSSMAP
			#pragma shader_feature _PARALLAXMAP
			#pragma multi_compile_shadowcaster
			#pragma multi_compile_instancing

			#pragma vertex vertShadowCaster
			#pragma fragment fragShadowCaster

			#include "UnityStandardShadow.cginc"

			ENDCG
		}
	}
}

﻿using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;


public class ClusteredShader : MonoBehaviour
{

    public uint tile_size = 32u;
    public uint depth_divisions = 32u;
    public ulong sx, sy, sz;
    public int width, height;
    public int llsize;
    public float[,] pLights;
    public List<float> pLightParams;
    public ComputeBuffer tx;
    public ComputeBuffer txxx;
    public ComputeBuffer pBuffer;
    public Camera cam;

    // Use this for initialization
    IEnumerator Start()
    {
#if UNITY_WEBGL && !UNITY_EDITOR
        RegisterPlugin();
#endif
        pLightParams = new List<float>();
        Light[] lights = FindObjectsOfType(typeof(Light)) as Light[];
        foreach (Light lgt in lights)
        {
            if (lgt.type == LightType.Directional || lgt.type == LightType.Area)
            {
                // not collecting directional lights
                continue;
            }
            // light position for point/spot lights is: (position, intensity)
            if (lgt.type == LightType.Point)
                pLightParams.AddRange(new [] {lgt.transform.position.x, lgt.transform.position.y
                                                 , lgt.transform.position.z, lgt.range });
            else 
            {
                float radAngle = Mathf.Deg2Rad * lgt.spotAngle;
                float lRadius = Mathf.Cos(radAngle) * lgt.range;
                Vector3 halfDir = lgt.transform.forward.normalized * lgt.range * 0.5f;
                pLightParams.AddRange(new [] {lgt.transform.position.x + halfDir.x,
                    lgt.transform.position.y + halfDir.y,
                    lgt.transform.position.z + halfDir.z,
                    Mathf.Max( lgt.range * 0.6f, lRadius ) });
            }
            // light colour + intensity.
            pLightParams.AddRange(new [] { lgt.color.r, lgt.color.g, lgt.color.b, lgt.intensity });
            // attenuation set in a way where distance attenuation can be computed:
            //  float lengthSq = dot(toLight, toLight);
            //  float atten = 1.0 / (1.0 + lengthSq * LightAtten[i].z);
            // and spot cone attenuation:
            //  float rho = max (0, dot(normalize(toLight), SpotDirection[i].xyz));
            //  float spotAtt = (rho - LightAtten[i].x) * LightAtten[i].y;
            //  spotAtt = saturate(spotAtt);
            // and the above works for all light types, i.e. spot light code works out
            // to correct math for point & directional lights as well.

            float rangeSq = lgt.range * lgt.range;
            float quadAtten = 25.0f / rangeSq;
            // spot direction & attenuation
            if (lgt.type == LightType.Spot)
            {
                Vector3 dir = lgt.transform.forward.normalized;
                pLightParams.AddRange(new float[] {dir.x, dir.y, dir.z, 0});

                float radAngle = Mathf.Deg2Rad * lgt.spotAngle;
                float cosTheta = Mathf.Cos(radAngle * 0.25f);
                float cosPhi = Mathf.Cos(radAngle * 0.5f);
                float cosDiff = cosTheta - cosPhi;
                pLightParams.AddRange(new []{ cosPhi, (cosDiff != 0.0f) ? 1.0f / cosDiff : 1.0f, quadAtten, rangeSq });
            } else
            {
                // non-spot light
                pLightParams.AddRange(new []{ 0.0f, 0.0f, 1.0f, 1.0f });
                pLightParams.AddRange(new []{ -1.0f, 1.0f, quadAtten, rangeSq });
            }
            //Destroy(lgt);
        }
        if (pLightParams.Count != 0)
        {
            pLights = new float[pLightParams.Count / 16, 4];

            for ( int i = 0, j = 0; i < pLightParams.Count; i += 16, ++j )
            {
                pLights[j, 0] = pLightParams[i]; 
                pLights[j, 1] = pLightParams[i + 1]; 
                pLights[j, 2] = pLightParams[i + 2]; 
                pLights[j, 3] = pLightParams[i + 3];
            }
            pBuffer = new ComputeBuffer(pLightParams.Count / 16, 16 * sizeof(float));
            pBuffer.SetData(pLightParams.ToArray());
            Shader.SetGlobalBuffer("_LightParams", pBuffer);
            Shader.SetGlobalInt("_LightParamsSize", pLightParams.Count);
            cam = GetComponent<Camera>();
            if (cam == null || cam.enabled == false)
            {
                Debug.LogError("NoCamera");
            } else
            {
                Debug.Log("Camera:" + cam);
                //cam.depthTextureMode = DepthTextureMode.DepthNormals;
                width = cam.pixelWidth;
                height = cam.pixelWidth;
                LightAWrapper.createLightAssignment(Mathf.Deg2Rad * cam.fieldOfView,
                                                    (uint)cam.pixelWidth,
                                                    (uint)cam.pixelHeight,
                                                    cam.nearClipPlane,
                                                    cam.farClipPlane);
                int num = LightAWrapper.registerLights(pLights);
                if (num == 0)
                    throw new ExternalException("No Lights to Scan!");
                LightAWrapper.createCullingPlanes(cam.transform.position,
                                                  cam.transform.up.normalized,
                                                  cam.transform.forward.normalized,
                                                  tile_size,
                                                  depth_divisions);
                LightAWrapper.scanRegisteredLights();
                llsize = LightAWrapper.getLightListsSize();
                if (llsize != 0)
                {
                    tx = new ComputeBuffer(4194304, sizeof(uint));
                    Shader.SetGlobalBuffer("_LightLists", tx);
                    Shader.SetGlobalInt("_LightListsSize", llsize);
                    //Debug.Log("ll size:" + llsize);
                    System.IntPtr xptr = tx.GetNativeBufferPtr();
                    LightAWrapper.setLightListsPtr(ref xptr);

                }
                LightAWrapper.getClsSize(ref sx, ref sy, ref sz);
                txxx = new ComputeBuffer((int)(sx * sy * sz), sizeof(uint) * 2);
                Shader.SetGlobalBuffer("_Clusters", txxx);
                Shader.SetGlobalInt("_Cellsx", (int)sx);
                Shader.SetGlobalInt("_Cellsy", (int)sy);
                Shader.SetGlobalInt("_Cellsz", (int)sz);
                Shader.SetGlobalInt("_TileSize", (int)tile_size);
                System.IntPtr xxxptr = txxx.GetNativeBufferPtr();
                LightAWrapper.setClustersPtr(ref xxxptr);

            }
        }
        yield return StartCoroutine("CallPluginAtEndOfFrames");
    }

    void Update()
    {
        cam = GetComponent<Camera>();
        if (cam == null || cam.enabled == false)
        {
            Debug.LogError("NoCamera");
        } else
        {
            LightAWrapper.clearLightAssignment();
            LightAWrapper.createCullingPlanes(cam.transform.position,
                                                  cam.transform.up.normalized,
                                                  cam.transform.forward.normalized,
                                                  tile_size,
                                                  depth_divisions);
            LightAWrapper.scanRegisteredLights();
            llsize = LightAWrapper.getLightListsSize();
            if (llsize > 0)
            {
                Shader.SetGlobalInt("_LightListsSize", llsize);
                tx.SetCounterValue((uint)llsize);
                System.IntPtr xptr = tx.GetNativeBufferPtr();
                LightAWrapper.setLightListsPtr(ref xptr);
                System.IntPtr xxxptr = txxx.GetNativeBufferPtr();
                LightAWrapper.setClustersPtr(ref xxxptr);
            }
        }
    }

    private IEnumerator CallPluginAtEndOfFrames()
    {
        while (true) {
            // Wait until all frame rendering is done
            yield return new WaitForEndOfFrame();
            // Issue a plugin event with arbitrary integer identifier.
            // The plugin can distinguish between different
            // things it needs to do based on this ID.
            // For our simple plugin, it does not matter which ID we pass here.
            GL.IssuePluginEvent(LightAWrapper.GetRenderEventFunc(), 1);
        }
    }

    void OnDestroy()
    {
        LightAWrapper.disposeLightAssignment();
        pBuffer.Release();
        tx.Release();
        txxx.Release();
    }
}

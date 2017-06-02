using System.Runtime.InteropServices;
using UnityEngine.Assertions;
using UnityEngine;

public static class LightAWrapper
{

#if UNITY_STANDALONE_WIN
	private const static string LIBRARY_NAME = "LightAssignmentDLL";


#elif UNITY_STANDALONE_LINUX
    private const string LIBRARY_NAME = "LightAssignmentSO";

#else
	private const string LIBRARY_NAME = "LightAssignmentSO";

#endif

#if UNITY_WEBGL && !UNITY_EDITOR
    [DllImport ("__Internal")]
    private static extern void RegisterPlugin();
#endif

    //////////////////////////////////////////////////////////////////////////////////////////////////
    //                                      Light Assignment.                                       //
    //////////////////////////////////////////////////////////////////////////////////////////////////
    [DllImport(LIBRARY_NAME, EntryPoint = "makeCullingPlanes")]
    private static extern void makeCullingPlanes(float camPosx, float camPosy, float camPosz
                                               , float upx, float upy, float upz
                                               , float dirx, float diry, float dirz
                                               , uint pixDiv, uint zDiv);

    [DllImport(LIBRARY_NAME, EntryPoint = "regLTs")]
    private static extern void regLTs([In] float[,] ls, ref ulong size);

    [DllImport(LIBRARY_NAME, EntryPoint = "findBVs")]
    private static extern void findBVs([In] float[,] ls,
                                       ref ulong size);

    [DllImport(LIBRARY_NAME, EntryPoint = "findBV")]
    private static extern void findBV([In] float[] ls,
                                      [Out][MarshalAs(UnmanagedType.LPArray, SizeConst = 6)] uint[] result);

    [DllImport(LIBRARY_NAME, EntryPoint = "findregBVs")]
    public static extern void scanRegisteredLights();

    [DllImport(LIBRARY_NAME, EntryPoint = "clipLight")]
    private static extern bool clipLight([In] float[] v);

    [DllImport(LIBRARY_NAME, EntryPoint = "clipLights")]
    private static extern void clipLights([In] float[,] ls, ref ulong size);

    [DllImport(LIBRARY_NAME, EntryPoint = "createLA")]
    public static extern void createLightAssignment(float fovy, uint w, uint h, float n, float f);

    [DllImport(LIBRARY_NAME, EntryPoint = "clearLA")]
    public static extern void clearLightAssignment();

#if (UNITY_IPHONE || UNITY_WEBGL) && !UNITY_EDITOR
    [DllImport ("__Internal")]
#else
    [DllImport(LIBRARY_NAME, EntryPoint = "disposeLA")]
#endif
    public static extern void disposeLightAssignment();

#if (UNITY_IPHONE || UNITY_WEBGL) && !UNITY_EDITOR
    [DllImport ("__Internal")]
#else
    [DllImport(LIBRARY_NAME)]
#endif
    public static extern System.IntPtr GetRenderEventFunc();

    public static void createCullingPlanes(Vector3 camPos, Vector3 up, Vector3 dir, uint pixDiv, uint zDiv)
    {
        makeCullingPlanes(camPos.x, camPos.y, camPos.z, up.x, up.y, up.z, dir.x, dir.y, dir.z, pixDiv, zDiv);
    }

    public static bool isVisible(Vector3 light, float radius)
    {
        float[] l = { light[0], light[1], light[2], radius };
        return !clipLight(l);
    }

    public static void getVisibleLights(float[,] lights)
    {
        Assert.IsTrue(lights.GetLength(1) == 4);
        ulong size = (ulong)lights.GetLongLength(0);
        clipLights(lights, ref size);
    }

    public static int registerLights(float[,] lights)
    {
        Assert.IsTrue(lights.GetLength(1) == 4);
        ulong size = (ulong)lights.GetLongLength(0);
        regLTs(lights, ref size);
        return (int)size;
    }

    public static void scanLights(float[,] lights)
    {
        Assert.IsTrue(lights.GetLength(1) == 4);
        ulong size = (ulong)lights.GetLongLength(0);
        findBVs(lights, ref size);
    }

    public static uint[] scanLight(Vector3 light, float radius)
    {
        float[] l = { light.x, light.y, light.z, radius };
        uint[] result = new uint[6];
        findBV(l, result);
        return result;
    }

    [DllImport(LIBRARY_NAME, EntryPoint = "setClusterPtr")]
    public static extern void setClustersPtr(ref System.IntPtr send);

    [DllImport(LIBRARY_NAME, EntryPoint = "setClusterData")]
    private static extern void getCls([Out][MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 1)] uint[] result,
                                      ref ulong size);

    [DllImport(LIBRARY_NAME, EntryPoint = "getClusterDataSize")]
    public static extern void getClsSize(ref ulong xtilesize,
                                         ref ulong ytilesize,
                                         ref ulong zdivisions);

    public static uint[] getClusters()
    {
        ulong sx = 0, sy = 0, sz = 0, size = 0;
        getClsSize(ref sx, ref sy, ref sz);
        size = sx * sy * sz * 2;
        uint[] result = new uint[size];
        getCls(result, ref size);
        return result;
    }

    public static int getClustersSize()
    {
        ulong sx = 0, sy = 0, sz = 0, size = 0;
        getClsSize(ref sx, ref sy, ref sz);
        size = sx * sy * sz * 2;
        return (int)size;
    }

    [DllImport(LIBRARY_NAME, EntryPoint = "setLightListPtr")]
    public static extern void setLightListsPtr(ref System.IntPtr send);

    [DllImport(LIBRARY_NAME, EntryPoint = "setLightListData")]
    private static extern void getLL([Out][MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 1)] uint[] result,
                                     ref ulong size);

    [DllImport(LIBRARY_NAME, EntryPoint = "getLightListDataSize")]
    public static extern int getLightListsSize();

    public static uint[] getLightLists()
    {
        int size = getLightListsSize();
        uint[] result = new uint[size];
        ulong sz = (ulong)size;
        getLL(result, ref sz);
        return result;
    }

    //////////////////////////////////////////////////////////////////////////////////////////////////
    //                                        Frustum Matrix.                                       //
    //////////////////////////////////////////////////////////////////////////////////////////////////
    [DllImport(LIBRARY_NAME, EntryPoint = "element")]
    private static extern void element(uint x, uint y, uint z, ref float rx, ref float ry, ref float rz);

    [DllImport(LIBRARY_NAME, EntryPoint = "makePointGrid")]
    private static extern void makePointGrid(float camPosx, float camPosy, float camPosz,
                                             float upx, float upy, float upz,
                                             float dirx, float diry, float dirz,
                                             uint pixDiv, uint zDiv);

    [DllImport(LIBRARY_NAME, EntryPoint = "createFrustumMatrix")]
    public static extern void createFrustumMatrix(float fovy, uint w, uint h, float n, float f);

    public static void createPointGrid(Vector3 camPos, Vector3 up, Vector3 dir, uint pixDiv, uint zDiv)
    {
        makePointGrid(camPos.x, camPos.y, camPos.z, up.x, up.y, up.z, dir.x, dir.y, dir.z, pixDiv, zDiv);
    }

    [DllImport(LIBRARY_NAME, EntryPoint = "matrixSize")]
    public static extern uint getMatrixSize(ref ulong xtilesize,
                                            ref ulong ytilesize,
                                            ref ulong zdivisions);


    public static Vector3 getElement(uint x, uint y, uint z)
    {
        float rx = 0, ry = 0, rz = 0;
        element(x, y, z, ref rx, ref ry, ref rz);
        return new Vector3(rx, ry, rz);
    }

    [DllImport(LIBRARY_NAME, EntryPoint = "clearFrustumMatrix")]
    public static extern void clearFrustumMatrix();

    [DllImport(LIBRARY_NAME, EntryPoint = "deleteFrustumMatrix")]
    public static extern void disposeFrustumMatrix();
}
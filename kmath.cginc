
inline float3 tclamp( float3 inp, float mini, float maxi ){
	inp  = inp < mini ? mini : inp;
	return inp > maxi ? maxi : inp;
}

inline float3 axatan(float3 x){
	return 0.5*( x/(abs(x)+1) )+0.5;
}

//zero to one clamp
inline float3 zoclamp( float3 inp ){
	return (axatan(inp)-0.5)*3.14;
}

half3 colorHSL( half3 RGB /*Color*/, half3 HSL /*float3(H,S,L) 0 to 1*/ ){

	//yanky ass adjust hue
	HSL.x*=6.28;
	//https://en.wikipedia.org/wiki/YIQ
	
	float3x3 RGBtoYIQ = {
		+0.2990, +0.5870, +0.1140,
		+0.5959, -0.2746, -0.3213,
		+0.2115, -0.5227, +0.3112
	};
	
	float3x3 YIQtoRGB = {
		+1.0000, +0.9560, +0.6190,
		+1.0000, -0.2720, -0.6470,
		+1.0000, -1.1060, +1.7030
	};
	
	float c0 = cos(HSL.x);
	float s0 = sin(HSL.x);

	float2x2 rotX = {
		c0,-s0,
		s0, c0
	};

	//Convert to YIQ
	RGB		= mul(RGB,RGBtoYIQ);
	//Rotate by angle HSL.x about the x axis
	RGB.yz 	= mul(RGB.yz,rotX);
	//Convert to RGB
	RGB 	= mul(RGB,YIQtoRGB);

	float L = dot(RGB, float3(0.2126, 0.7152, 0.0722)); //Luminance
	RGB = lerp(L,RGB,HSL.y); //Adjust Saturation
	RGB = RGB*HSL.z; //Adjust Brightness

	return RGB;

}

half3 linearToGamma(half3 RGB){
		return sqrt(RGB);
}

half3 gammaToLinear(half3 RGB){
		return RGB*RGB;
}

half linearToGamma(half RGB){
		return sqrt(RGB);
}

half gammaToLinear(half RGB){
		return RGB*RGB;
}

//probably would speed up things if these were put into main shader code and used already computed variables
//UnityCG-minimal.cginc
//Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#if defined(UNITY_SINGLE_PASS_STEREO)
float2 TransformStereoScreenSpaceTex(float2 uv, float w)
{
    float4 scaleOffset = unity_StereoScaleOffset[unity_StereoEyeIndex];
    return uv.xy * scaleOffset.xy + scaleOffset.zw * w;
}

inline float2 UnityStereoTransformScreenSpaceTex(float2 uv)
{
    return TransformStereoScreenSpaceTex(saturate(uv), 1.0);
}

inline float4 UnityStereoTransformScreenSpaceTex(float4 uv)
{
    return float4(UnityStereoTransformScreenSpaceTex(uv.xy), UnityStereoTransformScreenSpaceTex(uv.zw));
}
inline float2 UnityStereoClamp(float2 uv, float4 scaleAndOffset)
{
    return float2(clamp(uv.x, scaleAndOffset.z, scaleAndOffset.z + scaleAndOffset.x), uv.y);
}
#else
#define TransformStereoScreenSpaceTex(uv, w) uv
#define UnityStereoTransformScreenSpaceTex(uv) uv
#define UnityStereoClamp(uv, scaleAndOffset) uv
#endif

// Unpack normal as DXT5nm (1, y, 1, x) or BC5 (x, y, 0, 1)
// Note neutral texture like "bump" is (0, 0, 1, 1) to work with both plain RGB normal and DXT5nm/BC5
fixed3 UnpackNormalmapRGorAG(fixed4 packednormal)
{
    // This do the trick
   packednormal.x *= packednormal.w;

    fixed3 normal;
    normal.xy = packednormal.xy * 2 - 1;
    normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));
    return normal;
}
inline fixed3 UnpackNormal(fixed4 packednormal)
{
#if defined(UNITY_NO_DXT5nm)
    return packednormal.xyz * 2 - 1;
#else
    return UnpackNormalmapRGorAG(packednormal);
#endif
}

inline float4 ComputeNonStereoScreenPos(float4 pos) {
    float4 o = pos * 0.5f;
    o.xy = float2(o.x, o.y*_ProjectionParams.x) + o.w;
    o.zw = pos.zw;
    return o;
}

inline float4 ComputeScreenPos(float4 pos) {
    float4 o = ComputeNonStereoScreenPos(pos);
#if defined(UNITY_SINGLE_PASS_STEREO)
    o.xy = TransformStereoScreenSpaceTex(o.xy, pos.w);
#endif
    return o;
}

// Transforms normal from object to world space
inline float3 UnityObjectToWorldNormal( in float3 norm )
{
#ifdef UNITY_ASSUME_UNIFORM_SCALING
    return UnityObjectToWorldDir(norm);
#else
    // mul(IT_M, norm) => mul(norm, I_M) => {dot(norm, I_M.col0), dot(norm, I_M.col1), dot(norm, I_M.col2)}
    return normalize(mul(norm, (float3x3)unity_WorldToObject));
#endif
}

// Computes world space light direction, from world space position
inline float3 UnityWorldSpaceLightDir( in float3 worldPos )
{
    #ifndef USING_LIGHT_MULTI_COMPILE
        return _WorldSpaceLightPos0.xyz - worldPos * _WorldSpaceLightPos0.w;
    #else
        #ifndef USING_DIRECTIONAL_LIGHT
        return _WorldSpaceLightPos0.xyz - worldPos;
        #else
        return _WorldSpaceLightPos0.xyz;
        #endif
    #endif
}


float4 UnityClipSpaceShadowCasterPos(float4 vertex, float3 normal)
{
    float4 wPos = mul(unity_ObjectToWorld, vertex);

//    if (unity_LightShadowBias.z != 0.0)
//    {
        float3 wNormal = UnityObjectToWorldNormal(normal);
        float3 wLight = normalize(UnityWorldSpaceLightDir(wPos.xyz));

        float shadowCos = dot(wNormal, wLight);
        float shadowSine = sqrt(1-shadowCos*shadowCos);
        float normalBias = unity_LightShadowBias.z * shadowSine;

        wPos.xyz -= wNormal * normalBias;
//    }

    return mul(UNITY_MATRIX_VP, wPos);
}

float4 UnityApplyLinearShadowBias(float4 clipPos)

{
    // For point lights that support depth cube map, the bias is applied in the fragment shader sampling the shadow map.
    // This is because the legacy behaviour for point light shadow map cannot be implemented by offseting the vertex position
    // in the vertex shader generating the shadow map.
#if !(defined(SHADOWS_CUBE) && defined(SHADOWS_CUBE_IN_DEPTH_TEX))
    #if defined(UNITY_REVERSED_Z)
        // We use max/min instead of clamp to ensure proper handling of the rare case
        // where both numerator and denominator are zero and the fraction becomes NaN.
        clipPos.z += max(-1, min(unity_LightShadowBias.x / clipPos.w, 0));
    #else
        clipPos.z += saturate(unity_LightShadowBias.x/clipPos.w);
    #endif
#endif

#if defined(UNITY_REVERSED_Z)
    float clamped = min(clipPos.z, clipPos.w*UNITY_NEAR_CLIP_VALUE);
#else
    float clamped = max(clipPos.z, clipPos.w*UNITY_NEAR_CLIP_VALUE);
#endif
    clipPos.z = lerp(clipPos.z, clamped, unity_LightShadowBias.y);
    return clipPos;
}
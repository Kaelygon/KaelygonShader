//v=26May23
//
//Kaelygon 2023
//Creative Commons Attribution 4.0 International
//
Shader "Kaelygon/KaelReflect"
{
	Properties
	{
		
		[Header(Textures)]_MainTex ("Base (RGB)", 2D) = "white" {}
		_Cutoff ("Cutoff", range(0,1) ) = 0.5
		_CutoutMap ("Cutout Map", 2D) = "black" {}
		[NoScaleOffset] _NormalMap ("Normal Map", 2D) = "white" {}
		_NormalStrength ("Normal Strength", range(-2,2) ) = 0.8
		[NoScaleOffset] _EmissionMap ("Emission", 2D) = "white" {}
		_EmissionColor("Emission Color", Color) = (1,1,1,1)

		[Header(Lighting)][NoScaleOffset] _Cube("Cube Map", Cube) = "black" {}
		[NoScaleOffset] _CubeSmoothness("Cube Smoothness Map", 2D) = "white" {}
		_CubeReflectivity ("Cube Reflectivity", range(0,5)) = 1
		[NoScaleOffset] _ShadowRamp ("Shadow Ramp", 2D) = "white" {}
		_RampPriority( "Ramp Priority", range(0,1) ) = 0
		_ShadowColor("Shadow Color", Color) = (0.333,0.333,0.333,1)
		_Hue ("Hue", range(0,1)) = 0
		_Saturation ("Saturation", range(0,3)) = 1
		_Value ("Value", range(0,3)) = 1
		_CubeAdd( "Cube Multiply-Add", range(0,1) ) = 0.5
		_ShadowAdd( "Shadow Add", range(0,1) ) = 0
		_ShadowMult( "Shadow Multiply", range(0,1) ) = 0
	}

	SubShader 
	{
		Tags {"Queue" = "AlphaTest" "RenderType" = "TransparentCutout"}
		LOD 300
		Pass{
			Tags {"LightMode"="ForwardBase" "BW"="TrueProbes"}             

			CGPROGRAM

			#include "kmath.cginc"

			#define additiveCube 1

			#pragma vertex vert ForwardBase
			#pragma fragment frag
			#pragma target 5.0

			half3 _LightColor0;

			uniform sampler2D _MainTex;
			uniform sampler2D _EmissionMap;
			uniform sampler2D _NormalMap;
			uniform sampler2D _ShadowRamp;
			uniform samplerCUBE _Cube;
			uniform sampler2D _CubeSmoothness;
			uniform sampler2D _CutoutMap;

			uniform sampler2D _LightTexture0;
			uniform sampler2D _ShadowMapTexture;

			half4 _MainTex_ST;
			half4 _CutoutMap_ST;

			half _Value;
			half3 _EmissionColor;
			half _NormalStrength;
			half3 _ShadowColor;
			half _Cutoff;
			half _Hue;
			half _Saturation;
			half _CubeReflectivity;
			half _CubeAdd;

			half _ShadowAdd;
			half _ShadowMult;
			half _RampPriority;
			float4x4 unity_WorldToLight;
		
			struct vout {
				float4 vert : POSITION;
				float2 uv0 : TEXCOORD0; 
				half3 nor : NORMAL;
			};

			struct vin {
				float4 vert : POSITION;
				float2 uv0 : TEXCOORD0;
				half3 reflDir : TEXCOORD1;

				float4 _ShadowCoord : TEXCOORD3;
				float4 _LightCoord : TEXCOORD4;
				half3 fourlight : TEXCOORD2;   
				half3 sh9 : TEXCOORD5;       
			};

			vin vert (vout v)
			{
				vin o;
				
				//world position
				float4 wpos = mul(unity_ObjectToWorld, v.vert);
				o.vert =  mul(UNITY_MATRIX_VP, wpos );

				//world normal
				half3 wnor=normalize( mul(unity_ObjectToWorld, v.nor) );

				//reflection direction
				o.reflDir = reflect( wpos-_WorldSpaceCameraPos.xyz , wnor );

				//directional light
				half3 dir = max(0, dot( wnor , _WorldSpaceLightPos0 )*_LightColor0 );
				
				//4-light
				o.fourlight=0;
				for (int index = 0; index < 4; index++)
				{  
					float4	lightPosition = float4(unity_4LightPosX0[index], unity_4LightPosY0[index], 	unity_4LightPosZ0[index], 1.0);
			
					float3	vertexToLightSource = lightPosition - wpos;    
					half3	lightv = normalize(vertexToLightSource);
					float	lightDist = dot(vertexToLightSource, vertexToLightSource);
					float	attenuation = 1 / (1.0 + unity_4LightAtten0[index] * lightDist);
					half3	diffuseReflection = attenuation * unity_LightColor[index] * max(0.0, dot(wnor, lightv));
			
					o.fourlight += diffuseReflection; 
				}
				

				//light probe
				o.sh9.r = dot(unity_SHAr,wnor);
				o.sh9.g = dot(unity_SHAg,wnor);
				o.sh9.b = dot(unity_SHAb,wnor);
				o.sh9*= half3(unity_SHAr.w,unity_SHAg.w,unity_SHAb.w);
				o.sh9;
				
				//linear to gamma
				o.sh9 = max(o.sh9, half3(0.h, 0.h, 0.h));
				o.sh9 = max(1.055h * pow(o.sh9, 0.417h) - 0.055h, 0.h);

				o.sh9+=dir;

				//transforms 
				o.uv0=v.uv0.xy*_MainTex_ST.xy+_MainTex_ST.zw;

				//shadow receive
				o._LightCoord = mul(unity_WorldToLight, wpos.xyz );
				o._ShadowCoord = UNITY_PROJ_COORD(ComputeScreenPos(o.vert));
				
				return o;
			}

			fixed4 frag (vin i) : SV_Target {
				
					//alpha cutout
					half4 outColor = tex2D(_MainTex, i.uv0);
					half cutAlpha = tex2D(_CutoutMap, i.uv0*_CutoutMap_ST.xy+_CutoutMap_ST.zw).r;
					if( outColor.a - 0.01 < _Cutoff+cutAlpha ){
						discard;
					};
					
					//base light
					half3 lights = _ShadowColor;

					//shadow receive
					float4 attenuation = tex2D(_LightTexture0, dot(i._LightCoord,i._LightCoord).rr).UNITY_ATTEN_CHANNEL ;
					attenuation *= tex2Dproj( _ShadowMapTexture, (i._ShadowCoord) );

					//use attenuation to sample shadow ramp
					attenuation = tex2D( _ShadowRamp, attenuation *_ShadowMult+_ShadowAdd );
					//Shadow ramp strength blend. [0,1] ShadowRamp -> sh9
					i.sh9 = lerp( tex2D( _ShadowRamp, i.sh9 * _ShadowMult+_ShadowAdd ) , i.sh9 , 1-lights-_RampPriority );
					
					//normal map strength
					half3 normalTex = lerp( half3(0.5,0.5,1), UnpackNormal(tex2D(_NormalMap, i.uv0)), (_NormalStrength) );

					//vertex sh9 and four light
					half3 flsh9 = i.fourlight+attenuation*i.sh9;
					lights += flsh9*max( 0.0, dot(normalTex,flsh9) );

					//add emission
					lights += tex2D(_EmissionMap, i.uv0).rgb*_EmissionColor;

					//clamp
					lights = clamp(lights,0.0,1.5);

					//cube reflections					
					half3 cubeRefl = texCUBE(_Cube, i.reflDir ) * tex2D(_CubeSmoothness, i.uv0).r * _CubeReflectivity;
					//reflections are dimmer in shadow
					cubeRefl = lerp( cubeRefl*(flsh9*0.3+0.09) , cubeRefl*flsh9 , lights );

					//color edit
					outColor.rgb = colorHSL( outColor.rgb , half3(_Hue,_Saturation,_Value) );

					//mix additive and, or multiplicative cube lights
					outColor.rgb = lerp( 
						outColor.rgb * (lights + cubeRefl*8),	//multiplicative
						outColor.rgb * lights + cubeRefl,		//additive
						_CubeAdd
					);

					return fixed4( outColor.rgb, 1 );
			}
			ENDCG
		}


		Pass {
			Tags { "LightMode" = "ShadowCaster" }
			ZWrite On ZTest LEqual

			CGPROGRAM

			#include "kmath.cginc"

			#pragma vertex vert
			#pragma fragment frag

			half _Cutoff;

			uniform sampler2D _MainTex;
			half4 _MainTex_ST;
			uniform sampler2D _CutoutMap;
			half4 _CutoutMap_ST;

			struct vout
			{
				float4 vert   : POSITION;
				half3 normal   : NORMAL;
				float2 uv0 : TEXCOORD0;
			};

			struct vin
			{
				float4 vert   : POSITION;
				float2 uv0 : TEXCOORD0; 
			};

			vin vert (vout v)
			{
				vin o;
				
				o.vert = v.vert;
				o.vert = UnityClipSpaceShadowCasterPos(o.vert, v.normal);
				o.vert = UnityApplyLinearShadowBias(o.vert);

				//transforms 
				o.uv0=v.uv0.xy*_MainTex_ST.xy+_MainTex_ST.zw;
				
				return o;
			}

			fixed4 frag (vin i) : SV_Target {
				//alpha cutout
				half4 outColor = tex2D(_MainTex, i.uv0);
				half cutAlpha = tex2D(_CutoutMap, i.uv0*_CutoutMap_ST.xy+_CutoutMap_ST.zw).r;
				if( outColor.a - 0.01 < _Cutoff+cutAlpha ){
					discard;
				};

				return 0;
			}

			ENDCG
		}

	}
}


const int R11F_G11F_B10F = 0;
const int RGBA8 = 0;
const int RGBA16 = 0;
const int RG16F = 0;
const int RGBA16F = 0;
const int RGBA32 = 0;
const int RG32F = 0;

const int colortex0Format = RGBA16F;
const int colortex1Format = RGBA16F;
const int colortex2Format = RGBA16F;
const int colortex3Format = RGBA16F;
const int colortex4Format = RGBA16;
const int colortex5Format = RGBA16F;
const int colortex6Format = RG32F;
const int colortex7Format = RGBA16F;
const int colortex8Format = RGBA16F;
const int colortex9Format = RG16F;

const int shadowcolor0Format = RGBA16F;
const int shadowcolor1Format = RGBA8;

const bool colortex2Clear = false;
const bool colortex3Clear = false;
const bool colortex6Clear = false;
const bool colortex7Clear = false;

/*
0: rgb:color
1: hrr data
2: rgb:TAA          		a:temporal data
3: rgba:hrr temporal data(rsm/ao/cloud/ssr/fog)
4: r:parallax shadow/ao		g:blockID/gbufferID		ba:specular		(df6)rg:albedo/ao	(df11)rgba:color
5: rg:normal				ba:lmcoord													(df11)rgba:pre color
6: hrr normal/depth (pre/cur)
7: sky box/T1/MS/avgLum/sunColor/skyColor
8: custom texture(MS/noise3d low)
9: rg:velocity
*/

varying vec2 texcoord;

varying vec3 sunWorldDir, moonWorldDir, lightWorldDir;
varying vec3 sunViewDir, moonViewDir, lightViewDir;

varying vec3 sunColor, skyColor;


#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"
#include "/lib/common/noise.glsl"
#include "/lib/camera/colorToolkit.glsl"
// #include "/lib/camera/filter.glsl"
#include "/lib/common/position.glsl"
#include "/lib/atmosphere/atmosphericScattering.glsl"
#include "/lib/water/waterFog.glsl"

#ifdef FSH

void main() {
	vec4 color = texture(colortex0, texcoord);
	float depth = texture(depthtex0, texcoord).r;
	vec4 viewPos = screenPosToViewPos(vec4(unTAAJitter(texcoord), depth, 1.0));
	vec4 worldPos = viewPosToWorldPos(viewPos);
	float worldDis = length(worldPos);
	vec3 worldDir = normalize(worldPos.xyz);

	#ifdef UNDERWATER_FOG
		if(isEyeInWater == 1){
			color.rgb = underWaterFog(color.rgb, worldDir, worldDis);
		}
	#endif

	// color.rgb = texture(colortex9, texcoord).rgb;
	
/* DRAWBUFFERS:0 */
	gl_FragData[0] = color;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

void main() {
	sunViewDir = normalize(sunPosition);
	moonViewDir = normalize(moonPosition);
	lightViewDir = normalize(shadowLightPosition);

	sunWorldDir = normalize(viewPosToWorldPos(vec4(sunPosition, 0.0)).xyz);
    moonWorldDir = normalize(viewPosToWorldPos(vec4(moonPosition, 0.0)).xyz);
    lightWorldDir = normalize(viewPosToWorldPos(vec4(shadowLightPosition, 0.0)).xyz);

	sunColor = getSunColor();
	skyColor = getSkyColor();

	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif
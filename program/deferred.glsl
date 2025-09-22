

varying vec2 texcoord;

#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"

#include "/lib/common/position.glsl"
#include "/lib/common/normal.glsl"

#ifdef FSH

void main() {
	vec4 CT6 = texelFetch(colortex6, ivec2(gl_FragCoord.xy), 0);
	vec2 uv2 = texcoord * 2.0;
	float curZ = 0.0;
	vec3 curNormalW = vec3(0.0);
	if(!outScreen(uv2)){
		curZ = texelFetch(depthtex1, ivec2(uv2 * viewSize), 0).r;
		curNormalW = normalize(viewPosToWorldPos(vec4(getNormalH(uv2), 0.0)).xyz);

		CT6 = vec4(packNormal(curNormalW), curZ, 0.0, 0.0);
	}
	
/* DRAWBUFFERS:6 */
	gl_FragData[0] = CT6;
}

#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}

#endif
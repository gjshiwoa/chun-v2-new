varying vec2 texcoord;

#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/common/utils.glsl"

#include "/lib/common/position.glsl"

#ifdef FSH

void main() {
	vec4 CT7 = texture(colortex7, texcoord);
	
	ivec2 iTexcoord = ivec2(gl_FragCoord.xy);

	ivec2 uv0 = ivec2(remap(iTexcoord.x, T1_I.x, T1_I.z, T1_O.x, T1_O.z), 
					  remap(iTexcoord.y, T1_I.y, T1_I.w, T1_O.y, T1_O.w));
	if(iTexcoord.x >= T1_I.x && iTexcoord.x <= T1_I.z && iTexcoord.y >= T1_I.y && iTexcoord.y <= T1_I.w)
		CT7 = texelFetch(colortex1, uv0, 0);

	ivec2 uv1 = ivec2(remap(iTexcoord.x, MS_I.x, MS_I.z, MS_O.x, MS_O.z), 
					  remap(iTexcoord.y, MS_I.y, MS_I.w, MS_O.y, MS_O.w));
	if(iTexcoord.x >= MS_I.x && iTexcoord.x <= MS_I.z && iTexcoord.y >= MS_I.y && iTexcoord.y <= MS_I.w)
		CT7 = texelFetch(depthtex2, uv1, 0);



/* DRAWBUFFERS:7 */
	gl_FragData[0] = CT7;
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
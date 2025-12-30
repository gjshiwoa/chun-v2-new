vec3 coloredLight(vec3 worldPos, vec3 normalV, vec3 normalW){
    vec3 randomVec = rand2_3(texcoord + sin(frameTimeCounter)) * 2.0 - 1.0;

    vec3 tangent = normalize(randomVec - normalV * dot(randomVec, normalV));
    vec3 bitangent = normalize(cross(normalV, tangent));
    mat3 TBN = mat3(tangent, bitangent, normalV);

    vec3 color = vec3(0.0);
    const float DIR_SAMPLES = 4.0;
    for(int i = 0; i < DIR_SAMPLES; ++i){
        vec3 dir = rand2_3(texcoord + sin(frameTimeCounter) + i);
        dir.xy = dir.xy * 2.0 - 1.0;
        dir = normalize(TBN * dir);
        dir = normalize(viewPosToWorldPos(vec4(dir, 0.0)).xyz);

        float noise = temporalBayer64(gl_FragCoord.xy);
        float stepSize = 1.0;
        vec3 stepVec = dir * stepSize;
        ivec3 oriVp = relWorldToVoxelCoord(worldPos + normalW * 0.05);
        vec3 oriWp = worldPos;
        worldPos += stepVec * noise;
        worldPos += normalW * 0.05;
        const float N_SAMPLES = 8.0;

        for(int j = 0; j < N_SAMPLES; ++j){
            vec3 wp = worldPos + stepVec * float(j);
            ivec3 vp = relWorldToVoxelCoord(wp);
            vec4 sampleCol = texelFetch(customimg0, vp.xyz, 0);
            float dis = distance(vp, oriVp);
            if(abs(sampleCol.a - 0.5) < 0.05){
                float dis1 = distance(oriWp, wp) + 1.0;
                color += toLinearR(sampleCol.rgb) * saturate(dot(dir, normalW)) * 2.0;
                break;
            }
        }
    }

    return color / DIR_SAMPLES;
}

vec2 SSRT_PT(vec3 viewPos, vec3 reflectViewDir, vec3 normalTex, out vec3 outMissPos){
    float curStep = REFLECTION_STEP_SIZE;

    vec3 startPos = viewPos;
    float worldDis = length(viewPos);
    #ifdef GBF
        startPos += normalTex * 0.2;
    #else
        startPos += normalTex * clamp(worldDis / 60.0, 0.01, 0.2);
    #endif

    float jitter = temporalBayer64(gl_FragCoord.xy);

    float cumUnjittered = 0.0;
    vec3 testScreenPos = viewPosToScreenPos(vec4(startPos, 1.0)).xyz;
    vec3 preTestPos = startPos;
    bool isHit = false;

    outMissPos = vec3(0.0);

    vec3 curTestPos = startPos;

    for (int i = 0; i < int(REFLECTION_SAMPLES); ++i){
        cumUnjittered += curStep;
        float adjustedDist = cumUnjittered - jitter * curStep;
        curTestPos = startPos + reflectViewDir * adjustedDist;
        testScreenPos = viewPosToScreenPos(vec4(curTestPos, 1.0)).xyz;

        if (outScreen(testScreenPos.xy)){
            outMissPos = preTestPos;
            return vec2(-1.0);
        }

        float closest = texture(depthtex1, testScreenPos.xy).r;
        #if defined DISTANT_HORIZONS && !defined NETHER && !defined END
            #ifdef GBF
                float dhDepth = texture(dhDepthTex1, testScreenPos.xy).r;
            #else
                float dhDepth = texture(dhDepthTex0, testScreenPos.xy).r;
            #endif
            vec4 dhViewPos = screenPosToViewPosDH(vec4(testScreenPos.xy, dhDepth, 1.0));
            closest = min(closest, viewPosToScreenPos(dhViewPos).z);
        #endif
        vec3 ivalueTestScreenPos = vec3(testScreenPos.xy, closest);

        if (testScreenPos.z > closest){
            isHit = true;
            vec3 ds = curTestPos - preTestPos;
            vec3 probePos = curTestPos;
            float sig = -1.0;
            float closestB = 1.0;
            for (int j = 1; j <= 5; ++j){
                float n = pow(0.5, float(j));
                probePos = probePos + sig * n * ds;
                testScreenPos = viewPosToScreenPos(vec4(probePos, 1.0)).xyz;
                closestB = texture(depthtex1, testScreenPos.xy).r;
                #if defined DISTANT_HORIZONS && !defined NETHER && !defined END
                    #ifdef GBF
                        float dhDepthB = texture(dhDepthTex1, testScreenPos.xy).r;
                    #else
                        float dhDepthB = texture(dhDepthTex0, testScreenPos.xy).r;
                    #endif
                    vec4 dhViewPosB = screenPosToViewPosDH(vec4(testScreenPos.xy, dhDepthB, 1.0));
                    closestB = min(closestB, viewPosToScreenPos(dhViewPosB).z);
                #endif
                sig = sign(closestB - testScreenPos.z);
            }

            vec3 newTestPos = screenPosToViewPos(vec4(ivalueTestScreenPos, 1.0)).xyz;
            float tp_dist = distance(curTestPos, newTestPos);
            float ds_len = length(ds);
            float cosA = dot(reflectViewDir, normalize(normalTex));
            if (tp_dist < ds_len * saturate(sqrt(1.0 - cosA * cosA))){
                return testScreenPos.st;
            }
            outMissPos = curTestPos;
            break;
        }

        preTestPos = curTestPos;
        curStep *= REFLECTION_STEP_GROWTH_BASE;
    }

    bool depthCondition = true;
    #if !defined END && !defined NETHER
        #ifdef DISTANT_HORIZONS
            depthCondition = texture(dhDepthTex0, testScreenPos.xy).r < 1.0 || texture(depthtex1, testScreenPos.xy).r < 1.0;
        #else
            depthCondition = texture(depthtex1, testScreenPos.xy).r < 1.0;
        #endif
    #endif

    if (!isHit){
        if(depthCondition) return vec2(testScreenPos.xy);
        else outMissPos = curTestPos;
    }

    return vec2(-1.0);
}


vec3 pathTracing(vec3 viewPos, vec3 worldPos, vec3 normalV, vec3 normalW){
    vec3 randomVec = rand2_3(texcoord + sin(frameTimeCounter)) * 2.0 - 1.0;

    vec3 tangent = normalize(randomVec - normalV * dot(randomVec, normalV));
    vec3 bitangent = normalize(cross(normalV, tangent));
    mat3 TBN = mat3(tangent, bitangent, normalV);

    vec3 color = vec3(0.0);
    const float DIR_SAMPLES = 4.0;
    for(int i = 0; i < DIR_SAMPLES; ++i){
        vec3 dir = rand2_3(texcoord + sin(frameTimeCounter) + i);
        dir.xy = dir.xy * 2.0 - 1.0;
        vec3 refViewDir = normalize(TBN * dir);
        vec3 refWorldDir = normalize(viewPosToWorldPos(vec4(refViewDir, 0.0)).xyz);
        vec3 missPos = vec3(0.0);
        float LoN = saturate(dot(normalW, refWorldDir));

        vec2 ssrHitPos = SSRT_PT(viewPos, refViewDir, normalV, missPos);
        if(ssrHitPos.x + ssrHitPos.y > 0.0){
            vec3 hitAlbedo = pow(texture(colortex0, ssrHitPos).rgb, vec3(2.2));
            vec3 hitDiffuse = hitAlbedo / PI;
            vec4 CT4 = texture(colortex4, ssrHitPos);
            vec4 CT5 = texture(colortex5, ssrHitPos);
            vec2 CT4R = unpack16To2x8(CT4.r);
            float hitShadow = min(CT4R.x, CT4R.y);
            vec3 hitNormalV = normalize(normalDecode(CT5.rg));
            float hitLoN = saturate(dot(hitNormalV, lightViewDir));

            vec3 hitLo = sunColor * hitShadow * hitDiffuse * hitLoN;
            color += DIRECT_LUMINANCE * hitLo * LoN;
        } else {

        }
    }

    return color / DIR_SAMPLES;
}

vec4 temporal_RT(vec4 color_c){
    vec2 uv = texcoord * 2;
    vec2 cur = texelFetch(colortex6, ivec2(gl_FragCoord.xy), 0).rg;
    float z = cur.g;
    vec4 viewPos = screenPosToViewPos(vec4(uv, z, 1.0));
    vec3 prePos = getPrePos(viewPosToWorldPos(viewPos));

    prePos.xy = prePos.xy * 0.5 * viewSize - 0.5;
    vec2 fPrePos = floor(prePos.xy);

    vec4 c_s = vec4(0.0);
    float w_s = 0.0;
    
    vec3 normal_c = unpackNormal(cur.r);
    float depth_c = linearizeDepth(prePos.z);
    float fDepth = fwidth(depth_c);

    for(int i = 0; i <= 1; i++){
    for(int j = 0; j <= 1; j++){
        vec2 curUV = fPrePos + vec2(i, j);
        if(outScreen(curUV * 2 * invViewSize)) continue;

        vec2 pre = texelFetch(colortex6, ivec2(curUV + 0.5 * viewSize), 0).rg;
        float depth_p = linearizeDepth(pre.g);   

        float weight = (1.0 - abs(prePos.x - curUV.x)) * (1.0 - abs(prePos.y - curUV.y));
        float depthWeight = exp(-abs(depth_p - depth_c) / (1.0 + fDepth * 2.0 + depth_p / 2.0));
        float normalWeight = saturate(dot(normal_c, unpackNormal(pre.r)));

        weight *= depthWeight;
        weight *= normalWeight;
        
        c_s += texelFetch(colortex10, ivec2(curUV), 0) * weight;
        w_s += weight;
    }
    }

    vec4 blend = vec4(vec3(0.98), 0.9);
    color_c = mix(color_c, c_s, w_s * blend);

    return color_c;
}

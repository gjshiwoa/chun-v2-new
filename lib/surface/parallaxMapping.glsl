// 效果设计-Parallax Mapping视差映射
// https://miusjun13qu.feishu.cn/docx/G17IdiCyhoEd7XxBqJOcb3J1nie

vec2 GetParallaxCoord(vec2 offsetNormalized) {
    vec2 tileSizeNormalized = vec2(float(textureResolution)) / vec2(atlasSize);
    vec2 tileStart = floor(texcoord / tileSizeNormalized) * tileSizeNormalized;

    vec2 targetCoord = texcoord + offsetNormalized;
    vec2 relativeCoord = targetCoord - tileStart;
    vec2 wrappedRelativeCoord = mod(relativeCoord, tileSizeNormalized);

    return tileStart + wrappedRelativeCoord;
}

float getParallaxHeight(vec2 uv, vec2 texGradX, vec2 texGradY){
    // 1) 如果基底贴图在该 uv 的 alpha==0，保持原逻辑
    float baseAlpha = texture(tex, uv).a;
    
    // 2) 计算 tile 的归一化尺寸与 tile 起点
    vec2 tileSizeNormalized = vec2(float(textureResolution)) / atlasSize; // tile 在 atlas 中的 normalized 尺寸
    vec2 tileStart = floor(uv / tileSizeNormalized) * tileSizeNormalized; // tile 起点（normalized）
    
    // 3) tile 内局部 uv（0..1）
    vec2 localUV = (uv - tileStart) / tileSizeNormalized;
    // Clamp localUV 到 [0,1) 的范围可以避免少数浮点问题（但下面我们取模）
    // localUV = fract(localUV);

    // 4) 计算在 tile 内的连续像素坐标（0..textureResolution）
    vec2 texPos = localUV * float(textureResolution); // 连续像素坐标（0..res）
    vec2 f = fract(texPos);               // 双线性插值权重
    ivec2 i0 = ivec2(floor(texPos));      // 左下像素索引（tile 内）

    // 5) atlas 的像素尺寸（整数）
    ivec2 atlasPxSize = textureSize(normals, 0);

    // 6) 计算 tile 起点的像素坐标（整数）, 理论上 tileStart * atlasPxSize 应该正好是整数
    ivec2 tileStartPx = ivec2(tileStart * vec2(atlasPxSize) + 0.5);

    // 7) 施工四个像素在 tile 内的索引（带 wrap/repeat）
    int res = textureResolution;
    // 将 i0.x/y 与 res 做模以实现 tile 内 repeat
    int ix = i0.x % res;
    int iy = i0.y % res;
    if(ix < 0) ix += res;
    if(iy < 0) iy += res;

    int ix1 = (ix + 1) % res;
    int iy1 = (iy + 1) % res;

    ivec2 p00 = tileStartPx + ivec2(ix,  iy);
    ivec2 p10 = tileStartPx + ivec2(ix1, iy);
    ivec2 p01 = tileStartPx + ivec2(ix,  iy1);
    ivec2 p11 = tileStartPx + ivec2(ix1, iy1);

    // 8) 使用 texelFetch 精确读取四个像素（level 0）
    float h00 = texelFetch(normals, p00, 0).a;
    float h10 = texelFetch(normals, p10, 0).a;
    float h01 = texelFetch(normals, p01, 0).a;
    float h11 = texelFetch(normals, p11, 0).a;

    // 9) 双线性插值
    float hx0 = mix(h00, h10, f.x);
    float hx1 = mix(h01, h11, f.x);
    float height = mix(hx0, hx1, f.y);

    // 10) 保持原有的 alpha==0 特殊处理
    if(baseAlpha == 0.0) height = 1.0;

    return height;
}

vec2 parallaxMapping(vec3 viewVector, vec2 texGradX, vec2 texGradY, out vec3 parallaxOffset){
    // const float slicesMin = 60.0;
    // const float slicesMax = 60.0;
    // float slicesNum = ceil(lerp(slicesMax, slicesMin, abs(dot(vec3(0, 0, 1), viewVector))));
    float slicesNum = PARALLAX_SAMPPLES;

    float dHeight = 1.0 / slicesNum;
    vec2 dUV = vec2(textureResolution)/vec2(atlasSize) * PARALLAX_HEIGHT * (viewVector.xy / viewVector.z) / slicesNum;

    vec2 currUVOffset = vec2(0.0);
    float rayHeight = 1.0;
    float weight = 0.0;
    float prevHeight = getParallaxHeight(GetParallaxCoord(vec2(0.0)), texGradX, texGradY);
    float currHeight = prevHeight;
    if(prevHeight < 1.0){
        rayHeight = 1.0 - dHeight;
        currUVOffset -= dUV;
        currHeight = getParallaxHeight(GetParallaxCoord(currUVOffset), texGradX, texGradY);
        for(int i = 0; i < slicesNum; ++i){
            if(currHeight > rayHeight){
                break;
            }
            prevHeight = currHeight;
            currUVOffset -= dUV;
            rayHeight -= dHeight;
            currHeight = getParallaxHeight(GetParallaxCoord(currUVOffset), texGradX, texGradY);
        }

        float currDeltaHeight = currHeight - rayHeight;
        float prevDeltaHeight = rayHeight + dHeight - prevHeight;
        weight = currDeltaHeight / (currDeltaHeight + prevDeltaHeight);
    }

    vec2 lerpOffset = vec2(0.0);
    #ifdef PARALLAX_LERP
        lerpOffset = weight * dUV;
    #endif
    parallaxOffset = vec3(currUVOffset + lerpOffset, rayHeight);
    return GetParallaxCoord(currUVOffset + lerpOffset);
}



float ParallaxShadow(vec3 parallaxOffset, vec3 viewDirTS, vec3 lightDirTS, vec2 texGradX, vec2 texGradY){
    float parallaxHeight = parallaxOffset.z;
    float shadow = 0.0;

    if(parallaxHeight < 0.99){  
        const float shadowSoftening = PARALLAX_SHADOW_SOFTENING;
        float slicesNum = PARALLAX_SHADOW_SAMPPLES;
        
        float dDist = 1.0 / slicesNum;
        float dHeight = (1.0 - parallaxHeight) / slicesNum;
        vec2 dUV = vec2(textureResolution)/vec2(atlasSize) * PARALLAX_HEIGHT * dHeight * lightDirTS.xy / lightDirTS.z;

        float rayHeight = parallaxHeight + dHeight;
        float dist = dDist;

        float prevHeight = parallaxHeight;
        vec2 currUVOffset = parallaxOffset.st + dUV;
        float currHeight = getParallaxHeight(GetParallaxCoord(currUVOffset, texcoord.st, textureResolution), texGradX, texGradY);

        for (int i = 1; i < slicesNum && rayHeight < 1.0; i++){
                if (currHeight > rayHeight){
                    shadow = max(shadow, (currHeight - rayHeight) / dist * shadowSoftening);
                    if(1.0 == shadow) break;
                }
                rayHeight += dHeight;
                dist += dDist;
            
            currUVOffset += dUV;
            prevHeight = currHeight;
            currHeight = getParallaxHeight(GetParallaxCoord(currUVOffset, texcoord.st, textureResolution), texGradX, texGradY);
        }

    }

    return saturate(1.0 - shadow);
}

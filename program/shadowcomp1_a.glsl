#include "/lib/uniform.glsl"
#include "/lib/settings.glsl"
#include "/lib/lighting/voxelization.glsl"

const ivec3 workGroups = ivec3(32, 16, 32);
layout(local_size_x=8, local_size_y=8, local_size_z=8) in;

layout(rgba8, binding = 0) uniform image3D voxel;
layout(rgba8, binding = 1) uniform image3D voxelPrev;

layout(rgba8, binding = 2) uniform image3D voxelLitSky;
layout(rgba8, binding = 3) uniform image3D voxelLitSkyPrev;

void main() {
    ivec3 p = ivec3(gl_GlobalInvocationID.xyz);
    if (!voxelInBounds(p)) return;

    // 当前帧体素数据
    vec4 cur    = imageLoad(voxel, p);
    vec4 curSky = imageLoad(voxelLitSky, p); // 仅使用 curSky.r

    bool curOcc = voxelOccupied(cur);

    // 为空体素：直接写回，并把天光清零（避免残留导致“空体素有天光”）
    if (!curOcc) {
        imageStore(voxel, p, cur);
        imageStore(voxelLitSky, p, vec4(0.0));
        return;
    }

    // 重投影到上一帧体素坐标
    ivec3 pp = reprojectToPrevVoxel(p);
    if (!voxelInBounds(pp)) {
        imageStore(voxel, p, cur);
        // 有物体时保留当前天光（只用r，其余写0）
        imageStore(voxelLitSky, p, vec4(curSky.r, 0.0, 0.0, 0.0));
        return;
    }

    vec4 hist    = imageLoad(voxelPrev, pp);
    vec4 histSky = imageLoad(voxelLitSkyPrev, pp);

    bool histOcc = voxelOccupied(hist);

    // 占用发生变化：不使用历史，避免放置/破坏方块时的拖影延迟
    if (histOcc != curOcc) {
        imageStore(voxel, p, cur);
        imageStore(voxelLitSky, p, vec4(curSky.r, 0.0, 0.0, 0.0));
        return;
    }

    // 可选：如果你担心“天空光/颜色突变”产生拖影，可启用阈值切断
    // float skyDiff = abs(curSky.r - histSky.r);
    // if (skyDiff > 0.25) {
    //     imageStore(voxel, p, cur);
    //     imageStore(voxelLitSky, p, vec4(curSky.r, 0.0, 0.0, 0.0));
    //     return;
    // }

    // 时域权重（历史占比）
    float historyWeight      = 0.98; // 体素颜色/自发光
    float historyWeightSky   = 0.98; // 天光（你也可以单独调，比如 0.9 让它更“跟手”）

    vec4 outv = mix(cur, hist, historyWeight);

    // 天光只混合r通道，其余保持0
    float outSkyR = mix(curSky.r, histSky.r, historyWeightSky);
    vec4  outSky  = vec4(outSkyR, 0.0, 0.0, 0.0);

    imageStore(voxel, p, outv);
    imageStore(voxelLitSky, p, outSky);
}
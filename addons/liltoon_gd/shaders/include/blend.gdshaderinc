#ifndef LILTOON_GD_BLEND_INCLUDED
#define LILTOON_GD_BLEND_INCLUDED

// 对齐 lilToon 的 lilBlendColor（lil_common_functions.hlsl:325-335）。
//
// 关键语义：dst_col 是"写该效果之前的表面累计色"，**不是帧缓冲**。
// 因此只要效果色由 shader 自己算出（rim、自定义反射立方体贴图），就能等价实现四式混合；
// 而引擎 IBL 的反射色由引擎在 shader 之后合成，shader 取不到，那条路径只能保持加法。
//
// 0 = Normal（替换）  1 = Add（相加）  2 = Screen  3 = Multiply
// 最后按 src_alpha 与 dst 插值，与原版 lerp(dstCol, outCol, srcA) 一致。
vec3 lil_blend_color(vec3 dst_col, vec3 src_col, vec3 src_alpha, int blend_mode) {
    vec3 ad = dst_col + src_col;
    vec3 mu = dst_col * src_col;
    vec3 out_col = src_col;
    if (blend_mode == 1) {
        out_col = ad;
    } else if (blend_mode == 2) {
        out_col = max(ad - mu, dst_col);
    } else if (blend_mode == 3) {
        out_col = mu;
    }
    return mix(dst_col, out_col, src_alpha);
}

#endif

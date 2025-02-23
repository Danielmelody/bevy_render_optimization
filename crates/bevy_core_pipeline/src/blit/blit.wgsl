#import bevy_core_pipeline::fullscreen_vertex_shader::FullscreenVertexOutput

@group(0) @binding(0) var in_texture: texture_2d<f32>;
@group(0) @binding(1) var in_sampler: sampler;

fn cubic(v: f32) -> vec4<f32> {
    let v2 = v * v;
    let v3 = v2 * v;
    return vec4<f32>(
         -0.5 * v3 + v2 - 0.5 * v,
          1.5 * v3 - 2.5 * v2 + 1.0,
         -1.5 * v3 + 2.0 * v2 + 0.5 * v,
          0.5 * v3 - 0.5 * v2
    );
}

fn textureBicubic(tex: texture_2d<f32>, samp: sampler, texCoords: vec2<f32>) -> vec4<f32> {
    // Retrieve texture size and compute its inverse as floating point values.
    let dims: vec2<u32> = textureDimensions(tex, 0);
    let texSize = vec2<f32>(dims);
    let invTexSize = 1.0 / texSize;
    
    // Transform coordinates from normalized [0,1] to texel space and offset by half a texel.
    var coords = texCoords * texSize - vec2<f32>(0.5);
    let fxy = fract(coords);
    coords = coords - fxy;
    
    // Compute the cubic interpolation weights for each axis.
    let xcubic = cubic(fxy.x);
    let ycubic = cubic(fxy.y);
    
    // Build the initial coordinate vector.
    let c = vec4<f32>(coords.x, coords.x, coords.y, coords.y) +
            vec4<f32>(-0.5, 1.5, -0.5, 1.5);
    
    // Compute the denominators for interpolation in x and y.
    let s = vec4<f32>(
        xcubic.x + xcubic.y,  // = (xcubic.xz + xcubic.yw).x
        xcubic.z + xcubic.w,  // = (xcubic.xz + xcubic.yw).y
        ycubic.x + ycubic.y,  // = (ycubic.xz + ycubic.yw).x
        ycubic.z + ycubic.w   // = (ycubic.xz + ycubic.yw).y
    );
    
    // Calculate offset for sampling by adjusting with the cubic weights.
    let offset = c + vec4<f32>(xcubic.y, xcubic.w, ycubic.y, ycubic.w) / s;
    let finalOffset = offset * vec4<f32>(invTexSize.x, invTexSize.x, invTexSize.y, invTexSize.y);
    
    // Sample four neighboring texels.
    let sample0 = min(textureSample(tex, samp, vec2<f32>(finalOffset.x, finalOffset.z)), vec4<f32>(1.0));
    let sample1 = min(textureSample(tex, samp, vec2<f32>(finalOffset.y, finalOffset.z)), vec4<f32>(1.0));
    let sample2 = min(textureSample(tex, samp, vec2<f32>(finalOffset.x, finalOffset.w)), vec4<f32>(1.0));
    let sample3 = min(textureSample(tex, samp, vec2<f32>(finalOffset.y, finalOffset.w)), vec4<f32>(1.0));
    
    // Compute the blend factors along x and y.
    let sx = s.x / (s.x + s.y);
    let sy = s.z / (s.z + s.w);
    
    // Perform the bilinear interpolation of the two interpolated values.
    let mixA = sample3 * (1.0 - sx) + sample2 * sx;
    let mixB = sample1 * (1.0 - sx) + sample0 * sx;
    return mixA * (1.0 - sy) + mixB * sy;
}

// #define USE_BICUBIC

@fragment
fn fs_main(in: FullscreenVertexOutput) -> @location(0) vec4<f32> {
    #ifdef USE_BICUBIC
        return textureBicubic(in_texture, in_sampler, in.uv);
    #else
        return textureSample(in_texture, in_sampler, in.uv);
    #endif
}

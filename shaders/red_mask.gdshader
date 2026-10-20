shader_type canvas_item;
// Red-ink mask for painted or textured assets in The Violence.
//
// Base art stays neutral; a greyscale shade mask says where the ink lands. White
// mask = full red, black = no red, so blood, routes and alarms all share one
// source of colour and the monochrome proof is a single uniform.
//
// Leave shade_mask unassigned for an asset that is entirely red (the white masks
// in assets/redink/masks/), or assign a greyscale texture to tint only part of it.

uniform sampler2D shade_mask : source_color, filter_linear_mipmap;
uniform float red_strength : hint_range(0.0, 1.0) = 0.78;
uniform bool red_ink_enabled = true;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	// stepped tones, not gradients: base art uses a few greys only
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float tone = floor(luminance * 4.0 + 0.5) / 4.0;
	float mask = texture(shade_mask, UV).r * red_strength;
	if (!red_ink_enabled) {
		mask = 0.0;
	}
	vec3 neutral = vec3(tone);
	vec3 red_ink = vec3(tone, tone * 0.18, tone * 0.20);
	COLOR = vec4(mix(neutral, red_ink, mask), source.a) * COLOR;
}

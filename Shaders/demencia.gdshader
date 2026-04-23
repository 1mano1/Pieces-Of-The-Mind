shader_type canvas_item;

// intensidad: 0.0 = invisible, 1.0 = efecto completo
uniform float intensidad : hint_range(0.0, 1.0) = 0.0;
uniform float tiempo     : hint_range(0.0, 100.0) = 0.0;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	// Grano de estatica (ruido blanco)
	float grain = rand(uv + fract(tiempo * 0.23));

	// Lineas horizontales de interferencia
	float scanline = sin(uv.y * 280.0 + tiempo * 10.0) * 0.5 + 0.5;
	scanline = pow(scanline, 3.0);

	// Lineas verticales rapidas ocasionales
	float vline = step(0.97, rand(vec2(floor(uv.x * 60.0), fract(tiempo * 0.07))));

	// Combina efectos
	float noise = grain * 0.6 + scanline * 0.25 + vline * 0.4;

	// Color del ruido: blanco con leve tinte frio (no verde)
	vec3 noise_color = vec3(noise * 0.95, noise * 0.95, noise);

	// Viñeta: los bordes se oscurecen mas con la intensidad
	vec2 v_uv = uv * 2.0 - 1.0;
	float vignette = dot(v_uv * 0.6, v_uv * 0.6);
	vignette = clamp(vignette, 0.0, 1.0);

	// Alpha: el overlay es transparente al centro y mas opaco en bordes
	// Solo se hace visible con la intensidad
	float alpha_base = mix(noise * 0.35, noise * 0.75, vignette);
	float alpha = alpha_base * intensidad;

	// En el pico de intensidad (> 0.7) agrega un flash global leve
	float flash = max(0.0, (intensidad - 0.7) / 0.3) * grain * 0.3;
	alpha = clamp(alpha + flash, 0.0, 0.92);

	COLOR = vec4(noise_color, alpha);
}

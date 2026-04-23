shader_type canvas_item;

// apertura: 0.0 = ojo cerrado (todo negro), 1.0 = ojo abierto (ve la escena)
uniform float apertura : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	// El ojo es MUY ancho y poco alto — forma de almendra real
	// x va de -1 a 1 en anchura completa de pantalla
	// y es muy achatado: dividimos por 0.38 para hacerlo más aplastado
	float alto = max(apertura * 0.38, 0.001);

	// Elipse: dentro del ojo (dentro < 1) = TRANSPARENTE (se ve la casa)
	//         fuera del ojo (dentro > 1) = NEGRO (el párpado)
	float dentro = (uv.x * uv.x) + (uv.y * uv.y) / (alto * alto);

	// dentro < 1 → ojo abierto → alpha = 0 (transparente)
	// dentro > 1 → párpado    → alpha = 1 (negro)
	float alpha = smoothstep(0.94, 1.06, dentro);

	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}

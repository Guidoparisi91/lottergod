shader_type spatial;
render_mode cull_disabled, depth_draw_never, diffuse_burley;

// Capa de suelo (tierra, pasto) que se apoya sobre el piso base.
//
// Tres problemas resueltos:
//   1. Textura estirada al escalar el nodo  -> la textura TILEA por dentro.
//   2. Borde rectangular duro               -> alpha calculado aparte, con ruido.
//   3. La grilla del tileado se nota        -> ver "detalle macro" abajo.

uniform sampler2D textura : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mapa_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D mapa_ao : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool usar_normal = false;
uniform bool usar_ao = false;
uniform float normal_fuerza : hint_range(0.0, 3.0) = 1.0;
uniform float ao_fuerza : hint_range(0.0, 1.0) = 0.7;

// Cuántas veces se repite la textura a lo largo del parche. Si agrandás el nodo,
// subilo en la misma proporción o los granos se ven gigantes.
uniform float repeticiones : hint_range(1.0, 60.0) = 10.0;

// --- Detalle macro: lo que mata la repetición ---
// Se muestrea la MISMA textura una segunda vez, mucho más grande, y se multiplica.
// El resultado tiene manchas del tamaño del parche entero, así que la grilla del
// tileado deja de leerse. Es la técnica estándar y cuesta un solo sample extra.
uniform float macro_escala : hint_range(0.05, 1.0) = 0.22;
uniform float macro_fuerza : hint_range(0.0, 1.0) = 0.55;

// --- Borde ---
uniform float borde_inicio : hint_range(0.0, 0.95) = 0.45;
uniform float irregularidad : hint_range(0.0, 0.4) = 0.18;

// --- Mezcla con el piso de abajo ---
// Bajarla deja ver el adoquín POR DEBAJO, y ahí se lee como suciedad acumulada
// en vez de como una calcomanía pegada encima.
uniform float opacidad : hint_range(0.0, 1.0) = 1.0;

uniform vec3 tinte : source_color = vec3(1.0);
uniform float aspereza : hint_range(0.0, 1.0) = 0.95;

void fragment() {
	vec2 uv_tile  = UV * repeticiones;
	vec2 uv_macro = UV * repeticiones * macro_escala;

	vec3 detalle = texture(textura, uv_tile).rgb;
	vec3 macro   = texture(textura, uv_macro).rgb;

	// El macro modula el brillo del detalle. La razon entre ambas luminancias se
	// autonormaliza: donde las dos coinciden el factor es 1 y no cambia nada, asi
	// que la textura NO se oscurece ni se aclara en promedio, solo se le agregan
	// manchas grandes. El clamp evita que una zona muy clara la queme a blanco.
	float lum_macro = dot(macro,   vec3(0.299, 0.587, 0.114));
	float lum_det   = dot(detalle, vec3(0.299, 0.587, 0.114));
	float razon = (lum_macro + 0.02) / (lum_det + 0.02);
	float factor = clamp(mix(1.0, razon, macro_fuerza), 0.65, 1.35);
	vec3 color = detalle * factor;

	if (usar_ao) {
		float ao = texture(mapa_ao, uv_tile).r;
		color *= mix(1.0, ao, ao_fuerza);
	}

	// Distancia al centro en UV sin tilear: 0 en el medio, 1 en el borde.
	vec2 desde_centro = UV - vec2(0.5);
	float d = length(desde_centro) * 2.0;

	// Radio deformado por ángulo: rompe el óvalo con dos armónicos.
	float ang = atan(desde_centro.y, desde_centro.x);
	float radio = 1.0 + irregularidad * (sin(ang * 3.0) + 0.6 * sin(ang * 5.0 + 1.3));

	ALBEDO = color * tinte;
	ALPHA = (1.0 - smoothstep(borde_inicio * radio, radio, d)) * opacidad;
	ROUGHNESS = aspereza;
	SPECULAR = 0.1;

	if (usar_normal) {
		NORMAL_MAP = texture(mapa_normal, uv_tile).rgb;
		NORMAL_MAP_DEPTH = normal_fuerza;
	}
}

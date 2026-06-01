shader_type canvas_item;

uniform bool Inverted;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	if (Inverted) {
		COLOR = vec4(1.0-COLOR.x,1.0-COLOR.y,1.0-COLOR.z,COLOR.a);
	}
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}

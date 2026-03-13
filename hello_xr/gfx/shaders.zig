pub const es3 = struct {
    // The version statement has come on first line.
    pub const vs: [*:0]const u8 =
        \\#version 320 es
        \\
        \\in vec3 VertexPos;
        \\in vec3 VertexColor;
        \\
        \\out vec3 PSVertexColor;
        \\
        \\uniform mat4 ModelViewProjection;
        \\
        \\void main() {
        \\   gl_Position = ModelViewProjection * vec4(VertexPos, 1.0);
        \\   PSVertexColor = VertexColor;
        \\}
        \\
    ;

    // The version statement has come on first line.
    pub const fs: [*:0]const u8 =
        \\#version 320 es
        \\
        \\in lowp vec3 PSVertexColor;
        \\out lowp vec4 FragColor;
        \\
        \\void main() {
        \\   FragColor = vec4(PSVertexColor, 1);
        \\}
        \\
    ;
};

pub const gl4 = struct {
    pub const vs: [*:0]const u8 =
        \\#version 410
        \\
        \\in vec3 VertexPos;
        \\in vec3 VertexColor;
        \\
        \\out vec3 PSVertexColor;
        \\
        \\uniform mat4 ModelViewProjection;
        \\
        \\void main() {
        \\   gl_Position = ModelViewProjection * vec4(VertexPos, 1.0);
        \\   PSVertexColor = VertexColor;
        \\}
        \\
    ;

    pub const fs: [*:0]const u8 =
        \\#version 410
        \\
        \\in vec3 PSVertexColor;
        \\out vec4 FragColor;
        \\
        \\void main() {
        \\   FragColor = vec4(PSVertexColor, 1);
        \\}
        \\
    ;
};

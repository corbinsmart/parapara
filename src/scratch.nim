
  # let baseEntity = initTwoDEntity(primitives.rectangle[GLfloat]())
  # var uncompiledEntity = initInstancedEntity(baseEntity)
  # for _ in 0 ..< 50:
  #   var e = baseEntity
  #   e.project(float(windowWidth), float(windowHeight))
  #   e.translate(GLfloat(rand(windowWidth)), GLfloat(rand(windowHeight)))
  #   e.scale(GLfloat(rand(300)), GLfloat(rand(300)))
  #   e.color(vec4(GLfloat(rand(1.0)), GLfloat(rand(1.0)), GLfloat(rand(1.0)), 1f))
  #   uncompiledEntity.add(e)
  # entity = compile(game, uncompiledEntity)























#   fragmentShader =
#     """
# #version 330 core
# in vec4 v_color;
# //in vec2 fragCoord;
# //in vec2 gl_Position;
# out vec4 fragColor;

# void main()
# {
#   vec2 iResolution = vec2(1024, 768);
#   //vec2 fragCoord = gl_Position;

#   vec2 p = (2.0*gl_Position-iResolution.xy)/min(iResolution.y,iResolution.x);

#   fragColor = v_color;
# }
#     """

#   fragmentShader =
#     """
# #version 330 core
# in vec4 v_color;
# out vec4 fragColor;

# void main( out vec4 fragColor, in vec2 fragCoord )
# {
# 	vec2 p = (2.0*fragCoord-iResolution.xy)/min(iResolution.y,iResolution.x);

#   // background color
#   vec3 bcol = vec3(1.0,0.8,0.7-0.07*p.y)*(1.0-0.25*length(p));

#   // animate
#   float tt = mod(iTime,1.5)/1.5;
#   float ss = pow(tt,.2)*0.5 + 0.5;
#   ss = 1.0 + ss*0.5*sin(tt*6.2831*3.0 + p.y*0.5)*exp(-tt*4.0);
#   p *= vec2(0.5,1.5) + ss*vec2(0.5,-0.5);

#   // shape
#   p.y -= 0.25;
#   float a = atan(p.x,p.y)/3.141593;
#   float r = length(p);
#   float h = abs(a);
#   float d = (13.0*h - 22.0*h*h + 10.0*h*h*h)/(6.0-5.0*h);
    
# 	// color
# 	float s = 0.75 + 0.75*p.x;
# 	s *= 1.0-0.4*r;
# 	s = 0.3 + 0.7*s;
# 	s *= 0.5+0.5*pow( 1.0-clamp(r/d, 0.0, 1.0 ), 0.1 );
# 	vec3 hcol = vec3(1.0,0.4*r,0.3)*s;

#     vec3 col = mix( bcol, hcol, smoothstep( -0.01, 0.01, d-r) );

#     fragColor = vec4(col,1.0);
# }
#     """

# proc circleSmooth(fragColor: var Vec4, uv: Vec2, time: Uniform[float32]) =
#   var a = 0.0
#   var radius = 300.0 + 100 * sin(time)
#   for x in 0 ..< 8:
#     for y in 0 ..< 8:
#       if (uv + vec2(x.float32 - 4.0, y.float32 - 4.0) / 8.0).length < radius:
#         a += 1
#   a = a / (8 * 8)
#   fragColor = vec4(a, a, a, 1)
# var generatedFragShader = toGLSL(circleSmooth)
# echo generatedFragShader

# proc vert(
#   gl_Position: var Vec4,
#   MVP: Uniform[Mat4],
#   vCol: Vec3,
#   vPos: Vec3
# ) =
#   gl_Position = MVP * vec4(vPos.x, vPos.y, 0.0, 1.0)

# proc frag(fragColor: var Vec4, vertColor: Vec3) =
#   fragColor = vec4(vertColor.x, vertColor.y, vertColor.z, 1.0)

# var
#   vertText = toGLSL(vert)
#   fragText = toGLSL(frag)
# echo vertText
# echo fragText

const
  vertexShader =
    """
#version 330 core
layout (location = 0) in vec2 a_pos;
out vec4 vertexColor;

void main()
{
  gl_Position = vec4(a_pos.x, a_pos.y, 0.0, 1.0);
  vertexColor = vec4(0.5, 0.0, 0.0, 1.0);
}
    """

  fragmentShader =
    """
#version 330 core
out vec4 fragColor;

uniform vec4 u_color;
//uniform vec2 u_resolution;
//uniform vec2 u_mouse;
//uniform float u_float;

void main()
{
  //fragColor = vec4(abs(sin(u_float)), 0.0, 0.0, 1.0);
  fragColor = u_color;
}
    """

 fragmentShaderGenerated =
    """
#version 330 core
//#define fragCoord gl_FragCoord.xy

// REMOVE
//#version 410
//precision highp float;
// from frag
//vec2 iResolution = vec2();

// ADD
uniform vec3 iResolution;

float opSmoothUnion(float a, float b, float kk);
float sdRoundedBox(vec2 p, vec2 b, vec4 rr);

float opSmoothUnion(
  float a,
  float b,
  float kk
) {
  float result;
  float k = kk;
  k *= 4.0;
  float h = max(k - abs(a - b), 0.0);
  result = min(a, b) - ((h * h) * 0.25) / k;
  return result;
}
float sdRoundedBox(
  vec2 p,
  vec2 b,
  vec4 rr
) {
  float result;
  vec4 r = rr;
  (r).xy = ((0.0 < float(p.x)) ? (r.xy) : (r.zw));
  r.x = ((0.0 < float(p.y)) ? (r.x) : (r.y));
  vec2 q = (abs(p) - b) + r.x;
  result = (min(float(max(q.x, q.y)), 0.0) + float(length(max(q, 0.0)))) - float(r.x);
  return result;
}

out vec4 fragColor;

// REMOVE
//out vec4 gl_FragCoord;

void main() {
  vec2 fragCoord = (gl_FragCoord).xy;
  vec2 p = (fragCoord * 2.0 - iResolution.xy) / iResolution.y;
  vec3 sky = vec3(0.55, 0.75, 0.9);
  vec3 grey = vec3(0.5, 0.5, 0.5);
  vec3 white = vec3(1.0);
  float r1 = sdRoundedBox(p + vec2(-0.2, -0.2), vec2(0.6, 0.2), vec4(0.1, 0.1, 0.1, 0.1));
  float r2 = sdRoundedBox(p + vec2(0.2, 0.2), vec2(0.6, 0.2), vec4(0.1, 0.1, 0.1, 0.1));
  float d = opSmoothUnion(r1, r2, 0.1);
  vec3 col = ((0.0 < d) ? (white) : (sky));
  fragColor = vec4(col, 1.0);
}
  """
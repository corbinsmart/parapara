import paranim/opengl
import paranim/gl, paranim/gl/uniforms, paranim/gl/attributes, paranim/gl/entities
from paranim/primitives import nil
from paranim/math as pmath import nil
import paranim/glfw
import paranim/glm
import random
import typeinfo
import math

# import paranim/gl, paranim/gl/[uniforms, attributes, entities]
# from paranim/gl/attributes import nil
# import shady, vmath
# import vmath

type
  float = float32
  Handle = enum
    None,
    Left, Right, Top, Bottom,
    TopLeft, TopRight, BottomLeft, BottomRight
  Game* = object of RootGame
    deltaTime*: float
    totalTime*: float
  PaneUniforms = tuple[
    iTime: Uniform[float],
    iResolution: Uniform[Vec3f],
    iMouse: Uniform[Vec4f],
    iM: Uniform[Vec2f],
    uColor: Uniform[Vec4f],
    uBalls: Uniform[seq[Vec4f]],
    uBoxes: Uniform[seq[Vec4f]],
    uZIndex: Uniform[seq[GLint]],
    uArrows: Uniform[seq[Vec4f]],
  ]
  PaneAttributes = tuple[
    aPos: Attribute[float]
  ]
  Pane = object of ArrayEntity[PaneUniforms, PaneAttributes]
  UncompiledPane = object of UncompiledEntity[Pane, PaneUniforms, PaneAttributes]

const
  pi = PI.float32
  BALL_COUNT = 10
  BOX_COUNT = 1
  ARROW_COUNT = 3
  vertices = [-1f, -1f,
              -1f, 1f,
              1f, 1f,
              
              1f, 1f,
              1f, -1f,
              -1f, -1f]
  vertexShader =
    """
#version 330 core
layout (location = 0) in vec2 aPos;

void main()
{
  gl_Position = vec4(aPos.x, aPos.y, 0.0, 1.0);
}
    """

  fragmentShader =
    """
#version 330 core
out vec4 fragColor;

uniform float iTime;
uniform vec3 iResolution;
uniform vec4 iMouse;
uniform vec2 iM;

uniform vec4 uColor;
uniform vec4 uBalls[""" & $BALL_COUNT & """];
uniform vec4 uBoxes[""" & $BOX_COUNT & """];
uniform int uZIndex[""" & $BOX_COUNT & """];
uniform vec4 uArrows[""" & $ARROW_COUNT & """];

// const
const vec3 c = vec3(1.,0.,-1.);
const float pi = acos(-1.);

// noise
vec3 random3(vec3 c) {
    float j = 4096.0*sin(dot(c,vec3(17.0, 59.4, 15.0)));
    vec3 r;
    r.z = fract(512.0*j);
    j *= .125;
    r.x = fract(512.0*j);
    j *= .125;
    r.y = fract(512.0*j);
    return r-0.5;
}
const float F3 =  0.3333333;
const float G3 =  0.1666667;
float snoise(vec3 p) {

    vec3 s = floor(p + dot(p, vec3(F3)));
    vec3 x = p - s + dot(s, vec3(G3));

    vec3 e = step(vec3(0.0), x - x.yzx);
    vec3 i1 = e*(1.0 - e.zxy);
    vec3 i2 = 1.0 - e.zxy*(1.0 - e);

    vec3 x1 = x - i1 + G3;
    vec3 x2 = x - i2 + 2.0*G3;
    vec3 x3 = x - 1.0 + 3.0*G3;

    vec4 w, d;

    w.x = dot(x, x);
    w.y = dot(x1, x1);
    w.z = dot(x2, x2);
    w.w = dot(x3, x3);

    w = max(0.6 - w, 0.0);

    d.x = dot(random3(s), x);
    d.y = dot(random3(s + i1), x1);
    d.z = dot(random3(s + i2), x2);
    d.w = dot(random3(s + 1.0), x3);

    w *= w;
    w *= w;
    d *= w;

    return dot(d, vec4(52.0));
}

// sdf
float sdCircle( vec2 p, float r ) {
    return length(p) - r;
}
float sdRoundedBox( in vec2 p, in vec2 b, in vec4 r ) {
  r.xy = (p.x>0.0)?r.xy : r.zw;
  r.x  = (p.y>0.0)?r.x  : r.y;
  vec2 q = abs(p)-b+r.x;
  return min(max(q.x,q.y),0.0) + length(max(q,0.0)) - r.x;
}
float sdSegment( in vec2 p, in vec2 a, in vec2 b, in float r ) {
    vec2 ba = b-a;
    vec2 pa = p-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length(pa-h*ba)-r;
}

// sdf ops
float opSmoothUnion( float a, float b, float k ) {
  k *= 4.0;
  float h = max(k-abs(a-b),0.0);
  return min(a, b) - h*h*0.25/k;
}

// Cubic bezier curve
vec2 B3(float t, vec2 P0, vec2 P1, vec2 P2, vec2 P3) {
    float m1 = 1.-t;
    return m1*m1*m1*P0 + 3.*m1*t*(m1*P1+t*P2) + t*t*t*P3;
}
// Cubic bezier partial derivative with respect to t
vec2 B3Prime(float t, vec2 P0, vec2 P1, vec2 P2, vec2 P3) {
    float m1 = 1.-t;
    return 3.*(m1*m1*(P1-P0)+2.*m1*t*(P2-P1)+t*t*(P3-P2));
}
// Cubic bezier second partial derivative with respect to t
vec2 B3Second(float t, vec2 P0, vec2 P1, vec2 P2, vec2 P3) {
    float m1 = 1.-t;
    return 6.*m1*(P2-2.*P1+P0)+6.*t*(P3-2.*P2+P1);
}
// This is the "easy" representation of the quintic that has to be solved
// for the sdf.
float D3Prime(vec2 x, float  t, vec2 P0, vec2 P1, vec2 P2, vec2 P3) {
    return dot(x-B3(t,P0,P1,P2,P3), B3Prime(t,P0,P1,P2,P3));
}
// Determine zeros of a*x^2+b*x+c
vec2 quadratic_zeros(float a, float b, float cc) {
    if(a == 0.) return -cc/b*c.xx;
    float d = b*b-4.*a*cc;
    if(d<0.) return vec2(1.e4);
    return (c.xz*sqrt(d)-b)/(2.*a);
}
// Determine zeros of a*x^3+b*x^2+c*x+d
vec3 cubic_zeros(float a, float b, float cc, float d) {
    if(a == 0.) return quadratic_zeros(b,cc,d).xyy;
    
    // Depress
    vec3 ai = vec3(b,cc,d)/a;
    
    //discriminant and helpers
    float tau = ai.x/3., 
        p = ai.y-tau*ai.x, 
        q = -tau*(tau*tau+p)+ai.z, 
        dis = q*q/4.+p*p*p/27.;
        
    //triple real root
    if(dis > 0.) {
        vec2 ki = -.5*q*c.xx+sqrt(dis)*c.xz, 
            ui = sign(ki)*pow(abs(ki), c.xx/3.);
        return vec3(ui.x+ui.y-tau);
    }
    
    //three distinct real roots
    float fac = sqrt(-4./3.*p), 
        arg = acos(-.5*q*sqrt(-27./p/p/p))/3.;
    return c.zxz*fac*cos(arg*c.xxx+c*pi/3.)-tau;
}
// Determine zeros of a*x^4+b*x^3+c*x^2+d*x+e
vec4 quartic_zeros(float a, float b, float cc, float d, float e) {
    if(a == 0.) return cubic_zeros(b, cc, d, e).xyzz;
    
    // Depress
    float _b = b/a,
        _c = cc/a,
        _d = d/a,
        _e = e/a;
        
    // Helpers
    float p = (8.*_c-3.*_b*_b)/8.,
        q = (_b*_b*_b-4.*_b*_c+8.*_d)/8.,
        r = (-3.*_b*_b*_b*_b+256.*_e-64.*_b*_d+16.*_b*_b*_c)/256.;
        
    // Determine available resolvent zeros
    vec3 res = cubic_zeros(8.,8.*p,2.*p*p-8.*r,-q*q);
    
    // Find nonzero resolvent zero
    float m = res.x;
    if(m == 0.) m = res.y;
    if(m == 0.) m = res.z;
    
    // Apply newton iteration to fix numerical artifacts;
    // Credit goes to NinjaKoala / epoqe :)
    for(int i=0; i < 2; i++) {
        float a_2 = p + m;
        float a_1 = p*p/4.-r + m * a_2;
        float b_2 = a_2 + m;

        float f = -q*q/8. + m * a_1;
        float f1 = a_1 + m * b_2;

        m -= f / f1; // Newton iteration step
    }
    
    // Apply Ferrari method
    return vec4(
        quadratic_zeros(1.,sqrt(2.*m),p/2.+m-q/(2.*sqrt(2.*m))),
        quadratic_zeros(1.,-sqrt(2.*m),p/2.+m+q/(2.*sqrt(2.*m)))
    )-_b/4.;
}
// minimum distance to a cubic spline with the following strategy:
float dcubic_spline(in vec2 x, in vec2 p0, in vec2 p1, in vec2 p2, in vec2 p3) {
    // Use relative coordinates to eliminate all terms containing p0.
    x -= p0;
    p1 -= p0;
    p2 -= p0;
    p3 -= p0;
    p0 = c.yy;
    
    // Use interval approximation to determine a numerical solution for the quintic.
    // TODO: find something better, I really would like an analytical approach
    float tmin = -0.5, tmax = 1.5, tnew, 
        dmin = D3Prime(x,tmin,p0,p1,p2,p3),
        dmax = D3Prime(x,tmax,p0,p1,p2,p3),
        dnew;
    
    for(int i=0; i<20; ++i)
    {
        tnew = mix(tmin, tmax, .5);
        dnew = D3Prime(x,tnew,p0,p1,p2,p3);
        
        if(dnew>0.)
        {
            tmin = tnew;
            dmin = dnew;
        }
        else 
        {
            tmax = tnew;
            dmax = dnew;
        }
    }
    
    // Determine coefficients of quintic equation.
    vec2 pa = p2-p1;
    float a5 = -dot(p3,p3)+3.*dot(pa,2.*p3-3.*pa),
        a4 = 5.*dot(p1-pa,p3)+15.*dot(pa,pa-p1),
        a3 = -6.*dot(p2,p2)+4.*dot(p1,9.*pa-p3),
        a2 = dot(p3-3.*pa,x)+9.*dot(p1,p1-pa),
        a1 = 2.*dot(pa-p1,x)-3.*dot(p1,p1),
        a0 = dot(p1,x);
    
    // Polynomial division of numerical solution.
    float _a = a5,
        _b = a4+_a*tmin,
        _c = a3+_b*tmin,
        _d = a2+_c*tmin,
        _e = a1+_d*tmin;
        
    vec4 t = clamp(quartic_zeros(_a,_b,_c,_d,_e),0.,1.);
    tmin = clamp(tmin, 0.,1.);
    
    return min(
        length(x-B3(tmin,p0,p1,p2,p3)),
        min(
            min(
                length(x-B3(t.x,p0,p1,p2,p3)),
                length(x-B3(t.y,p0,p1,p2,p3))
            ),
            min(
                length(x-B3(t.z,p0,p1,p2,p3)),
                length(x-B3(t.w,p0,p1,p2,p3))
            )
        )
    );
}

float spline(vec2 p) {
    // control points
    vec2 p_0 = .5*vec2(sin(1.1*iTime), .5*cos(3.*iTime)), 
    p_1 = .5*vec2(1.-sin(1.3*iTime), .5-.5*sin(1.3*iTime)),
    p_2 = .5*vec2(cos(1.5*iTime), .5*sin(1.1*iTime)),
    p_3 = .5*vec2(-sin(1.15*iTime), .5-.5*cos(.2-iTime));

    // bezier curve
    float d = abs(dcubic_spline(p,p_0,p_1,p_2,p_3))-.01;
    return d;
}

// arc
float DFarc(vec2 p, vec2 p1, vec2 p2) {
    vec2 v1 = p1;;
    vec2 v2 = p2;
    // The parameters are over-determined by one degree of freedom.
    // If p1 and p2 are not on the same distance from c, the arc doesn't
    // actually end in p2, but the end cap is still centered there.
    // Uncomment this line if needed to adjust the distance from p2 to c.
    // v2 = normalize(v2)*length(v1);
    vec2 v = p;

    // The signs of w.x, w.y are used to determine if we're in the gap
    vec2 w = vec2(dot(v, -vec2(-v1.y, v1.x)), dot(v, vec2(-v2.y, v2.x)));
    bool longarc = (dot(v1, vec2(-v2.y, v2.x)) < 0.0); // Arc angle > pi
    // Tweak by iq: "fake" OR/AND of booleans by max/min of floats
    float ingap = longarc ? max(w.x,w.y) : min(w.x,w.y);
    return (ingap > 0.0) ? min(length(p1-p), length(p2-p)) : abs(length(v) - length(v1));
}
float SDFarc(vec2 p, vec2 p1, vec2 p2, float w) {
    return DFarc(p, p1, p2) - w;
}
float arc(vec2 pos, float r, float ang1, float ang2, float w) {
  vec2 p1 = r * vec2(cos(ang1), sin(ang1));
  vec2 p2 = r * vec2(cos(ang2), sin(ang2));
  return SDFarc(pos, p1, p2, w);
}

// .x = f(p)
// .y = ∂f(p)/∂x
// .z = ∂f(p)/∂y
// .yz = ∇f(p) with ‖∇f(p)‖ = 1
vec3 sdgBox( in vec2 p, in vec2 b, vec4 ra ) {
    ra.xy   = (p.x>0.0)?ra.xy : ra.zw;
    float r = (p.y>0.0)?ra.x  : ra.y;
    
    vec2 w = abs(p)-(b-r);
    vec2 s = sign(p);//vec2(p.x<0.0?-1:1,p.y<0.0?-1:1);
    
    float g = max(w.x,w.y);
  	vec2  q = max(w,0.0);
    float l = length(q);
    
    return vec3(   (g>0.0)?l-r: g-r,
                s*((g>0.0)?q/l : ((w.x>w.y)?vec2(1,0):vec2(0,1))));
}

// antialiasing
float sm(in float d) {
  return smoothstep(1.5/iResolution.y, -1.5/iResolution.y, d);
}

float bloby(vec2 p, vec2 m) {
  // n boxes
  float d = 9999.0;
  vec4 corner_radii = vec4(0.05);
  for (int i = 0; i < uBoxes.length(); i++) {
    vec4 box = uBoxes[i];
    vec2 pos = -box.xy;
    vec2 size = box.zw;
    float d_box = sdRoundedBox(p+pos, size, corner_radii);
    d = min(d_box,d);
  }
  return d;
  
  // 1 box
  //float r1 = sdRoundedBox(p+vec2(-0.2,-0.2), vec2(0.6,0.2), vec4(0.1,0.1,0.1,0.1));
  //return r1;

  // smooth 2 boxes, noise
  //float r1 = sdRoundedBox(p+vec2(-0.2,-0.2), vec2(0.6,0.2), vec4(0.1,0.1,0.1,0.1));
  //float r2 = sdRoundedBox(p+vec2(0.2,0.2), vec2(0.6,0.2), vec4(0.1,0.1,0.1,0.1));
  //float d = opSmoothUnion(r1, r2, 0.1);
  //d += -0.015 + snoise(vec3(p*5.0+iTime*0.2,0.1))*0.03;
  //return d;
}

void main()
{
  vec2 fragCoord = gl_FragCoord.xy;
  vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
  //vec2 m = (2.0*iMouse.xy-iResolution.xy)/iResolution.y;
  vec4 iMouse_UNUSED = iMouse;
  vec2 m = iM;

  // colors
  vec3 sky = vec3(0.55,0.75,0.9);
  vec3 grey = vec3(0.8,0.8,0.8);
  vec3 white = vec3(1.0);
  vec3 black = vec3(0.0);
  vec3 yellow = vec3(1.0,1.0,0.0);
  vec3 color = uColor.xyz;
  float greenValue = 0.9 + (1.0+sin(iTime))*0.5*0.1;
  vec3 green = vec3(0.0, greenValue, 0.0);
  
  vec3 col = grey;
  float d;
  int len;

  // boxes
  vec4 corner_radii = vec4(0.05);
  len = uBoxes.length();
  for (int i = len-1; i >= 0; i--) {
    int z = uZIndex[i];

    vec4 box = uBoxes[i];
    vec2 pos = -box.xy;
    vec2 size = box.zw;
    float d_box = sdRoundedBox(p+pos, size, corner_radii);
    col = mix(col, white, sm(d_box));
    col = mix( col, black, 1.0-smoothstep(0.0,0.01,abs(d_box)) );
  }
  // boxes:hover
  float corner_r = corner_radii.x;
  float corner = corner_r * 2.0;
  for (int i = len-1; i >= 0; i--) {
    vec4 box = uBoxes[i];
    vec2 pos = box.xy;
    vec2 size = box.zw;

    vec2 botleft = vec2(pos.x-size.x, pos.y-size.y);
    vec2 botright = vec2(pos.x+size.x, pos.y-size.y);
    vec2 topleft = vec2(pos.x-size.x, pos.y+size.y);
    vec2 topright = vec2(pos.x+size.x, pos.y+size.y);

    // edge
    float d_edge_bot = sdSegment(p, botleft+vec2(corner,0.0), botright+vec2(-corner,0.0), 0.02);
    float d_edge_bot_m = sdSegment(m, botleft+vec2(corner,0.0), botright+vec2(-corner,0.0), 0.02);
    if (d_edge_bot_m < 0.0)
      col = mix(col, green, sm(d_edge_bot));

    float d_edge_top = sdSegment(p, topleft+vec2(corner,0.0), topright+vec2(-corner,0.0), 0.02);
    float d_edge_top_m = sdSegment(m, topleft+vec2(corner,0.0), topright+vec2(-corner,0.0), 0.02);
    if (d_edge_top_m < 0.0)
      col = mix(col, green, sm(d_edge_top));

    float d_edge_left = sdSegment(p, botleft+vec2(0.0,corner), topleft+vec2(0.0,-corner), 0.02);
    float d_edge_left_m = sdSegment(m, botleft+vec2(0.0,corner), topleft+vec2(0.0,-corner), 0.02);
    if (d_edge_left_m < 0.0)
      col = mix(col, green, sm(d_edge_left));

    float d_edge_right = sdSegment(p, botright+vec2(0.0,corner), topright+vec2(0.0,-corner), 0.02);
    float d_edge_right_m = sdSegment(m, botright+vec2(0.0,corner), topright+vec2(0.0,-corner), 0.02);
    if (d_edge_right_m < 0.0)
      col = mix(col, green, sm(d_edge_right));

    // corner
    vec2 center;
    float w = 0.02;

    center = topleft+vec2(corner_r,-corner_r);
    float d_arc_topleft = arc(p-center, corner_r, pi*0.5, pi, w);
    float d_arc_topleft_m = arc(m-center, corner_r, pi*0.5, pi, w);
    if (d_arc_topleft_m < 0.0)
      col = mix(col, yellow, sm(d_arc_topleft));

    center = topright+vec2(-corner_r,-corner_r);
    float d_arc_topright = arc(p-center, corner_r, 0.0, pi*0.5, w);
    float d_arc_topright_m = arc(m-center, corner_r, 0.0, pi*0.5, w);
    if (d_arc_topright_m < 0.0)
      col = mix(col, yellow, sm(d_arc_topright));

    center = botleft+vec2(corner_r,corner_r);
    float d_arc_botleft = arc(p-center, corner_r, pi, pi*1.5, w);
    float d_arc_botleft_m = arc(m-center, corner_r, pi, pi*1.5, w);
    if (d_arc_botleft_m < 0.0)
      col = mix(col, yellow, sm(d_arc_botleft));

    center = botright+vec2(-corner_r,corner_r);
    float d_arc_botright = arc(p-center, corner_r, pi*1.5, pi*2.0, w);
    float d_arc_botright_m = arc(m-center, corner_r, pi*1.5, pi*2.0, w);
    if (d_arc_botright_m < 0.0)
      col = mix(col, yellow, sm(d_arc_botright));
  }


  // arrows
  len = uArrows.length();
  for (int i = len-1; i >= 0; i--) {
    vec4 arrow = uArrows[i];
    vec2 start = arrow.xy;
    vec2 stop = arrow.zw;
    
    // control points
    //vec2 p_0 = .5*vec2(sin(1.1*iTime), .5*cos(3.*iTime)),
    //     p_1 = .5*vec2(1.-sin(1.3*iTime), .5-.5*sin(1.3*iTime)),
    //     p_2 = .5*vec2(cos(1.5*iTime), .5*sin(1.1*iTime)),
    //     p_3 = .5*vec2(-sin(1.15*iTime), .5-.5*cos(.2-iTime));
    vec2 p_0 = start;
    vec2 p_1 = start+vec2(0.1,0.0);
    vec2 p_2 = stop-vec2(0.1,0.0);
    vec2 p_3 = stop;

    // bezier curve
    float d_arrow = abs(dcubic_spline(p,p_0,p_1,p_2,p_3))-.01;
    //col = mix(col, black, sm(d_arrow));
    //col = mix( col, black, 1.0-smoothstep(0.0,0.01,abs(d_arrow)) );
  }

  // Draw rects
  //float mdist = 9999.0;
  //for (int i = 0; i < uRects.length(); i++) {
  //  vec4 rect = uRects[i];
  //  vec2 pos = -rect.xy;
  //  vec2 size = rect.zw;
  //  float d_rect = sdRoundedBox(m+pos, size, corner_radii);
  //  mdist = min(d_rect,mdist);
  //}
  //vec3 rcol = mdist < 0.0 && iMouse.z > 0.0 ? green :
  //            mdist < 0.0 ? yellow :
  //            white;
  //col = mix(col, rcol, sm(d_rects));
  

  // bezier spline
  //float d_spline = spline(p);
  
  // arc
  //float time = iTime;
  //float tb = 3.14*(0.5+0.5*cos(time*0.31+2.0));
  //float rb = 0.15*(0.5+0.5*cos(time*0.41+3.0));
  //vec2  sc = vec2(sin(tb),cos(tb));
  //float d_arc = sdArc(p, m, sc, 0.7, rb);

  // Draw distance isolines
  //float interval = clamp(.03 * (d-mod(d,.025))/.025, 0., 1.);
  //col = mix(vec3(1.00,0.90,0.68), vec3(0.98,0.64,0.67), 2.*interval);
  //if(interval > .5) col = mix(col, vec3(0.54,0.80,0.80), 2.*(interval-.5));

  //float mdist = bloby(m,m);
  //vec3 rcol = mdist < 0.0 && iMouse.z > 0.0 ? green :
  //            mdist < 0.0 ? yellow :
  //            white;
  //col = mix(col, rcol, sm(d_rects));

  // Draw bezier curve
  //col = mix(col, black, sm(d_arc));

  // interaction
	//vec2 si = vec2(0.9,0.6) + 0.3*cos(iTime+vec2(0,2));
  //vec4 ra = 0.3 + 0.3*cos( 2.0*iTime + vec4(0,1,2,3) );
  //ra = min(ra,min(si.x,si.y));
  //vec3  dg = sdgBox(p,si,ra);
  //d = dg.x;
  //vec2 g = dg.yz;

  // mouse radius from d
  //if (iMouse.z > 0.0) {
  //  //d = sdgBox(m,si,ra).x;
  //  d = d_rects;
  //  col = mix(col, black, 1.0-smoothstep(0.0, 0.005, abs(length(p-m)-abs(d))-0.0025));
  //  col = mix(col, black, 1.0-smoothstep(0.0, 0.005, length(p-m)-0.015));
  //}

    // calc normal	
    //float a = bloby(p, m);
    //float b = bloby( p + vec2(2.0,0.0)/iResolution.y, m );
    //float c = bloby( p + vec2(0.0,2.0)/iResolution.y, m );
    //vec2 nor = normalize( vec2(b-a, c-a) );

    //vec3 col = grey;

    // specular	borders
    //col += 0.2*pow(clamp(dot(nor,normalize(vec2(-1.0,1.0))),0.0,1.0),2.0);
    //col += 0.5*pow(clamp(dot(nor,normalize(vec2(-1.0,1.0))),0.0,1.0),8.0);
    
    // specular highlight
    //col += 0.8*(1.0-d)*exp(-4.0*length(p-vec2(-0.3,0.3)));

    // color
    // col = abs(d) < 0.005 ? black :
    //      d < 0.0 ? white : grey;

    // concentric isolines
    //float interval = clamp(.03 * (d-mod(d,.025))/.025, 0., 1.);
    //vec3 col = mix(vec3(1.00,0.90,0.68), vec3(0.98,0.64,0.67), 2.*interval);
    //if(interval > .5) col = mix(col, vec3(0.54,0.80,0.80), 2.*(interval-.5));
    //col = mix(col, c.yyy, sm(d));
    //col = mix(col, .4*c.xxx, sm(abs(mod(d+.0125,.025)-.0125)-.001));
    
    // balls
    for (int i = 0; i < 10; i++) {
      vec4 ball = uBalls[i];
      vec2 pos = ball.xy;
      vec2 vel = ball.zw;
      float r = 0.1;
      float db = sdCircle(p-pos,r);
      //col = db < 0.0 ? black : col;
    }

    // aa
    //float w = 0.5*fwidth(d);
    //w *= 1.5; // extra blur
    //col = mix( black, col, smoothstep(-w,w,d-0.05) );
    //col = mix( green, col, smoothstep(-w,w,d-0.04) );




  fragColor = vec4(col,1.0);
}
    """

# sdf collision
proc sdRoundedBox(p: Vec2f, b: Vec2f, rr: Vec4f): float =
  var r = rr
  r.xy = if p.x > 0f: r.xy else: r.zw
  let q = abs(p) - b + r.x
  min(max(q.x,q.y),0f) + length(max(q,0f)) - r.x

proc dfArc(p: Vec2f, p1: Vec2f, p2: Vec2f): float =
  let
    v1 = p1
    v2 = p2
    v = p
    w = vec2(dot(v, -vec2(-v1.y, v1.x)), dot(v, vec2(-v2.y, v2.x)))
    longarc = dot(v1, vec2(-v2.y, v2.x)) < 0.0
    ingap = if longarc: max(w.x,w.y) else: min(w.x,w.y)
  if ingap > 0.0: min(length(p1-p), length(p2-p)) else: abs(length(v) - length(v1))

proc sdfArc(p: Vec2f, p1: Vec2f, p2: Vec2f, w: float): float =
  dfArc(p, p1, p2) - w

proc sdArc(pos: Vec2f, r: float, ang1: float, ang2: float, w: float): float =
  let
    p1 = r * vec2(cos(ang1), sin(ang1))
    p2 = r * vec2(cos(ang2), sin(ang2))
  sdfArc(pos, p1, p2, w)

proc sdSegment(p: Vec2f, a: Vec2f, b: Vec2f, r: float): float =
  let
    ba = b-a
    pa = p-a
    h = clamp(dot(pa,ba)/dot(ba,ba), 0f, 1f)
  length(pa-h*ba)-r

randomize()

var
  windowWidth: int
  windowHeight: int
  uncompiledPane: UncompiledPane
  pane: Pane
  activeBoxIndex = -1
  activeArrowIndex = -1
  mouseStartPos = vec2(0f)
  boxStart = vec4(0f)
  activeHandle = Handle.None
  holdingOption = false

proc initPane(): UncompiledPane =
  var position = Attribute[float](size: 2, iter: 1)
  new(position.data)
  position.data[].add(vertices)
  
  UncompiledPane(
    vertexSource: vertexShader,
    fragmentSource: fragmentShader,
    attributes: (
      aPos: position
    ),
    uniforms: (
      iTime: Uniform[GLfloat](),
      iResolution: Uniform[Vec3f](),
      iMouse: Uniform[Vec4f](),
      iM: Uniform[Vec2f](),
      uColor: Uniform[Vec4f](),
      uBalls: Uniform[seq[Vec4f]](),
      uBoxes: Uniform[seq[Vec4f]](),
      uZIndex: Uniform[seq[GLint]](),
      uArrows: Uniform[seq[Vec4f]](),
    )
  )

proc onKeyPress*(key: int) =
  case key:
    of 342:
      holdingOption = true
    else:
      discard

proc onKeyRelease*(key: int) =
  case key:
    of 342:
      holdingOption = false
    else:
      discard

proc onMouseClick*(button: int, action: int, mods: int) =
  let v = pane.uniforms.iMouse.data
  let iResolution = pane.uniforms.iResolution.data
  
  let iMouse = vec4(v.x, v.y, action.float, v.w)
  pane.uniforms.iMouse.disable = false
  pane.uniforms.iMouse.data = iMouse

  let iM = ((iMouse.xy*2f)-iResolution.xy)/iResolution.y
  pane.uniforms.iM.disable = false
  pane.uniforms.iM.data = iM

  if activeBoxIndex == -1 and action == 1:
    # body/handle selection
    for i in 0 ..< BOX_COUNT:
      let
        corner_radii = vec4(0.05f)
        box = pane.uniforms.uBoxes.data[i]
        pos = box.xy
        size = box.zw
        corner_r = corner_radii.x
        corner = corner_r * 2f
        width = 0.02f
      
      # select handle
      let
        botleft = pos + vec2(-size.x, -size.y)
        botright = pos + vec2(size.x, -size.y)
        topleft = pos + vec2(-size.x, size.y)
        topright = pos + vec2(size.x, size.y)

      activeHandle = Handle.None

      # edge
      let d_edge_bot = sdSegment(iM, botleft+vec2(corner,0f), botright+vec2(corner,0f), width)
      if d_edge_bot < 0f:
        activeHandle = Handle.Bottom

      let d_edge_top = sdSegment(iM, topleft+vec2(corner,0f), topright+vec2(-corner,0f), width)
      if d_edge_top < 0f:
        activeHandle = Handle.Top

      let d_edge_left = sdSegment(iM, botleft+vec2(0f,corner), topleft+vec2(0f,-corner), width)
      if d_edge_left < 0f:
        activeHandle = Handle.Left

      let d_edge_right = sdSegment(iM, botright+vec2(0f,corner), topright+vec2(0f,-corner), width)
      if d_edge_right < 0f:
        activeHandle = Handle.Right

      # corner
      var center: Vec2f
      center = topleft+vec2(corner_r,-corner_r)
      let d_arc_topleft = sdArc(iM-center, corner_r, pi*0.5f, pi, width);
      if d_arc_topleft < 0f:
        activeHandle = Handle.TopLeft

      center = topright+vec2(-corner_r,-corner_r)
      let d_arc_topright = sdArc(iM-center, corner_r, 0f, pi*0.5f, width);
      if d_arc_topright < 0f:
        activeHandle = Handle.TopRight

      center = botleft+vec2(corner_r,corner_r)
      let d_arc_botleft = sdArc(iM-center, corner_r, pi, pi*1.5f, width);
      if d_arc_botleft < 0f:
        activeHandle = Handle.BottomLeft

      center = botright+vec2(-corner_r,corner_r)
      let d_arc_botright = sdArc(iM-center, corner_r, pi*1.5f, pi*2f, width);
      if d_arc_botright < 0f:
        activeHandle = Handle.BottomRight

      # select body
      let
        d = sdRoundedBox(iM-pos, size, corner_radii)
        inside = d < 0f
      if inside:
        activeBoxIndex = i
        break

    # start drag box handle
    if activeBoxIndex > -1 and activeHandle != Handle.None:
      mouseStartPos = vec2(iM.x,iM.y)
      boxStart = pane.uniforms.uBoxes.data[activeBoxIndex]

    # start drag box body
    elif activeBoxIndex > -1 and activeHandle == Handle.None:
      mouseStartPos = vec2(iM.x,iM.y)
      boxStart = pane.uniforms.uBoxes.data[activeBoxIndex]

    # draw arrow
    else:
      activeArrowIndex = 0
      pane.uniforms.uArrows.disable = false
      pane.uniforms.uArrows.data[activeArrowIndex].xy = iM

  elif action == 0:
    activeBoxIndex = -1
    activeArrowIndex = -1
    activeHandle = Handle.None

proc onMouseMove*(xpos: float, ypos: float) =
  let iResolution = pane.uniforms.iResolution.data
  let v = pane.uniforms.iMouse.data
  
  let
    x = xpos
    y = iResolution.y - ypos
  let iMouse = vec4(x, y, v.z, v.w)
  pane.uniforms.iMouse.disable = false
  pane.uniforms.iMouse.data = iMouse

  let iM = ((iMouse.xy*2f)-iResolution.xy)/iResolution.y
  pane.uniforms.iM.disable = false
  pane.uniforms.iM.data = iM

  # drag box handle
  if activeBoxIndex > -1 and activeHandle != Handle.None:
    var scale = vec2(0f)
    var repos = vec2(0f)
        
    case activeHandle:
      # edge
      of Handle.Bottom:
        scale.y = -0.5f
        repos.y = 0.5f
      of Handle.Top:
        scale.y = 0.5f
        repos.y = 0.5f
      of Handle.Right:
        repos.x = 0.5f
        scale.x = 0.5f
      of Handle.Left:
        repos.x = 0.5f
        scale.x = -0.5f
      
      # corner
      of Handle.TopRight:
        repos = vec2(0.5f,0.5f)
        scale = vec2(0.5f,0.5f)
      of Handle.TopLeft:
        repos = vec2(0.5f,0.5f)
        scale = vec2(-0.5f,0.5f)
      of Handle.BottomLeft:
        repos = vec2(0.5f,0.5f)
        scale = vec2(-0.5f,-0.5f)
      of Handle.BottomRight:
        repos = vec2(0.5f,0.5f)
        scale = vec2(0.5f,-0.5f)
      else:
        discard 

    # symmetric scaling
    if holdingOption:
      repos = vec2(0f)
      scale *= 2f

    let
      delta = iM - mouseStartPos
      pos = boxStart.xy + delta * repos
      size = boxStart.zw + delta * scale
    pane.uniforms.uBoxes.disable = false
    pane.uniforms.uBoxes.data[activeBoxIndex].xy = pos
    pane.uniforms.uBoxes.data[activeBoxIndex].zw = size

  # drag box body
  elif activeBoxIndex > -1 and activeHandle == Handle.None:
    let
      delta = iM - mouseStartPos
      box = pane.uniforms.uBoxes.data[activeBoxIndex]
      pos = boxStart.xy + delta
    pane.uniforms.uBoxes.disable = false
    pane.uniforms.uBoxes.data[activeBoxIndex].xy = pos
    pane.uniforms.uBoxes.data[activeBoxIndex].zw = box.zw

  # draw arrow
  if activeArrowIndex > -1:
    let arrow = pane.uniforms.uArrows.data[activeArrowIndex]
    pane.uniforms.uArrows.disable = false
    pane.uniforms.uArrows.data[activeArrowIndex].xy = arrow.xy
    pane.uniforms.uArrows.data[activeArrowIndex].zw = iM.xy

  # mousePos = vec2(xpos, ypos)
  # let
  #   # iMouse = pane.uniforms.iMouse.data.xy
  #   iResolution = pane.uniforms.iResolution.data.xy
    
  #   # x[-1,1] y[-1,1]
  #   # m = (iMouse*2.0-iResolution)/iResolution.y
  #   mx = (mousePos.x*2.0-iResolution.x)/iResolution.y
  #   my = (mousePos.y*2.0-iResolution.y)/iResolution.y
  #   m = vec2(mx,-my)

  #   # delta = mousePos-mouseDownPos #vec2(mousePos.x - mouseDownPos.x, mousePos.y - mouseDownPos.y)
  #   # dx = (delta.x * 2.0 - iResolution.x)/iResolution.y
  #   # dy = (delta.y * 2.0 - iResolution.y)/iResolution.y
  #   # d = vec2(dx,dy)

  #   rect = pane.uniforms.uRects.data[0]
  #   # pos = vec2(rect.x+d.x, rect.y+d.y)
  # pane.uniforms.uRects.disable = false
  # pane.uniforms.uRects.data[0] = vec4(GLfloat(m.x), GLfloat(m.y), GLfloat(rect.z), GLfloat(rect.w))

proc onWindowResize*(width: int, height: int, worldWidth: int, worldHeight: int) =
  windowWidth = width
  windowHeight = height
  pane.uniforms.iResolution.disable = false
  pane.uniforms.iResolution.data = vec3(windowWidth.float, windowHeight.float, 1f)

proc test_types() =
  # let
  #   f: float = 0.0

  #   v = vec4(0.0, 0.0, 0.0, 0.0)
  #   uf = pane.uniforms.iTime.data
  #   uv = pane.uniforms.iMouse.data

  #   # sumf = f + uf
  #   # sumv = v + uv
  # echo f
  # echo v
  # echo uf
  # echo uv

  var x: Any
  var
    f: float = 42
    f32: float32 = 42
    f64: float64 = 42
    ff = 42.0
    fff = 42f
    glf = GLfloat(42)
    i = 42

    f32_v: Vec2[float32] = vec2(42f, 42f)      # Vec2[float32]
    f64_v: Vec2[float64] = vec2(42.0, 42.0)   # Vec2[float64]
    vf: Vec2f = vec2(42f, 42f)

  x = f.toAny
  echo "f is ",x.kind

  x = f32.toAny
  echo "f32 is ",x.kind

  x = f64.toAny
  echo "f64 is ",x.kind

  x = ff.toAny
  echo "ff is ",x.kind

  x = fff.toAny
  echo "fff is ",x.kind

  x = glf.toAny
  echo "glf is ",x.kind

  x = i.toAny
  echo "i is ",x.kind

  # todo: how to cast ff_v to Vec2[float32] ?
  # let sum: Vec2f = f32_v + f64_v

proc init*(game: var Game) =
  doAssert glInit()

  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glDisable(GL_CULL_FACE)
  glDisable(GL_DEPTH_TEST)

  uncompiledPane = initPane()

  var
    timeValue = glfwGetTime()
    greenValue = (sin(timeValue) / 2f) + 0.5f
    color = vec4(GLfloat(0.0f), GLfloat(greenValue), GLfloat(0.0f), GLfloat(1.0f))

  uncompiledPane.uniforms.iTime.data = 0f
  uncompiledPane.uniforms.iResolution.data = vec3(windowWidth.float, windowHeight.float, 1f)
  uncompiledPane.uniforms.iMouse.data = vec4(0f)
  uncompiledPane.uniforms.uColor.data = color
  uncompiledPane.uniforms.uBalls.data = block:
    var balls = newSeq[Vec4[GLfloat]]()
    for i in 0 ..< BALL_COUNT:
      let vel = vec2(-0.5f+rand(1f), -0.5f+rand(1f)) * 0.1f
      balls.add(vec4(0f, 0f, vel.x, vel.y))
    balls
  uncompiledPane.uniforms.uBoxes.data = block:
    var boxes = newSeq[Vec4f]()
    for i in 0 ..< BOX_COUNT:
      var pos = vec2(-0.5f+rand(1f), -0.5f+rand(1f)) * 1f
      var size = vec2(rand(1f), rand(1f)) * 0.5f
      boxes.add(vec4f(pos.x, pos.y, size.x, size.y))
    boxes
  uncompiledPane.uniforms.uZIndex.data = block:
    var zs = newSeq[GLint]()
    for z in 0 ..< BOX_COUNT:
      zs.add(GLint(z))
    zs
  uncompiledPane.uniforms.uArrows.data = block:
    var arrows = newSeq[Vec4f]()
    for i in 0 ..< ARROW_COUNT:
      var start = vec2(-0.5f+rand(1f), -0.5f+rand(1f)) * 1f
      var stop = vec2(-0.5f+rand(1f), -0.5f+rand(1f)) * 1f
      arrows.add(vec4f(start.x, start.y, stop.x, stop.y))
    arrows

  pane = compile(game, uncompiledPane)

proc tick*(game: Game) =
  let timeValue = glfwGetTime()
  pane.uniforms.iTime.disable = false
  pane.uniforms.iTime.data = GLfloat(timeValue)

  # check mouse collision
  # let
  #   iMouse = pane.uniforms.iMouse.data.xy
  #   iResolution = pane.uniforms.iResolution.data.xy
  #   m = (iMouse*2.0-iResolution)/iResolution.y
  #   b = pane.uniforms.uRects.data[0]
  #   corner_radii = vec4(1.0) * 0.05
  #   d = sdRoundedBox(m, b.zw, corner_radii)
  #   inside = d < 0.0
  # echo inside

  # sim balls
  pane.uniforms.uBalls.disable = false
  for i in 0 ..< BALL_COUNT:
    var ball = pane.uniforms.uBalls.data[i]
    
    # update vel
    ball.xy += ball.zw
    
    # friction
    # ball.zw *= 0.99

    if ball.x < -1f:
      ball.x = -1f
      ball.z *= -1f
    if ball.x > 1f:
      ball.x = 1f
      ball.z *= -1f

    if ball.y < -1f:
      ball.y = -1f
      ball.w *= -1f
    if ball.y > 1f:
      ball.y = 1f
      ball.w *= -1f
    pane.uniforms.uBalls.data[i] = ball

  glClearColor(60/255, 180/255, 30/255, 1f)
  glClear(GL_COLOR_BUFFER_BIT)
  glViewport(0, 0, int32(windowWidth), int32(windowHeight))
  render(game, pane)
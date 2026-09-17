// 2D Drawing Library - by fad
// https://www.shadertoy.com/view/cdB3RD
// https://www.shadertoy.com/user/fad

#define SDF_FONT_TEXTURE iChannel0

// Treat the context as an opaque data type.
struct Context {
    vec2 pixelCoord;
    float scale;
    bool drawingEnabled;
    bool fillEnabled;
    vec4 fillColor;
    bool strokeEnabled;
    bool strokeOverFill;
    vec4 strokeColor;
    float strokeWidth;
    vec4 outColor;
    vec2 writePosition;
    float charSize;
    float charWeight;
    float lineSpacing;
    float charSpacing;
    int floatPrecision;
    vec2 nextCharTopLeft;
};

// Create a new drawing context with the position of the pixel. The
// mapping from fragCoord to pixelCoord is expected to be aspect-ratio
// preserving, i.e. uniform scaling across both axes. The context
// inherits its properties from the currently bound context. To use the
// created canvas, bind it with bindContext().
Context newContext(vec2 pixelCoord);

// Bind a new context and return the previously bound context
Context bindContext(Context ctx);

// Get the currently bound context
Context getContext();

// Blit (copy) the canvas of a context onto the currently bound context,
// optionally using another context canvas's alpha channel as a mask
void blit(Context ctx);
void blit(Context ctx, Context mask);

// Draw the canvas of a context over the currently bound context,
// optionally using another context canvas's alpha channel as a mask
void drawCanvas(Context ctx);
void drawCanvas(Context ctx, Context mask);

// Get the rendered color so far (not premultiplied)
vec4 getColor();

// Enable or disable drawing
void enableDrawing(bool drawingEnabled);
void enableDrawing();
void disableDrawing();

// Enable or disable fill
void enableFill(bool fillEnabled);
void enableFill();
void disableFill();

// Set the fill color
void setFillColor(vec4 fillColor);

// Enable or disable stroke
void enableStroke(bool strokeEnabled);
void enableStroke();
void disableStroke();

// Set the stroke to render over or behind the fill
void strokeOverFill(bool enable);
void strokeOverFill();
void strokeBehindFill();

// Set the stroke color
void setStrokeColor(vec4 strokeColor);

// Set the stroke width
// Note: a width of 0 does not work as expected
void setStrokeWidth(float strokeWidth);

// Draw a pixel for the current fragment
void drawPixel(vec4 color);

// Draw a shape
void drawLine(vec2 start, vec2 end, float thickness);
void drawRect(vec2 center, vec2 sideLength);
void drawAABB(vec2 bottomLeft, vec2 topRight);
void drawCircle(vec2 center, float radius);
void drawGrid(vec2 spacing, vec2 thickness);
void drawGrid(float spacing, float thickness);

// Draw a shape defined by a signed distance value (sd < 0.0)
void drawSD(float sd);

// Draw a shape defined by an implicit function (f < 0.0)
void drawImplicit(float f);

// Draw a shape defined by the contour (zero-crossing) of an implicit
// function (f == 0.0)
void drawImplicitContour(float f, float width);

// Text rendering functions
// Set the top left position to write the text from
void setWritePosition(vec2 writePosition);

// Set the size of each character in pixels
void setCharSize(float charSize);

// Set the weight of each character (between 0 and 1)
void setCharWeight(float charWeight);

// Set the space between lines relative to character scale
void setLineSpacing(float lineSpacing);

// Set the space between successive characters relative to character
// scale
void setCharSpacing(float charSpacing);

// Set the precision floating point numbers are printed at
void setFloatPrecision(int floatPrecision);

// Print Functions
void printChar(int x);
// These functions are also overloaded for vectors
void print(bool x);
void print(int x);
void print(uint x);
void print(float x);

// The next two print functions are actually macros

#define PREVENT_LOOP_UNROLLING 1

// void printCharArray(int[] charArray);

// void printString(string s);

// Use printString with two pairs of brackets and comma separated chars,
// e.g. printString((CH_H,CH_e,CH_l,CH_l,CH_o));

// Calculate the color from blending the front color over the back color
vec4 blendOver(vec4 front, vec4 back);

// Premultiply a color
vec4 premultiply(vec4 color);

// Get the fraction of a pixel covered by an SDF (i.e. where sd < 0.0).
// This function expects the SDF to be in screen-space where 1 unit of
// distance corresponds to the width of a pixel.
float sdfFill(float sd);

// Get the fraction of a pixel covered by the outline of an SDF (i.e.
// where abs(sd) < width / 2.0). This function expects the SDF to be in
// screen-space where 1 unit of distance corresponds to the width of a
// pixel.
float sdfOutline(float sd, float width);

// Get the fraction of a pixel covered by an implicit function (i.e.
// where f < 0.0) by approximating the distance to the edge with
// derivatives
float implicitFill(float f);

// Get the fraction of a pixel covered by the outline of an implicit
// function (i.e. where (distance to f=0) < width / 2.0) by
// approximating the distance to the edge with derivatives.
float implicitOutline(float f, float width);

// Return the fraction of the pixel where step(edge, x) == 1.0 by
// approximating the distance to the edge with derivatives.
float aastep(float edge, float x);

// Character Definitions
const int CH_TAB = 9;   // \t
const int CH_NL  = 10;  // \n
const int CH_SPC = 32;  // space
const int CH_EXC = 33;  // !
const int CH_DQT = 34;  // "
const int CH_HSH = 35;  // #
const int CH_DLR = 36;  // $
const int CH_PER = 37;  // %
const int CH_AMP = 38;  // &
const int CH_SQT = 39;  // '
const int CH_LP  = 40;  // (
const int CH_RP  = 41;  // )
const int CH_AST = 42;  // *
const int CH_PLS = 43;  // +
const int CH_CMA = 44;  // ,
const int CH_HYP = 45;  // -
const int CH_DOT = 46;  // .
const int CH_FSL = 47;  // /
const int CH_0   = 48;  // 0
const int CH_1   = 49;  // 1
const int CH_2   = 50;  // 2
const int CH_3   = 51;  // 3
const int CH_4   = 52;  // 4
const int CH_5   = 53;  // 5
const int CH_6   = 54;  // 6
const int CH_7   = 55;  // 7
const int CH_8   = 56;  // 8
const int CH_9   = 57;  // 9
const int CH_CLN = 58;  // :
const int CH_SCL = 59;  // ;
const int CH_LT  = 60;  // <
const int CH_EQ  = 61;  // =
const int CH_GT  = 62;  // >
const int CH_QST = 63;  // ?
const int CH_AT  = 64;  // @
const int CH_A   = 65;  // A
const int CH_B   = 66;  // B
const int CH_C   = 67;  // C
const int CH_D   = 68;  // D
const int CH_E   = 69;  // E
const int CH_F   = 70;  // F
const int CH_G   = 71;  // G
const int CH_H   = 72;  // H
const int CH_I   = 73;  // I
const int CH_J   = 74;  // J
const int CH_K   = 75;  // K
const int CH_L   = 76;  // L
const int CH_M   = 77;  // M
const int CH_N   = 78;  // N
const int CH_O   = 79;  // O
const int CH_P   = 80;  // P
const int CH_Q   = 81;  // Q
const int CH_R   = 82;  // R
const int CH_S   = 83;  // S
const int CH_T   = 84;  // T
const int CH_U   = 85;  // U
const int CH_V   = 86;  // V
const int CH_W   = 87;  // W
const int CH_X   = 88;  // X
const int CH_Y   = 89;  // Y
const int CH_Z   = 90;  // Z
const int CH_LB  = 91;  // [ 
const int CH_BSL = 92;  // \
const int CH_RB  = 93;  // ]
const int CH_CRT = 94;  // ^
const int CH_UND = 95;  // _
const int CH_GRV = 96;  // `
const int CH_a   = 97;  // a
const int CH_b   = 98;  // b
const int CH_c   = 99;  // c
const int CH_d   = 100; // d
const int CH_e   = 101; // e
const int CH_f   = 102; // f
const int CH_g   = 103; // g
const int CH_h   = 104; // h
const int CH_i   = 105; // i
const int CH_j   = 106; // j
const int CH_k   = 107; // k
const int CH_l   = 108; // l
const int CH_m   = 109; // m
const int CH_n   = 110; // n
const int CH_o   = 111; // o
const int CH_p   = 112; // p
const int CH_q   = 113; // q
const int CH_r   = 114; // r
const int CH_s   = 115; // s
const int CH_t   = 116; // t
const int CH_u   = 117; // u
const int CH_v   = 118; // v
const int CH_w   = 119; // w
const int CH_x   = 120; // x
const int CH_y   = 121; // y
const int CH_z   = 122; // z
const int CH_LC  = 123; // {
const int CH_VB  = 124; // |
const int CH_RC  = 125; // }
const int CH_TLD = 126; // ~

// IMPLEMENTATION

Context _ctx = Context(
    vec2(0.0),
    0.0,
    false,
    false,
    vec4(0.0),
    false,
    false,
    vec4(0.0),
    0.0,
    vec4(0.0),
    vec2(0.0),
    0.0,
    0.0,
    0.0,
    0.0,
    0,
    vec2(0.0)
);

Context newContext(vec2 pixelCoord) {
    Context ctx;
    float scale = 1.0 / length(vec2(dFdx(pixelCoord.x), dFdy(pixelCoord.x)));
    
    if (getContext().scale != 0.0) {
        ctx = getContext();
        ctx.outColor = vec4(0.0);
        ctx.pixelCoord = pixelCoord;
        ctx.scale = scale;
    } else {
        ctx.pixelCoord = pixelCoord;
        ctx.scale = scale;
        ctx.drawingEnabled = true;
        ctx.fillEnabled = true;
        ctx.fillColor = vec4(1.0, 0.0, 0.0, 1.0);
        ctx.strokeEnabled = true;
        ctx.strokeOverFill = true;
        ctx.strokeColor = vec4(0.0, 0.0, 0.0, 1.0);
        ctx.strokeWidth = 1.0;
        ctx.outColor = vec4(0.0);
        Context old = bindContext(ctx);
        setWritePosition(vec2(100.0));
        setCharSize(64.0);
        setCharWeight(0.5);
        setLineSpacing(0.0);
        setCharSpacing(-0.55);
        setFloatPrecision(5);
        ctx = bindContext(old);
    }
    
    return ctx;
}

Context bindContext(Context ctx) {
    Context old = getContext();
    _ctx = ctx;
    return old;
}

Context getContext() {
    return _ctx;
}

void blit(Context ctx) {
    _ctx.outColor = ctx.outColor;
}

void blit(Context ctx, Context mask) {
    _ctx.outColor = mix(_ctx.outColor, ctx.outColor, mask.outColor.a);
}

void drawCanvas(Context ctx) {
    drawPixel(ctx.outColor);
}

void drawCanvas(Context ctx, Context mask) {
    drawPixel(ctx.outColor * vec4(1.0, 1.0, 1.0, mask.outColor.a));
}

void enableDrawing(bool drawingEnabled) {
    _ctx.drawingEnabled = drawingEnabled;
}

void enableDrawing() {
    enableDrawing(true);
}

void disableDrawing() {
    enableDrawing(false);
}

void enableFill(bool fillEnabled) {
    _ctx.fillEnabled = fillEnabled;
}

void enableFill() {
    enableFill(true);
}

void disableFill() {
    enableFill(false);
}

void setFillColor(vec4 fillColor) {
    _ctx.fillColor = clamp(fillColor, 0.0, 1.0);
}

void enableStroke(bool strokeEnabled) {
    _ctx.strokeEnabled = strokeEnabled;
}

void enableStroke() {
    enableStroke(true);
}

void disableStroke() {
    enableStroke(false);
}

void strokeOverFill(bool enable) {
    _ctx.strokeOverFill = enable;
}

void strokeOverFill() {
    strokeOverFill(true);
}

void strokeBehindFill() {
    strokeOverFill(false);
}

void setStrokeColor(vec4 strokeColor) {
    _ctx.strokeColor = clamp(strokeColor, 0.0, 1.0);
}

void setStrokeWidth(float strokeWidth) {
    _ctx.strokeWidth = max(strokeWidth, 0.0);
}

void drawPixel(vec4 color) {
    if (_ctx.drawingEnabled) {
        _ctx.outColor = blendOver(color, _ctx.outColor);
    }
}

void _drawFillStroke(float fillOpacity, float strokeOpacity) {
    if (_ctx.strokeEnabled && !_ctx.strokeOverFill) {
        drawPixel(_ctx.strokeColor * vec4(1.0, 1.0, 1.0, strokeOpacity));
    }

    if (_ctx.fillEnabled) {
        drawPixel(_ctx.fillColor * vec4(1.0, 1.0, 1.0, fillOpacity));
    }
    
    if (_ctx.strokeEnabled && _ctx.strokeOverFill) {
        drawPixel(_ctx.strokeColor * vec4(1.0, 1.0, 1.0, strokeOpacity));
    }
}

void drawSD(float sd) {
    sd *= _ctx.scale;
    _drawFillStroke(sdfFill(sd), sdfOutline(sd, _ctx.scale * _ctx.strokeWidth));
}

void drawImplicit(float f) {
    _drawFillStroke(implicitFill(f), implicitOutline(f, _ctx.scale * _ctx.strokeWidth));
}

void drawImplicitContour(float f, float width) {
    float sd = abs(f) / length(vec2(dFdx(f), dFdy(f))) - _ctx.scale * width / 2.0;
    _drawFillStroke(sdfFill(sd), sdfOutline(sd, _ctx.scale * _ctx.strokeWidth));
}

void drawLine(vec2 start, vec2 end, float thickness) {
    vec2 ba = end - start;
	vec2 pa = _ctx.pixelCoord - start;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	drawSD(length(pa - h * ba) - thickness);
}

void drawRect(vec2 center, vec2 sideLength) {
    vec2 a = abs(_ctx.pixelCoord - center) - sideLength / 2.0;
    drawSD(length(max(a, vec2(0.0))) + min(max(a.x, a.y), 0.0));
}

void drawAABB(vec2 bottomLeft, vec2 topRight) {
    drawRect((bottomLeft + topRight) / 2.0, abs(topRight - bottomLeft));
}

void drawCircle(vec2 center, float radius) {
    drawSD(distance(_ctx.pixelCoord, center) - radius);
}

void drawGrid(vec2 origin, vec2 spacing, vec2 thickness) {
    vec2 a = 
        abs(mod(_ctx.pixelCoord - origin + spacing / 2.0, spacing) - spacing / 2.0) -
        thickness / 2.0;
    drawSD(min(a.x, a.y));
    
}

void drawGrid(float spacing, float thickness) {
    drawGrid(vec2(0.0), vec2(spacing), vec2(thickness));
}

void setWritePosition(vec2 writePosition) {
    _ctx.writePosition = writePosition;
    _ctx.nextCharTopLeft = writePosition;
}

void setCharSize(float charSize) {
    _ctx.charSize = charSize;
}

void setCharWeight(float charWeight) {
    _ctx.charWeight = charWeight;
}

void setLineSpacing(float lineSpacing) {
    _ctx.lineSpacing = lineSpacing;
}

void setCharSpacing(float charSpacing) {
    _ctx.charSpacing = charSpacing;
}

void setFloatPrecision(int floatPrecision) {
    _ctx.floatPrecision = floatPrecision;
}

#ifndef HW_PERFORMANCE
uniform sampler2D SDF_FONT_TEXTURE;
#endif

void printChar(int char) {
    if (char == 10) {
        _ctx.nextCharTopLeft.x = _ctx.writePosition.x;
        _ctx.nextCharTopLeft.y -= (1.0 + _ctx.lineSpacing) * _ctx.charSize;
        return;
    }
    
    vec2 bottomLeft = _ctx.nextCharTopLeft - vec2(0.0, _ctx.charSize);
    vec2 uv = (_ctx.pixelCoord - bottomLeft) / _ctx.charSize;
    
    if (clamp(uv, 0.0, 1.0) == uv) {
        drawSD((texture(SDF_FONT_TEXTURE, (uv + vec2(char % 16, 15 - char / 16)) / 16.0).a - mix(0.45, 0.55, _ctx.charWeight)) * _ctx.charSize);
    }
    
    _ctx.nextCharTopLeft.x += (1.0 + _ctx.charSpacing) * _ctx.charSize;
}

#ifndef HW_PERFORMANCE
uniform int iFrame;
#endif

#define printCharArray(charArray) for (int i = 0; i < (charArray).length() + min(PREVENT_LOOP_UNROLLING * iFrame, 0); ++i) printChar((charArray)[i])

#define printString(string) printCharArray(int[]string)

void print(bool x) {
    if (x) {
        printString((CH_t,CH_r,CH_u,CH_e));
    } else {
        printString((CH_f,CH_a,CH_l,CH_s,CH_e));
    }
}

void print(int x) {
    if (x < 0) {
        printChar(CH_HYP);
        x = -x;
    }
    
    print(uint(x));
}

void print(uint x) {
    int n = 1;
    uint t = x % 10u;
    
    while (x > 9u) {
        ++n;
        x /= 10u;
        t = 10u * t + x % 10u;
    }
    
    while (n --> 0) { // lol
        printChar(CH_0 + int(t % 10u));
        t /= 10u;
    }
}

void print(float x) {
    if (isnan(x)) {
        printString((CH_n,CH_a,CH_n));
        return;
    }
    
    if (floatBitsToUint(x) >> 31 == 1u) {
        printChar(CH_HYP);
        x = -x;
    }
    
    if (isinf(x)) {
        printString((CH_i,CH_n,CH_f));
        return;
    }
    
    if (x == 0.0) {
        printChar(CH_0);
        return;
    }
    
    float e = floor(log2(x)/log2(10.0));
    x /= pow(10.0, e);
    
    for (int n = 0; x > 0.0 && n < _ctx.floatPrecision; ++n) {
        if (n == 1) {
            printChar(CH_DOT);
        }
        
        float digit = floor(x);
        printChar(CH_0 + int(digit));
        x = (x - digit) * 10.0;
    }
    
    printChar(CH_e);
    print(int(e));
}

#define OVERLOAD_PRINT(T, n, c)                              \
    void print(T x) {                                        \
        printString((c, CH_v, CH_e, CH_c, CH_0 + n, CH_LP)); \
                                                             \
        for (int i = 0; i < n; ++i) {                        \
            print(x[i]);                                     \
                                                             \
            if (i != n - 1) {                                \
                printString((CH_CMA, CH_SPC));               \
            }                                                \
        }                                                    \
                                                             \
        printChar(CH_RP);                                    \
    }

#define OVERLOAD_PRINT_FLOAT(T, n)                           \
    void print(T x) {                                        \
        printString((CH_v, CH_e, CH_c, CH_0 + n, CH_LP));    \
                                                             \
        for (int i = 0; i < n; ++i) {                        \
            print(x[i]);                                     \
                                                             \
            if (i != n - 1) {                                \
                printString((CH_CMA, CH_SPC));               \
            }                                                \
        }                                                    \
                                                             \
        printChar(CH_RP);                                    \
    }

OVERLOAD_PRINT(bvec2, 2, CH_b)
OVERLOAD_PRINT(bvec3, 3, CH_b)
OVERLOAD_PRINT(bvec4, 4, CH_b)
OVERLOAD_PRINT(ivec2, 2, CH_i)
OVERLOAD_PRINT(ivec3, 3, CH_i)
OVERLOAD_PRINT(ivec4, 4, CH_i)
OVERLOAD_PRINT(uvec2, 2, CH_u)
OVERLOAD_PRINT(uvec3, 3, CH_u)
OVERLOAD_PRINT(uvec4, 4, CH_u)
OVERLOAD_PRINT_FLOAT(vec2, 2)
OVERLOAD_PRINT_FLOAT(vec3, 3)
OVERLOAD_PRINT_FLOAT(vec4, 4)

vec4 blendOver(vec4 top, vec4 bottom) {
    float a = top.a + bottom.a * (1.0 - top.a);
    return a > 0.0
        ? vec4((top.rgb * top.a + bottom.rgb * bottom.a * (1.0 - top.a)) / a , a)
        : vec4(0.0);
}

vec4 premultiply(vec4 color) {
    return vec4(color.rgb * color.a, color.a);
}

vec4 getColor() {
    return _ctx.outColor;
}

float _areaSquareLine(vec2 n, float d) {
    // From https://www.shadertoy.com/view/mtcXDH
    // https://www.desmos.com/calculator/dorvdj5nbq for visualization
    n = abs(n);
    n = vec2(max(n.x, n.y), min(n.x, n.y));
    float a = abs(d);
    float b;

    if (n.y != 0.0 && n.x - n.y <= 2.0 * a) {
        vec2 c = 1.0 + (n - 2.0 * a) / n.yx;
        b = 1.0 - max(c.x, 0.0) * c.y / 8.0;
    } else {
        b = min(0.5 + a / n.x, 1.0);
    }
    
    return d < 0.0 ? 1.0 - b : b;
}

float _areaSquareLineAverage(float d) {
    // From https://www.shadertoy.com/view/mtcXDH
    // Approximate average value of areaSquareLine(n, d) w.r.t. n
    float a = abs(d);
    float b;
    
    if (a < 1.0 / sqrt(2.0)) {
        b = 4.1434218 * pow(a, 12.647891) -
            1.3070394 * pow(a, 3.9787831) +
            1.0998631 * a +
            0.5012205;
        b = clamp(b, 0.0, 1.0);
    } else {
        b = 1.0;
    }
    
    return d < 0.0 ? 1.0 - b : b;
}

float sdfFill(float sd) {
    // From https://www.shadertoy.com/view/mtcXDH
    // Return the fraction of the pixel covered by the SDF (i.e. where
    // sd < 0.0)
    vec2 n = vec2(dFdx(sd), dFdy(sd));
    
    if (n == vec2(0.0) || isnan(n.x) || isnan(n.y)) {
        // Ambiguous case, so instead we just return the average. This
        // is the problem with using dFdx/dFdy that would occur much
        // less frequently if we had access to the analytic derivatives.
        return _areaSquareLineAverage(-sd);
    }

    n = normalize(n);
    return _areaSquareLine(n, -sd);
}

float sdfOutline(float sd, float width) {
    // From https://www.shadertoy.com/view/mtcXDH
    // Return the fraction of the pixel covered by the outline of the
    // SDF (i.e. where abs(sd) < width / 2.0)
    return sdfFill(sd - width / 2.0) - sdfFill(sd + width / 2.0);
}

float aastep(float edge, float x) {
    // From https://www.shadertoy.com/view/mtcXDH
    // Return the fraction of the pixel where step(edge, x) == 1.0 by
    // approximating the distance to the edge with derivatives.
    x -= edge;
    vec2 n = vec2(dFdx(x), dFdy(x));
    
    if (n == vec2(0.0) || isnan(n.x) || isnan(n.y)) {
        // Ambiguous case, so we resort to using regular step(edge, x).
        // We can't use areaSquareLineAverage(x) because that function
        // assumes that x measures distance across pixels but we have no
        // information about distance here as the derivatives are zero.
        return step(edge, x);
    }
    
    float l = length(n);
    return _areaSquareLine(n / l, x / l);
}

float implicitFill(float f) {
    return aastep(f, 0.0);
}

float implicitOutline(float f, float width) {
    return implicitFill(abs(f) / length(vec2(dFdx(f), dFdy(f))) - width / 2.0);
}
/'*********************************************************************************************
*
*   rlgl v3.1 - raylib OpenGL abstraction layer
*
*   rlgl is a wrapper for multiple OpenGL versions (1.1, 2.1, 3.3 Core, ES 2.0) to
*   pseudo-OpenGL 1.1 style functions (rlVertex, rlTranslate, rlRotate...).
*
*   When chosing an OpenGL version greater than OpenGL 1.1, rlgl stores vertex data on internal
*   VBO buffers (and VAOs if available). It requires calling 3 functions:
*       rlglInit()  - Initialize internal buffers and auxiliar resources
*       rlglDraw()  - Process internal buffers and send required draw calls
*       rlglClose() - De-initialize internal buffers data and other auxiliar resources
*
*   CONFIGURATION:
*
*   #define GRAPHICS_API_OPENGL_11
*   #define GRAPHICS_API_OPENGL_21
*   #define GRAPHICS_API_OPENGL_33
*   #define GRAPHICS_API_OPENGL_ES2
*       Use selected OpenGL graphics backend, should be supported by platform
*       Those preprocessor defines are only used on rlgl module, if OpenGL version is
*       required by any other module, use rlGetVersion() tocheck it
*
*   #define RLGL_IMPLEMENTATION
*       Generates the implementation of the library into the included file.
*       If not defined, the library is in header only mode and can be included in other headers
*       or source files without problems. But only ONE file should hold the implementation.
*
*   #define RLGL_STANDALONE
*       Use rlgl as standalone library (no raylib dependency)
*
*   #define SUPPORT_VR_SIMULATOR
*       Support VR simulation functionality (stereo rendering)
*
*   DEPENDENCIES:
*       raymath     - 3D math functionality (Vector3, Matrix, Quaternion)
*       GLAD        - OpenGL extensions loading (OpenGL 3.3 Core only)
*
*
*   LICENSE: zlib/libpng
*
*   Copyright (c) 2014-2021 Ramon Santamaria (@raysan5)
*
*   This software is provided "as-is", without any express or implied warranty. In no event
*   will the authors be held liable for any damages arising from the use of this software.
*
*   Permission is granted to anyone to use this software for any purpose, including commercial
*   applications, and to alter it and redistribute it freely, subject to the following restrictions:
*
*     1. The origin of this software must not be misrepresented you must not claim that you
*     wrote the original software. If you use this software in a product, an acknowledgment
*     in the product documentation would be appreciated but is not required.
*
*     2. Altered source versions must be plainly marked as such, and must not be misrepresented
*     as being the original software.
*
*     3. This notice may not be removed or altered from any source distribution.
*
*********************************************************************************************'/

#ifndef RLGL_BI
#define RLGL_BI
'hack
#inclib "raylib"

#If Defined(RLGL_STANDALONE)
    #define RAYMATH_STANDALONE
    #define RAYMATH_HEADER_ONLY
'hack
    #Ifndef RLAPI
    #define RLAPI   '' We are building or using rlgl as a static library (or Linux shared library)
	#EndIf
    #if defined(_WIN32)
        #if defined(BUILD_LIBTYPE_SHARED)
            #define Declare __declspec(dllexport)         '' We are building raylib as a Win32 shared library (.dll)
        #ElseIf defined(USE_LIBTYPE_SHARED)
            #define Declare __declspec(dllimport)         '' We are using raylib as a Win32 shared library (.dll)
        #endif
    #endif

    '' Support TRACELOG macros
    #if Not Defined(TRACELOG)
        #define TRACELOG(level, ...) ()0
        #define TRACELOGD(...) ()0
    #endif

    '' Allow custom memory allocators
    #ifndef RL_MALLOC
        #define RL_MALLOC(sz)       malloc(sz)
    #endif
    #ifndef RL_CALLOC
        #define RL_CALLOC(n,sz)     calloc(n,sz)
    #endif
    #ifndef RL_REALLOC
        #define RL_REALLOC(n,sz)    realloc(n,sz)
    #endif
    #ifndef RL_FREE
        #define RL_FREE(p)          free(p)
    #endif
#else
    #include Once "raylib.bi"         '' Required for: Model, Shader, Texture2D, TRACELOG()
#endif

#include once "raymath.bi"            '' Required for: Vector3, Matrix

'' Security check in case no GRAPHICS_API_OPENGL_* defined
#if Not Defined(GRAPHICS_API_OPENGL_11) andalso _
    Not Defined(GRAPHICS_API_OPENGL_21) andalso _
    Not Defined(GRAPHICS_API_OPENGL_33) andalso _
    Not Defined(GRAPHICS_API_OPENGL_ES2)
        #define GRAPHICS_API_OPENGL_33
#endif

'' Security check in case multiple GRAPHICS_API_OPENGL_* defined
#if defined(GRAPHICS_API_OPENGL_11)
    #if defined(GRAPHICS_API_OPENGL_21)
        #undef GRAPHICS_API_OPENGL_21
    #endif
    #if defined(GRAPHICS_API_OPENGL_33)
        #undef GRAPHICS_API_OPENGL_33
    #endif
    #if defined(GRAPHICS_API_OPENGL_ES2)
        #undef GRAPHICS_API_OPENGL_ES2
    #endif
#endif

#if defined(GRAPHICS_API_OPENGL_21)
    #define GRAPHICS_API_OPENGL_33
#endif

#define SUPPORT_RENDER_TEXTURES_HINT

''----------------------------------------------------------------------------------
'' Defines and Macros
''----------------------------------------------------------------------------------
'' Default internal render batch limits
#ifndef DEFAULT_BATCH_BUFFER_ELEMENTS
    #if defined(GRAPHICS_API_OPENGL_11) OrElse defined(GRAPHICS_API_OPENGL_33)
        '' This is the maximum amount of elements (quads) per batch
        '' NOTE: Be careful with text, every letter maps to a quad
        #define DEFAULT_BATCH_BUFFER_ELEMENTS   8192
    #elseif defined(GRAPHICS_API_OPENGL_ES2)
        '' We reduce memory sizes for embedded systems (RPI and HTML5)
        '' NOTE: On HTML5 (emscripten) this is allocated on heap,
        '' by default it's only 16MB!...just take care...
        #define DEFAULT_BATCH_BUFFER_ELEMENTS   2048
    #endif
#endif
#ifndef DEFAULT_BATCH_BUFFERS
    #define DEFAULT_BATCH_BUFFERS            1      '' Default number of batch buffers (multi-buffering)
#endif
#ifndef DEFAULT_BATCH_DRAWCALLS
    #define DEFAULT_BATCH_DRAWCALLS        256      '' Default number of batch draw calls (by state changes: mode, texture)
#endif
#ifndef MAX_BATCH_ACTIVE_TEXTURES
    #define MAX_BATCH_ACTIVE_TEXTURES        4      '' Maximum number of additional textures that can be activated on batch drawing (SetShaderValueTexture())
#endif

'' Internal Matrix stack
#ifndef MAX_MATRIX_STACK_SIZE
    #define MAX_MATRIX_STACK_SIZE           32      '' Maximum size of Matrix stack
#endif

'' Shader and material limits
#ifndef MAX_SHADER_LOCATIONS
    #define MAX_SHADER_LOCATIONS            32      '' Maximum number of shader locations supported
#endif
#ifndef MAX_MATERIAL_MAPS
    #define MAX_MATERIAL_MAPS               12      '' Maximum number of shader maps supported
#endif

'' Projection matrix culling
#ifndef RL_CULL_DISTANCE_NEAR
    #define RL_CULL_DISTANCE_NEAR         0.01      '' Default near cull distance
#endif
#ifndef RL_CULL_DISTANCE_FAR
    #define RL_CULL_DISTANCE_FAR        1000.0      '' Default far cull distance
#endif

'' Texture parameters (equivalent to OpenGL defines)
#define RL_TEXTURE_WRAP_S               &H2802      '' GL_TEXTURE_WRAP_S
#define RL_TEXTURE_WRAP_T               &H2803      '' GL_TEXTURE_WRAP_T
#define RL_TEXTURE_MAG_FILTER           &H2800      '' GL_TEXTURE_MAG_FILTER
#define RL_TEXTURE_MIN_FILTER           &H2801      '' GL_TEXTURE_MIN_FILTER
#define RL_TEXTURE_ANISOTROPIC_FILTER   &H3000      '' Anisotropic filter (custom identifier)

#define RL_FILTER_NEAREST               &H2600      '' GL_NEAREST
#define RL_FILTER_LINEAR                &H2601      '' GL_LINEAR
#define RL_FILTER_MIP_NEAREST           &H2700      '' GL_NEAREST_MIPMAP_NEAREST
#define RL_FILTER_NEAREST_MIP_LINEAR    &H2702      '' GL_NEAREST_MIPMAP_LINEAR
#define RL_FILTER_LINEAR_MIP_NEAREST    &H2701      '' GL_LINEAR_MIPMAP_NEAREST
#define RL_FILTER_MIP_LINEAR            &H2703      '' GL_LINEAR_MIPMAP_LINEAR

#define RL_WRAP_REPEAT                  &H2901      '' GL_REPEAT
#define RL_WRAP_CLAMP                   &H812F      '' GL_CLAMP_TO_EDGE
#define RL_WRAP_MIRROR_REPEAT           &H8370      '' GL_MIRRORED_REPEAT
#define RL_WRAP_MIRROR_CLAMP            &H8742      '' GL_MIRROR_CLAMP_EXT

'' Matrix modes (equivalent to OpenGL)
#define RL_MODELVIEW                    &H1700      '' GL_MODELVIEW
#define RL_PROJECTION                   &H1701      '' GL_PROJECTION
#define RL_TEXTURE                      &H1702      '' GL_TEXTURE

'' Primitive assembly draw modes
#define RL_LINES                        &H0001      '' GL_LINES
#define RL_TRIANGLES                    &H0004      '' GL_TRIANGLES
#define RL_QUADS                        &H0007      '' GL_QUADS

''----------------------------------------------------------------------------------
'' Types and Structures Definition
''----------------------------------------------------------------------------------
enum GlVersion
OPENGL_11 = 1, OPENGL_21, OPENGL_33, OPENGL_ES_20 
End enum

Enum FramebufferAttachType
    RL_ATTACHMENT_COLOR_CHANNEL0 = 0,
    RL_ATTACHMENT_COLOR_CHANNEL1,
    RL_ATTACHMENT_COLOR_CHANNEL2,
    RL_ATTACHMENT_COLOR_CHANNEL3,
    RL_ATTACHMENT_COLOR_CHANNEL4,
    RL_ATTACHMENT_COLOR_CHANNEL5,
    RL_ATTACHMENT_COLOR_CHANNEL6,
    RL_ATTACHMENT_COLOR_CHANNEL7,
    RL_ATTACHMENT_DEPTH = 100,
    RL_ATTACHMENT_STENCIL = 200,
End enum

Enum FramebufferTexType
    RL_ATTACHMENT_CUBEMAP_POSITIVE_X = 0,
    RL_ATTACHMENT_CUBEMAP_NEGATIVE_X,
    RL_ATTACHMENT_CUBEMAP_POSITIVE_Y,
    RL_ATTACHMENT_CUBEMAP_NEGATIVE_Y,
    RL_ATTACHMENT_CUBEMAP_POSITIVE_Z,
    RL_ATTACHMENT_CUBEMAP_NEGATIVE_Z,
    RL_ATTACHMENT_TEXTURE2D = 100,
    RL_ATTACHMENT_RENDERBUFFER = 200,
End Enum

#if defined(RLGL_STANDALONE)
    #Ifndef __cplusplus
    '' Boolean type
    enum bool
    false, true
    End Enum
    #endif

    '' Color type, RGBA (32bit)
    type Color 
        r as UByte
        g as UByte
        b as UByte
        a as UByte
    End Type

    '' Rectangle type
    Type Rectangl
        x as Single
        y as Single
        width as Single
        height As single
    End Type

    '' Texture type
    '' NOTE: Data stored in GPU memory
    Type Texture 
        id as ULong        '' OpenGL texture id
        width as Long              '' Texture base width
        height as Long             '' Texture base height
        mipmaps As long            '' Mipmap levels, 1 by default
        format as Long             '' Data format (PixelFormat)
    End Type

    '' Texture2D type, same as Texture
    Type Texture Texture2D

    '' TextureCubemap type, actually, same as Texture
    Type Texture TextureCubemap

    '' Vertex data definning a mesh
    type Mesh
        vertexCount As long        '' number of vertices stored in arrays
        triangleCount As Long      '' number of triangles stored (indexed or not)
        vertices As Single Ptr        '' vertex position (XYZ - 3 components per vertex) (shader-location = 0)
        texcoords As Single Ptr       '' vertex texture coordinates (UV - 2 components per vertex) (shader-location = 1)
        texcoords2 As Single Ptr      '' vertex second texture coordinates (useful for lightmaps) (shader-location = 5)
        normals As Single Ptr         '' vertex normals (XYZ - 3 components per vertex) (shader-location = 2)
        tangents As Single Ptr       '' vertex tangents (XYZW - 4 components per vertex) (shader-location = 4)
        colors As Byte ptr '' vertex colors (RGBA - 4 components per vertex) (shader-location = 3)
        indices As UShort ptr'' vertex indices (in case vertex data comes indexed)

        '' Animation vertex data
        animVertices As Single ptr   '' Animated vertex positions (after bones transformations)
        animNormals As Single ptr     '' Animated normals (after bones transformations)
        boneIds As Long ptr           '' Vertex bone ids, up to 4 bones influence by vertex (skinning)
        boneWeights As Single ptr     '' Vertex bone weight, up to 4 bones influence by vertex (skinning)

        '' OpenGL identifiers
        vaoId as ULong     '' OpenGL Vertex Array Object id
        vboId As ULong ptr    '' OpenGL Vertex Buffer Objects id (7 types of vertex data)
    End type

    '' Shader type (generic)
    type Shader
        id as ULong        '' Shader program id
        locs As Long ptr              '' Shader locations array (MAX_SHADER_LOCATIONS)
    End Type

    '' Material texture map
    Type MaterialMap
        texture as Texture2D      '' Material map texture
        Color As Color            '' Material map color
        value As single            '' Material map value
    End Type

    '' Material type (generic)
    Type Material
        As Shader shader          '' Material shader
        As MaterialMap Ptr maps      '' Material maps (MAX_MATERIAL_MAPS)
        As Single Ptr params          '' Material generic parameters (if required)
    End Type

    '' Camera type, defines a camera position/orientation in 3d space
    type Camera
        As Vector3 position       '' Camera position
        As Vector3 target         '' Camera target it looks-at
        As Vector3 up             '' Camera up vector (rotation over its axis)
        As Single fovy             '' Camera field-of-view apperture in Y (degrees)
    End Type

    '' Head-Mounted-Display device parameters
    Type VrDeviceInfo
        As long hResolution                '' HMD horizontal resolution in pixels
        As Long vResolution                '' HMD vertical resolution in pixels
        As Single hScreenSize              '' HMD horizontal size in meters
        As Single vScreenSize              '' HMD vertical size in meters
        As Single vScreenCenter            '' HMD screen center in meters
        As Single eyeToScreenDistance      '' HMD distance between eye and display in meters
        As Single lensSeparationDistance   '' HMD lens separation distance in meters
        As Single interpupillaryDistance   '' HMD IPD (distance between pupils) in meters
        As Single lensDistortionValues(0 To 3)  '' HMD lens distortion constant parameters
        As single chromaAbCorrection(0 To 3)    '' HMD chromatic aberration correction parameters
    End type

    '' VR Stereo rendering configuration for simulator
    typedef struct VrStereoConfig {
        As Shader distortionShader        '' VR stereo rendering distortion shader
        As Matrix eyesProjection(0 To 1)       '' VR stereo rendering eyes projection matrices
        As Matrix eyesViewOffset(0 To 1)       '' VR stereo rendering eyes view offset matrices
        As Long eyeViewportRight(0 To 3)        '' VR stereo rendering right eye viewport [x, y, w, h]
        As long eyeViewportLeft(0 To 3)         '' VR stereo rendering left eye viewport [x, y, w, h]
    End Type

    '' TraceLog message types
    Enum TraceLogType
        LOG_ALL,
        LOG_TRACE,
        LOG_DEBUG,
        LOG_INFO,
        LOG_WARNING,
        LOG_ERROR,
        LOG_FATAL,
        LOG_NONE
    End Enum

    '' Texture formats (support depends on OpenGL version)
    Enum PixelFormat
        UNCOMPRESSED_GRAYSCALE = 1,     '' 8 bit per pixel (no alpha)
        UNCOMPRESSED_GRAY_ALPHA,
        UNCOMPRESSED_R5G6B5,            '' 16 bpp
        UNCOMPRESSED_R8G8B8,            '' 24 bpp
        UNCOMPRESSED_R5G5B5A1,          '' 16 bpp (1 bit alpha)
        UNCOMPRESSED_R4G4B4A4,          '' 16 bpp (4 bit alpha)
        UNCOMPRESSED_R8G8B8A8,          '' 32 bpp
        UNCOMPRESSED_R32,               '' 32 bpp (1 channel - single)
        UNCOMPRESSED_R32G32B32,         '' 32*3 bpp (3 channels - single)
        UNCOMPRESSED_R32G32B32A32,      '' 32*4 bpp (4 channels - single)
        COMPRESSED_DXT1_RGB,            '' 4 bpp (no alpha)
        COMPRESSED_DXT1_RGBA,           '' 4 bpp (1 bit alpha)
        COMPRESSED_DXT3_RGBA,           '' 8 bpp
        COMPRESSED_DXT5_RGBA,           '' 8 bpp
        COMPRESSED_ETC1_RGB,            '' 4 bpp
        COMPRESSED_ETC2_RGB,            '' 4 bpp
        COMPRESSED_ETC2_EAC_RGBA,       '' 8 bpp
        COMPRESSED_PVRT_RGB,            '' 4 bpp
        COMPRESSED_PVRT_RGBA,           '' 4 bpp
        COMPRESSED_ASTC_4x4_RGBA,       '' 8 bpp
        COMPRESSED_ASTC_8x8_RGBA        '' 2 bpp
    End Enum

    '' Texture parameters: filter mode
    '' NOTE 1: Filtering considers mipmaps if available in the texture
    '' NOTE 2: Filter is accordingly set for minification and magnification
    Enum TextureFilterMode
        FILTER_POINT = 0,               '' No filter, just pixel aproximation
        FILTER_BILINEAR,                '' Linear filtering
        FILTER_TRILINEAR,               '' Trilinear filtering (linear with mipmaps)
        FILTER_ANISOTROPIC_4X,          '' Anisotropic filtering 4x
        FILTER_ANISOTROPIC_8X,          '' Anisotropic filtering 8x
        FILTER_ANISOTROPIC_16X,         '' Anisotropic filtering 16x
    End Enum

    '' Color blending modes (pre-defined)
    Enum BlendMode
        BLEND_ALPHA = 0,                '' Blend textures considering alpha (default)
        BLEND_ADDITIVE,                 '' Blend textures adding colors
        BLEND_MULTIPLIED,               '' Blend textures multiplying colors
        BLEND_ADD_COLORS,               '' Blend textures adding colors (alternative)
        BLEND_SUBTRACT_COLORS,          '' Blend textures subtracting colors (alternative)
        BLEND_CUSTOM                    '' Belnd textures using custom src/dst factors (use SetBlendModeCustom())
    End Enum

    '' Shader location point type
    Enum ShaderLocationIndex
        LOC_VERTEX_POSITION = 0,
        LOC_VERTEX_TEXCOORD01,
        LOC_VERTEX_TEXCOORD02,
        LOC_VERTEX_NORMAL,
        LOC_VERTEX_TANGENT,
        LOC_VERTEX_COLOR,
        LOC_MATRIX_MVP,
        LOC_MATRIX_MODEL,
        LOC_MATRIX_VIEW,
        LOC_MATRIX_PROJECTION,
        LOC_VECTOR_VIEW,
        LOC_COLOR_DIFFUSE,
        LOC_COLOR_SPECULAR,
        LOC_COLOR_AMBIENT,
        LOC_MAP_ALBEDO,          '' LOC_MAP_DIFFUSE
        LOC_MAP_METALNESS,       '' LOC_MAP_SPECULAR
        LOC_MAP_NORMAL,
        LOC_MAP_ROUGHNESS,
        LOC_MAP_OCCLUSION,
        LOC_MAP_EMISSION,
        LOC_MAP_HEIGHT,
        LOC_MAP_CUBEMAP,
        LOC_MAP_IRRADIANCE,
        LOC_MAP_PREFILTER,
        LOC_MAP_BRDF
    End Enum

    '' Shader uniform data types
    Enum ShaderUniformDataType
        UNIFORM_FLOAT = 0,
        UNIFORM_VEC2,
        UNIFORM_VEC3,
        UNIFORM_VEC4,
        UNIFORM_INT,
        UNIFORM_IVEC2,
        UNIFORM_IVEC3,
        UNIFORM_IVEC4,
        UNIFORM_SAMPLER2D
    End Enum

    #define LOC_MAP_DIFFUSE      LOC_MAP_ALBEDO
    #define LOC_MAP_SPECULAR     LOC_MAP_METALNESS

    '' Material map type
    Enum MaterialMapType
        MAP_ALBEDO    = 0,       '' MAP_DIFFUSE
        MAP_METALNESS = 1,       '' MAP_SPECULAR
        MAP_NORMAL    = 2,
        MAP_ROUGHNESS = 3,
        MAP_OCCLUSION,
        MAP_EMISSION,
        MAP_HEIGHT,
        MAP_CUBEMAP,             '' NOTE: Uses GL_TEXTURE_CUBE_MAP
        MAP_IRRADIANCE,          '' NOTE: Uses GL_TEXTURE_CUBE_MAP
        MAP_PREFILTER,           '' NOTE: Uses GL_TEXTURE_CUBE_MAP
        MAP_BRDF
    End enum

    #define MAP_DIFFUSE      MAP_ALBEDO
    #define MAP_SPECULAR     MAP_METALNESS
#endif

#if defined(__cplusplus)
extern "C" {            '' Prevents name mangling of functions
#EndIf
'hack
extern "C"
''------------------------------------------------------------------------------------
'' Functions Declaration - Matrix operations
''------------------------------------------------------------------------------------
declare sub rlMatrixMode(mode As long)                    '' Choose the current matrix to be transformed
Declare sub rlPushMatrix()                        '' Push the current matrix to stack
Declare sub rlPopMatrix()                         '' Pop lattest inserted matrix from stack
Declare sub rlLoadIdentity()                      '' Reset current matrix to identity matrix
Declare Sub rlTranslatef(x as single, y as Single, z as Single)   '' Multiply the current matrix by a translation matrix
Declare Sub rlRotatef(angleDeg as single, x as Single, y as Single, z as Single)  '' Multiply the current matrix by a rotation matrix
Declare Sub rlScalef(x as Single, y as Single, z as Single)       '' Multiply the current matrix by a scaling matrix
Declare Sub rlMultMatrixf(matf as single ptr)                '' Multiply the current matrix by another matrix
Declare Sub rlFrustum(left as double, right as Double, bottom as Double, top as Double, znear as Double, zfar as Double)
Declare Sub rlOrtho(left as Double, right as Double, bottom as Double, top as Double, znear as Double, zfar as double)
Declare Sub rlViewport(x as long, y as Long, width as long, height as long) '' Set the viewport area

''------------------------------------------------------------------------------------
'' Functions Declaration - Vertex level operations
''------------------------------------------------------------------------------------
Declare Sub rlBegin(mode as long)                         '' Initialize drawing mode (how to organize vertex)
Declare sub rlEnd()                               '' Finish vertex providing
Declare Sub rlVertex2i(x as Long, y as Long)                  '' Define one vertex (position) - 2 int
Declare Sub rlVertex2f(x as Single, y as Single)              '' Define one vertex (position) - 2 single
Declare Sub rlVertex3f(x as Single, y as Single, z as Single)     '' Define one vertex (position) - 3 single
Declare Sub rlTexCoord2f(x as Single, y as Single)            '' Define one vertex (texture coordinate) - 2 single
Declare Sub rlNormal3f(x as Single, y as Single, z as Single)     '' Define one vertex (normal) - 3 single
Declare Sub rlColor4ub(r as ubyte, g as UByte, b as UByte, a as UByte)  '' Define one vertex (color) - 4 byte
Declare Sub rlColor3f(x as Single, y as Single, z as Single)          '' Define one vertex (color) - 3 single
Declare Sub rlColor4f(x as Single, y as Single, z as Single, w as single) '' Define one vertex (color) - 4 single

''------------------------------------------------------------------------------------
'' Functions Declaration - OpenGL equivalent functions (common to 1.1, 3.3+, ES2)
'' NOTE: This functions are used to completely abstract raylib code from OpenGL layer
''------------------------------------------------------------------------------------
Declare Sub rlEnableTexture(id as ulong)                  '' Enable texture usage
Declare sub rlDisableTexture()                            '' Disable texture usage
Declare Sub rlTextureParameters(id as ULong, param as long, value as Long) '' Set texture parameters (filter, wrap)
Declare Sub rlEnableShader(id as ULong)                   '' Enable shader program usage
Declare sub rlDisableShader()                             '' Disable shader program usage
Declare Sub rlEnableFramebuffer(id as ULong)              '' Enable render texture (fbo)
Declare sub rlDisableFramebuffer()                        '' Disable render texture (fbo), return to default framebuffer
Declare sub rlEnableDepthTest()                           '' Enable depth test
Declare sub rlDisableDepthTest()                          '' Disable depth test
Declare sub rlEnableDepthMask()                           '' Enable depth write
Declare sub rlDisableDepthMask()                          '' Disable depth write
Declare sub rlEnableBackfaceCulling()                     '' Enable backface culling
Declare sub rlDisableBackfaceCulling()                    '' Disable backface culling
Declare sub rlEnableScissorTest()                         '' Enable scissor test
Declare sub rlDisableScissorTest()                        '' Disable scissor test
Declare Sub rlScissor(x as Long, y as Long, width as Long, height as Long)    '' Scissor test
Declare sub rlEnableWireMode()                            '' Enable wire mode
Declare sub rlDisableWireMode()                           '' Disable wire mode
Declare Sub rlSetLineWidth(Width as Single)                       '' Set the line drawing width
Declare Function rlGetLineWidth() As single                             '' Get the line drawing width
Declare sub rlEnableSmoothLines()                         '' Enable line aliasing
Declare sub rlDisableSmoothLines()                        '' Disable line aliasing

Declare Sub rlClearColor(r as UByte, g as UByte, b as UByte, a as UByte)  '' Clear color buffer with color
Declare sub rlClearScreenBuffers()                        '' Clear used screen buffers (color and depth)
Declare sub rlUpdateBuffer(bufferId as long, Data As Any ptr, dataSize as long) '' Update GPU buffer with new data
Declare function rlLoadAttribBuffer(vaoId as ulong, shaderLoc as long, buffer As Any ptr, size as long, dynamic as boolean) As ulong  '' Load a new attributes buffer

''------------------------------------------------------------------------------------
'' Functions Declaration - rlgl functionality
''------------------------------------------------------------------------------------
Declare Sub rlglInit(width as Long, height as Long)           '' Initialize rlgl (buffers, shaders, textures, states)
Declare sub rlglClose()                           '' De-inititialize rlgl (buffers, shaders, textures)
Declare sub rlglDraw()                            '' Update and draw default internal buffers
Declare sub rlCheckErrors()                       '' Check and log OpenGL error codes

Declare Function rlGetVersion() As long                        '' Returns current OpenGL version
Declare function rlCheckBufferLimit(vCount As Long) As boolean            '' Check internal buffer overflow for a given number of vertex
Declare Sub rlSetDebugMarker(text As const ZString ptr)        '' Set debug marker for analysis
Declare Sub rlSetBlendMode(glSrcFactor as long, glDstFactor as long, glEquationr as long)    '' '' Set blending mode factor and equation (using OpenGL factors)
'TODO Declare sub rlLoadExtensions(void *loader)            '' Load OpenGL extensions

'' Textures data management
Declare Function rlLoadTexture(Data As Any ptr, width as Long, height as Long, format as long, mipmapCount as long) As ulong'' Load texture in GPU
Declare Function rlLoadTextureDepth(width as Long, height as Long, useRenderBuffer as boolean) As Ulong               '' Load depth texture/renderbuffer (to be attached to fbo)
Declare Function rlLoadTextureCubemap(Data As Any ptr, size as Long, format as Long) As ulong                        '' Load texture cubemap
Declare sub rlUpdateTexture(id as ULong, offsetX as long, offsetY as Long, width as Long, height as Long, format as Long, Data As Const Any ptr)  '' Update GPU texture with new data
Declare Sub rlGetGlTextureFormats(format as Long, glInternalFormat as ulong ptr, glFormat as ulong ptr, glTypet as ulong ptr)  '' Get OpenGL internal formats
Declare Sub rlUnloadTexture(id as ULong)                              '' Unload texture from GPU memory

Declare Sub rlGenerateMipmaps(texture as Texture2D ptr)                         '' Generate mipmap data for selected texture
Declare function rlReadTexturePixels(texture as Texture2D) As Any ptr                      '' Read texture pixel data
Declare Function rlReadScreenPixels(width as Long, height as Long) As UByte ptr          '' Read screen pixel data (color buffer)

'' Framebuffer management (fbo)
Declare Function rlLoadFramebuffer(width as Long, height as Long) as ulong             '' Load an empty framebuffer
Declare Sub rlFramebufferAttach(fboId as ulong, texId as ulong, attachType as long, texType as long)  '' Attach texture/renderbuffer to a framebuffer
Declare function rlFramebufferComplete(id as ULong) As boolean                        '' Verify framebuffer is complete
Declare Sub rlUnloadFramebuffer(id as ULong)                          '' Delete framebuffer from GPU

'' Vertex data management
Declare Sub rlLoadMesh(mesh0 as Mesh ptr, dynamic as boolean)                          ' Upload vertex data into GPU and provided VAO/VBO ids
Declare Sub rlUpdateMesh(mesh as Mesh, buffer as long, count as long)                '' Update vertex or index data on GPU (upload new data to one buffer)
Declare Sub rlUpdateMeshAt(mesh as Mesh, buffer as Long, count as Long, index as long)   '' Update vertex or index data on GPU, at index
Declare Sub rlDrawMesh(mesh as Mesh, material as Material, transform as Matrix)    '' Draw a 3d mesh with material and transform
Declare Sub rlDrawMeshInstanced(mesh as Mesh, material as Material, transform as Matrix ptr, count as Long)    '' Draw a 3d mesh with material and transform
Declare Sub rlUnloadMesh(mesh as Mesh)                                       '' Unload mesh data from CPU and GPU

'' NOTE: There is a set of shader related functions that are available to end user,
'' to asub creating function wrappers through core module, they have been directly declared in raylib.h

#if defined(RLGL_STANDALONE)
''------------------------------------------------------------------------------------
'' Shaders System Functions (Module: rlgl)
'' NOTE: This functions are useless when using OpenGL 1.1
''------------------------------------------------------------------------------------
'' Shader loading/unloading functions
Declare Shader LoadShader(const char *vsFileName, const char *fsFileName)  '' Load shader from files and bind default locations
Declare Shader LoadShaderCode(const char *vsCode, const char *fsCode)      '' Load shader from code strings and bind default locations
Declare Sub UnloadShader(Shader shader)                                   '' Unload shader from GPU memory (VRAM)

Declare Shader GetShaderDefault()                                      '' Get default shader
Declare Texture2D GetTextureDefault()                                  '' Get default texture
Declare Texture2D GetShapesTexture()                                   '' Get texture to draw shapes
Declare Rectangle GetShapesTextureRec()                                '' Get texture rectangle to draw shapes

'' Shader configuration functions
Declare int GetShaderLocation(Shader shader, const char *uniformName)              '' Get shader uniform location
Declare int GetShaderLocationAttrib(Shader shader, const char *attribName)         '' Get shader attribute location
Declare sub SetShaderValue(Shader shader, int uniformLoc, const Sub *value, int uniformType)               '' Set shader uniform value
Declare sub SetShaderValueV(Shader shader, int uniformLoc, const Sub *value, int uniformType, count as Long)   '' Set shader uniform value vector
Declare Sub SetShaderValueMatrix(Shader shader, int uniformLoc, Matrix mat)       '' Set shader uniform value (matrix 4x4)
Declare Sub SetMatrixProjection(Matrix proj)                              '' Set a custom projection matrix (replaces internal projection matrix)
Declare Sub SetMatrixModelview(Matrix view)                               '' Set a custom modelview matrix (replaces internal modelview matrix)
Declare Matrix GetMatrixModelview()                                    '' Get internal modelview matrix

'' Texture maps generation (PBR)
'' NOTE: Required shaders should be provided
Declare TextureCubemap GenTextureCubemap(Shader shader, Texture2D panorama, size as Long, format as Long) '' Generate cubemap texture from 2D panorama texture
Declare TextureCubemap GenTextureIrradiance(Shader shader, TextureCubemap cubemap, size as Long)      '' Generate irradiance texture using cubemap data
Declare TextureCubemap GenTexturePrefilter(Shader shader, TextureCubemap cubemap, size as Long)       '' Generate prefilter texture using cubemap data
Declare Texture2D GenTextureBRDF(Shader shader, size as Long)                  '' Generate BRDF texture using cubemap data

'' Shading begin/end functions
Declare Sub BeginShaderMode(Shader shader)              '' Begin custom shader drawing
Declare sub EndShaderMode()                         '' End custom shader drawing (use default shader)
Declare Sub BeginBlendMode(mode as Long)                    '' Begin blending mode (alpha, additive, multiplied)
Declare sub EndBlendMode()                          '' End blending mode (reset to case else: alpha blending)

'' VR control functions
Declare sub InitVrSimulator()                       '' Init VR simulator for selected device parameters
Declare sub CloseVrSimulator()                      '' Close VR simulator for current device
Declare Sub UpdateVrTracking(Camera *camera)            '' Update VR tracking (position and orientation) and camera
Declare Sub SetVrConfiguration(VrDeviceInfo info, Shader distortion)      '' Set stereo rendering configuration parameters
Declare bool IsVrSimulatorReady()                    '' Detect if VR simulator is ready
Declare sub ToggleVrMode()                          '' Enable/Disable VR experience
Declare sub BeginVrDrawing()                        '' Begin VR simulator stereo rendering
Declare sub EndVrDrawing()                          '' End VR simulator stereo rendering

Declare char *LoadFileText(const char *fileName)         '' Load chars array from text file
Declare int GetPixelDataSize(width as Long, height as Long, format as Long)'' Get pixel data size in bytes (image or texture)

#endif

#if defined(__cplusplus)
End Extern
#EndIf
'hack
End Extern

#endif '' RLGL_H

/'**********************************************************************************
*
*   RLGL IMPLEMENTATION
*
***********************************************************************************'/

#if defined(RLGL_IMPLEMENTATION)

#if defined(RLGL_STANDALONE)
    #include <stdio.h>                  '' Required for: fopen(), fseek(), fread(), fclose() [LoadFileText]
#else
    '' Check if config flags have been externally provided on compilation line
    #if Not Defined(EXTERNAL_CONFIG_FLAGS)
        #include "config.bi"             '' Defines module configuration flags
    #endif
    #include "raymath.bi"                '' Required for: Vector3 and Matrix functions
#endif

#include "crt/stdlib.bi"                     '' Required for: malloc(), free()
#include "crt/string.bi"                    '' Required for: strcmp(), strlen() [Used in rlglInit(), on extensions loading]
#include "crt/math.bi"                       '' Required for: atan2f()

#if defined(GRAPHICS_API_OPENGL_11)
    #if defined(__APPLE__)
        #include "OpenGL/gl.bi"          '' OpenGL 1.1 library for OSX
        #include "OpenGL/glext.bi"
    #else
        '' APIENTRY for OpenGL function pointer declarations is required
        #ifndef APIENTRY
            #if defined(_WIN32)
                #define APIENTRY __stdcall
            #else
                #define APIENTRY
            #endif
        #endif
        '' WINGDIAPI definition. Some Windows OpenGL headers need it
        #if Not Defined(WINGDIAPI) andalso defined(_WIN32)
            #define WINGDIAPI __declspec(dllimport)
        #endif

        #include "GL/gl.bi"              '' OpenGL 1.1 library
    #endif
#endif

#if defined(GRAPHICS_API_OPENGL_21)
    #define GRAPHICS_API_OPENGL_33      '' OpenGL 2.1 uses mostly OpenGL 3.3 Core functionality
#endif

#if defined(GRAPHICS_API_OPENGL_33)
    #if defined(__APPLE__)
        #include "OpenGL/gl3.bi"         '' OpenGL 3 library for OSX
        #include "OpenGL/gl3ext.bi"      '' OpenGL 3 extensions library for OSX
    #else
        #define GLAD_REALLOC RL_REALLOC
        #define GLAD_FREE RL_FREE

        #define GLAD_IMPLEMENTATION
        #if defined(RLGL_STANDALONE)
            #include "glad.bi"           '' GLAD extensions loading library, includes OpenGL headers
        #else
            #include "external/glad.bi"  '' GLAD extensions loading library, includes OpenGL headers
        #endif
    #endif
#endif

#if defined(GRAPHICS_API_OPENGL_ES2)
    #define GL_GLEXT_PROTOTYPES
    #include "EGL/egl.bi"                '' EGL library
    #include "GLES2/gl2.bi"              '' OpenGL ES 2.0 library
    #include "GLES2/gl2ext.bi"           '' OpenGL ES 2.0 extensions library
#endif

''----------------------------------------------------------------------------------
'' Defines and Macros
''----------------------------------------------------------------------------------
#ifndef GL_SHADING_LANGUAGE_VERSION
    #define GL_SHADING_LANGUAGE_VERSION         &H8B8C
#endif

#ifndef GL_COMPRESSED_RGB_S3TC_DXT1_EXT
    #define GL_COMPRESSED_RGB_S3TC_DXT1_EXT     &H83F0
#endif
#ifndef GL_COMPRESSED_RGBA_S3TC_DXT1_EXT
    #define GL_COMPRESSED_RGBA_S3TC_DXT1_EXT    &H83F1
#endif
#ifndef GL_COMPRESSED_RGBA_S3TC_DXT3_EXT
    #define GL_COMPRESSED_RGBA_S3TC_DXT3_EXT    &H83F2
#endif
#ifndef GL_COMPRESSED_RGBA_S3TC_DXT5_EXT
    #define GL_COMPRESSED_RGBA_S3TC_DXT5_EXT    &H83F3
#endif
#ifndef GL_ETC1_RGB8_OES
    #define GL_ETC1_RGB8_OES                    &H8D64
#endif
#ifndef GL_COMPRESSED_RGB8_ETC2
    #define GL_COMPRESSED_RGB8_ETC2             &H9274
#endif
#ifndef GL_COMPRESSED_RGBA8_ETC2_EAC
    #define GL_COMPRESSED_RGBA8_ETC2_EAC        &H9278
#endif
#ifndef GL_COMPRESSED_RGB_PVRTC_4BPPV1_IMG
    #define GL_COMPRESSED_RGB_PVRTC_4BPPV1_IMG  &H8C00
#endif
#ifndef GL_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG
    #define GL_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG &H8C02
#endif
#ifndef GL_COMPRESSED_RGBA_ASTC_4x4_KHR
    #define GL_COMPRESSED_RGBA_ASTC_4x4_KHR     &H93b0
#endif
#ifndef GL_COMPRESSED_RGBA_ASTC_8x8_KHR
    #define GL_COMPRESSED_RGBA_ASTC_8x8_KHR     &H93b7
#endif

#ifndef GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT
    #define GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT   &H84FF
#endif
#ifndef GL_TEXTURE_MAX_ANISOTROPY_EXT
    #define GL_TEXTURE_MAX_ANISOTROPY_EXT       &H84FE
#endif

#if defined(GRAPHICS_API_OPENGL_11)
    #define GL_UNSIGNED_SHORT_5_6_5             &H8363
    #define GL_UNSIGNED_SHORT_5_5_5_1           &H8034
    #define GL_UNSIGNED_SHORT_4_4_4_4           &H8033
#endif
#if defined(GRAPHICS_API_OPENGL_21)
    #define GL_LUMINANCE                        &H1909
    #define GL_LUMINANCE_ALPHA                  &H190A
#endif

#if defined(GRAPHICS_API_OPENGL_ES2)
    #define glClearDepth                 glClearDepthf
    #define GL_READ_FRAMEBUFFER         GL_FRAMEBUFFER
    #define GL_DRAW_FRAMEBUFFER         GL_FRAMEBUFFER
#endif

'' Default shader vertex attribute names to set location points
#ifndef DEFAULT_SHADER_ATTRIB_NAME_POSITION
    #define DEFAULT_SHADER_ATTRIB_NAME_POSITION    "vertexPosition"    '' Binded by default to shader location: 0
#endif
#ifndef DEFAULT_SHADER_ATTRIB_NAME_TEXCOORD
    #define DEFAULT_SHADER_ATTRIB_NAME_TEXCOORD    "vertexTexCoord"    '' Binded by default to shader location: 1
#endif
#ifndef DEFAULT_SHADER_ATTRIB_NAME_NORMAL
    #define DEFAULT_SHADER_ATTRIB_NAME_NORMAL      "vertexNormal"      '' Binded by default to shader location: 2
#endif
#ifndef DEFAULT_SHADER_ATTRIB_NAME_COLOR
    #define DEFAULT_SHADER_ATTRIB_NAME_COLOR       "vertexColor"       '' Binded by default to shader location: 3
#endif
#ifndef DEFAULT_SHADER_ATTRIB_NAME_TANGENT
    #define DEFAULT_SHADER_ATTRIB_NAME_TANGENT     "vertexTangent"     '' Binded by default to shader location: 4
#endif
#ifndef DEFAULT_SHADER_ATTRIB_NAME_TEXCOORD2
    #define DEFAULT_SHADER_ATTRIB_NAME_TEXCOORD2   "vertexTexCoord2"   '' Binded by default to shader location: 5
#endif

''----------------------------------------------------------------------------------
'' Types and Structures Definition
''----------------------------------------------------------------------------------

'' Dynamic vertex buffers (position + texcoords + colors + indices arrays)
Type VertexBuffer 
    As Long elementsCount          '' Number of elements in the buffer (QUADS)

    As Long vCounter               '' Vertex position counter to process (and draw) from full buffer
    As Long tcCounter              '' Vertex texcoord counter to process (and draw) from full buffer
    As Long cCounter               '' Vertex color counter to process (and draw) from full buffer

    As Single Ptr vertices            '' Vertex position (XYZ - 3 components per vertex) (shader-location = 0)
    As Single Ptr texcoords           '' Vertex texture coordinates (UV - 2 components per vertex) (shader-location = 1)
    As UByte Ptr colors      '' Vertex colors (RGBA - 4 components per vertex) (shader-location = 3)
#if defined(GRAPHICS_API_OPENGL_11) OrElse defined(GRAPHICS_API_OPENGL_33)
    As ULong Ptr indices      '' Vertex indices (in case vertex data comes indexed) (6 indices per quad)
#elseif defined(GRAPHICS_API_OPENGL_ES2)
    As UShort Ptr indices    '' Vertex indices (in case vertex data comes indexed) (6 indices per quad)
#endif
    vaoId as ULong         '' OpenGL Vertex Array Object id
    As ULong vboId(0 To 4)      '' OpenGL Vertex Buffer Objects id (4 types of vertex data)
End Type

'' Draw call type
'' NOTE: Only texture changes register a new draw, other state-change-related elements are not
'' used at this moment (vaoId, shaderId, matrices), raylib just forces a batch draw call if any
'' of those state-change happens (this is done in core module)
type DrawCall
    mode as Long                   '' Drawing mode: LINES, TRIANGLES, QUADS
    As Long vertexCount            '' Number of vertex of the draw
    As Long vertexAlignment        '' Number of vertex required for index alignment (LINES, TRIANGLES)
    ''vaoId as ulong       '' Vertex array id to be used on the draw -> Using RLGL.currentBatch->vertexBuffer.vaoId
    ''unsigned int shaderId    '' Shader id to be used on the draw -> Using RLGL.currentShader.id
    As ULong textureId     '' Texture id to be used on the draw -> Use to create new draw call if changes

    ''Matrix projection        '' Projection matrix for this draw -> Using RLGL.projection
    ''Matrix modelview         '' Modelview matrix for this draw -> Using RLGL.modelview
End Type

'' RenderBatch type
Type RenderBatch
    buffer as longsCount           '' Number of vertex buffers (multi-buffering support)
    As Long currentBuffer          '' Current buffer tracking in case of multi-buffering
    As VertexBuffer Ptr vertexBuffer '' Dynamic buffer(s) for vertex data

    As DrawCall ptr draws            '' Draw calls array, depends on textureId
    As Long drawsCounter           '' Draw calls counter
    As Single currentDepth         '' Current depth value for next draw
End Type

#if defined(SUPPORT_VR_SIMULATOR)
'' VR Stereo rendering configuration for simulator
Type VrStereoConfig 
    As Shader distortionShader        '' VR stereo rendering distortion shader
    As Matrix eyesProjection(0 To 1)       '' VR stereo rendering eyes projection matrices
    As Matrix eyesViewOffset(0 To 1)       '' VR stereo rendering eyes view offset matrices
    As Long eyeViewportRight(0 To 3)        '' VR stereo rendering right eye viewport [x, y, w, h]
    As Long eyeViewportLeft(0 To 3)         '' VR stereo rendering left eye viewport [x, y, w, h]
End Type
#EndIf

#if defined(GRAPHICS_API_OPENGL_33) orelse defined(GRAPHICS_API_OPENGL_ES2)
'TODO
type rlglData
    As RenderBatch Ptr currentBatch              '' Current render batch
    As RenderBatch defaultBatch               '' Default internal render batch

    Type State
        As Long currentMatrixMode              '' Current matrix mode
        As Matrix *currentMatrix              '' Current matrix pointer
        As Matrix modelview                   '' Default modelview matrix
        As Matrix projection                  '' Default projection matrix
        As Matrix transform                   '' Transform matrix to be used with rlTranslate, rlRotate, rlScale
        As boolean transformRequired             '' Require transform matrix application to current draw-call vertex (if required)
        As Matrix stack(MAX_MATRIX_STACK_SIZE)'' Matrix stack for push/pop
        As Long stackCounter                   '' Matrix stack counter

        As Texture2D shapesTexture            '' Texture used on shapes drawing (usually a white pixel)
        As Rectangle shapesTextureRec         '' Texture source rectangle used on shapes drawing
        As ULong defaultTextureId      '' Default texture used on shapes/poly drawing (required by shader)
        As Ulong activeTextureId(4)    '' Active texture ids to be enabled on batch drawing (0 active by default)
        As ULong defaultVShaderId      '' Default vertex shader id (used by default shader program)
        As ULong defaultFShaderId      '' Default fragment shader Id (used by default shader program)
        As Shader defaultShader               '' Basic shader, support vertex color and diffuse texture
        As Shader currentShader               '' Shader to be used on rendering (by default, defaultShader)

        As Long currentBlendMode               '' Blending mode active
        As Long glBlendSrcFactor               '' Blending source factor
        As Long glBlendDstFactor               '' Blending destination factor
        As Long glBlendEquation                '' Blending equation

        As Long framebufferWidth               '' Default framebuffer width
        As Long framebufferHeight              '' Default framebuffer height

    End Type
    Type ExtSupported 
        As boolean vao                           '' VAO support (OpenGL ES2 could not support VAO extension)
        As boolean texNPOT                       '' NPOT textures full support
        As boolean texDepth                      '' Depth textures supported
        As boolean texFloat32                    '' single textures support (32 bit per channel)
        As boolean texCompDXT                    '' DDS texture compression support
        As boolean texCompETC1                   '' ETC1 texture compression support
        As boolean texCompETC2                   '' ETC2/EAC texture compression support
        As boolean texCompPVRT                   '' PVR texture compression support
        As boolean texCompASTC                   '' ASTC texture compression support
        As boolean texMirrorClamp                '' Clamp mirror wrap mode supported
        As boolean texAnisoFilter                '' Anisotropic texture filtering support
        As boolean debugMarker                   '' Debug marker support

        As Single maxAnisotropicLevel          '' Maximum anisotropy level supported (minimum is 2.0f)
        As Long maxDepthBits                   '' Maximum bits for depth component

    End Type     '' Extensions supported flags
#if defined(SUPPORT_VR_SIMULATOR)
    Type Vr
        As VrStereoConfig config              '' VR stereo configuration for simulator
        As ULong stereoFboId           '' VR stereo rendering framebuffer id
        As ULong stereoTexId           '' VR stereo color texture (attached to framebuffer)
        As boolean simulatorReady                '' VR simulator ready flag
        As boolean stereoRender                  '' VR stereo rendering enabled/disabled flag
    End type
#endif  '' SUPPORT_VR_SIMULATOR
End Type
#endif  '' GRAPHICS_API_OPENGL_33 orelse GRAPHICS_API_OPENGL_ES2

''----------------------------------------------------------------------------------
'' Global Variables Definition
''----------------------------------------------------------------------------------
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
static rlglData RLGL = { 0 }
#endif  '' GRAPHICS_API_OPENGL_33 orelse GRAPHICS_API_OPENGL_ES2

#if defined(GRAPHICS_API_OPENGL_ES2)
'' NOTE: VAO functionality is exposed through extensions (OES)
static PFNGLGENVERTEXARRAYSOESPROC glGenVertexArrays        '' Entry point pointer to function glGenVertexArrays()
static PFNGLBINDVERTEXARRAYOESPROC glBindVertexArray        '' Entry point pointer to function glBindVertexArray()
static PFNGLDELETEVERTEXARRAYSOESPROC glDeleteVertexArrays  '' Entry point pointer to function glDeleteVertexArrays()
#endif

''----------------------------------------------------------------------------------
'' Module specific Functions Declaration
''----------------------------------------------------------------------------------
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
static Function CompileShader(shaderStr As Const ZString ptr, Type As long) As  ULong    '' Compile custom shader and return shader id
static Function LoadShaderProgram(vShaderId As ulong, fShaderId As ulong) As ulong '' Load custom shader program

static Function LoadShaderDefault() As Shader                 '' Load default shader (just vertex positioning and texture coloring)
static Sub SetShaderDefaultLocations(shader As Shader Ptr)  '' Bind default shader locations (attributes and uniforms)
static sub UnloadShaderDefault()                  '' Unload default shader

static function LoadRenderBatch(numBuffers As Long, bufferElements as Long) As RenderBatch'' Load a render batch system
static Sub UnloadRenderBatch(batch As RenderBatch)       '' Unload render batch system
static Sub DrawRenderBatch(batch As RenderBatch Ptr )        '' Draw render batch data (Update->Draw->Reset)
static Sub SetRenderBatchActive(batch As RenderBatch ptr)   '' Set the active render batch for rlgl
static sub SetRenderBatchDefault()                '' Set default render batch for rlgl
''static bool CheckRenderBatchLimit(RenderBatch batch, int vCount)   '' Check render batch vertex buffer limits

static sub GenDrawCube()              '' Generate and draw cube
static sub GenDrawQuad()              '' Generate and draw quad

#if defined(SUPPORT_VR_SIMULATOR)
static Sub SetStereoView(eye As Long,matProjection As Matrix , matModelView As  Matrix )  '' Set internal projection and modelview matrix depending on eye
#endif

#endif  '' GRAPHICS_API_OPENGL_33 orelse GRAPHICS_API_OPENGL_ES2

#if defined(GRAPHICS_API_OPENGL_11)
static Function GenerateMipmaps(Data As ZString ptr, baseWidth As long, baseHeight As long) As long
static Function GenNextMipmap(srcData As Color ptr, srcWidth As long, srcHeight As long) As Color Ptr
#endif

''----------------------------------------------------------------------------------
'' Module Functions Definition - Matrix operations
''----------------------------------------------------------------------------------

#if defined(GRAPHICS_API_OPENGL_11)

'' Fallback to OpenGL 1.1 function calls
''---------------------------------------
Sub rlMatrixMode(mode as Long)
    Select Case (mode)
    
    	case RL_PROJECTION: glMatrixMode(GL_PROJECTION)  
    	case RL_MODELVIEW: glMatrixMode(GL_MODELVIEW)  
    	case RL_TEXTURE: glMatrixMode(GL_TEXTURE)  
    	Case else:  
    End Select
End Sub

Sub rlFrustum(left as Double, right as Double, bottom as Double, top as Double, znear as double, zfar as Double)
    glFrustum(left, right, bottom, top, znear, zfar)
End Sub

Sub rlOrtho(left as Double, right as Double, bottom as Double, top as double, znear as Double, zfar as Double)
    glOrtho(left, right, bottom, top, znear, zfar)
End Sub

sub rlPushMatrix() 
	glPushMatrix() 
End Sub
sub rlPopMatrix() 
	glPopMatrix()
End Sub
sub rlLoadIdentity() 
	glLoadIdentity()
End Sub
Sub rlTranslatef(x as Single, y as Single, z as Single)
	glTranslatef(x, y, z) 
End Sub
Sub rlRotatef(angleDeg as Single, x as Single, y as Single, z as Single) 
	glRotatef(angleDeg, x, y, z)
End Sub
Sub rlScalef(x as Single, y as Single, z as Single) 
	glScalef(x, y, z)
End Sub
Sub rlMultMatrixf(matf as single Ptr) 
	glMultMatrixf(matf)
End Sub

#elseif defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)

'' Choose the current matrix to be transformed
Sub rlMatrixMode(mode as Long)
    if (mode = RL_PROJECTION) Then RLGL.State.currentMatrix = @RLGL.State.projection
    elseif (mode = RL_MODELVIEW) Then RLGL.State.currentMatrix = @RLGL.State.modelview
    ''else if (mode == RL_TEXTURE) '' Not supported
	 EndIf
	 
    RLGL.State.currentMatrixMode = mode
End Sub

'' Push the current matrix into RLGL.State.stack
sub rlPushMatrix()
    if (RLGL.State.stackCounter >= MAX_MATRIX_STACK_SIZE) Then TRACELOG(LOG_ERROR, "RLGL: Matrix stack overflow (MAX_MATRIX_STACK_SIZE)")

    if (RLGL.State.currentMatrixMode = RL_MODELVIEW) Then
        RLGL.State.transformRequired = TRUE
        RLGL.State.currentMatrix = @RLGL.State.transform
    EndIf

    RLGL.State.stack[RLGL.State.stackCounter] = *RLGL.State.currentMatrix
    RLGL.State.stackCounter+=1
End Sub

'' Pop lattest inserted matrix from RLGL.State.stack
sub rlPopMatrix()
    if (RLGL.State.stackCounter > 0) then
        Dim As Matrix mat = RLGL.State.stack[RLGL.State.stackCounter - 1]
        *RLGL.State.currentMatrix = mat
        RLGL.State.stackCounter-=1
    End If

    if ((RLGL.State.stackCounter = 0) andalso (RLGL.State.currentMatrixMode = RL_MODELVIEW)) Then
        RLGL.State.currentMatrix = @RLGL.State.modelview
        RLGL.State.transformRequired = FALSE
    End If
End Sub

'' Reset current matrix to identity matrix
sub rlLoadIdentity()
    *RLGL.State.currentMatrix = MatrixIdentity()
End Sub

'' Multiply the current matrix by a translation matrix
Sub rlTranslatef(x as Single, y as Single, z as Single)
    Dim As Matrix matTranslation = MatrixTranslate(x, y, z)

    '' NOTE: We transpose matrix with multiplication order
    *RLGL.State.currentMatrix = MatrixMultiply(matTranslation, *RLGL.State.currentMatrix)
End Sub

'' Multiply the current matrix by a rotation matrix
Sub rlRotatef(angleDeg as Single, x as Single, y as Single, z as Single)
    Dim As Matrix matRotation = MatrixIdentity()

    Dim As Vector3 axis = Vector3( x, y, z )
    matRotation = MatrixRotate(Vector3Normalize(axis), angleDeg*DEG2RAD)

    '' NOTE: We transpose matrix with multiplication order
    *RLGL.State.currentMatrix = MatrixMultiply(matRotation, *RLGL.State.currentMatrix)
End Sub

'' Multiply the current matrix by a scaling matrix
Sub rlScalef(x as Single, y as Single, z as Single)
    Dim As Matrix matScale = MatrixScale(x, y, z)

    '' NOTE: We transpose matrix with multiplication order
    *RLGL.State.currentMatrix = MatrixMultiply(matScale, *RLGL.State.currentMatrix)
End Sub

'' Multiply the current matrix by another matrix
Sub rlMultMatrixf(matf as Single ptr)
    '' Matrix creation from array
    Dim As Matrix mat = Type<Matrix>( matf[0], matf[4], matf[8], matf[12], _
                   matf[1], matf[5], matf[9], matf[13], _
                   matf[2], matf[6], matf[10], matf[14], _
                   matf[3], matf[7], matf[11], matf[15] )

    *RLGL.State.currentMatrix = MatrixMultiply(*RLGL.State.currentMatrix, mat)
End Sub

'' Multiply the current matrix by a perspective matrix generated by parameters
Sub rlFrustum(left as Double, right as Double, bottom as double, top as Double, znear as Double, zfar as Double)
    Dim As Matrix matPerps = MatrixFrustum(left, right, bottom, top, znear, zfar)

    *RLGL.State.currentMatrix = MatrixMultiply(*RLGL.State.currentMatrix, matPerps)
End Sub

'' Multiply the current matrix by an orthographic matrix generated by parameters
Sub rlOrtho(left as Double, right as double, bottom as Double, top as Double, znear as Double, zfar as Double)
    '' NOTE: If left-right and top-botton values are equal it could create
    '' a division by zero on MatrixOrtho(), response to it is platform/compiler dependant
    Dim As Matrix matOrtho = MatrixOrtho(left, right, bottom, top, znear, zfar)

    *RLGL.State.currentMatrix = MatrixMultiply(*RLGL.State.currentMatrix, matOrtho)
End Sub

#endif

'' Set the viewport area (transformation from normalized device coordinates to window coordinates)
Sub rlViewport(x as Long, y as Long, width as Long, height as Long)
    glViewport(x, y, width, height)
End Sub

''----------------------------------------------------------------------------------
'' Module Functions Definition - Vertex level operations
''----------------------------------------------------------------------------------
#if defined(GRAPHICS_API_OPENGL_11)

'' Fallback to OpenGL 1.1 function calls
''---------------------------------------
Sub rlBegin(mode as Long)
    Select Case (mode)
        case RL_LINES: glBegin(GL_LINES)  
        case RL_TRIANGLES: glBegin(GL_TRIANGLES)  
        case RL_QUADS: glBegin(GL_QUADS)  
        case else:  
    End Select
End Sub

Sub rlEnd() 
	glEnd()
End Sub
Sub rlVertex2i(x as Long, y as Long) 
	glVertex2i(x, y)
End Sub
Sub rlVertex2f(x as Single, y as Single) 
	glVertex2f(x, y)
End Sub
Sub rlVertex3f(x as Single, y as Single, z as Single) 
	glVertex3f(x, y, z)
End Sub
Sub rlTexCoord2f(x as Single, y as Single) 
	glTexCoord2f(x, y)
End Sub
Sub rlNormal3f(x as Single, y as Single, z as Single) 
	glNormal3f(x, y, z)
End Sub
Sub rlColor4ub(r as UByte, g as UByte, b as UByte, a as ubyte) 
	glColor4ub(r, g, b, a)
End Sub
Sub rlColor3f(x as Single, y as Single, z as Single) 
	glColor3f(x, y, z)
End Sub
Sub rlColor4f(x as Single, y as Single, z as Single, w as Single) 
	glColor4f(x, y, z, w)
End Sub

#ElseIf defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)

'' Initialize drawing mode (how to organize vertex)
Sub rlBegin(mode as Long)
    '' Draw mode can be RL_LINES, RL_TRIANGLES and RL_QUADS
    '' NOTE: In all three cases, vertex are accumulated over default internal vertex buffer
    if (RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].mode <> mode) Then
        if (RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexCount > 0) Then
            '' Make sure current RLGL.currentBatch->draws[i].vertexCount is aligned a multiple of 4,
            '' that way, following QUADS drawing will keep aligned with index processing
            '' It implies adding some extra alignment vertex at the end of the draw,
            '' those vertex are not processed but they are considered as an additional offset
            '' for the next set of vertex to be drawn
            if (RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].mode = RL_LINES) Then
            	RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexAlignment = IIf(((RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexCount < 4), RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexCount , RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexCount Mod 4))
            elseif (RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].mode = RL_TRIANGLES) 
            	RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexAlignment = IIf(((RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexCount < 4), 1 , (4 - (RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexCount Mod 4))))

            else RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexAlignment = 0

            if (rlCheckBufferLimit(RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexAlignment)) Then
            	DrawRenderBatch(RLGL.currentBatch)
            Else
                RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].vCounter += RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexAlignment
                RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].cCounter += RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexAlignment
                RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].tcCounter += RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexAlignment

                RLGL.currentBatch->drawsCounter+=1
            EndIf
        EndIf

        if (RLGL.currentBatch->drawsCounter >= DEFAULT_BATCH_DRAWCALLS) DrawRenderBatch(RLGL.currentBatch)

        RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].mode = mode
        RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexCount = 0
        RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].textureId = RLGL.State.defaultTextureId
    End If
End Sub

'' Finish vertex providing
sub rlEnd()
    '' Make sure vertexCount is the same for vertices, texcoords, colors and normals
    '' NOTE: In OpenGL 1.1, one glColor call can be made for all the subsequent glVertex calls

    '' Make sure colors count match vertex count
    if (RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].vCounter <> RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].cCounter) Then
        Dim As long addColors = RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].vCounter - RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].cCounter

        for i As long = 0 To addColors-1
            RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].colors[4*RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].cCounter] = RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].colors[4*RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].cCounter - 4]
            RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].colors[4*RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].cCounter + 1] = RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].colors[4*RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].cCounter - 3]
            RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].colors[4*RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].cCounter + 2] = RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].colors[4*RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].cCounter - 2]
            RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].colors[4*RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].cCounter + 3] = RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].colors[4*RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].cCounter - 1]
            RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].cCounter+=1
        Next
    EndIf

    '' Make sure texcoords count match vertex count
    if (RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].vCounter <> RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].tcCounter) Then
        Dim As Long addTexCoords = RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].vCounter - RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].tcCounter

        for i As Long = 0 to addTexCoords-1
            RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].texcoords[2*RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].tcCounter] = 0.0f
            RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].texcoords[2*RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].tcCounter + 1] = 0.0f
            RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].tcCounter+=1
        Next
    EndIf

    '' TODO: Make sure normals count match vertex count... if normals support is added in a future... :P

    '' NOTE: Depth increment is dependant on rlOrtho(): z-near and z-far values,
    '' as well as depth buffer bit-depth (16bit or 24bit or 32bit)
    '' Correct increment formula would be: depthInc = (zfar - znear)/pow(2, bits)
    RLGL.currentBatch->currentDepth += (1.0f/20000.0f)

    '' Verify internal buffers limits
    '' NOTE: This check is combined with usage of rlCheckBufferLimit()
    if ((RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].vCounter) >= (RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].elementsCount*4 - 4)) Then
        '' WARNING: If we are between rlPushMatrix() and rlPopMatrix() and we need to force a DrawRenderBatch(),
        '' we need to call rlPopMatrix() before to recover *RLGL.State.currentMatrix (RLGL.State.modelview) for the next forced draw call!
        '' If we have multiple matrix pushed, it will require "RLGL.State.stackCounter" pops before launching the draw
        for i As Long = RLGL.State.stackCounter to 0 Step -1 
        	rlPopMatrix()
        Next
        	DrawRenderBatch(RLGL.currentBatch)
        
    EndIf
End Sub

'' Define one vertex (position)
'' NOTE: Vertex position data is the basic information required for drawing
Sub rlVertex3f(x as Single, y as Single, z as Single)
    Dim As Vector3 vec = Vector3(x, y, z )

    '' Transform provided vector if required
    if (RLGL.State.transformRequired) Then vec = Vector3Transform(vec, RLGL.State.transform)

    '' Verify that current vertex buffer elements limit has not been reached
    if (RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].vCounter < (RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].elementsCount*4)) then
        RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].vertices[3*RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].vCounter] = vec.x
        RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].vertices[3*RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].vCounter + 1] = vec.y
        RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].vertices[3*RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].vCounter + 2] = vec.z
        RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].vCounter+=1

        RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexCount+=1
    else 
    TRACELOG(LOG_ERROR, "RLGL: Batch elements overflow")
	EndIf
End Sub

'' Define one vertex (position)
Sub rlVertex2f(x as Single, y as Single)
    rlVertex3f(x, y, RLGL.currentBatch->currentDepth)
End Sub

'' Define one vertex (position)
Sub rlVertex2i(x as Long, y as Long)
    rlVertex3f((single)x, (Single)y, RLGL.currentBatch->currentDepth)
End Sub

'' Define one vertex (texture coordinate)
'' NOTE: Texture coordinates are limited to QUADS only
Sub rlTexCoord2f(x as Single, y as Single)
    RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].texcoords[2*RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].tcCounter] = x
    RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].texcoords[2*RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].tcCounter + 1] = y
    RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].tcCounter+=1
End Sub

'' Define one vertex (normal)
'' NOTE: Normals limited to TRIANGLES only?
Sub rlNormal3f(x as Single, y as Single, z as Single)
    '' TODO: Normals usage...
    glNormal3f(x,y,z)
End Sub

'' Define one vertex (color)
Sub rlColor4ub(x as ubyte, y As UByte, z As UByte, w As UByte)
    RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].colors[4*RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].cCounter] = x
    RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].colors[4*RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].cCounter + 1] = y
    RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].colors[4*RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].cCounter + 2] = z
    RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].colors[4*RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].cCounter + 3] = w
    RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].cCounter+=1
End sub

'' Define one vertex (color)
Sub rlColor4f(r As Single, g As Single, b As Single, a As single)
    rlColor4ub(int(r*255), int(g*255), int(b*255), Int(a*255))
End Sub

'' Define one vertex (color)
Sub rlColor3f(x as Single, y as Single, z as single)
    rlColor4ub(int(x*255), int(y*255), Int(z*255), 255)
End Sub

#endif

''----------------------------------------------------------------------------------
'' Module Functions Definition - OpenGL equivalent functions (common to 1.1, 3.3+, ES2)
''----------------------------------------------------------------------------------

'' Enable texture usage
Sub rlEnableTexture(id as ULong)
#If defined(GRAPHICS_API_OPENGL_11)
    glEnable(GL_TEXTURE_2D)
    glBindTexture(GL_TEXTURE_2D, id)
#endif

#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    if (RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].textureId <> id) then
        if (RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexCount > 0) Then
            '' Make sure current RLGL.currentBatch->draws[i].vertexCount is aligned a multiple of 4,
            '' that way, following QUADS drawing will keep aligned with index processing
            '' It implies adding some extra alignment vertex at the end of the draw,
            '' those vertex are not processed but they are considered as an additional offset
            '' for the next set of vertex to be drawn
            if (RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].mode == RL_LINES) RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexAlignment = ((RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexCount < 4)? RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexCount : RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexCount%4)
            else if (RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].mode == RL_TRIANGLES) RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexAlignment = ((RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexCount < 4)? 1 : (4 - (RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexCount%4)))

            else RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexAlignment = 0

            if (rlCheckBufferLimit(RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexAlignment)) Then
            	DrawRenderBatch(RLGL.currentBatch)
            else
                RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].vCounter += RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexAlignment
                RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].cCounter += RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexAlignment
                RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].tcCounter += RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexAlignment

                RLGL.currentBatch->drawsCounter+=1
        		EndIf
        End If

        if (RLGL.currentBatch->drawsCounter >= DEFAULT_BATCH_DRAWCALLS) Then DrawRenderBatch(RLGL.currentBatch)

        RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].textureId = id
        RLGL.currentBatch->draws[RLGL.currentBatch->drawsCounter - 1].vertexCount = 0
    Endif
#endif
End Sub

'' Disable texture usage
sub rlDisableTexture()
#If defined(GRAPHICS_API_OPENGL_11)
    glDisable(GL_TEXTURE_2D)
    glBindTexture(GL_TEXTURE_2D, 0)
#else
    '' NOTE: If quads batch limit is reached,
    '' we force a draw call and next batch starts
    if (RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].vCounter >= (RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].elementsCount*4)) Then DrawRenderBatch(RLGL.currentBatch)
#endif
End Sub

'' Set texture parameters (wrap mode/filter mode)
Sub rlTextureParameters(id as ULong, param as Long, value as long)
    glBindTexture(GL_TEXTURE_2D, id)

    Select Case (param)
        case RL_TEXTURE_WRAP_S:
    	case RL_TEXTURE_WRAP_T:
            if (value = RL_WRAP_MIRROR_CLAMP) Then
#If Not Defined(GRAPHICS_API_OPENGL_11)
                if (RLGL.ExtSupported.texMirrorClamp) Then 
                	glTexParameteri(GL_TEXTURE_2D, param, value)
                else 
                	TRACELOG(LOG_WARNING, "GL: Clamp mirror wrap mode not supported (GL_MIRROR_CLAMP_EXT)")
                EndIf
#EndIf
            else glTexParameteri(GL_TEXTURE_2D, param, value)
            EndIf
    	case RL_TEXTURE_MAG_FILTER:
    	case RL_TEXTURE_MIN_FILTER: 
    		glTexParameteri(GL_TEXTURE_2D, param, value)  
        case RL_TEXTURE_ANISOTROPIC_FILTER:
#If Not Defined(GRAPHICS_API_OPENGL_11)
            if (value <= RLGL.ExtSupported.maxAnisotropicLevel) Then
            	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, (Single)value)
            ElseIf (RLGL.ExtSupported.maxAnisotropicLevel > 0.0f) Then
                TRACELOG(LOG_WARNING, "GL: Maximum anisotropic filter level supported is %iX", id, RLGL.ExtSupported.maxAnisotropicLevel)
                glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, (single)value)
            else 
            	TRACELOG(LOG_WARNING, "GL: Anisotropic filtering not supported")
            EndIf
#EndIf  
        case Else:  
    End Select

    glBindTexture(GL_TEXTURE_2D, 0)
End Sub

'' Enable shader program usage
Sub rlEnableShader(id as ULong)
#If (defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2))
    glUseProgram(id)
#endif
End sub

'' Disable shader program usage
sub rlDisableShader()
#If (defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2))
    glUseProgram(0)
#endif
End Sub

'' Enable rendering to texture (fbo)
Sub rlEnableFramebuffer(id as ULong)
#If (defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)) AndAlso defined(SUPPORT_RENDER_TEXTURES_HINT)
    glBindFramebuffer(GL_FRAMEBUFFER, id)
#endif
End Sub

'' Disable rendering to texture
sub rlDisableFramebuffer()
#If (defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)) AndAlso defined(SUPPORT_RENDER_TEXTURES_HINT)
    glBindFramebuffer(GL_FRAMEBUFFER, 0)
#endif
End Sub

'' Enable depth test
sub rlEnableDepthTest() 
	glEnable(GL_DEPTH_TEST) 
End Sub

'' Disable depth test
sub rlDisableDepthTest()
	glDisable(GL_DEPTH_TEST)
End Sub

'' Enable depth write
sub rlEnableDepthMask()
	glDepthMask(GL_TRUE)
End Sub

'' Disable depth write
sub rlDisableDepthMask()
	glDepthMask(GL_FALSE)
End Sub

'' Enable backface culling
sub rlEnableBackfaceCulling()
	glEnable(GL_CULL_FACE)
End Sub

'' Disable backface culling
sub rlDisableBackfaceCulling()
	glDisable(GL_CULL_FACE)
End Sub

'' Enable scissor test
Sub rlEnableScissorTest()
glEnable(GL_SCISSOR_TEST)
End Sub

'' Disable scissor test
Sub rlDisableScissorTest()
	glDisable(GL_SCISSOR_TEST)
End Sub

'' Scissor test
Sub rlScissor(x as Long, y as Long, width as Long, height as Long)
	glScissor(x, y, width, height)
End Sub

'' Enable wire mode
sub rlEnableWireMode()
#If defined(GRAPHICS_API_OPENGL_11) OrElse defined(GRAPHICS_API_OPENGL_33)
    '' NOTE: glPolygonMode() not available on OpenGL ES
    glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)
#endif
End Sub

'' Disable wire mode
sub rlDisableWireMode()
#If defined(GRAPHICS_API_OPENGL_11) OrElse defined(GRAPHICS_API_OPENGL_33)
    '' NOTE: glPolygonMode() not available on OpenGL ES
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
#endif
End Sub
'' Set the line drawing width
Sub rlSetLineWidth(Width as Single)
    glLineWidth(width)
End Sub

'' Get the line drawing width
Function rlGetLineWidth() As Single
    w as singleidth = 0
    glGetFloatv(GL_LINE_WIDTH, @width)
    return Width
End Function

'' Enable line aliasing
sub rlEnableSmoothLines()
#If defined(GRAPHICS_API_OPENGL_33) orelse defined(GRAPHICS_API_OPENGL_21) OrElse defined(GRAPHICS_API_OPENGL_11)
    glEnable(GL_LINE_SMOOTH)
#endif
End Sub

'' Disable line aliasing
sub rlDisableSmoothLines()
#if defined(GRAPHICS_API_OPENGL_33) orelse defined(GRAPHICS_API_OPENGL_21) OrElse defined(GRAPHICS_API_OPENGL_11)
    glDisable(GL_LINE_SMOOTH)
#endif
End Sub

'' Unload framebuffer from GPU memory
'' NOTE: All attached textures/cubemaps/renderbuffers are also deleted
Sub rlUnloadFramebuffer(id as ULong)
#If (defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)) AndAlso defined(SUPPORT_RENDER_TEXTURES_HINT)

    '' Query depth attachment to automatically delete texture/renderbuffer
    Dim As Long depthType = 0, depthId = 0
    glBindFramebuffer(GL_FRAMEBUFFER, id)   '' Bind framebuffer to query depth texture type
    glGetFramebufferAttachmentParameteriv(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE, @depthType)
    glGetFramebufferAttachmentParameteriv(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME, @depthId)

    Dim As ulong depthIdU = depthId
    if (depthType = GL_RENDERBUFFER) Then
    	glDeleteRenderbuffers(1, @depthIdU)
    ElseIf (depthType = GL_RENDERBUFFER) Then
    	glDeleteTextures(1, @depthIdU)
    EndIf
    '' NOTE: If a texture object is deleted while its image is attached to the *currently bound* framebuffer,
    '' the texture image is automatically detached from the currently bound framebuffer.

    glBindFramebuffer(GL_FRAMEBUFFER, 0)
    glDeleteFramebuffers(1, @id)

    TRACELOG(LOG_INFO, "FBO: [ID %i] Unloaded framebuffer from VRAM (GPU)", id)
#endif
End Sub

'' Clear color buffer with color
Sub rlClearColor(r as ubyte, g as ubyte, b as ubyte, a as ubyte)
    '' Color values clamp to 0.0f(0) and 1.0f(255)
    single cr = (Single)r/255
    single cg = (Single)g/255
    single cb = (Single)b/255
    single ca = (Single)a/255

    glClearColor(cr, cg, cb, ca)
End Sub

'' Clear used screen buffers (color and depth)
sub rlClearScreenBuffers()
    glClear(GL_COLOR_BUFFER_BIT Or GL_DEPTH_BUFFER_BIT)     '' Clear used buffers: Color and Depth (Depth is used for 3D)
    ''glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT)     '' Stencil buffer not used...
End Sub

'' Update GPU buffer with new data
sub rlUpdateBuffer(bufferId as Long, Data As Any Ptr, dataSize as Long)
#If defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    glBindBuffer(GL_ARRAY_BUFFER, bufferId)
    glBufferSubData(GL_ARRAY_BUFFER, 0, dataSize, data)
#endif
End Sub

''----------------------------------------------------------------------------------
'' Module Functions Definition - rlgl Functions
''----------------------------------------------------------------------------------

'' Initialize rlgl: OpenGL extensions, default buffers/shaders/textures, OpenGL states
Sub rlglInit(width as Long, height as Long)
    '' Check OpenGL information and capabilities
    ''------------------------------------------------------------------------------
    '' Print current OpenGL and GLSL version
    TRACELOG(LOG_INFO, "GL: OpenGL device information:")
    TRACELOG(LOG_INFO, "    > Vendor:   %s", glGetString(GL_VENDOR))
    TRACELOG(LOG_INFO, "    > Renderer: %s", glGetString(GL_RENDERER))
    TRACELOG(LOG_INFO, "    > Version:  %s", glGetString(GL_VERSION))
    TRACELOG(LOG_INFO, "    > GLSL:     %s", glGetString(GL_SHADING_LANGUAGE_VERSION))

    '' NOTE: We can get a bunch of extra information about GPU capabilities (glGet*)
    ''int maxTexSize
    ''glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTexSize)
    ''TRACELOG(LOG_INFO, "GL: Maximum texture size: %i", maxTexSize)

    ''GL_MAX_TEXTURE_IMAGE_UNITS
    ''GL_MAX_VIEWPORT_DIMS

    ''int numAuxBuffers
    ''glGetIntegerv(GL_AUX_BUFFERS, &numAuxBuffers)
    ''TRACELOG(LOG_INFO, "GL: Number of aixiliar buffers: %i", numAuxBuffers)

    ''GLint numComp = 0
    ''GLformat as long[32] = { 0 }
    ''glGetIntegerv(GL_NUM_COMPRESSED_TEXTURE_FORMATS, &numComp)
    ''glGetIntegerv(GL_COMPRESSED_TEXTURE_FORMATS, format)
    ''for (int i = 0 i < numComp i++) TRACELOG(LOG_INFO, "GL: Supported compressed format: &H%x", format[i])

    '' NOTE: We don't need that much data on screen... right now...

    '' TODO: Automatize extensions loading using rlLoadExtensions() and GLAD
    '' Actually, when rlglInit() is called in InitWindow() in core.c,
    '' OpenGL context has already been created and required extensions loaded

#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    '' Get supported extensions list
    Dim As GLint numExt = 0

#if defined(GRAPHICS_API_OPENGL_33) && !defined(GRAPHICS_API_OPENGL_21)
    '' NOTE: On OpenGL 3.3 VAO and NPOT are supported by default
    RLGL.ExtSupported.vao = TRUE

    '' Multiple texture extensions supported by default
    RLGL.ExtSupported.texNPOT = TRUE
    RLGL.ExtSupported.texFloat32 = TRUE
    RLGL.ExtSupported.texDepth = TRUE

    '' We get a list of available extensions and we check for some of them (compressed textures)
    '' NOTE: We don't need to check again supported extensions but we do (GLAD already dealt with that)
    glGetIntegerv(GL_NUM_EXTENSIONS, @numExt)

    '' Allocate numExt strings pointers
    Dim As ZString Ptr Ptr extList = RL_MALLOC(sizeof(Byte ptr)*numExt)

    '' Get extensions strings
    for i As long= 0 To numExt-1 
    extList[i] = glGetStringi(GL_EXTENSIONS, i)
    Next

#endif
#if defined(GRAPHICS_API_OPENGL_ES2) OrElse defined(GRAPHICS_API_OPENGL_21)
    '' Allocate 512 strings pointers (2 KB)
    Dim As ZString Ptr Ptr extList = RL_MALLOC(512*sizeof(byte Ptr))

    Dim As ZString Ptr extensions = glGetString(GL_EXTENSIONS)  '' One big const string

    '' NOTE: We have to duplicate string because glGetString() returns a const string
    Dim As long len0 = strlen(extensions) + 1
    Dim As ZString Ptr extensionsDup = RL_CALLOC(len0, sizeof(byte))
    strcpy(extensionsDup, extensions)

    extList[numExt] = extensionsDup

    for i As Long = 0 To Len0-1
        if (extensionsDup[i] = " ") then
            extensionsDup[i] = !"\0"

            numExt+=1
            extList[numExt] = @extensionsDup[i + 1]
        EndIf
    Next

    '' NOTE: Duplicated string (extensionsDup) must be deallocated
#endif

    TRACELOG(LOG_INFO, "GL: Supported extensions count: %i", numExt)

    '' Show supported extensions
    ''for (int i = 0 i < numExt i++)  TRACELOG(LOG_INFO, "Supported extension: %s", extList[i])

    '' Check required extensions
    for i As Long = 0 to numExt-1
#If defined(GRAPHICS_API_OPENGL_ES2)
        '' Check VAO support
        '' NOTE: Only check on OpenGL ES, OpenGL 3.3 has VAO support as core feature
        if (strcmp(extList[i], @"GL_OES_vertex_array_object") = 0) Then
            '' The extension is supported by our hardware and driver, try to get related functions pointers
            '' NOTE: emscripten does not support VAOs natively, it uses emulation and it reduces overall performance...
            glGenVertexArrays = (PFNGLGENVERTEXARRAYSOESPROC)eglGetProcAddress("glGenVertexArraysOES")
            glBindVertexArray = (PFNGLBINDVERTEXARRAYOESPROC)eglGetProcAddress("glBindVertexArrayOES")
            glDeleteVertexArrays = (PFNGLDELETEVERTEXARRAYSOESPROC)eglGetProcAddress("glDeleteVertexArraysOES")
            ''glIsVertexArray = (PFNGLISVERTEXARRAYOESPROC)eglGetProcAddress("glIsVertexArrayOES")     '' NOTE: Fails in WebGL, omitted

            if ((glGenVertexArrays <> NULL) andalso (glBindVertexArray <> NULL) andalso (glDeleteVertexArrays <> NULL)) Then RLGL.ExtSupported.vao = TRUE
        EndIf

        '' Check NPOT textures support
        '' NOTE: Only check on OpenGL ES, OpenGL 3.3 has NPOT textures full support as core feature
        if (strcmp(extList[i], @"GL_OES_texture_npot") = 0) Then RLGL.ExtSupported.texNPOT = TRUE

        '' Check texture single support
        if (strcmp(extList[i], @"GL_OES_texture_float") = 0) RLGL.ExtSupported.texFloat32 = TRUE

        '' Check depth texture support
        if ((strcmp(extList[i], @"GL_OES_depth_texture") = 0) OrElse _
            (strcmp(extList[i], @"GL_WEBGL_depth_texture") = 0)) Then RLGL.ExtSupported.texDepth = TRUE

        if (strcmp(extList[i], @"GL_OES_depth24") = 0) Then RLGL.ExtSupported.maxDepthBits = 24
        if (strcmp(extList[i], @"GL_OES_depth32") = 0) Then RLGL.ExtSupported.maxDepthBits = 32
#endif
        '' DDS texture compression support
        if ((strcmp(extList[i], @"GL_EXT_texture_compression_s3tc") = 0) OrElse _
            (strcmp(extList[i], @"GL_WEBGL_compressed_texture_s3tc") = 0) OrElse _
            (strcmp(extList[i], @"GL_WEBKIT_WEBGL_compressed_texture_s3tc") = 0)) Then RLGL.ExtSupported.texCompDXT = TRUE

        '' ETC1 texture compression support
        if ((strcmp(extList[i], @"GL_OES_compressed_ETC1_RGB8_texture") = 0) OrElse _
            (strcmp(extList[i], @"GL_WEBGL_compressed_texture_etc1") = 0)) Then RLGL.ExtSupported.texCompETC1 = TRUE

        '' ETC2/EAC texture compression support
        if (strcmp(extList[i], @"GL_ARB_ES3_compatibility") = 0) Then RLGL.ExtSupported.texCompETC2 = TRUE

        '' PVR texture compression support
        if (strcmp(extList[i], @"GL_IMG_texture_compression_pvrtc") = 0) Then RLGL.ExtSupported.texCompPVRT = TRUE

        '' ASTC texture compression support
        if (strcmp(extList[i], @"GL_KHR_texture_compression_astc_hdr") = 0) Then RLGL.ExtSupported.texCompASTC = TRUE

        '' Anisotropic texture filter support
        if (strcmp(extList[i], @"GL_EXT_texture_filter_anisotropic") = 0) Then
            RLGL.ExtSupported.texAnisoFilter = TRUE
            glGetFloatv(&H84FF, @RLGL.ExtSupported.maxAnisotropicLevel)   '' GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT
        EndIf

        '' Clamp mirror wrap mode supported
        if (strcmp(extList[i], @"GL_EXT_texture_mirror_clamp") = 0) Then RLGL.ExtSupported.texMirrorClamp = TRUE

        '' Debug marker support
        if (strcmp(extList[i], @"GL_EXT_debug_marker") = 0) Then RLGL.ExtSupported.debugMarker = TRUE
    Next

    '' Free extensions pointers
    RL_FREE(extList)

#if defined(GRAPHICS_API_OPENGL_ES2) OrElse defined(GRAPHICS_API_OPENGL_21)
    RL_FREE(extensionsDup)    '' Duplicated string must be deallocated
#endif

#if defined(GRAPHICS_API_OPENGL_ES2)
    if (RLGL.ExtSupported.vao) Then 
    	TRACELOG(LOG_INFO, "GL: VAO extension detected, VAO functions initialized successfully")
    else 
    	TRACELOG(LOG_WARNING, "GL: VAO extension not found, VAO usage not supported")
    EndIf

    if (RLGL.ExtSupported.texNPOT) Then
    	TRACELOG(LOG_INFO, "GL: NPOT textures extension detected, full NPOT textures supported")
    else 
    	TRACELOG(LOG_WARNING, "GL: NPOT textures extension not found, limited NPOT support (no-mipmaps, no-repeat)")
    EndIf
#EndIf

    if (RLGL.ExtSupported.texCompDXT) Then TRACELOG(LOG_INFO, "GL: DXT compressed textures supported")
    if (RLGL.ExtSupported.texCompETC1) Then TRACELOG(LOG_INFO, "GL: ETC1 compressed textures supported")
    if (RLGL.ExtSupported.texCompETC2) Then TRACELOG(LOG_INFO, "GL: ETC2/EAC compressed textures supported")
    if (RLGL.ExtSupported.texCompPVRT) Then TRACELOG(LOG_INFO, "GL: PVRT compressed textures supported")
    if (RLGL.ExtSupported.texCompASTC) Then TRACELOG(LOG_INFO, "GL: ASTC compressed textures supported")

    if (RLGL.ExtSupported.texAnisoFilter) Then TRACELOG(LOG_INFO, "GL: Anisotropic textures filtering supported (max: %.0fX)", RLGL.ExtSupported.maxAnisotropicLevel)
    if (RLGL.ExtSupported.texMirrorClamp) Then TRACELOG(LOG_INFO, "GL: Mirror clamp wrap texture mode supported")

    if (RLGL.ExtSupported.debugMarker) Then TRACELOG(LOG_INFO, "GL: Debug Marker supported")

    '' Initialize buffers, default shaders and default textures
    ''----------------------------------------------------------
    '' Init default white texture
    Dim As UByte pixels(0 To 3) = { 255, 255, 255, 255 }   '' 1 pixel RGBA (4 bytes)
    RLGL.State.defaultTextureId = rlLoadTexture(pixels, 1, 1, UNCOMPRESSED_R8G8B8A8, 1)

    if (RLGL.State.defaultTextureId <> 0) Then
    	TRACELOG(LOG_INFO, "TEXTURE: [ID %i] Default texture loaded successfully", RLGL.State.defaultTextureId)
    else 
    	TRACELOG(LOG_WARNING, "TEXTURE: Failed to load default texture")
    EndIf

    '' Init default Shader (customized for GL 3.3 and ES2)
    RLGL.State.defaultShader = LoadShaderDefault()
    RLGL.State.currentShader = RLGL.State.defaultShader

    '' Init default vertex arrays buffers
    RLGL.defaultBatch = LoadRenderBatch(DEFAULT_BATCH_BUFFERS, DEFAULT_BATCH_BUFFER_ELEMENTS)
    RLGL.currentBatch = @RLGL.defaultBatch

    '' Init stack matrices (emulating OpenGL 1.1)
    for i As Long = 0 To MAX_MATRIX_STACK_SIZE-1 
    RLGL.State.stack[i] = MatrixIdentity()
    Next

    '' Init internal matrices
    RLGL.State.transform = MatrixIdentity()
    RLGL.State.projection = MatrixIdentity()
    RLGL.State.modelview = MatrixIdentity()
    RLGL.State.currentMatrix = @RLGL.State.modelview

#endif      '' GRAPHICS_API_OPENGL_33 orelse GRAPHICS_API_OPENGL_ES2

    '' Initialize OpenGL default states
    ''----------------------------------------------------------
    '' Init state: Depth test
    glDepthFunc(GL_LEQUAL)                                 '' Type of depth testing to apply
    glDisable(GL_DEPTH_TEST)                               '' Disable depth testing for 2D (only used for 3D)

    '' Init state: Blending mode
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)      '' Color blending function (how colors are mixed)
    glEnable(GL_BLEND)                                     '' Enable color blending (required to work with transparencies)

    '' Init state: Culling
    '' NOTE: All shapes/models triangles are drawn CCW
    glCullFace(GL_BACK)                                    '' Cull the back face (default)
    glFrontFace(GL_CCW)                                    '' Front face are defined counter clockwise (default)
    glEnable(GL_CULL_FACE)                                 '' Enable backface culling

    '' Init state: Cubemap seamless
#if defined(GRAPHICS_API_OPENGL_33)
    glEnable(GL_TEXTURE_CUBE_MAP_SEAMLESS)                 '' Seamless cubemaps (not supported on OpenGL ES 2.0)
#endif

#if defined(GRAPHICS_API_OPENGL_11)
    '' Init state: Color hints (deprecated in OpenGL 3.0+)
    glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST)      '' Improve quality of color and texture coordinate interpolation
    glShadeModel(GL_SMOOTH)                                '' Smooth shading between vertex (vertex colors interpolation)
#endif

#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    '' Store screen size into global variables
    RLGL.State.framebufferWidth = Width
    RLGL.State.framebufferHeight = height

    '' Init texture and rectangle used on basic shapes drawing
    RLGL.State.shapesTexture = GetTextureDefault()
    RLGL.State.shapesTextureRec = Rectangle( 0.0f, 0.0f, 1.0f, 1.0f )

    TRACELOG(LOG_INFO, "RLGL: Default state initialized successfully")
#endif

    '' Init state: Color/Depth buffers clear
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f)                   '' Set clear color (black)
    glClearDepth(1.0f)                                     '' Set clear depth value (default)
    glClear(GL_COLOR_BUFFER_BIT Or GL_DEPTH_BUFFER_BIT)     '' Clear color and depth buffers (depth buffer required for 3D)
End Sub

'' Vertex Buffer Object deinitialization (memory free)
sub rlglClose()
#If defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    UnloadRenderBatch(RLGL.defaultBatch)

    UnloadShaderDefault()          '' Unload default shader
    glDeleteTextures(1, @RLGL.State.defaultTextureId) '' Unload default texture

    TRACELOG(LOG_INFO, "TEXTURE: [ID %i] Unloaded default texture data from VRAM (GPU)", RLGL.State.defaultTextureId)
#endif
End Sub

'' Update and draw internal buffers
sub rlglDraw()
#If defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    DrawRenderBatch(RLGL.currentBatch)    '' NOTE: Stereo rendering is checked inside
#endif
End Sub

'' Check and log OpenGL error codes
Sub rlCheckErrors()
#if defined(GRAPHICS_API_OPENGL_21) orelse defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    Dim As long check = 1
    while (check)
        Dim As GLenum err0 = glGetError()
        Select Case (err0) 
            case GL_NO_ERROR:
                check = 0
                 
            case &H0500: '' GL_INVALID_ENUM:
                TRACELOG(LOG_WARNING, "GL: Error detected: GL_INVALID_ENUM")
                 
            case &H0501: ''GL_INVALID_VALUE:
                TRACELOG(LOG_WARNING, "GL: Error detected: GL_INVALID_VALUE")
                 
            case &H0502: ''GL_INVALID_OPERATION:
                TRACELOG(LOG_WARNING, "GL: Error detected: GL_INVALID_OPERATION")
                 
            case &H0503: '' GL_STACK_OVERFLOW:
                TRACELOG(LOG_WARNING, "GL: Error detected: GL_STACK_OVERFLOW")
                 
            case &H0504: '' GL_STACK_UNDERFLOW:
                TRACELOG(LOG_WARNING, "GL: Error detected: GL_STACK_UNDERFLOW")
                 
            case &H0505: '' GL_OUT_OF_MEMORY:
                TRACELOG(LOG_WARNING, "GL: Error detected: GL_OUT_OF_MEMORY")
                 
            case &H0506: '' GL_INVALID_FRAMEBUFFER_OPERATION:
                TRACELOG(LOG_WARNING, "GL: Error detected: GL_INVALID_FRAMEBUFFER_OPERATION")
                 
            case Else:
                TRACELOG(LOG_WARNING, "GL: Error detected: unknown error code %x", err0)
                 
        End Select
    Wend
#endif
End Sub

'' Returns current OpenGL version
Function rlGetVersion() As Long
#If defined(GRAPHICS_API_OPENGL_11)
    return OPENGL_11
#ElseIf defined(GRAPHICS_API_OPENGL_21)
    #if defined(__APPLE__)
        return OPENGL_33           '' NOTE: Force OpenGL 3.3 on OSX
    #else
        return OPENGL_21
    #endif
#ElseIf defined(GRAPHICS_API_OPENGL_33)
    return OPENGL_33
#ElseIf defined(GRAPHICS_API_OPENGL_ES2)
    return OPENGL_ES_20
#endif
End Function

'' Check internal buffer overflow for a given number of vertex
function rlCheckBufferLimit(vCount As Long)As boolean
    Dim As boolean overflow = FALSE
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    if ((RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].vCounter + vCount) >= (RLGL.currentBatch->vertexBuffer[RLGL.currentBatch->currentBuffer].elementsCount*4)) Then overflow = TRUE
#endif
    return overflow
End Function

'' Set debug marker
Sub rlSetDebugMarker(text As ZString Ptr)
#If defined(GRAPHICS_API_OPENGL_33)
    if (RLGL.ExtSupported.debugMarker) glInsertEventMarkerEXT(0, text)
#endif
End Sub

'' Set blending mode factor and equation
Sub rlSetBlendMode(glSrcFactor as Long, glDstFactor as Long, glEquationr As long)
#If defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    RLGL.State.glBlendSrcFactor = glSrcFactor
    RLGL.State.glBlendDstFactor = glDstFactor
    RLGL.State.glBlendEquation = glEquation
#endif
End Sub

'' Load OpenGL extensions
'' NOTE: External loader function could be passed as a pointer
'TODO
sub rlLoadExtensions(loader As function)
#If defined(GRAPHICS_API_OPENGL_33)
    '' NOTE: glad is generated and contains only required OpenGL 3.3 Core extensions (and lower versions)
    #if Not Defined(__APPLE__)
        if (Not gladLoadGLLoader((GLADloadproc)loader)) Then
        	TRACELOG(LOG_WARNING, "GLAD: Cannot load OpenGL extensions")
        else 
        	TRACELOG(LOG_INFO, "GLAD: OpenGL extensions loaded successfully")
        EndIf

        #if defined(GRAPHICS_API_OPENGL_21)
        if (GLAD_GL_VERSION_2_1) Then TRACELOG(LOG_INFO, "GL: OpenGL 2.1 profile supported")
        #ElseIf defined(GRAPHICS_API_OPENGL_33)
        if (GLAD_GL_VERSION_3_3) Then 
        	TRACELOG(LOG_INFO, "GL: OpenGL 3.3 Core profile supported")
        else 
        	TRACELOG(LOG_ERROR, "GL: OpenGL 3.3 Core profile not supported")
        EndIf
        #endif
    #endif

    '' With GLAD, we can check if an extension is supported using the GLAD_GL_xxx booleans
    ''if (GLAD_GL_ARB_vertex_array_object) '' Use GL_ARB_vertex_array_object
#endif
End Sub

'' Convert image data to OpenGL texture (returns OpenGL valid Id)
Function rlLoadTexture(Data As Any ptr, width as Long, height as Long, format as Long, mipmapCount as Long) As ULong
    glBindTexture(GL_TEXTURE_2D, 0)    '' Free any old binding

    Dim id as ULong = 0

    '' Check texture format support by OpenGL 1.1 (compressed textures not supported)
#if defined(GRAPHICS_API_OPENGL_11)
    if (format >= COMPRESSED_DXT1_RGB) Then
        TRACELOG(LOG_WARNING, "GL: OpenGL 1.1 does not support GPU compressed texture formats")
        return id
    EndIf
#else
    if ((Not RLGL.ExtSupported.texCompDXT) andalso ((format = COMPRESSED_DXT1_RGB) orelse (format = COMPRESSED_DXT1_RGBA) OrElse _
        (format = COMPRESSED_DXT3_RGBA) OrElse (format = COMPRESSED_DXT5_RGBA))) Then
        TRACELOG(LOG_WARNING, "GL: DXT compressed texture format not supported")
        return id
    End If
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    if ((Not RLGL.ExtSupported.texCompETC1) andalso (format = COMPRESSED_ETC1_RGB)) Then
        TRACELOG(LOG_WARNING, "GL: ETC1 compressed texture format not supported")
        return id
    EndIf

    if ((Not RLGL.ExtSupported.texCompETC2) andalso ((format = COMPRESSED_ETC2_RGB) OrElse (format = COMPRESSED_ETC2_EAC_RGBA))) Then
        TRACELOG(LOG_WARNING, "GL: ETC2 compressed texture format not supported")
        return id
    EndIf

    if ((Not RLGL.ExtSupported.texCompPVRT) andalso ((format = COMPRESSED_PVRT_RGB) OrElse (format = COMPRESSED_PVRT_RGBA))) Then
        TRACELOG(LOG_WARNING, "GL: PVRT compressed texture format not supported")
        return id
    EndIf

    if ((Not RLGL.ExtSupported.texCompASTC) andalso ((format = COMPRESSED_ASTC_4x4_RGBA) OrElse (format = COMPRESSED_ASTC_8x8_RGBA))) Then
        TRACELOG(LOG_WARNING, "GL: ASTC compressed texture format not supported")
        return id
    EndIf
#endif
#endif      '' GRAPHICS_API_OPENGL_11

    glPixelStorei(GL_UNPACK_ALIGNMENT, 1)

    glGenTextures(1, @id)              '' Generate texture id

#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    ''glActiveTexture(GL_TEXTURE0)     '' If not defined, using GL_TEXTURE0 by default (shader texture)
#endif

    glBindTexture(GL_TEXTURE_2D, id)

    Dim As Long mipWidth = Width
    Dim As Long mipHeight = height
    Dim As Long mipOffset = 0          '' Mipmap data offset

    '' Load the different mipmap levels
    for i As Long = 0 To mipmapCount-1
        Dim As ULong mipSize = GetPixelDataSize(mipWidth, mipHeight, format)

        Dim As ULong glInternalFormat, glFormat, glType
        rlGetGlTextureFormats(format, @glInternalFormat, @glFormat, @glType)

        TRACELOGD("TEXTURE: Load mipmap level %i (%i x %i), size: %i, offset: %i", i, mipWidth, mipHeight, mipSize, mipOffset)

        if (glInternalFormat <> -1) Then
            if (format < COMPRESSED_DXT1_RGB) Then
            	glTexImage2D(GL_TEXTURE_2D, i, glInternalFormat, mipWidth, mipHeight, 0, glFormat, glType, Data + mipOffset)
        #if !defined(GRAPHICS_API_OPENGL_11)
            else 
            	glCompressedTexImage2D(GL_TEXTURE_2D, i, glInternalFormat, mipWidth, mipHeight, 0, mipSize, Data + mipOffset)
        #endif
            EndIf

        #if defined(GRAPHICS_API_OPENGL_33)
            if (format = UNCOMPRESSED_GRAYSCALE) Then
                Dim As GLint swizzleMask(0 To 3) = { GL_RED, GL_RED, GL_RED, GL_ONE }
                glTexParameteriv(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_RGBA, swizzleMask)
            ElseIf (format = UNCOMPRESSED_GRAY_ALPHA) Then
            #if defined(GRAPHICS_API_OPENGL_21)
                Dim As GLint swizzleMask(0 To 3) = { GL_RED, GL_RED, GL_RED, GL_ALPHA }
            #ElseIf defined(GRAPHICS_API_OPENGL_33)
                Dim As GLint swizzleMask(0 To 3) = { GL_RED, GL_RED, GL_RED, GL_GREEN }
            #endif
                glTexParameteriv(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_RGBA, swizzleMask)
            EndIf
        #endif
        EndIf

        mipWidth /= 2
        mipHeight /= 2
        mipOffset += mipSize

        '' Security check for NPOT textures
        if (mipWidth < 1) Then mipWidth = 1
        if (mipHeight < 1) Then mipHeight = 1
    Next

    '' Texture parameters configuration
    '' NOTE: glTexParameteri does NOT affect texture uploading, just the way it's used
#if defined(GRAPHICS_API_OPENGL_ES2)
    '' NOTE: OpenGL ES 2.0 with no GL_OES_texture_npot support (i.e. WebGL) has limited NPOT support, so CLAMP_TO_EDGE must be used
    if (RLGL.ExtSupported.texNPOT) Then
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)       '' Set texture to repeat on x-axis
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)       '' Set texture to repeat on y-axis
    Else
        '' NOTE: If using negative texture coordinates (LoadOBJ()), it does not work!
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)       '' Set texture to clamp on x-axis
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)       '' Set texture to clamp on y-axis
    EndIf
#else
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)       '' Set texture to repeat on x-axis
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)       '' Set texture to repeat on y-axis
#endif

    '' Magnification and minification filters
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)  '' Alternative: GL_LINEAR
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)  '' Alternative: GL_LINEAR

#if defined(GRAPHICS_API_OPENGL_33)
    if (mipmapCount > 1) Then
        '' Activate Trilinear filtering if mipmaps are available
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR)
    EndIf
#endif

    '' At this point we have the texture loaded in GPU and texture parameters configured

    '' NOTE: If mipmaps were not in data, they are not generated automatically

    '' Unbind current texture
    glBindTexture(GL_TEXTURE_2D, 0)

    if (id > 0) Then
    	TRACELOG(LOG_INFO, "TEXTURE: [ID %i] Texture created successfully (%ix%i - %i mipmaps)", id, width, height, mipmapCount)
    else 
    	TRACELOG(LOG_WARNING, "TEXTURE: Failed to load texture")
    EndIf

    return id
End Function

'' Load depth texture/renderbuffer (to be attached to fbo)
'' WARNING: OpenGL ES 2.0 requires GL_OES_depth_texture/WEBGL_depth_texture extensions
Function rlLoadTextureDepth(width as Long, height as Long, useRenderBuffer as boolean) As ULong
    Dim id as ULong = 0

#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    '' In case depth textures not supported, we force renderbuffer usage
    if (Not RLGL.ExtSupported.texDepth) Then useRenderBuffer = TRUE

    '' NOTE: We let the implementation to choose the best bit-depth
    '' Possible formats: GL_DEPTH_COMPONENT16, GL_DEPTH_COMPONENT24, GL_DEPTH_COMPONENT32 and GL_DEPTH_COMPONENT32F
    Dim As ULong glInternalFormat = GL_DEPTH_COMPONENT

#if defined(GRAPHICS_API_OPENGL_ES2)
    if (RLGL.ExtSupported.maxDepthBits = 32) Then 
    	glInternalFormat = GL_DEPTH_COMPONENT32_OES
    ElseIf (RLGL.ExtSupported.maxDepthBits = 24) Then 
    	glInternalFormat = GL_DEPTH_COMPONENT24_OES
    else 
    	glInternalFormat = GL_DEPTH_COMPONENT16
    EndIf
#EndIf

    if (Not useRenderBuffer andalso RLGL.ExtSupported.texDepth) Then
        glGenTextures(1, @id)
        glBindTexture(GL_TEXTURE_2D, id)
        glTexImage2D(GL_TEXTURE_2D, 0, glInternalFormat, width, height, 0, GL_DEPTH_COMPONENT, GL_UNSIGNED_INT, NULL)

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

        glBindTexture(GL_TEXTURE_2D, 0)

        TRACELOG(LOG_INFO, "TEXTURE: Depth texture loaded successfully")
    Else
        '' Create the renderbuffer that will serve as the depth attachment for the framebuffer
        '' NOTE: A renderbuffer is simpler than a texture and could offer better performance on embedded devices
        glGenRenderbuffers(1, @id)
        glBindRenderbuffer(GL_RENDERBUFFER, id)
        glRenderbufferStorage(GL_RENDERBUFFER, glInternalFormat, width, height)

        glBindRenderbuffer(GL_RENDERBUFFER, 0)

        TRACELOG(LOG_INFO, "TEXTURE: [ID %i] Depth renderbuffer loaded successfully (%i bits)", id, (RLGL.ExtSupported.maxDepthBits >= 24)? RLGL.ExtSupported.maxDepthBits : 16)
    EndIf
#endif

    return id
End Function

'' Load texture cubemap
'' NOTE: Cubemap data is expected to be 6 images in a single data array (one after the other),
'' expected the following convention: +X, -X, +Y, -Y, +Z, -Z
Function rlLoadTextureCubemap(Data As Any ptr, size as Long, format as Long) As ULong
    Dim id as ULong = 0

#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    Dim dataSize as ULong = GetPixelDataSize(size, size, format)

    glGenTextures(1, @id)
    glBindTexture(GL_TEXTURE_CUBE_MAP, id)

    Dim As ULong glInternalFormat, glFormat, glType
    rlGetGlTextureFormats(format, @glInternalFormat, @glFormat, @glType)

    if (glInternalFormat <> -1) Then
        '' Load cubemap faces
        for i As ULong = 0 To 5
            if (data = NULL) Then
                if (format < COMPRESSED_DXT1_RGB) then
                    if (format = UNCOMPRESSED_R32G32B32) Then
                        '' Instead of using a sized internal texture format (GL_RGB16F, GL_RGB32F), we let the driver to choose the better format for us (GL_RGB)
                        if (RLGL.ExtSupported.texFloat32) Then 
                        	glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, GL_RGB, size, size, 0, GL_RGB, GL_FLOAT, NULL)
                        else 
                        	TRACELOG(LOG_WARNING, "TEXTURES: Cubemap requested format not supported")
                        EndIf
                    ElseIf ((format = UNCOMPRESSED_R32) OrElse (format = UNCOMPRESSED_R32G32B32A32)) Then 
                    	TRACELOG(LOG_WARNING, "TEXTURES: Cubemap requested format not supported")
                    Else 
                    	glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, glInternalFormat, size, size, 0, glFormat, glType, NULL)
                    EndIf
                Else 
                	TRACELOG(LOG_WARNING, "TEXTURES: Empty cubemap creation does not support compressed format")
                EndIf
            Else
                if (format < COMPRESSED_DXT1_RGB) Then
                	glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, glInternalFormat, size, size, 0, glFormat, glType, data + i*dataSize)
                else 
                	glCompressedTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, glInternalFormat, size, size, 0, dataSize, Data + i*dataSize)
                EndIf
            EndIf

#if defined(GRAPHICS_API_OPENGL_33)
            if (format = UNCOMPRESSED_GRAYSCALE) Then
                Dim As GLint swizzleMask(0 To 3) = { GL_RED, GL_RED, GL_RED, GL_ONE }
                glTexParameteriv(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_SWIZZLE_RGBA, swizzleMask)
            ElseIf (format = UNCOMPRESSED_GRAY_ALPHA) Then
#If defined(GRAPHICS_API_OPENGL_21)
                Dim As GLint swizzleMask(0 To 3) = { GL_RED, GL_RED, GL_RED, GL_ALPHA }
#ElseIf defined(GRAPHICS_API_OPENGL_33)
                Dim As GLint swizzleMask(0 To 3) = { GL_RED, GL_RED, GL_RED, GL_GREEN }
#endif
                glTexParameteriv(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_SWIZZLE_RGBA, swizzleMask)
            EndIf
#endif
        Next
    EndIf

    '' Set cubemap texture sampling parameters
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
#if defined(GRAPHICS_API_OPENGL_33)
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE)  '' Flag not supported on OpenGL ES 2.0
#endif

    glBindTexture(GL_TEXTURE_CUBE_MAP, 0)
#endif

    if (id > 0) Then
    	TRACELOG(LOG_INFO, "TEXTURE: [ID %i] Cubemap texture created successfully (%ix%i)", id, size, size)
    else 
    	TRACELOG(LOG_WARNING, "TEXTURE: Failed to load cubemap texture")
    EndIf

    return id
End Function

'' Update already loaded texture in GPU with new data
'' NOTE: We don't know safely if internal texture format is the expected one...
sub rlUpdateTexture(id as ULong, offsetX as Long, offsetY as long, width as Long, height as Long, format as Long, Data As Any ptr)
    glBindTexture(GL_TEXTURE_2D, id)

    Dim As ULong glInternalFormat, glFormat, glType
    rlGetGlTextureFormats(format, @glInternalFormat, @glFormat, @glType)

    if ((glInternalFormat <> -1) andalso (format < COMPRESSED_DXT1_RGB)) then
        glTexSubImage2D(GL_TEXTURE_2D, 0, offsetX, offsetY, width, height, glFormat, glType, data)
    else 
    TRACELOG(LOG_WARNING, "TEXTURE: [ID %i] Failed to update for current texture format (%i)", id, format)
		EndIf
End Sub

'' Get OpenGL internal formats and data type from raylib PixelFormat
Sub rlGetGlTextureFormats(format as Long, glInternalFormat as ulong ptr, glFormat as ulong ptr, glTypet as ulong Ptr)
    *glInternalFormat = -1
    *glFormat = -1
    *glType = -1

    Select Case (format)
    #if defined(GRAPHICS_API_OPENGL_11) orelse defined(GRAPHICS_API_OPENGL_21) OrElse defined(GRAPHICS_API_OPENGL_ES2)
        '' NOTE: on OpenGL ES 2.0 (WebGL), internalFormat must match format and options allowed are: GL_LUMINANCE, GL_RGB, GL_RGBA
    	case UNCOMPRESSED_GRAYSCALE: 
    		*glInternalFormat = GL_LUMINANCE 
    		*glFormat = GL_LUMINANCE 
    		*glType = GL_UNSIGNED_BYTE  
    	case UNCOMPRESSED_GRAY_ALPHA: 
    		*glInternalFormat = GL_LUMINANCE_ALPHA 
    		*glFormat = GL_LUMINANCE_ALPHA 
    		*glType = GL_UNSIGNED_BYTE  
    	case UNCOMPRESSED_R5G6B5: 
    		*glInternalFormat = GL_RGB 
    		*glFormat = GL_RGB 
    		*glType = GL_UNSIGNED_SHORT_5_6_5  
    	case UNCOMPRESSED_R8G8B8: 
    		*glInternalFormat = GL_RGB 
    		*glFormat = GL_RGB 
    		*glType = GL_UNSIGNED_BYTE  
    	case UNCOMPRESSED_R5G5B5A1: 
    		*glInternalFormat = GL_RGBA 
    		*glFormat = GL_RGBA 
    		*glType = GL_UNSIGNED_SHORT_5_5_5_1  
    	case UNCOMPRESSED_R4G4B4A4: 
    		*glInternalFormat = GL_RGBA 
    		*glFormat = GL_RGBA 
    		*glType = GL_UNSIGNED_SHORT_4_4_4_4  
    	case UNCOMPRESSED_R8G8B8A8: 
    		*glInternalFormat = GL_RGBA 
    		*glFormat = GL_RGBA 
    		*glType = GL_UNSIGNED_BYTE  
        #if Not Defined(GRAPHICS_API_OPENGL_11)
    	case UNCOMPRESSED_R32: 
    		if (RLGL.ExtSupported.texFloat32) Then
    			*glInternalFormat = GL_LUMINANCE 
    			*glFormat = GL_LUMINANCE 
    			*glType = GL_FLOAT     '' NOTE: Requires extension OES_texture_float
    		EndIf
    	case UNCOMPRESSED_R32G32B32: 
    		if (RLGL.ExtSupported.texFloat32) Then 
    			*glInternalFormat = GL_RGB 
    			*glFormat = GL_RGB 
    			*glType = GL_FLOAT           '' NOTE: Requires extension OES_texture_float
    		EndIf
    	case UNCOMPRESSED_R32G32B32A32: 
    		if (RLGL.ExtSupported.texFloat32) Then
    			*glInternalFormat = GL_RGBA 
    			*glFormat = GL_RGBA 
    			*glType = GL_FLOAT      '' NOTE: Requires extension OES_texture_float
    		EndIf
        #endif
    #ElseIf defined(GRAPHICS_API_OPENGL_33)
    	case UNCOMPRESSED_GRAYSCALE: 
    		*glInternalFormat = GL_R8 
    		*glFormat = GL_RED 
    		*glType = GL_UNSIGNED_BYTE  
    	case UNCOMPRESSED_GRAY_ALPHA: 
    		*glInternalFormat = GL_RG8 
    		*glFormat = GL_RG 
    		*glType = GL_UNSIGNED_BYTE  
    	case UNCOMPRESSED_R5G6B5: 
    		*glInternalFormat = GL_RGB565 
    		*glFormat = GL_RGB 
    		*glType = GL_UNSIGNED_SHORT_5_6_5  
    	case UNCOMPRESSED_R8G8B8: 
    		*glInternalFormat = GL_RGB8 
    		*glFormat = GL_RGB 
    		*glType = GL_UNSIGNED_BYTE  
    	case UNCOMPRESSED_R5G5B5A1: 
    		*glInternalFormat = GL_RGB5_A1 
    		*glFormat = GL_RGBA 
    		*glType = GL_UNSIGNED_SHORT_5_5_5_1  
    	case UNCOMPRESSED_R4G4B4A4: 
    		*glInternalFormat = GL_RGBA4 
    		*glFormat = GL_RGBA 
    		*glType = GL_UNSIGNED_SHORT_4_4_4_4  
    	case UNCOMPRESSED_R8G8B8A8: 
    		*glInternalFormat = GL_RGBA8 
    		*glFormat = GL_RGBA 
    		*glType = GL_UNSIGNED_BYTE  
    	case UNCOMPRESSED_R32: 
    		if (RLGL.ExtSupported.texFloat32) Then
    			*glInternalFormat = GL_R32F 
    			*glFormat = GL_RED 
    			*glType = GL_FLOAT  
    		EndIf
    	case UNCOMPRESSED_R32G32B32: 
    		if (RLGL.ExtSupported.texFloat32) Then
    			*glInternalFormat = GL_RGB32F 
    			*glFormat = GL_RGB 
    			*glType = GL_FLOAT  
    		EndIf
    	case UNCOMPRESSED_R32G32B32A32:
    		if (RLGL.ExtSupported.texFloat32) Then
    			*glInternalFormat = GL_RGBA32F 
    			*glFormat = GL_RGBA 
    			*glType = GL_FLOAT  
    		EndIf
    #endif
        #if Not Defined(GRAPHICS_API_OPENGL_11)
    	case COMPRESSED_DXT1_RGB: 
    		if (RLGL.ExtSupported.texCompDXT) Then
    			*glInternalFormat = GL_COMPRESSED_RGB_S3TC_DXT1_EXT  
    		EndIf
    	case COMPRESSED_DXT1_RGBA: 
    		if (RLGL.ExtSupported.texCompDXT) Then
    			*glInternalFormat = GL_COMPRESSED_RGBA_S3TC_DXT1_EXT  
    		EndIf
    	case COMPRESSED_DXT3_RGBA: 
    		if (RLGL.ExtSupported.texCompDXT) Then
    			*glInternalFormat = GL_COMPRESSED_RGBA_S3TC_DXT3_EXT  
    		EndIf
    	case COMPRESSED_DXT5_RGBA: 
    		if (RLGL.ExtSupported.texCompDXT) Then
    			*glInternalFormat = GL_COMPRESSED_RGBA_S3TC_DXT5_EXT  
    		EndIf
    	case COMPRESSED_ETC1_RGB:
    		if (RLGL.ExtSupported.texCompETC1) Then
    			*glInternalFormat = GL_ETC1_RGB8_OES                        '' NOTE: Requires OpenGL ES 2.0 or OpenGL 4.3
    		EndIf
    	case COMPRESSED_ETC2_RGB:
    		if (RLGL.ExtSupported.texCompETC2) Then
    			*glInternalFormat = GL_COMPRESSED_RGB8_ETC2                 '' NOTE: Requires OpenGL ES 3.0 or OpenGL 4.3
    		EndIf
    	case COMPRESSED_ETC2_EAC_RGBA:
    		if (RLGL.ExtSupported.texCompETC2) Then
    			*glInternalFormat = GL_COMPRESSED_RGBA8_ETC2_EAC       '' NOTE: Requires OpenGL ES 3.0 or OpenGL 4.3
    		EndIf
    	case COMPRESSED_PVRT_RGB:
    		if (RLGL.ExtSupported.texCompPVRT) Then
    			*glInternalFormat = GL_COMPRESSED_RGB_PVRTC_4BPPV1_IMG      '' NOTE: Requires PowerVR GPU
    		EndIf
    	case COMPRESSED_PVRT_RGBA:
    		if (RLGL.ExtSupported.texCompPVRT) Then
    			*glInternalFormat = GL_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG    '' NOTE: Requires PowerVR GPU
    		EndIf
    	case COMPRESSED_ASTC_4x4_RGBA:
    		if (RLGL.ExtSupported.texCompASTC) Then
    			*glInternalFormat = GL_COMPRESSED_RGBA_ASTC_4x4_KHR    '' NOTE: Requires OpenGL ES 3.1 or OpenGL 4.3
    		EndIf
    	case COMPRESSED_ASTC_8x8_RGBA:
    		if (RLGL.ExtSupported.texCompASTC) Then
    			*glInternalFormat = GL_COMPRESSED_RGBA_ASTC_8x8_KHR    '' NOTE: Requires OpenGL ES 3.1 or OpenGL 4.3
    		EndIf
        #endif
    	case Else: 
    		TRACELOG(LOG_WARNING, "TEXTURE: Current format not supported (%i)", format)  
    End Select
End Sub

'' Unload texture from GPU memory
Sub rlUnloadTexture(id as ULong)
    glDeleteTextures(1, @id)
End Sub

'' Load a framebuffer to be used for rendering
'' NOTE: No textures attached
Function rlLoadFramebuffer(width as Long, height as Long) As ULong
    Dim fboId as ULong = 0

#if (defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)) AndAlso defined(SUPPORT_RENDER_TEXTURES_HINT)
    glGenFramebuffers(1, @fboId)       '' Create the framebuffer object
    glBindFramebuffer(GL_FRAMEBUFFER, 0)   '' Unbind any framebuffer
#endif

    return fboId
End Function

'' Attach color buffer texture to an fbo (unloads previous attachment)
'' NOTE: Attach type: 0-Color, 1-Depth renderbuffer, 2-Depth texture
Sub rlFramebufferAttach(fboId as ULong, texId as ulong, attachType as Long, texType as Long)
#If (defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)) AndAlso defined(SUPPORT_RENDER_TEXTURES_HINT)
    glBindFramebuffer(GL_FRAMEBUFFER, fboId)

    Select Case (attachType)
        case RL_ATTACHMENT_COLOR_CHANNEL0:
        case RL_ATTACHMENT_COLOR_CHANNEL1:
        case RL_ATTACHMENT_COLOR_CHANNEL2:
        case RL_ATTACHMENT_COLOR_CHANNEL3:
        case RL_ATTACHMENT_COLOR_CHANNEL4:
        case RL_ATTACHMENT_COLOR_CHANNEL5:
        case RL_ATTACHMENT_COLOR_CHANNEL6:
    	Case RL_ATTACHMENT_COLOR_CHANNEL7:
            if (texType = RL_ATTACHMENT_TEXTURE2D) Then
            	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + attachType, GL_TEXTURE_2D, texId, 0)
            ElseIf (texType = RL_ATTACHMENT_RENDERBUFFER) Then
            	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + attachType, GL_RENDERBUFFER, texId)
            ElseIf (texType >= RL_ATTACHMENT_CUBEMAP_POSITIVE_X) Then
            	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + attachType, GL_TEXTURE_CUBE_MAP_POSITIVE_X + texType, texId, 0)
				EndIf  
    	case RL_ATTACHMENT_DEPTH:
            if (texType = RL_ATTACHMENT_TEXTURE2D) Then
            	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, texId, 0)
            elseif (texType = RL_ATTACHMENT_RENDERBUFFER) Then
            	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, texId)
            EndIf  
        case RL_ATTACHMENT_STENCIL:
            if (texType = RL_ATTACHMENT_TEXTURE2D) Then
            	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_TEXTURE_2D, texId, 0)
            elseif (texType = RL_ATTACHMENT_RENDERBUFFER) Then
            	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, texId)
				EndIf  
        case Else:  
    End Select

    glBindFramebuffer(GL_FRAMEBUFFER, 0)
#endif
End Sub

'' Verify render texture is complete
Function rlFramebufferComplete(id as ULong) As boolean
    Dim As boolean result = FALSE

#if (defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)) AndAlso defined(SUPPORT_RENDER_TEXTURES_HINT)
    glBindFramebuffer(GL_FRAMEBUFFER, id)

    Dim As GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER)

    if (status <> GL_FRAMEBUFFER_COMPLETE) Then
        Select Case (status)
        	case GL_FRAMEBUFFER_UNSUPPORTED:
        		TRACELOG(LOG_WARNING, "FBO: [ID %i] Framebuffer is unsupported", id)  
        	case GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT: 
        		TRACELOG(LOG_WARNING, "FBO: [ID %i] Framebuffer has incomplete attachment", id)  
#if defined(GRAPHICS_API_OPENGL_ES2)
        	case GL_FRAMEBUFFER_INCOMPLETE_DIMENSIONS:
        		TRACELOG(LOG_WARNING, "FBO: [ID %i] Framebuffer has incomplete dimensions", id)  
#endif
        	case GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT:
        		TRACELOG(LOG_WARNING, "FBO: [ID %i] Framebuffer has a missing attachment", id)  
        	Case Else:  
        End Select
    EndIf

    glBindFramebuffer(GL_FRAMEBUFFER, 0)

    result = iif(status = GL_FRAMEBUFFER_COMPLETE,1,0)
#endif

    return result
End Function

'' Generate mipmap data for selected texture
Sub rlGenerateMipmaps(texture as Texture2D Ptr)
    glBindTexture(GL_TEXTURE_2D, texture->id)

    '' Check if texture is power-of-two (POT)
    Dim As boolean texIsPOT = FALSE

    if (((texture->width > 0) AndAlso ((texture->width And (texture->width - 1)) = 0)) AndAlso
        ((texture->height > 0) AndAlso ((texture->height and (texture->height - 1)) = 0))) Then texIsPOT = TRUE

#if defined(GRAPHICS_API_OPENGL_11)
    if (texIsPOT) Then
        '' WARNING: Manual mipmap generation only works for RGBA 32bit textures!
        if (texture->format = UNCOMPRESSED_R8G8B8A8) then
            '' Retrieve texture data from VRAM
            Dim As Any Ptr Data = rlReadTexturePixels(*texture)

            '' NOTE: data size is reallocated to fit mipmaps data
            '' NOTE: CPU mipmap generation only supports RGBA 32bit data
            Dim mipmapCount as Long = GenerateMipmaps(data, texture->width, texture->height)

            Dim size as Long = texture->width*texture->height*4
            Dim As long offset = size

            Dim As long mipWidth = texture->width/2
            Dim As long mipHeight = texture->height/2

            '' Load the mipmaps
            for level As ULong = 1 to mipmapCount-1
                glTexImage2D(GL_TEXTURE_2D, level, GL_RGBA8, mipWidth, mipHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, Data + offset)

                size = mipWidth*mipHeight*4
                offset += size

                mipWidth /= 2
                mipHeight /= 2
            Next

            texture->mipmaps = mipmapCount + 1
            RL_FREE(data) '' Once mipmaps have been generated and data has been uploaded to GPU VRAM, we can discard RAM data

            TRACELOG(LOG_WARNING, "TEXTURE: [ID %i] Mipmaps generated manually on CPU side, total: %i", texture->id, texture->mipmaps)
        else 
        TRACELOG(LOG_WARNING, "TEXTURE: [ID %i] Failed to generate mipmaps for provided texture format", texture->id)
        EndIf
#ElseIf defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    if ((texIsPOT) OrElse (RLGL.ExtSupported.texNPOT)) Then
        ''glHint(GL_GENERATE_MIPMAP_HINT, GL_DONT_CARE)   '' Hint for mipmaps generation algorythm: GL_FASTEST, GL_NICEST, GL_DONT_CARE
        glGenerateMipmap(GL_TEXTURE_2D)    '' Generate mipmaps automatically

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR)   '' Activate Trilinear filtering for mipmaps

        #define MIN(a,b) IIf(((a)<(b)),(a),(b))
        #define MAX(a,b) IIf(((a)>(b)),(a),(b))

        texture->mipmaps =  1 + (int)floor(log(MAX(texture->width, texture->height))/log(2))
        TRACELOG(LOG_INFO, "TEXTURE: [ID %i] Mipmaps generated automatically, total: %i", texture->id, texture->mipmaps)
#EndIf
    else 
    TRACELOG(LOG_WARNING, "TEXTURE: [ID %i] Failed to generate mipmaps", texture->id)
		EndIf
    glBindTexture(GL_TEXTURE_2D, 0)
End Sub

'' Upload vertex data into a VAO (if supported) and VBO
'TODO
Sub rlLoadMesh(mesh as Mesh ptr, dynamic as boolean)
    if (mesh->vaoId > 0) Then
        '' Check if mesh has already been loaded in GPU
        TRACELOG(LOG_WARNING, "VAO: [ID %i] Trying to re-load an already loaded mesh", mesh->vaoId)
        Exit Sub
    EndIf

    mesh->vaoId = 0        '' Vertex Array Object
    mesh->vboId[0] = 0     '' Vertex positions VBO
    mesh->vboId[1] = 0     '' Vertex texcoords VBO
    mesh->vboId[2] = 0     '' Vertex normals VBO
    mesh->vboId[3] = 0     '' Vertex colors VBO
    mesh->vboId[4] = 0     '' Vertex tangents VBO
    mesh->vboId[5] = 0     '' Vertex texcoords2 VBO
    mesh->vboId[6] = 0     '' Vertex indices VBO

#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    Dim As Long drawHint = GL_STATIC_DRAW
    if (dynamic) Then drawHint = GL_DYNAMIC_DRAW

    if (RLGL.ExtSupported.vao) Then
        '' Initialize Quads VAO (Buffer A)
        glGenVertexArrays(1, &mesh->vaoId)
        glBindVertexArray(mesh->vaoId)
    EndIf

    '' NOTE: Attributes must be uploaded considering default locations points

    '' Enable vertex attributes: position (shader-location = 0)
    glGenBuffers(1, @mesh->vboId[0])
    glBindBuffer(GL_ARRAY_BUFFER, mesh->vboId[0])
    glBufferData(GL_ARRAY_BUFFER, mesh->vertexCount*3*sizeof(Single), mesh->vertices, drawHint)
    glVertexAttribPointer(0, 3, GL_FLOAT, 0, 0, 0)
    glEnableVertexAttribArray(0)

    '' Enable vertex attributes: texcoords (shader-location = 1)
    glGenBuffers(1, @mesh->vboId[1])
    glBindBuffer(GL_ARRAY_BUFFER, mesh->vboId[1])
    glBufferData(GL_ARRAY_BUFFER, mesh->vertexCount*2*sizeof(Single), mesh->texcoords, drawHint)
    glVertexAttribPointer(1, 2, GL_FLOAT, 0, 0, 0)
    glEnableVertexAttribArray(1)

    '' Enable vertex attributes: normals (shader-location = 2)
    if (mesh->normals <> NULL) Then
        glGenBuffers(1, @mesh->vboId[2])
        glBindBuffer(GL_ARRAY_BUFFER, mesh->vboId[2])
        glBufferData(GL_ARRAY_BUFFER, mesh->vertexCount*3*sizeof(Single), mesh->normals, drawHint)
        glVertexAttribPointer(2, 3, GL_FLOAT, 0, 0, 0)
        glEnableVertexAttribArray(2)
    Else
        '' Default color vertex attribute set to WHITE
        glVertexAttrib3f(2, 1.0f, 1.0f, 1.0f)
        glDisableVertexAttribArray(2)
    EndIf

    '' Default color vertex attribute (shader-location = 3)
    if (mesh->colors <> NULL) Then
        glGenBuffers(1, @mesh->vboId[3])
        glBindBuffer(GL_ARRAY_BUFFER, mesh->vboId[3])
        glBufferData(GL_ARRAY_BUFFER, mesh->vertexCount*4*sizeof(unsigned char), mesh->colors, drawHint)
        glVertexAttribPointer(3, 4, GL_UNSIGNED_BYTE, GL_TRUE, 0, 0)
        glEnableVertexAttribArray(3)
    Else
        '' Default color vertex attribute set to WHITE
        glVertexAttrib4f(3, 1.0f, 1.0f, 1.0f, 1.0f)
        glDisableVertexAttribArray(3)
    EndIf

    '' Default tangent vertex attribute (shader-location = 4)
    if (mesh->tangents <> NULL) Then
        glGenBuffers(1, @mesh->vboId[4])
        glBindBuffer(GL_ARRAY_BUFFER, mesh->vboId[4])
        glBufferData(GL_ARRAY_BUFFER, mesh->vertexCount*4*sizeof(Single), mesh->tangents, drawHint)
        glVertexAttribPointer(4, 4, GL_FLOAT, 0, 0, 0)
        glEnableVertexAttribArray(4)
    Else
        '' Default tangents vertex attribute
        glVertexAttrib4f(4, 0.0f, 0.0f, 0.0f, 0.0f)
        glDisableVertexAttribArray(4)
    EndIf

    '' Default texcoord2 vertex attribute (shader-location = 5)
    if (mesh->texcoords2 <> NULL) Then
        glGenBuffers(1, @mesh->vboId[5])
        glBindBuffer(GL_ARRAY_BUFFER, mesh->vboId[5])
        glBufferData(GL_ARRAY_BUFFER, mesh->vertexCount*2*sizeof(Single), mesh->texcoords2, drawHint)
        glVertexAttribPointer(5, 2, GL_FLOAT, 0, 0, 0)
        glEnableVertexAttribArray(5)
    Else
        '' Default texcoord2 vertex attribute
        glVertexAttrib2f(5, 0.0f, 0.0f)
        glDisableVertexAttribArray(5)
    EndIf

    if (mesh->indices <> NULL) Then
        glGenBuffers(1, @mesh->vboId[6])
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh->vboId[6])
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, mesh->triangleCount*3*sizeof(unsigned short), mesh->indices, drawHint)
    EndIf

    if (RLGL.ExtSupported.vao) Then
        if (mesh->vaoId > 0) Then
        	TRACELOG(LOG_INFO, "VAO: [ID %i] Mesh uploaded successfully to VRAM (GPU)", mesh->vaoId)
        else 
   	 	TRACELOG(LOG_WARNING, "VAO: Failed to load mesh to VRAM (GPU)")
        EndIf
    Else
        TRACELOG(LOG_INFO, "VBO: Mesh uploaded successfully to VRAM (GPU)")
    EndIf 
#endif
End Sub

'' Load a new attributes buffer
function rlLoadAttribBuffer(vaoId as ulong, shaderLoc as Long, Sub *buffer, size as Long, dynamic as boolean) ULong
    Dim id as ulong = 0

#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    Dim As Long drawHint = GL_STATIC_DRAW
    if (dynamic) Then drawHint = GL_DYNAMIC_DRAW

    if (RLGL.ExtSupported.vao) Then glBindVertexArray(vaoId)

    glGenBuffers(1, @id)
    glBindBuffer(GL_ARRAY_BUFFER, id)
    glBufferData(GL_ARRAY_BUFFER, size, buffer, drawHint)
    glVertexAttribPointer(shaderLoc, 2, GL_FLOAT, 0, 0, 0)
    glEnableVertexAttribArray(shaderLoc)

    if (RLGL.ExtSupported.vao) Then glBindVertexArray(0)
#endif

    return id
End Function

'' Update vertex or index data on GPU (upload new data to one buffer)
Sub rlUpdateMesh(mesh as Mesh, buffer as Long, count as Long)
    rlUpdateMeshAt(mesh, buffer, count, 0)
End Sub

'' Update vertex or index data on GPU, at index
'' WARNING: error checking is in place that will cause the data to not be
''          updated if offset + size exceeds what the buffer can hold
Sub rlUpdateMeshAt(mesh as Mesh, buffer as Long, count as Long, index as Long)
#If defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    '' Activate mesh VAO
    if (RLGL.ExtSupported.vao) glBindVertexArray(mesh.vaoId)

    Select Case (buffer)
    	case 0     '' Update vertices (vertex position)
            glBindBuffer(GL_ARRAY_BUFFER, mesh.vboId[0])
            if (index = 0 andalso count >= mesh.vertexCount) Then
            	glBufferData(GL_ARRAY_BUFFER, count*3*sizeof(Single), mesh.vertices, GL_DYNAMIC_DRAW)
            elseif (index + count >= mesh.vertexCount) Then
            else 
            	glBufferSubData(GL_ARRAY_BUFFER, index*3*sizeof(single), count*3*sizeof(Single), mesh.vertices)
            EndIf

    	case 1     '' Update texcoords (vertex texture coordinates)
            glBindBuffer(GL_ARRAY_BUFFER, mesh.vboId[1])
            if (index = 0 andalso count >= mesh.vertexCount) Then
            	glBufferData(GL_ARRAY_BUFFER, count*2*sizeof(Single), mesh.texcoords, GL_DYNAMIC_DRAW)
            elseif (index + count >= mesh.vertexCount) Then  
            else 
            	glBufferSubData(GL_ARRAY_BUFFER, index*2*sizeof(single), count*2*sizeof(Single), mesh.texcoords)
            EndIf

    	case 2     '' Update normals (vertex normals)
            glBindBuffer(GL_ARRAY_BUFFER, mesh.vboId[2])
            if (index = 0 andalso count >= mesh.vertexCount) Then
            	glBufferData(GL_ARRAY_BUFFER, count*3*sizeof(Single), mesh.normals, GL_DYNAMIC_DRAW)
            elseif (index + count >= mesh.vertexCount) Then
            else 
            	glBufferSubData(GL_ARRAY_BUFFER, index*3*sizeof(single), count*3*sizeof(Single), mesh.normals)
            EndIf

    	case 3     '' Update colors (vertex colors)
            glBindBuffer(GL_ARRAY_BUFFER, mesh.vboId[3])
            if (index = 0 andalso count >= mesh.vertexCount) Then
             glBufferData(GL_ARRAY_BUFFER, count*4*sizeof(unsigned char), mesh.colors, GL_DYNAMIC_DRAW)
            elseif (index + count >= mesh.vertexCount) Then  
            else 
            glBufferSubData(GL_ARRAY_BUFFER, index*4*sizeof(unsigned char), count*4*sizeof(unsigned char), mesh.colors)
            EndIf

    	case 4     '' Update tangents (vertex tangents)
            glBindBuffer(GL_ARRAY_BUFFER, mesh.vboId[4])
            if (index = 0 andalso count >= mesh.vertexCount) Then
            	glBufferData(GL_ARRAY_BUFFER, count*4*sizeof(Single), mesh.tangents, GL_DYNAMIC_DRAW)
            elseif (index + count >= mesh.vertexCount) Then  
            else 
            	glBufferSubData(GL_ARRAY_BUFFER, index*4*sizeof(single), count*4*sizeof(Single), mesh.tangents)
            EndIf

    	case 5     '' Update texcoords2 (vertex second texture coordinates)
            glBindBuffer(GL_ARRAY_BUFFER, mesh.vboId[5])
            if (index = 0 andalso count >= mesh.vertexCount) Then
            	glBufferData(GL_ARRAY_BUFFER, count*2*sizeof(Single), mesh.texcoords2, GL_DYNAMIC_DRAW)
            elseif (index + count >= mesh.vertexCount) Then  
            else 
            	glBufferSubData(GL_ARRAY_BUFFER, index*2*sizeof(single), count*2*sizeof(Single), mesh.texcoords2)
            EndIf

    	case 6     '' Update indices (triangle index buffer)
            '' the * 3 is because each triangle has 3 indices
            Dim As ushort Ptr indices = mesh.indices
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.vboId[6])

            if (index = 0 andalso count >= mesh.triangleCount) Then
            	glBufferData(GL_ELEMENT_ARRAY_BUFFER, count*3*sizeof(*indices), indices, GL_DYNAMIC_DRAW)
            elseif (index + count >= mesh.triangleCount) Then 
            else 
            	glBufferSubData(GL_ELEMENT_ARRAY_BUFFER, index*3*sizeof(*indices), count*3*sizeof(*indices), indices)
            EndIf

    	case Else:  
    End Select

    '' Unbind the current VAO
    if (RLGL.ExtSupported.vao) Then glBindVertexArray(0)

    '' Another option would be using buffer mapping...
    ''mesh.vertices = glMapBuffer(GL_ARRAY_BUFFER, GL_READ_WRITE)
    '' Now we can modify vertices
    ''glUnmapBuffer(GL_ARRAY_BUFFER)
#endif
End Sub

'' Draw a 3d mesh with material and transform
Sub rlDrawMesh(mesh as Mesh, material as Material, transform as Matrix)
#If defined(GRAPHICS_API_OPENGL_11)
    glEnable(GL_TEXTURE_2D)
    glBindTexture(GL_TEXTURE_2D, material.maps[MAP_DIFFUSE].texture.id)

    '' NOTE: On OpenGL 1.1 we use Vertex Arrays to draw model
    glEnableClientState(GL_VERTEX_ARRAY)                   '' Enable vertex array
    glEnableClientState(GL_TEXTURE_COORD_ARRAY)            '' Enable texture coords array
    if (mesh.normals <> NULL) Then glEnableClientState(GL_NORMAL_ARRAY)     '' Enable normals array
    if (mesh.colors <> NULL) Then glEnableClientState(GL_COLOR_ARRAY)       '' Enable colors array

    glVertexPointer(3, GL_FLOAT, 0, mesh.vertices)         '' Pointer to vertex coords array
    glTexCoordPointer(2, GL_FLOAT, 0, mesh.texcoords)      '' Pointer to texture coords array
    if (mesh.normals <> NULL) Then glNormalPointer(GL_FLOAT, 0, mesh.normals)           '' Pointer to normals array
    if (mesh.colors <> NULL) Then glColorPointer(4, GL_UNSIGNED_BYTE, 0, mesh.colors)   '' Pointer to colors array

    rlPushMatrix()
        rlMultMatrixf(MatrixToFloat(transform))
        rlColor4ub(material.maps[MAP_DIFFUSE].color.r, material.maps[MAP_DIFFUSE].color.g, material.maps[MAP_DIFFUSE].color.b, material.maps[MAP_DIFFUSE].color.a)

        if (mesh.indices <> NULL) Then
        	glDrawElements(GL_TRIANGLES, mesh.triangleCount*3, GL_UNSIGNED_SHORT, mesh.indices)
        else 
        glDrawArrays(GL_TRIANGLES, 0, mesh.vertexCount)
        EndIf
    rlPopMatrix()

    glDisableClientState(GL_VERTEX_ARRAY)                  '' Disable vertex array
    glDisableClientState(GL_TEXTURE_COORD_ARRAY)           '' Disable texture coords array
    if (mesh.normals <> NULL) Then glDisableClientState(GL_NORMAL_ARRAY)    '' Disable normals array
    if (mesh.colors <> NULL) Then glDisableClientState(GL_NORMAL_ARRAY)     '' Disable colors array

    glDisable(GL_TEXTURE_2D)
    glBindTexture(GL_TEXTURE_2D, 0)
#endif

#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    '' Bind shader program
    glUseProgram(material.shader.id)

    '' Matrices and other values required by shader
    ''-----------------------------------------------------
    '' Calculate and send to shader model matrix (used by PBR shader)
    if (material.shader.locs(LOC_MATRIX_MODEL) <> -1) Then SetShaderValueMatrix(material.shader, material.shader.locs(LOC_MATRIX_MODEL), transform)

    '' Upload to shader material.colDiffuse
    if (material.shader.locs(LOC_COLOR_DIFFUSE) <> -1) Then
        glUniform4f(material.shader.locs(LOC_COLOR_DIFFUSE), material.maps(MAP_DIFFUSE).color.r/255.0f,
                                                           material.maps(MAP_DIFFUSE).color.g/255.0f,
                                                           material.maps(MAP_DIFFUSE).color.b/255.0f,
                                                           material.maps(MAP_DIFFUSE).color.a/255.0f)
    EndIf
    '' Upload to shader material.colSpecular (if available)
    if (material.shader.locs(LOC_COLOR_SPECULAR) <> -1) Then
        glUniform4f(material.shader.locs[LOC_COLOR_SPECULAR], material.maps(MAP_SPECULAR).color.r/255.0f,
                                                               material.maps(MAP_SPECULAR).color.g/255.0f,
                                                               material.maps(MAP_SPECULAR).color.b/255.0f,
                                                               material.maps(MAP_SPECULAR).color.a/255.0f)
    EndIf
    if (material.shader.locs(LOC_MATRIX_VIEW) <> -1) Then SetShaderValueMatrix(material.shader, material.shader.locs(LOC_MATRIX_VIEW), RLGL.State.modelview)
    if (material.shader.locs(LOC_MATRIX_PROJECTION) <> -1) Then SetShaderValueMatrix(material.shader, material.shader.locs(LOC_MATRIX_PROJECTION), RLGL.State.projection)

    '' At this point the modelview matrix just contains the view matrix (camera)
    '' That's because BeginMode3D() sets it an no model-drawing function modifies it, all use rlPushMatrix() and rlPopMatrix()
    Dim As Matrix matView = RLGL.State.modelview         '' View matrix (camera)
    Dim As Matrix matProjection = RLGL.State.projection  '' Projection matrix (perspective)

    '' TODO: Consider possible transform matrices in the RLGL.State.stack
    '' Is this the right order? or should we start with the first stored matrix instead of the last one?
    ''Matrix matStackTransform = MatrixIdentity()
    ''for (int i = RLGL.State.stackCounter i > 0 i--) matStackTransform = MatrixMultiply(RLGL.State.stack[i], matStackTransform)

    '' Transform to camera-space coordinates
    Dim As Matrix matModelView = MatrixMultiply(transform, MatrixMultiply(RLGL.State.transform, matView))
    ''-----------------------------------------------------

    '' Bind active texture maps (if available)
    for i As long= 0 to MAX_MATERIAL_MAPS-1
        if (material.maps(i).texture.id > 0)
            glActiveTexture(GL_TEXTURE0 + i)
            if ((i = MAP_IRRADIANCE) orelse (i = MAP_PREFILTER) OrElse (i = MAP_CUBEMAP)) Then
            	glBindTexture(GL_TEXTURE_CUBE_MAP, material.maps(i).texture.id)
            else 
            glBindTexture(GL_TEXTURE_2D, material.maps(i).texture.id)
				EndIf
            glUniform1i(material.shader.locs(LOC_MAP_DIFFUSE + i), i)
        EndIf
    Next

    '' Bind vertex array objects (or VBOs)
    if (RLGL.ExtSupported.vao) Then
    	glBindVertexArray(mesh.vaoId)
    else
        '' Bind mesh VBO data: vertex position (shader-location = 0)
        glBindBuffer(GL_ARRAY_BUFFER, mesh.vboId(0))
        glVertexAttribPointer(material.shader.locs(LOC_VERTEX_POSITION), 3, GL_FLOAT, 0, 0, 0)
        glEnableVertexAttribArray(material.shader.locs(LOC_VERTEX_POSITION))

        '' Bind mesh VBO data: vertex texcoords (shader-location = 1)
        glBindBuffer(GL_ARRAY_BUFFER, mesh.vboId(1))
        glVertexAttribPointer(material.shader.locs(LOC_VERTEX_TEXCOORD01), 2, GL_FLOAT, 0, 0, 0)
        glEnableVertexAttribArray(material.shader.locs(LOC_VERTEX_TEXCOORD01))

        '' Bind mesh VBO data: vertex normals (shader-location = 2, if available)
        if (material.shader.locs(LOC_VERTEX_NORMAL) <> -1) then
            glBindBuffer(GL_ARRAY_BUFFER, mesh.vboId(2))
            glVertexAttribPointer(material.shader.locs(LOC_VERTEX_NORMAL), 3, GL_FLOAT, 0, 0, 0)
            glEnableVertexAttribArray(material.shader.locs(LOC_VERTEX_NORMAL))
        EndIf

        '' Bind mesh VBO data: vertex colors (shader-location = 3, if available)
        if (material.shader.locs(LOC_VERTEX_COLOR) <> -1) then
            if (mesh.vboId(3) <> 0) Then
                glBindBuffer(GL_ARRAY_BUFFER, mesh.vboId(3))
                glVertexAttribPointer(material.shader.locs(LOC_VERTEX_COLOR), 4, GL_UNSIGNED_BYTE, GL_TRUE, 0, 0)
                glEnableVertexAttribArray(material.shader.locs(LOC_VERTEX_COLOR))
            Else
                '' Set default value for unused attribute
                '' NOTE: Required when using default shader and no VAO support
                glVertexAttrib4f(material.shader.locs(LOC_VERTEX_COLOR), 1.0f, 1.0f, 1.0f, 1.0f)
                glDisableVertexAttribArray(material.shader.locs(LOC_VERTEX_COLOR))
            EndIf
        EndIf

        '' Bind mesh VBO data: vertex tangents (shader-location = 4, if available)
        if (material.shader.locs(LOC_VERTEX_TANGENT) <> -1) then
            glBindBuffer(GL_ARRAY_BUFFER, mesh.vboId(4))
            glVertexAttribPointer(material.shader.locs(LOC_VERTEX_TANGENT), 4, GL_FLOAT, 0, 0, 0)
            glEnableVertexAttribArray(material.shader.locs(LOC_VERTEX_TANGENT))
        EndIf

        '' Bind mesh VBO data: vertex texcoords2 (shader-location = 5, if available)
        if (material.shader.locs(LOC_VERTEX_TEXCOORD02) <> -1) then
            glBindBuffer(GL_ARRAY_BUFFER, mesh.vboId(5))
            glVertexAttribPointer(material.shader.locs(LOC_VERTEX_TEXCOORD02), 2, GL_FLOAT, 0, 0, 0)
            glEnableVertexAttribArray(material.shader.locs(LOC_VERTEX_TEXCOORD02))
        EndIf

        if (mesh.indices <> NULL) Then glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.vboId(6))
    EndIf

    Dim As Long eyesCount = 1
#if defined(SUPPORT_VR_SIMULATOR)
    if (RLGL.Vr.stereoRender) Then eyesCount = 2
#endif

    for eye As long= 0 to eyesCount-1
        if (eyesCount = 1) Then
        	RLGL.State.modelview = matModelView
        #if defined(SUPPORT_VR_SIMULATOR)
        else 
        SetStereoView(eye, matProjection, matModelView)
        #endif
        EndIf
        '' Calculate model-view-projection matrix (MVP)
        Dim As Matrix matMVP = MatrixMultiply(RLGL.State.modelview, RLGL.State.projection)        '' Transform to screen-space coordinates

        '' Send combined model-view-projection matrix to shader
        glUniformMatrix4fv(material.shader.locs(LOC_MATRIX_MVP), 1, false, MatrixToFloat(matMVP))

        '' Draw call!
        if (mesh.indices <> NULL) Then 
        	glDrawElements(GL_TRIANGLES, mesh.triangleCount*3, GL_UNSIGNED_SHORT, 0) '' Indexed vertices draw
        else 
        glDrawArrays(GL_TRIANGLES, 0, mesh.vertexCount)
			EndIf
    Next

    '' Unbind all binded texture maps
    for i As Long= 0 To MAX_MATERIAL_MAPS-1
        glActiveTexture(GL_TEXTURE0 + i)       '' Set shader active texture
        if ((i = MAP_IRRADIANCE) orelse (i = MAP_PREFILTER) OrElse (i = MAP_CUBEMAP)) Then
        	glBindTexture(GL_TEXTURE_CUBE_MAP, 0)
        else 
        glBindTexture(GL_TEXTURE_2D, 0)   '' Unbind current active texture
    		EndIf
    Next

    '' Unind vertex array objects (or VBOs)
    if (RLGL.ExtSupported.vao) Then 
    	glBindVertexArray(0)
    Else
        glBindBuffer(GL_ARRAY_BUFFER, 0)
        if (mesh.indices <> NULL) glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0)
    EndIf

    '' Unbind shader program
    glUseProgram(0)

    '' Restore RLGL.State.projection/RLGL.State.modelview matrices
    '' NOTE: In stereo rendering matrices are being modified to fit every eye
    RLGL.State.projection = matProjection
    RLGL.State.modelview = matView
#endif
End Sub

'' Draw a 3d mesh with material and transform
Sub rlDrawMeshInstanced(mesh as Mesh, material as Material, transform as Matrix ptr, count as Long)
{
#if defined(GRAPHICS_API_OPENGL_33)
    '' Bind shader program
    glUseProgram(material.shader.id)

    '' Upload to shader material.colDiffuse
    if (material.shader.locs[LOC_COLOR_DIFFUSE] <> -1)
        glUniform4f(material.shader.locs[LOC_COLOR_DIFFUSE], (Single)material.maps[MAP_DIFFUSE].color.r/255.0f,
                                                           (Single)material.maps[MAP_DIFFUSE].color.g/255.0f,
                                                           (Single)material.maps[MAP_DIFFUSE].color.b/255.0f,
                                                           (Single)material.maps[MAP_DIFFUSE].color.a/255.0f)

    '' Upload to shader material.colSpecular (if available)
    if (material.shader.locs[LOC_COLOR_SPECULAR] <> -1)
        glUniform4f(material.shader.locs[LOC_COLOR_SPECULAR], (Single)material.maps[MAP_SPECULAR].color.r/255.0f,
                                                               (Single)material.maps[MAP_SPECULAR].color.g/255.0f,
                                                               (Single)material.maps[MAP_SPECULAR].color.b/255.0f,
                                                               (Single)material.maps[MAP_SPECULAR].color.a/255.0f)

    '' Bind active texture maps (if available)
    for (int i = 0 i < MAX_MATERIAL_MAPS i++)
    {
        if (material.maps[i].texture.id > 0)
        {
            glActiveTexture(GL_TEXTURE0 + i)
            if ((i == MAP_IRRADIANCE) orelse (i == MAP_PREFILTER) OrElse (i == MAP_CUBEMAP))
                glBindTexture(GL_TEXTURE_CUBE_MAP, material.maps[i].texture.id)
            else glBindTexture(GL_TEXTURE_2D, material.maps[i].texture.id)

            glUniform1i(material.shader.locs[LOC_MAP_DIFFUSE + i], i)
        }
    }

    '' Bind vertex array objects (or VBOs)
    glBindVertexArray(mesh.vaoId)

    '' At this point the modelview matrix just contains the view matrix (camera)
    '' For instanced shaders "mvp" is not premultiplied by any instance transform, only RLGL.State.transform
    glUniformMatrix4fv(material.shader.locs[LOC_MATRIX_MVP], 1, false,
                       MatrixToFloat(MatrixMultiply(MatrixMultiply(RLGL.State.transform, RLGL.State.modelview), RLGL.State.projection)))

    float16* instances = RL_MALLOC(count*sizeof(float16))

    for (int i = 0 i < count i++) instances[i] = MatrixToFloatV(transforms[i])

    '' This could alternatively use a static VBO and either glMapBuffer or glBufferSubData.
    '' It isn't clear which would be reliably faster in all cases and on all platforms, and
    '' anecdotally glMapBuffer seems very slow (syncs) while glBufferSubData seems no faster
    '' since we're transferring all the transform matrices anyway.
    unsigned int instancesB = 0
    glGenBuffers(1, &instancesB)
    glBindBuffer(GL_ARRAY_BUFFER, instancesB)
    glBufferData(GL_ARRAY_BUFFER, count*sizeof(float16), instances, GL_STATIC_DRAW)

    '' Instances are put in LOC_MATRIX_MODEL attribute location with space for 4x Vector4, eg:
    '' layout (location = 12) in mat4 instance
    unsigned int instanceA = material.shader.locs[LOC_MATRIX_MODEL]

    for (unsigned int i = 0 i < 4 i++)
    {
        glEnableVertexAttribArray(instanceA+i)
        glVertexAttribPointer(instanceA + i, 4, GL_FLOAT, GL_FALSE, sizeof(Matrix), (Sub *)(i*sizeof(Vector4)))
        glVertexAttribDivisor(instanceA + i, 1)
    }

    glBindBuffer(GL_ARRAY_BUFFER, 0)

    '' Draw call!
    if (mesh.indices <> NULL) glDrawElementsInstanced(GL_TRIANGLES, mesh.triangleCount*3, GL_UNSIGNED_SHORT, 0, count)
    else glDrawArraysInstanced(GL_TRIANGLES, 0, mesh.vertexCount, count)

    glDeleteBuffers(1, &instancesB)
    RL_FREE(instances)

    '' Unbind all binded texture maps
    for (int i = 0 i < MAX_MATERIAL_MAPS i++)
    {
        glActiveTexture(GL_TEXTURE0 + i)       '' Set shader active texture
        if ((i == MAP_IRRADIANCE) orelse (i == MAP_PREFILTER) OrElse (i == MAP_CUBEMAP)) glBindTexture(GL_TEXTURE_CUBE_MAP, 0)
        else glBindTexture(GL_TEXTURE_2D, 0)   '' Unbind current active texture
    }

    '' Unind vertex array objects (or VBOs)
    glBindVertexArray(0)

    '' Unbind shader program
    glUseProgram(0)

#else
    TRACELOG(LOG_ERROR, "VAO: Instanced rendering requires GRAPHICS_API_OPENGL_33")
#endif
}

'' Unload mesh data from CPU and GPU
Sub rlUnloadMesh(mesh as Mesh)
{
    RL_FREE(mesh.vertices)
    RL_FREE(mesh.texcoords)
    RL_FREE(mesh.normals)
    RL_FREE(mesh.colors)
    RL_FREE(mesh.tangents)
    RL_FREE(mesh.texcoords2)
    RL_FREE(mesh.indices)

    RL_FREE(mesh.animVertices)
    RL_FREE(mesh.animNormals)
    RL_FREE(mesh.boneWeights)
    RL_FREE(mesh.boneIds)

#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    for (int i = 0 i < 7 i++) glDeleteBuffers(1, &mesh.vboId[i]) '' DEFAULT_MESH_VERTEX_BUFFERS (model.c)
    if (RLGL.ExtSupported.vao)
    {
        glBindVertexArray(0)
        glDeleteVertexArrays(1, &mesh.vaoId)
        TRACELOG(LOG_INFO, "VAO: [ID %i] Unloaded vertex data from VRAM (GPU)", mesh.vaoId)
    }
    else TRACELOG(LOG_INFO, "VBO: Unloaded vertex data from VRAM (GPU)")
#endif
}

'' Read screen pixel data (color buffer)
unsigned char *rlReadScreenPixels(width as Long, height as Long)
{
    unsigned char *screenData = (unsigned char *)RL_CALLOC(width*height*4, sizeof(unsigned char))

    '' NOTE 1: glReadPixels returns image flipped vertically -> (0,0) is the bottom left corner of the framebuffer
    '' NOTE 2: We are getting alpha channel! Be careful, it can be transparent if not cleared properly!
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, screenData)

    '' Flip image vertically!
    unsigned char *imgData = (unsigned char *)RL_MALLOC(width*height*4*sizeof(unsigned char))

    for (y as Long = height - 1 y >= 0 y--)
    {
        for (x as Long = 0 x < (width*4) x++)
        {
            imgData[((height - 1) - y)*width*4 + x] = screenData[(y*width*4) + x]  '' Flip line

            '' Set alpha component value to 255 (no trasparent image retrieval)
            '' NOTE: Alpha value has already been applied to RGB in framebuffer, we don't need it!
            if (((x + 1)%4) == 0) imgData[((height - 1) - y)*width*4 + x] = 255
        }
    }

    RL_FREE(screenData)

    return imgData     '' NOTE: image data should be freed
}

'' Read texture pixel data
Sub *rlReadTexturePixels(texture as Texture2D)
{
    Sub *pixels = NULL

#if defined(GRAPHICS_API_OPENGL_11) OrElse defined(GRAPHICS_API_OPENGL_33)
    glBindTexture(GL_TEXTURE_2D, texture.id)

    '' NOTE: Using texture.id, we can retrieve some texture info (but not on OpenGL ES 2.0)
    '' Possible texture info: GL_TEXTURE_RED_SIZE, GL_TEXTURE_GREEN_SIZE, GL_TEXTURE_BLUE_SIZE, GL_TEXTURE_ALPHA_SIZE
    ''width as long, height, format
    ''glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_WIDTH, &width)
    ''glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_HEIGHT, &height)
    ''glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_INTERNAL_FORMAT, &format)

    '' NOTE: Each row written to or read from by OpenGL pixel operations like glGetTexImage are aligned to a 4 byte boundary by default, which may add some padding.
    '' Use glPixelStorei to modify padding with the GL_[UN]PACK_ALIGNMENT setting.
    '' GL_PACK_ALIGNMENT affects operations that read from OpenGL memory (glReadPixels, glGetTexImage, etc.)
    '' GL_UNPACK_ALIGNMENT affects operations that write to OpenGL memory (glTexImage, etc.)
    glPixelStorei(GL_PACK_ALIGNMENT, 1)

    unsigned int glInternalFormat, glFormat, glType
    rlGetGlTextureFormats(texture.format, &glInternalFormat, &glFormat, &glType)
    unsigned size as Long = GetPixelDataSize(texture.width, texture.height, texture.format)

    if ((glInternalFormat <> -1) && (texture.format < COMPRESSED_DXT1_RGB))
    {
        pixels = RL_MALLOC(size)
        glGetTexImage(GL_TEXTURE_2D, 0, glFormat, glType, pixels)
    }
    else TRACELOG(LOG_WARNING, "TEXTURE: [ID %i] Data retrieval not suported for pixel format (%i)", texture.id, texture.format)

    glBindTexture(GL_TEXTURE_2D, 0)
#endif

#if defined(GRAPHICS_API_OPENGL_ES2)
    '' glGetTexImage() is not available on OpenGL ES 2.0
    '' Texture2D width and height are required on OpenGL ES 2.0. There is no way to get it from texture id.
    '' Two possible Options:
    '' 1 - Bind texture to color fbo attachment and glReadPixels()
    '' 2 - Create an fbo, activate it, render quad with texture, glReadPixels()
    '' We are using Option 1, just need to care for texture format on retrieval
    '' NOTE: This behaviour could be conditioned by graphic driver...
    fboId as ulong = rlLoadFramebuffer(texture.width, texture.height)

    '' TODO: Create depth texture/renderbuffer for fbo?

    glBindFramebuffer(GL_FRAMEBUFFER, fboId)
    glBindTexture(GL_TEXTURE_2D, 0)

    '' Attach our texture to FBO
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture.id, 0)

    '' We read data as RGBA because FBO texture is configured as RGBA, despite binding another texture format
    pixels = (unsigned char *)RL_MALLOC(GetPixelDataSize(texture.width, texture.height, UNCOMPRESSED_R8G8B8A8))
    glReadPixels(0, 0, texture.width, texture.height, GL_RGBA, GL_UNSIGNED_BYTE, pixels)

    glBindFramebuffer(GL_FRAMEBUFFER, 0)

    '' Clean up temporal fbo
    rlUnloadFramebuffer(fboId)
#endif

    return pixels
}

''----------------------------------------------------------------------------------
'' Module Functions Definition - Shaders Functions
'' NOTE: Those functions are exposed directly to the user in raylib.h
''----------------------------------------------------------------------------------

'' Get default internal texture (white texture)
Texture2D GetTextureDefault()
{
    texture as Texture2D = { 0 }
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    texture.id = RLGL.State.defaultTextureId
    texture.width = 1
    texture.height = 1
    texture.mipmaps = 1
    texture.format = UNCOMPRESSED_R8G8B8A8
#endif
    return texture
}

'' Get texture to draw shapes (RAII)
Texture2D GetShapesTexture()
{
#if defined(GRAPHICS_API_OPENGL_11)
    texture as Texture2D = { 0 }
    return texture
#else
    return RLGL.State.shapesTexture
#endif
}

'' Get texture rectangle to draw shapes
Rectangle GetShapesTextureRec()
{
#if defined(GRAPHICS_API_OPENGL_11)
    Rectangle rec = { 0 }
    return rec
#else
    return RLGL.State.shapesTextureRec
#endif
}

'' Define default texture used to draw shapes
Sub SetShapesTexture(texture as Texture2D, Rectangle source)
{
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    RLGL.State.shapesTexture = texture
    RLGL.State.shapesTextureRec = source
#endif
}

'' Get default shader
Shader GetShaderDefault()
{
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    return RLGL.State.defaultShader
#else
    Shader shader = { 0 }
    return shader
#endif
}

'' Load shader from files and bind default locations
'' NOTE: If shader string is NULL, using default vertex/fragment shaders
Shader LoadShader(const char *vsFileName, const char *fsFileName)
{
    Shader shader = { 0 }

    '' NOTE: Shader.locs is allocated by LoadShaderCode()

    char *vShaderStr = NULL
    char *fShaderStr = NULL

    if (vsFileName <> NULL) vShaderStr = LoadFileText(vsFileName)
    if (fsFileName <> NULL) fShaderStr = LoadFileText(fsFileName)

    shader = LoadShaderCode(vShaderStr, fShaderStr)

    if (vShaderStr <> NULL) RL_FREE(vShaderStr)
    if (fShaderStr <> NULL) RL_FREE(fShaderStr)

    return shader
}

'' Load shader from code strings
'' NOTE: If shader string is NULL, using default vertex/fragment shaders
Shader LoadShaderCode(const char *vsCode, const char *fsCode)
{
    Shader shader = { 0 }
    shader.locs = (int *)RL_CALLOC(MAX_SHADER_LOCATIONS, sizeof(int))

    '' NOTE: All locations must be reseted to -1 (no location)
    for (int i = 0 i < MAX_SHADER_LOCATIONS i++) shader.locs[i] = -1

#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    unsigned int vertexShaderId = RLGL.State.defaultVShaderId
    unsigned int fragmentShaderId = RLGL.State.defaultFShaderId

    if (vsCode <> NULL) vertexShaderId = CompileShader(vsCode, GL_VERTEX_SHADER)
    if (fsCode <> NULL) fragmentShaderId = CompileShader(fsCode, GL_FRAGMENT_SHADER)

    if ((vertexShaderId == RLGL.State.defaultVShaderId) && (fragmentShaderId == RLGL.State.defaultFShaderId)) shader = RLGL.State.defaultShader
    else
    {
        shader.id = LoadShaderProgram(vertexShaderId, fragmentShaderId)

        if (vertexShaderId <> RLGL.State.defaultVShaderId)
        {
            '' Detach shader before deletion to make sure memory is freed
            glDetachShader(shader.id, vertexShaderId)
            glDeleteShader(vertexShaderId)
        }
        if (fragmentShaderId <> RLGL.State.defaultFShaderId)
        {
            '' Detach shader before deletion to make sure memory is freed
            glDetachShader(shader.id, fragmentShaderId)
            glDeleteShader(fragmentShaderId)
        }

        if (shader.id == 0)
        {
            TRACELOG(LOG_WARNING, "SHADER: Failed to load custom shader code")
            shader = RLGL.State.defaultShader
        }

        '' After shader loading, we TRY to set default location names
        if (shader.id > 0) SetShaderDefaultLocations(&shader)
    }

    '' Get available shader uniforms
    '' NOTE: This information is useful for debug...
    int uniformCount = -1

    glGetProgramiv(shader.id, GL_ACTIVE_UNIFORMS, &uniformCount)

    for (int i = 0 i < uniformCount i++)
    {
        int namelen = -1
        int num = -1
        char name[256] '' Assume no variable names longer than 256
        GLenum type = GL_ZERO

        '' Get the name of the uniforms
        glGetActiveUniform(shader.id, i, sizeof(name) - 1, &namelen, &num, &type, name)

        name[namelen] = 0

        TRACELOGD("SHADER: [ID %i] Active uniform (%s) set at location: %i", shader.id, name, glGetUniformLocation(shader.id, name))
    }
#endif

    return shader
}

'' Unload shader from GPU memory (VRAM)
Sub UnloadShader(Shader shader)
{
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    if (shader.id <> RLGL.State.defaultShader.id)
    {
        glDeleteProgram(shader.id)
        RL_FREE(shader.locs)

        TRACELOG(LOG_INFO, "SHADER: [ID %i] Unloaded shader program data from VRAM (GPU)", shader.id)
    }
#endif
}

'' Begin custom shader mode
Sub BeginShaderMode(Shader shader)
{
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    if (RLGL.State.currentShader.id <> shader.id)
    {
        DrawRenderBatch(RLGL.currentBatch)
        RLGL.State.currentShader = shader
    }
#endif
}

'' End custom shader mode (returns to default shader)
sub EndShaderMode()
{
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    BeginShaderMode(RLGL.State.defaultShader)
#endif
}

'' Get shader uniform location
int GetShaderLocation(Shader shader, const char *uniformName)
{
    int location = -1
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    location = glGetUniformLocation(shader.id, uniformName)

    if (location == -1) TRACELOG(LOG_WARNING, "SHADER: [ID %i] Failed to find shader uniform: %s", shader.id, uniformName)
    else TRACELOG(LOG_INFO, "SHADER: [ID %i] Shader uniform (%s) set at location: %i", shader.id, uniformName, location)
#endif
    return location
}

'' Get shader attribute location
int GetShaderLocationAttrib(Shader shader, const char *attribName)
{
    int location = -1
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    location = glGetAttribLocation(shader.id, attribName)

    if (location == -1) TRACELOG(LOG_WARNING, "SHADER: [ID %i] Failed to find shader attribute: %s", shader.id, attribName)
    else TRACELOG(LOG_INFO, "SHADER: [ID %i] Shader attribute (%s) set at location: %i", shader.id, attribName, location)
#endif
    return location
}

'' Set shader uniform value
sub SetShaderValue(Shader shader, int uniformLoc, const Sub *value, int uniformType)
{
    SetShaderValueV(shader, uniformLoc, value, uniformType, 1)
}

'' Set shader uniform value vector
sub SetShaderValueV(Shader shader, int uniformLoc, const Sub *value, int uniformType, count as Long)
{
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    glUseProgram(shader.id)

    switch (uniformType)
    {
        case UNIFORM_FLOAT: glUniform1fv(uniformLoc, count, (Single *)value)  
        case UNIFORM_VEC2: glUniform2fv(uniformLoc, count, (Single *)value)  
        case UNIFORM_VEC3: glUniform3fv(uniformLoc, count, (Single *)value)  
        case UNIFORM_VEC4: glUniform4fv(uniformLoc, count, (Single *)value)  
        case UNIFORM_INT: glUniform1iv(uniformLoc, count, (int *)value)  
        case UNIFORM_IVEC2: glUniform2iv(uniformLoc, count, (int *)value)  
        case UNIFORM_IVEC3: glUniform3iv(uniformLoc, count, (int *)value)  
        case UNIFORM_IVEC4: glUniform4iv(uniformLoc, count, (int *)value)  
        case UNIFORM_SAMPLER2D: glUniform1iv(uniformLoc, count, (int *)value)  
        case Else: TRACELOG(LOG_WARNING, "SHADER: [ID %i] Failed to set uniform, data type not recognized", shader.id)
    }

    ''glUseProgram(0)      '' Asub reseting current shader program, in case other uniforms are set
#endif
}


'' Set shader uniform value (matrix 4x4)
Sub SetShaderValueMatrix(Shader shader, int uniformLoc, Matrix mat)
{
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    glUseProgram(shader.id)

    glUniformMatrix4fv(uniformLoc, 1, false, MatrixToFloat(mat))

    ''glUseProgram(0)
#endif
}

'' Set shader uniform value for texture
Sub SetShaderValueTexture(Shader shader, int uniformLoc, texture as Texture2D)
{
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    glUseProgram(shader.id)

    '' Check if texture is already active
    for (int i = 0 i < MAX_BATCH_ACTIVE_TEXTURES i++) if (RLGL.State.activeTextureId[i] == texture.id) Return

    '' Register a new active texture for the internal batch system
    '' NOTE: Default texture is always activated as GL_TEXTURE0
    for (int i = 0 i < MAX_BATCH_ACTIVE_TEXTURES i++)
    {
        if (RLGL.State.activeTextureId[i] == 0)
        {
            glUniform1i(uniformLoc, 1 + i)             '' Activate new texture unit
            RLGL.State.activeTextureId[i] = texture.id '' Save texture id for binding on drawing
             
        }
    }

    ''glUseProgram(0)
#endif
}

'' Set a custom projection matrix (replaces internal projection matrix)
Sub SetMatrixProjection(Matrix projection)
{
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    RLGL.State.projection = projection
#endif
}

'' Return internal projection matrix
Matrix GetMatrixProjection() {
#if defined(GRAPHICS_API_OPENGL_11)
    Single mat[16]
    glGetFloatv(GL_PROJECTION_MATRIX,mat)
    Matrix m
    m.m0  = mat[0]     m.m1  = mat[1]     m.m2  = mat[2]     m.m3  = mat[3]
    m.m4  = mat[4]     m.m5  = mat[5]     m.m6  = mat[6]     m.m7  = mat[7]
    m.m8  = mat[8]     m.m9  = mat[9]     m.m10 = mat[10]    m.m11 = mat[11]
    m.m12 = mat[12]    m.m13 = mat[13]    m.m14 = mat[14]    m.m15 = mat[15]
    return m
#else
    return RLGL.State.projection
#endif
'#
}

'' Set a custom modelview matrix (replaces internal modelview matrix)
Sub SetMatrixModelview(Matrix view)
{
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    RLGL.State.modelview = View
#endif
}

'' Return internal modelview matrix
Matrix GetMatrixModelview()
{
    Matrix matrix = MatrixIdentity()
#if defined(GRAPHICS_API_OPENGL_11)
    Single mat[16]
    glGetFloatv(GL_MODELVIEW_MATRIX, mat)
    matrix.m0  = mat[0]     matrix.m1  = mat[1]     matrix.m2  = mat[2]     matrix.m3  = mat[3]
    matrix.m4  = mat[4]     matrix.m5  = mat[5]     matrix.m6  = mat[6]     matrix.m7  = mat[7]
    matrix.m8  = mat[8]     matrix.m9  = mat[9]     matrix.m10 = mat[10]    matrix.m11 = mat[11]
    matrix.m12 = mat[12]    matrix.m13 = mat[13]    matrix.m14 = mat[14]    matrix.m15 = mat[15]
#else
    matrix = RLGL.State.modelview
#endif
    return matrix
}

'' Generate cubemap texture from HDR texture
TextureCubemap GenTextureCubemap(Shader shader, Texture2D panorama, size as Long, format as Long)
{
    TextureCubemap cubemap = { 0 }
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    rlDisableBackfaceCulling()     '' Disable backface culling to render inside the cube

    '' STEP 1: Setup framebuffer
    ''------------------------------------------------------------------------------------------
    unsigned int rbo = rlLoadTextureDepth(size, size, true)
    cubemap.id = rlLoadTextureCubemap(NULL, size, format)

    unsigned int fbo = rlLoadFramebuffer(size, size)
    rlFramebufferAttach(fbo, rbo, RL_ATTACHMENT_DEPTH, RL_ATTACHMENT_RENDERBUFFER)
    rlFramebufferAttach(fbo, cubemap.id, RL_ATTACHMENT_COLOR_CHANNEL0, RL_ATTACHMENT_CUBEMAP_POSITIVE_X)

    '' Check if framebuffer is complete with attachments (valid)
    if (rlFramebufferComplete(fbo)) TRACELOG(LOG_INFO, "FBO: [ID %i] Framebuffer object created successfully", fbo)
    ''------------------------------------------------------------------------------------------

    '' STEP 2: Draw to framebuffer
    ''------------------------------------------------------------------------------------------
    '' NOTE: Shader is used to convert HDR equirectangular environment map to cubemap equivalent (6 faces)

    '' Define projection matrix and send it to shader
    Matrix fboProjection = MatrixPerspective(90.0*DEG2RAD, 1.0, RL_CULL_DISTANCE_NEAR, RL_CULL_DISTANCE_FAR)
    SetShaderValueMatrix(shader, shader.locs[LOC_MATRIX_PROJECTION], fboProjection)

    '' Define view matrix for every side of the cubemap
    Matrix fboViews[6] = {
        MatrixLookAt((Vector3){ 0.0f, 0.0f, 0.0f }, (Vector3){  1.0f,  0.0f,  0.0f }, (Vector3){ 0.0f, -1.0f,  0.0f }),
        MatrixLookAt((Vector3){ 0.0f, 0.0f, 0.0f }, (Vector3){ -1.0f,  0.0f,  0.0f }, (Vector3){ 0.0f, -1.0f,  0.0f }),
        MatrixLookAt((Vector3){ 0.0f, 0.0f, 0.0f }, (Vector3){  0.0f,  1.0f,  0.0f }, (Vector3){ 0.0f,  0.0f,  1.0f }),
        MatrixLookAt((Vector3){ 0.0f, 0.0f, 0.0f }, (Vector3){  0.0f, -1.0f,  0.0f }, (Vector3){ 0.0f,  0.0f, -1.0f }),
        MatrixLookAt((Vector3){ 0.0f, 0.0f, 0.0f }, (Vector3){  0.0f,  0.0f,  1.0f }, (Vector3){ 0.0f, -1.0f,  0.0f }),
        MatrixLookAt((Vector3){ 0.0f, 0.0f, 0.0f }, (Vector3){  0.0f,  0.0f, -1.0f }, (Vector3){ 0.0f, -1.0f,  0.0f })
    }

    rlEnableShader(shader.id)
#if !defined(GENTEXTURECUBEMAP_USE_BATCH_SYSTEM)
    glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_2D, panorama.id)
#endif

    rlViewport(0, 0, size, size)   '' Set viewport to current fbo dimensions

    for (int i = 0 i < 6 i++)
    {
        SetShaderValueMatrix(shader, shader.locs[LOC_MATRIX_VIEW], fboViews[i])
        rlFramebufferAttach(fbo, cubemap.id, RL_ATTACHMENT_COLOR_CHANNEL0, RL_ATTACHMENT_CUBEMAP_POSITIVE_X + i)

        rlEnableFramebuffer(fbo)
#if defined(GENTEXTURECUBEMAP_USE_BATCH_SYSTEM)
        rlEnableTexture(panorama.id)   '' WARNING: It must be called after enabling current framebuffer if using internal batch system!
#endif
        rlClearScreenBuffers()
        GenDrawCube()

#if defined(GENTEXTURECUBEMAP_USE_BATCH_SYSTEM)
        '' Using internal batch system instead of raw OpenGL cube creating+drawing
        '' NOTE: DrawCubeV() is actually provided by models.c! -> GenTextureCubemap() should be moved to user code!
        DrawCubeV(Vector3Zero(), Vector3One(), WHITE)
        DrawRenderBatch(RLGL.currentBatch)
#endif
    }
    ''------------------------------------------------------------------------------------------

    '' STEP 3: Unload framebuffer and reset state
    ''------------------------------------------------------------------------------------------
    rlDisableShader()          '' Unbind shader
    rlDisableTexture()         '' Unbind texture
    rlDisableFramebuffer()     '' Unbind framebuffer
    rlUnloadFramebuffer(fbo)   '' Unload framebuffer (and automatically attached depth texture/renderbuffer)

    '' Reset viewport dimensions to default
    rlViewport(0, 0, RLGL.State.framebufferWidth, RLGL.State.framebufferHeight)
    ''rlEnableBackfaceCulling()
    ''------------------------------------------------------------------------------------------

    cubemap.width = size
    cubemap.height = size
    cubemap.mipmaps = 1
    cubemap.format = UNCOMPRESSED_R32G32B32
#endif
    return cubemap
}

'' Generate irradiance texture using cubemap data
TextureCubemap GenTextureIrradiance(Shader shader, TextureCubemap cubemap, size as Long)
{
    TextureCubemap irradiance = { 0 }

#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    rlDisableBackfaceCulling()     '' Disable backface culling to render inside the cube

    '' STEP 1: Setup framebuffer
    ''------------------------------------------------------------------------------------------
    unsigned int rbo = rlLoadTextureDepth(size, size, true)
    irradiance.id = rlLoadTextureCubemap(NULL, size, UNCOMPRESSED_R32G32B32)

    unsigned int fbo = rlLoadFramebuffer(size, size)
    rlFramebufferAttach(fbo, rbo, RL_ATTACHMENT_DEPTH, RL_ATTACHMENT_RENDERBUFFER)
    rlFramebufferAttach(fbo, cubemap.id, RL_ATTACHMENT_COLOR_CHANNEL0, RL_ATTACHMENT_CUBEMAP_POSITIVE_X)
    ''------------------------------------------------------------------------------------------

    '' STEP 2: Draw to framebuffer
    ''------------------------------------------------------------------------------------------
    '' NOTE: Shader is used to solve diffuse integral by convolution to create an irradiance cubemap

    '' Define projection matrix and send it to shader
    Matrix fboProjection = MatrixPerspective(90.0*DEG2RAD, 1.0, RL_CULL_DISTANCE_NEAR, RL_CULL_DISTANCE_FAR)
    SetShaderValueMatrix(shader, shader.locs[LOC_MATRIX_PROJECTION], fboProjection)

    '' Define view matrix for every side of the cubemap
    Matrix fboViews[6] = {
        MatrixLookAt((Vector3){ 0.0f, 0.0f, 0.0f }, (Vector3){  1.0f,  0.0f,  0.0f }, (Vector3){ 0.0f, -1.0f,  0.0f }),
        MatrixLookAt((Vector3){ 0.0f, 0.0f, 0.0f }, (Vector3){ -1.0f,  0.0f,  0.0f }, (Vector3){ 0.0f, -1.0f,  0.0f }),
        MatrixLookAt((Vector3){ 0.0f, 0.0f, 0.0f }, (Vector3){  0.0f,  1.0f,  0.0f }, (Vector3){ 0.0f,  0.0f,  1.0f }),
        MatrixLookAt((Vector3){ 0.0f, 0.0f, 0.0f }, (Vector3){  0.0f, -1.0f,  0.0f }, (Vector3){ 0.0f,  0.0f, -1.0f }),
        MatrixLookAt((Vector3){ 0.0f, 0.0f, 0.0f }, (Vector3){  0.0f,  0.0f,  1.0f }, (Vector3){ 0.0f, -1.0f,  0.0f }),
        MatrixLookAt((Vector3){ 0.0f, 0.0f, 0.0f }, (Vector3){  0.0f,  0.0f, -1.0f }, (Vector3){ 0.0f, -1.0f,  0.0f })
    }

    rlEnableShader(shader.id)
    glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_CUBE_MAP, cubemap.id)

    rlViewport(0, 0, size, size)   '' Set viewport to current fbo dimensions

    for (int i = 0 i < 6 i++)
    {
        SetShaderValueMatrix(shader, shader.locs[LOC_MATRIX_VIEW], fboViews[i])
        rlFramebufferAttach(fbo, irradiance.id, RL_ATTACHMENT_COLOR_CHANNEL0, RL_ATTACHMENT_CUBEMAP_POSITIVE_X + i)

        rlEnableFramebuffer(fbo)
        rlClearScreenBuffers()
        GenDrawCube()
    }
    ''------------------------------------------------------------------------------------------

    '' STEP 3: Unload framebuffer and reset state
    ''------------------------------------------------------------------------------------------
    rlDisableShader()          '' Unbind shader
    rlDisableTexture()         '' Unbind texture
    rlDisableFramebuffer()     '' Unbind framebuffer
    rlUnloadFramebuffer(fbo)   '' Unload framebuffer (and automatically attached depth texture/renderbuffer)

    '' Reset viewport dimensions to default
    rlViewport(0, 0, RLGL.State.framebufferWidth, RLGL.State.framebufferHeight)
    ''rlEnableBackfaceCulling()
    ''------------------------------------------------------------------------------------------

    irradiance.width = size
    irradiance.height = size
    irradiance.mipmaps = 1
    irradiance.format = UNCOMPRESSED_R32G32B32
#endif
    return irradiance
}

'' Generate prefilter texture using cubemap data
TextureCubemap GenTexturePrefilter(Shader shader, TextureCubemap cubemap, size as Long)
{
    TextureCubemap prefilter = { 0 }

#if defined(GRAPHICS_API_OPENGL_33) '' orelse defined(GRAPHICS_API_OPENGL_ES2)
    rlDisableBackfaceCulling()     '' Disable backface culling to render inside the cube

    '' STEP 1: Setup framebuffer
    ''------------------------------------------------------------------------------------------
    unsigned int rbo = rlLoadTextureDepth(size, size, true)
    prefilter.id = rlLoadTextureCubemap(NULL, size, UNCOMPRESSED_R32G32B32)
    rlTextureParameters(prefilter.id, RL_TEXTURE_MIN_FILTER, RL_FILTER_MIP_LINEAR)

    unsigned int fbo = rlLoadFramebuffer(size, size)
    rlFramebufferAttach(fbo, rbo, RL_ATTACHMENT_DEPTH, RL_ATTACHMENT_RENDERBUFFER)
    rlFramebufferAttach(fbo, cubemap.id, RL_ATTACHMENT_COLOR_CHANNEL0, RL_ATTACHMENT_CUBEMAP_POSITIVE_X)
    ''------------------------------------------------------------------------------------------

    '' Generate mipmaps for the prefiltered HDR texture
    glGenerateMipmap(GL_TEXTURE_CUBE_MAP)
    ''rlGenerateMipmaps(texture as Texture2D ptr) '' Only GL_TEXTURE_2D

    '' STEP 2: Draw to framebuffer
    ''------------------------------------------------------------------------------------------
    '' NOTE: Shader is used to prefilter HDR and store data into mipmap levels

    '' Define projection matrix and send it to shader
    Matrix fboProjection = MatrixPerspective(90.0*DEG2RAD, 1.0, RL_CULL_DISTANCE_NEAR, RL_CULL_DISTANCE_FAR)
    SetShaderValueMatrix(shader, shader.locs[LOC_MATRIX_PROJECTION], fboProjection)

    '' Define view matrix for every side of the cubemap
    Matrix fboViews[6] = {
        MatrixLookAt((Vector3){ 0.0f, 0.0f, 0.0f }, (Vector3){  1.0f,  0.0f,  0.0f }, (Vector3){ 0.0f, -1.0f,  0.0f }),
        MatrixLookAt((Vector3){ 0.0f, 0.0f, 0.0f }, (Vector3){ -1.0f,  0.0f,  0.0f }, (Vector3){ 0.0f, -1.0f,  0.0f }),
        MatrixLookAt((Vector3){ 0.0f, 0.0f, 0.0f }, (Vector3){  0.0f,  1.0f,  0.0f }, (Vector3){ 0.0f,  0.0f,  1.0f }),
        MatrixLookAt((Vector3){ 0.0f, 0.0f, 0.0f }, (Vector3){  0.0f, -1.0f,  0.0f }, (Vector3){ 0.0f,  0.0f, -1.0f }),
        MatrixLookAt((Vector3){ 0.0f, 0.0f, 0.0f }, (Vector3){  0.0f,  0.0f,  1.0f }, (Vector3){ 0.0f, -1.0f,  0.0f }),
        MatrixLookAt((Vector3){ 0.0f, 0.0f, 0.0f }, (Vector3){  0.0f,  0.0f, -1.0f }, (Vector3){ 0.0f, -1.0f,  0.0f })
    }

    rlEnableShader(shader.id)
    glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_CUBE_MAP, cubemap.id)

    '' TODO: Locations should be taken out of this function... too shader dependant...
    int roughnessLoc = GetShaderLocation(shader, "roughness")

    rlEnableFramebuffer(fbo)

    #define MAX_MIPMAP_LEVELS   5   '' Max number of prefilter texture mipmaps

    for (int mip = 0 mip < MAX_MIPMAP_LEVELS mip++)
    {
        '' Resize framebuffer according to mip-level size.
        unsigned int mipWidth  = size*(int)powf(0.5f, (Single)mip)
        unsigned int mipHeight = size*(int)powf(0.5f, (Single)mip)

        rlViewport(0, 0, mipWidth, mipHeight)

        glBindRenderbuffer(GL_RENDERBUFFER, rbo)
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, mipWidth, mipHeight)

        single roughness = (single)mip/(Single)(MAX_MIPMAP_LEVELS - 1)
        glUniform1f(roughnessLoc, roughness)

        for (int i = 0 i < 6 i++)
        {
            SetShaderValueMatrix(shader, shader.locs[LOC_MATRIX_VIEW], fboViews[i])
            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, prefilter.id, mip)
            ''rlFramebufferAttach(fbo, irradiance.id, RL_ATTACHMENT_COLOR_CHANNEL0, RL_ATTACHMENT_CUBEMAP_POSITIVE_X + i)  '' TODO: Support mip levels?

            rlEnableFramebuffer(fbo)
            rlClearScreenBuffers()
            GenDrawCube()
        }
    }
    ''------------------------------------------------------------------------------------------

    '' STEP 3: Unload framebuffer and reset state
    ''------------------------------------------------------------------------------------------
    rlDisableShader()          '' Unbind shader
    rlDisableTexture()         '' Unbind texture
    rlDisableFramebuffer()     '' Unbind framebuffer
    rlUnloadFramebuffer(fbo)   '' Unload framebuffer (and automatically attached depth texture/renderbuffer)

    '' Reset viewport dimensions to default
    rlViewport(0, 0, RLGL.State.framebufferWidth, RLGL.State.framebufferHeight)
    ''rlEnableBackfaceCulling()
    ''------------------------------------------------------------------------------------------

    prefilter.width = size
    prefilter.height = size
    ''prefilter.mipmaps = 1 + (int)floor(log(size)/log(2)) '' MAX_MIPMAP_LEVELS
    ''prefilter.format = UNCOMPRESSED_R32G32B32
#endif
    return prefilter
}

'' Generate BRDF texture using cubemap data
'' TODO: Review implementation: https:''github.com/HectorMF/BRDFGenerator
Texture2D GenTextureBRDF(Shader shader, size as Long)
{
    Texture2D brdf = { 0 }
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    '' STEP 1: Setup framebuffer
    ''------------------------------------------------------------------------------------------
    unsigned int rbo = rlLoadTextureDepth(size, size, true)
    brdf.id = rlLoadTexture(NULL, size, size, UNCOMPRESSED_R32G32B32, 1)

    unsigned int fbo = rlLoadFramebuffer(size, size)
    rlFramebufferAttach(fbo, rbo, RL_ATTACHMENT_DEPTH, RL_ATTACHMENT_RENDERBUFFER)
    rlFramebufferAttach(fbo, brdf.id, RL_ATTACHMENT_COLOR_CHANNEL0, RL_ATTACHMENT_TEXTURE2D)
    ''------------------------------------------------------------------------------------------

    '' STEP 2: Draw to framebuffer
    ''------------------------------------------------------------------------------------------
    '' NOTE: Render BRDF LUT into a quad using FBO

    rlEnableShader(shader.id)

    rlViewport(0, 0, size, size)

    rlEnableFramebuffer(fbo)
    rlClearScreenBuffers()
    GenDrawQuad()
    ''------------------------------------------------------------------------------------------

    '' STEP 3: Unload framebuffer and reset state
    ''------------------------------------------------------------------------------------------
    rlDisableShader()          '' Unbind shader
    rlDisableTexture()         '' Unbind texture
    rlDisableFramebuffer()     '' Unbind framebuffer
    rlUnloadFramebuffer(fbo)   '' Unload framebuffer (and automatically attached depth texture/renderbuffer)

    '' Reset viewport dimensions to default
    rlViewport(0, 0, RLGL.State.framebufferWidth, RLGL.State.framebufferHeight)
    ''------------------------------------------------------------------------------------------

    brdf.width = size
    brdf.height = size
    brdf.mipmaps = 1
    brdf.format = UNCOMPRESSED_R32G32B32
#endif
    return brdf
}

'' Begin blending mode (alpha, additive, multiplied)
'' NOTE: Only 3 blending modes supported, default blend mode is alpha
Sub BeginBlendMode(mode As long)
{
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    if (RLGL.State.currentBlendMode <> mode)
    {
        DrawRenderBatch(RLGL.currentBatch)

        switch (mode)
        {
            case BLEND_ALPHA: glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA) glBlendEquation(GL_FUNC_ADD)  
            case BLEND_ADDITIVE: glBlendFunc(GL_SRC_ALPHA, GL_ONE) glBlendEquation(GL_FUNC_ADD)  
            case BLEND_MULTIPLIED: glBlendFunc(GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA) glBlendEquation(GL_FUNC_ADD)  
            case BLEND_ADD_COLORS: glBlendFunc(GL_ONE, GL_ONE) glBlendEquation(GL_FUNC_ADD)  
            case BLEND_SUBTRACT_COLORS: glBlendFunc(GL_ONE, GL_ONE) glBlendEquation(GL_FUNC_SUBTRACT)  
            case BLEND_CUSTOM: glBlendFunc(RLGL.State.glBlendSrcFactor, RLGL.State.glBlendDstFactor) glBlendEquation(RLGL.State.glBlendEquation)  
            case Else:  
        }

        RLGL.State.currentBlendMode = mode
    }
#endif
}

'' End blending mode (reset to case else: alpha blending)
sub EndBlendMode()
{
    BeginBlendMode(BLEND_ALPHA)
}

#if defined(SUPPORT_VR_SIMULATOR)
'' Init VR simulator for selected device parameters
'' NOTE: It modifies the global variable: RLGL.Vr.stereoFboId
sub InitVrSimulator()
{
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    '' Initialize framebuffer and textures for stereo rendering
    '' NOTE: Screen size should match HMD aspect ratio
    RLGL.Vr.stereoFboId = rlLoadFramebuffer(RLGL.State.framebufferWidth, RLGL.State.framebufferHeight)

    '' Load color/depth textures to attach to framebuffer
    RLGL.Vr.stereoTexId = rlLoadTexture(NULL, RLGL.State.framebufferWidth, RLGL.State.framebufferHeight, UNCOMPRESSED_R8G8B8A8, 1)
    unsigned int depthId = rlLoadTextureDepth(RLGL.State.framebufferWidth, RLGL.State.framebufferHeight, true)

    '' Attach color texture and depth renderbuffer/texture to FBO
    rlFramebufferAttach(RLGL.Vr.stereoFboId, RLGL.Vr.stereoTexId, RL_ATTACHMENT_COLOR_CHANNEL0, RL_ATTACHMENT_TEXTURE2D)
    rlFramebufferAttach(RLGL.Vr.stereoFboId, depthId, RL_ATTACHMENT_DEPTH, RL_ATTACHMENT_RENDERBUFFER)

    RLGL.Vr.simulatorReady = TRUE
#else
    TRACELOG(LOG_WARNING, "RLGL: VR Simulator not supported on OpenGL 1.1")
#endif
}

'' Update VR tracking (position and orientation) and camera
'' NOTE: Camera (position, target, up) gets update with head tracking information
Sub UpdateVrTracking(Camera *camera)
{
    '' TODO: Simulate 1st person camera system
}

'' Close VR simulator for current device
sub CloseVrSimulator()
{
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    if (RLGL.Vr.simulatorReady)
    {
        rlUnloadTexture(RLGL.Vr.stereoTexId)       '' Unload color texture
        rlUnloadFramebuffer(RLGL.Vr.stereoFboId)   '' Unload stereo framebuffer and depth texture/renderbuffer
    }
#endif
}

'' Set stereo rendering configuration parameters
Sub SetVrConfiguration(VrDeviceInfo hmd, Shader distortion)
{
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    '' Reset RLGL.Vr.config for a new values assignment
    memset(&RLGL.Vr.config, 0, sizeof(RLGL.Vr.config))

    '' Assign distortion shader
    RLGL.Vr.config.distortionShader = distortion

    '' Compute aspect ratio
    single aspect = ((single)hmd.hResolution*0.5f)/(Single)hmd.vResolution

    '' Compute lens parameters
    Single lensShift = (hmd.hScreenSize*0.25f - hmd.lensSeparationDistance*0.5f)/hmd.hScreenSize
    Single leftLensCenter[2] = { 0.25f + lensShift, 0.5f }
    Single rightLensCenter[2] = { 0.75f - lensShift, 0.5f }
    Single leftScreenCenter[2] = { 0.25f, 0.5f }
    Single rightScreenCenter[2] = { 0.75f, 0.5f }

    '' Compute distortion scale parameters
    '' NOTE: To get lens max radius, lensShift must be normalized to (-1..1]
    Single lensRadius = fabsf(-1.0f - 4.0f*lensShift)
    Single lensRadiusSq = lensRadius*lensRadius
    Single distortionScale = hmd.lensDistortionValues[0] +
                            hmd.lensDistortionValues[1]*lensRadiusSq +
                            hmd.lensDistortionValues[2]*lensRadiusSq*lensRadiusSq +
                            hmd.lensDistortionValues[3]*lensRadiusSq*lensRadiusSq*lensRadiusSq

    TRACELOGD("RLGL: VR device configuration:")
    TRACELOGD("    > Distortion Scale: %f", distortionScale)

    Single normScreenWidth = 0.5f
    Single normScreenHeight = 1.0f
    Single scaleIn[2] = { 2.0f/normScreenWidth, 2.0f/normScreenHeight/aspect }
    Single scale[2] = { normScreenWidth*0.5f/distortionScale, normScreenHeight*0.5f*aspect/distortionScale }

    TRACELOGD("    > Distortion Shader: LeftLensCenter = { %f, %f }", leftLensCenter[0], leftLensCenter[1])
    TRACELOGD("    > Distortion Shader: RightLensCenter = { %f, %f }", rightLensCenter[0], rightLensCenter[1])
    TRACELOGD("    > Distortion Shader: Scale = { %f, %f }", scale[0], scale[1])
    TRACELOGD("    > Distortion Shader: ScaleIn = { %f, %f }", scaleIn[0], scaleIn[1])

    '' Fovy is normally computed with: 2*atan2f(hmd.vScreenSize, 2*hmd.eyeToScreenDistance)
    '' ...but with lens distortion it is increased (see Oculus SDK Documentation)
    ''single fovy = 2.0f*atan2f(hmd.vScreenSize*0.5f*distortionScale, hmd.eyeToScreenDistance)     '' Really need distortionScale?
    single fovy = 2.0f*(Single)atan2f(hmd.vScreenSize*0.5f, hmd.eyeToScreenDistance)

    '' Compute camera projection matrices
    Single projOffset = 4.0f*lensShift      '' Scaled to projection space coordinates (-1..1]
    Matrix proj = MatrixPerspective(fovy, aspect, RL_CULL_DISTANCE_NEAR, RL_CULL_DISTANCE_FAR)
    RLGL.Vr.config.eyesProjection[0] = MatrixMultiply(proj, MatrixTranslate(projOffset, 0.0f, 0.0f))
    RLGL.Vr.config.eyesProjection[1] = MatrixMultiply(proj, MatrixTranslate(-projOffset, 0.0f, 0.0f))

    '' Compute camera transformation matrices
    '' NOTE: Camera movement might seem more natural if we model the head.
    '' Our axis of rotation is the base of our head, so we might want to add
    '' some y (base of head to eye level) and -z (center of head to eye protrusion) to the camera positions.
    RLGL.Vr.config.eyesViewOffset[0] = MatrixTranslate(-hmd.interpupillaryDistance*0.5f, 0.075f, 0.045f)
    RLGL.Vr.config.eyesViewOffset[1] = MatrixTranslate(hmd.interpupillaryDistance*0.5f, 0.075f, 0.045f)

    '' Compute eyes Viewports
    RLGL.Vr.config.eyeViewportRight[2] = hmd.hResolution/2
    RLGL.Vr.config.eyeViewportRight[3] = hmd.vResolution

    RLGL.Vr.config.eyeViewportLeft[0] = hmd.hResolution/2
    RLGL.Vr.config.eyeViewportLeft[1] = 0
    RLGL.Vr.config.eyeViewportLeft[2] = hmd.hResolution/2
    RLGL.Vr.config.eyeViewportLeft[3] = hmd.vResolution

    if (RLGL.Vr.config.distortionShader.id > 0)
    {
        '' Update distortion shader with lens and distortion-scale parameters
        SetShaderValue(RLGL.Vr.config.distortionShader, GetShaderLocation(RLGL.Vr.config.distortionShader, "leftLensCenter"), leftLensCenter, UNIFORM_VEC2)
        SetShaderValue(RLGL.Vr.config.distortionShader, GetShaderLocation(RLGL.Vr.config.distortionShader, "rightLensCenter"), rightLensCenter, UNIFORM_VEC2)
        SetShaderValue(RLGL.Vr.config.distortionShader, GetShaderLocation(RLGL.Vr.config.distortionShader, "leftScreenCenter"), leftScreenCenter, UNIFORM_VEC2)
        SetShaderValue(RLGL.Vr.config.distortionShader, GetShaderLocation(RLGL.Vr.config.distortionShader, "rightScreenCenter"), rightScreenCenter, UNIFORM_VEC2)

        SetShaderValue(RLGL.Vr.config.distortionShader, GetShaderLocation(RLGL.Vr.config.distortionShader, "scale"), scale, UNIFORM_VEC2)
        SetShaderValue(RLGL.Vr.config.distortionShader, GetShaderLocation(RLGL.Vr.config.distortionShader, "scaleIn"), scaleIn, UNIFORM_VEC2)
        SetShaderValue(RLGL.Vr.config.distortionShader, GetShaderLocation(RLGL.Vr.config.distortionShader, "hmdWarpParam"), hmd.lensDistortionValues, UNIFORM_VEC4)
        SetShaderValue(RLGL.Vr.config.distortionShader, GetShaderLocation(RLGL.Vr.config.distortionShader, "chromaAbParam"), hmd.chromaAbCorrection, UNIFORM_VEC4)
    }
#endif
}

'' Detect if VR simulator is running
bool IsVrSimulatorReady()
{
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    return RLGL.Vr.simulatorReady
#else
    return FALSE
#endif
}

'' Enable/Disable VR experience (device or simulator)
sub ToggleVrMode()
{
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    RLGL.Vr.simulatorReady = !RLGL.Vr.simulatorReady

    if (!RLGL.Vr.simulatorReady)
    {
        RLGL.Vr.stereoRender = FALSE

        '' Reset viewport and default projection-modelview matrices
        rlViewport(0, 0, RLGL.State.framebufferWidth, RLGL.State.framebufferHeight)
        RLGL.State.projection = MatrixOrtho(0.0, RLGL.State.framebufferWidth, RLGL.State.framebufferHeight, 0.0, 0.0, 1.0)
        RLGL.State.modelview = MatrixIdentity()
    }
    else RLGL.Vr.stereoRender = TRUE
#endif
}

'' Begin VR drawing configuration
sub BeginVrDrawing()
{
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    if (RLGL.Vr.simulatorReady)
    {
        rlEnableFramebuffer(RLGL.Vr.stereoFboId)   '' Setup framebuffer for stereo rendering
        ''glEnable(GL_FRAMEBUFFER_SRGB)          '' Enable SRGB framebuffer (only if required)

        ''rlViewport(0, 0, buffer.width, buffer.height) '' Useful if rendering to separate framebuffers (every eye)
        rlClearScreenBuffers()                   '' Clear current framebuffer

        RLGL.Vr.stereoRender = TRUE
    }
#endif
}

'' End VR drawing process (and desktop mirror)
sub EndVrDrawing()
{
#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    if (RLGL.Vr.simulatorReady)
    {
        RLGL.Vr.stereoRender = FALSE   '' Disable stereo render

        rlDisableFramebuffer()         '' Unbind current framebuffer

        rlClearScreenBuffers()         '' Clear current framebuffer

        '' Set viewport to default framebuffer size (screen size)
        rlViewport(0, 0, RLGL.State.framebufferWidth, RLGL.State.framebufferHeight)

        '' Let rlgl reconfigure internal matrices
        rlMatrixMode(RL_PROJECTION)                            '' Enable internal projection matrix
        rlLoadIdentity()                                       '' Reset internal projection matrix
        rlOrtho(0.0, RLGL.State.framebufferWidth, RLGL.State.framebufferHeight, 0.0, 0.0, 1.0) '' Recalculate internal RLGL.State.projection matrix
        rlMatrixMode(RL_MODELVIEW)                             '' Enable internal modelview matrix
        rlLoadIdentity()                                       '' Reset internal modelview matrix

        '' Draw stereo framebuffer texture using distortion shader if available
        if (RLGL.Vr.config.distortionShader.id > 0) RLGL.State.currentShader = RLGL.Vr.config.distortionShader
        else RLGL.State.currentShader = GetShaderDefault()

        rlEnableTexture(RLGL.Vr.stereoTexId)

        rlPushMatrix()
            rlBegin(RL_QUADS)
                rlColor4ub(255, 255, 255, 255)
                rlNormal3f(0.0f, 0.0f, 1.0f)

                '' Bottom-left corner for texture and quad
                rlTexCoord2f(0.0f, 1.0f)
                rlVertex2f(0.0f, 0.0f)

                '' Bottom-right corner for texture and quad
                rlTexCoord2f(0.0f, 0.0f)
                rlVertex2f(0.0f, (Single)RLGL.State.framebufferHeight)

                '' Top-right corner for texture and quad
                rlTexCoord2f(1.0f, 0.0f)
                rlVertex2f((single)RLGL.State.framebufferWidth, (Single)RLGL.State.framebufferHeight)

                '' Top-left corner for texture and quad
                rlTexCoord2f(1.0f, 1.0f)
                rlVertex2f((Single)RLGL.State.framebufferWidth, 0.0f)
            rlEnd()
        rlPopMatrix()

        rlDisableTexture()

        '' Update and draw render texture fbo with distortion to backbuffer
        DrawRenderBatch(RLGL.currentBatch)

        '' Restore RLGL.State.defaultShader
        RLGL.State.currentShader = RLGL.State.defaultShader

        '' Reset viewport and default projection-modelview matrices
        rlViewport(0, 0, RLGL.State.framebufferWidth, RLGL.State.framebufferHeight)
        RLGL.State.projection = MatrixOrtho(0.0, RLGL.State.framebufferWidth, RLGL.State.framebufferHeight, 0.0, 0.0, 1.0)
        RLGL.State.modelview = MatrixIdentity()

        rlDisableDepthTest()
    }
#endif
}
#endif          '' SUPPORT_VR_SIMULATOR

''----------------------------------------------------------------------------------
'' Module specific Functions Definition
''----------------------------------------------------------------------------------

#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
'' Compile custom shader and return shader id
static unsigned int CompileShader(const char *shaderStr, int type)
{
    unsigned int shader = glCreateShader(type)
    glShaderSource(shader, 1, &shaderStr, NULL)

    GLint success = 0
    glCompileShader(shader)
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success)

    if (success <> GL_TRUE)
    {
        TRACELOG(LOG_WARNING, "SHADER: [ID %i] Failed to compile shader code", shader)
        int maxLength = 0
        int length
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &maxLength)

#if defined(_MSC_VER)
        char *log = RL_MALLOC(maxLength)
#else
        char log[maxLength]
#endif
        glGetShaderInfoLog(shader, maxLength, &length, log)

        TRACELOG(LOG_WARNING, "SHADER: [ID %i] Compile error: %s", shader, log)

#if defined(_MSC_VER)
        RL_FREE(log)
#endif
    }
    else TRACELOG(LOG_INFO, "SHADER: [ID %i] Compiled successfully", shader)

    return shader
}

'' Load custom shader strings and return program id
static unsigned int LoadShaderProgram(unsigned int vShaderId, unsigned int fShaderId)
{
    unsigned int program = 0

#if defined(GRAPHICS_API_OPENGL_33) OrElse defined(GRAPHICS_API_OPENGL_ES2)
    GLint success = 0
    program = glCreateProgram()

    glAttachShader(program, vShaderId)
    glAttachShader(program, fShaderId)

    '' NOTE: Default attribute shader locations must be binded before linking
    glBindAttribLocation(program, 0, DEFAULT_SHADER_ATTRIB_NAME_POSITION)
    glBindAttribLocation(program, 1, DEFAULT_SHADER_ATTRIB_NAME_TEXCOORD)
    glBindAttribLocation(program, 2, DEFAULT_SHADER_ATTRIB_NAME_NORMAL)
    glBindAttribLocation(program, 3, DEFAULT_SHADER_ATTRIB_NAME_COLOR)
    glBindAttribLocation(program, 4, DEFAULT_SHADER_ATTRIB_NAME_TANGENT)
    glBindAttribLocation(program, 5, DEFAULT_SHADER_ATTRIB_NAME_TEXCOORD2)

    '' NOTE: If some attrib name is no found on the shader, it locations becomes -1

    glLinkProgram(program)

    '' NOTE: All uniform variables are intitialised to 0 when a program links

    glGetProgramiv(program, GL_LINK_STATUS, &success)

    if (success == GL_FALSE)
    {
        TRACELOG(LOG_WARNING, "SHADER: [ID %i] Failed to link shader program", program)

        int maxLength = 0
        int length

        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &maxLength)

#if defined(_MSC_VER)
        char *log = RL_MALLOC(maxLength)
#else
        char log[maxLength]
#endif
        glGetProgramInfoLog(program, maxLength, &length, log)

        TRACELOG(LOG_WARNING, "SHADER: [ID %i] Link error: %s", program, log)

#if defined(_MSC_VER)
        RL_FREE(log)
#endif
        glDeleteProgram(program)

        program = 0
    }
    else TRACELOG(LOG_INFO, "SHADER: [ID %i] Program loaded successfully", program)
#endif
    return program
}


'' Load default shader (just vertex positioning and texture coloring)
'' NOTE: This shader program is used for internal buffers
static Shader LoadShaderDefault()
{
    Shader shader = { 0 }
    shader.locs = (int *)RL_CALLOC(MAX_SHADER_LOCATIONS, sizeof(int))

    '' NOTE: All locations must be reseted to -1 (no location)
    for (int i = 0 i < MAX_SHADER_LOCATIONS i++) shader.locs[i] = -1

    '' Vertex shader directly defined, no external file required
    const char *defaultVShaderStr =
#if defined(GRAPHICS_API_OPENGL_21)
    "#version 120                       \n"
#ElseIf defined(GRAPHICS_API_OPENGL_ES2)
    "#version 100                       \n"
#endif
#if defined(GRAPHICS_API_OPENGL_ES2) OrElse defined(GRAPHICS_API_OPENGL_21)
    "attribute vec3 vertexPosition     \n"
    "attribute vec2 vertexTexCoord     \n"
    "attribute vec4 vertexColor        \n"
    "varying vec2 fragTexCoord         \n"
    "varying vec4 fragColor            \n"
#ElseIf defined(GRAPHICS_API_OPENGL_33)
    "#version 330                       \n"
    "in vec3 vertexPosition            \n"
    "in vec2 vertexTexCoord            \n"
    "in vec4 vertexColor               \n"
    "out vec2 fragTexCoord             \n"
    "out vec4 fragColor                \n"
#endif
    "uniform mat4 mvp                  \n"
    "sub main()                        \n"
    "{                                  \n"
    "    fragTexCoord = vertexTexCoord \n"
    "    fragColor = vertexColor       \n"
    "    gl_Position = mvp*vec4(vertexPosition, 1.0) \n"
    "}                                  \n"

    '' Fragment shader directly defined, no external file required
    const char *defaultFShaderStr =
#if defined(GRAPHICS_API_OPENGL_21)
    "#version 120                       \n"
#ElseIf defined(GRAPHICS_API_OPENGL_ES2)
    "#version 100                       \n"
    "precision mediump single           \n"     '' precision required for OpenGL ES2 (WebGL)
#endif
#if defined(GRAPHICS_API_OPENGL_ES2) OrElse defined(GRAPHICS_API_OPENGL_21)
    "varying vec2 fragTexCoord         \n"
    "varying vec4 fragColor            \n"
#ElseIf defined(GRAPHICS_API_OPENGL_33)
    "#version 330       \n"
    "in vec2 fragTexCoord              \n"
    "in vec4 fragColor                 \n"
    "out vec4 finalColor               \n"
#endif
    "uniform sampler2D texture0        \n"
    "uniform vec4 colDiffuse           \n"
    "sub main()                        \n"
    "{                                  \n"
#if defined(GRAPHICS_API_OPENGL_ES2) OrElse defined(GRAPHICS_API_OPENGL_21)
    "    vec4 texelColor = texture2D(texture0, fragTexCoord) \n" '' NOTE: texture2D() is deprecated on OpenGL 3.3 and ES 3.0
    "    gl_FragColor = texelColor*colDiffuse*fragColor      \n"
#ElseIf defined(GRAPHICS_API_OPENGL_33)
    "    vec4 texelColor = texture(texture0, fragTexCoord)   \n"
    "    finalColor = texelColor*colDiffuse*fragColor        \n"
#endif
    "}                                  \n"

    '' NOTE: Compiled vertex/fragment shaders are kept for re-use
    RLGL.State.defaultVShaderId = CompileShader(defaultVShaderStr, GL_VERTEX_SHADER)     '' Compile default vertex shader
    RLGL.State.defaultFShaderId = CompileShader(defaultFShaderStr, GL_FRAGMENT_SHADER)   '' Compile default fragment shader

    shader.id = LoadShaderProgram(RLGL.State.defaultVShaderId, RLGL.State.defaultFShaderId)

    if (shader.id > 0)
    {
        TRACELOG(LOG_INFO, "SHADER: [ID %i] Default shader loaded successfully", shader.id)

        '' Set default shader locations: attributes locations
        shader.locs[LOC_VERTEX_POSITION] = glGetAttribLocation(shader.id, "vertexPosition")
        shader.locs[LOC_VERTEX_TEXCOORD01] = glGetAttribLocation(shader.id, "vertexTexCoord")
        shader.locs[LOC_VERTEX_COLOR] = glGetAttribLocation(shader.id, "vertexColor")

        '' Set default shader locations: uniform locations
        shader.locs[LOC_MATRIX_MVP]  = glGetUniformLocation(shader.id, "mvp")
        shader.locs[LOC_COLOR_DIFFUSE] = glGetUniformLocation(shader.id, "colDiffuse")
        shader.locs[LOC_MAP_DIFFUSE] = glGetUniformLocation(shader.id, "texture0")

        '' NOTE: We could also use below function but in case DEFAULT_ATTRIB_* points are
        '' changed for external custom shaders, we just use direct bindings above
        ''SetShaderDefaultLocations(&shader)
    }
    else TRACELOG(LOG_WARNING, "SHADER: [ID %i] Failed to load default shader", shader.id)

    return shader
}

'' Get location handlers to for shader attributes and uniforms
'' NOTE: If any location is not found, loc point becomes -1
static Sub SetShaderDefaultLocations(Shader *shader)
{
    '' NOTE: Default shader attrib locations have been fixed before linking:
    ''          vertex position location    = 0
    ''          vertex texcoord location    = 1
    ''          vertex normal location      = 2
    ''          vertex color location       = 3
    ''          vertex tangent location     = 4
    ''          vertex texcoord2 location   = 5

    '' Get handles to GLSL input attibute locations
    shader->locs[LOC_VERTEX_POSITION] = glGetAttribLocation(shader->id, DEFAULT_SHADER_ATTRIB_NAME_POSITION)
    shader->locs[LOC_VERTEX_TEXCOORD01] = glGetAttribLocation(shader->id, DEFAULT_SHADER_ATTRIB_NAME_TEXCOORD)
    shader->locs[LOC_VERTEX_TEXCOORD02] = glGetAttribLocation(shader->id, DEFAULT_SHADER_ATTRIB_NAME_TEXCOORD2)
    shader->locs[LOC_VERTEX_NORMAL] = glGetAttribLocation(shader->id, DEFAULT_SHADER_ATTRIB_NAME_NORMAL)
    shader->locs[LOC_VERTEX_TANGENT] = glGetAttribLocation(shader->id, DEFAULT_SHADER_ATTRIB_NAME_TANGENT)
    shader->locs[LOC_VERTEX_COLOR] = glGetAttribLocation(shader->id, DEFAULT_SHADER_ATTRIB_NAME_COLOR)

    '' Get handles to GLSL uniform locations (vertex shader)
    shader->locs[LOC_MATRIX_MVP]  = glGetUniformLocation(shader->id, "mvp")
    shader->locs[LOC_MATRIX_PROJECTION]  = glGetUniformLocation(shader->id, "projection")
    shader->locs[LOC_MATRIX_VIEW]  = glGetUniformLocation(shader->id, "view")

    '' Get handles to GLSL uniform locations (fragment shader)
    shader->locs[LOC_COLOR_DIFFUSE] = glGetUniformLocation(shader->id, "colDiffuse")
    shader->locs[LOC_MAP_DIFFUSE] = glGetUniformLocation(shader->id, "texture0")
    shader->locs[LOC_MAP_SPECULAR] = glGetUniformLocation(shader->id, "texture1")
    shader->locs[LOC_MAP_NORMAL] = glGetUniformLocation(shader->id, "texture2")
}

'' Unload default shader
static sub UnloadShaderDefault()
{
    glUseProgram(0)

    glDetachShader(RLGL.State.defaultShader.id, RLGL.State.defaultVShaderId)
    glDetachShader(RLGL.State.defaultShader.id, RLGL.State.defaultFShaderId)
    glDeleteShader(RLGL.State.defaultVShaderId)
    glDeleteShader(RLGL.State.defaultFShaderId)

    glDeleteProgram(RLGL.State.defaultShader.id)

    RL_FREE(RLGL.State.defaultShader.locs)
}

'' Load render batch
static RenderBatch LoadRenderBatch(int numBuffers, buffer As longElements)
{
    RenderBatch batch = { 0 }

    '' Initialize CPU (RAM) vertex buffers (position, texcoord, color data and indexes)
    ''--------------------------------------------------------------------------------------------
    batch.vertexBuffer = (VertexBuffer *)RL_MALLOC(sizeof(VertexBuffer)*numBuffers)

    for (int i = 0 i < numBuffers i++)
    {
        batch.vertexBuffer[i].elementsCount = bufferElements

        batch.vertexBuffer[i].vertices = (single *)RL_MALLOC(bufferElements*3*4*sizeof(single))        '' 3 single by vertex, 4 vertex by quad
        batch.vertexBuffer[i].texcoords = (single *)RL_MALLOC(bufferElements*2*4*sizeof(single))       '' 2 single by texcoord, 4 texcoord by quad
        batch.vertexBuffer[i].colors = (unsigned char *)RL_MALLOC(bufferElements*4*4*sizeof(unsigned char))   '' 4 single by color, 4 colors by quad
#if defined(GRAPHICS_API_OPENGL_33)
        batch.vertexBuffer[i].indices = (unsigned int *)RL_MALLOC(bufferElements*6*sizeof(unsigned int))      '' 6 int by quad (indices)
#ElseIf defined(GRAPHICS_API_OPENGL_ES2)
        batch.vertexBuffer[i].indices = (unsigned short *)RL_MALLOC(bufferElements*6*sizeof(unsigned short))  '' 6 int by quad (indices)
#endif

        for (int j = 0 j < (3*4*bufferElements) j++) batch.vertexBuffer[i].vertices[j] = 0.0f
        for (int j = 0 j < (2*4*bufferElements) j++) batch.vertexBuffer[i].texcoords[j] = 0.0f
        for (int j = 0 j < (4*4*bufferElements) j++) batch.vertexBuffer[i].colors[j] = 0

        int k = 0

        '' Indices can be initialized right now
        for (int j = 0 j < (6*bufferElements) j += 6)
        {
            batch.vertexBuffer[i].indices[j] = 4*k
            batch.vertexBuffer[i].indices[j + 1] = 4*k + 1
            batch.vertexBuffer[i].indices[j + 2] = 4*k + 2
            batch.vertexBuffer[i].indices[j + 3] = 4*k
            batch.vertexBuffer[i].indices[j + 4] = 4*k + 2
            batch.vertexBuffer[i].indices[j + 5] = 4*k + 3

            k++
        }

        batch.vertexBuffer[i].vCounter = 0
        batch.vertexBuffer[i].tcCounter = 0
        batch.vertexBuffer[i].cCounter = 0
    }

    TRACELOG(LOG_INFO, "RLGL: Internal vertex buffers initialized successfully in RAM (CPU)")
    ''--------------------------------------------------------------------------------------------

    '' Upload to GPU (VRAM) vertex data and initialize VAOs/VBOs
    ''--------------------------------------------------------------------------------------------
    for (int i = 0 i < numBuffers i++)
    {
        if (RLGL.ExtSupported.vao)
        {
            '' Initialize Quads VAO
            glGenVertexArrays(1, &batch.vertexBuffer[i].vaoId)
            glBindVertexArray(batch.vertexBuffer[i].vaoId)
        }

        '' Quads - Vertex buffers binding and attributes enable
        '' Vertex position buffer (shader-location = 0)
        glGenBuffers(1, &batch.vertexBuffer[i].vboId[0])
        glBindBuffer(GL_ARRAY_BUFFER, batch.vertexBuffer[i].vboId[0])
        glBufferData(GL_ARRAY_BUFFER, bufferElements*3*4*sizeof(Single), batch.vertexBuffer[i].vertices, GL_DYNAMIC_DRAW)
        glEnableVertexAttribArray(RLGL.State.currentShader.locs[LOC_VERTEX_POSITION])
        glVertexAttribPointer(RLGL.State.currentShader.locs[LOC_VERTEX_POSITION], 3, GL_FLOAT, 0, 0, 0)

        '' Vertex texcoord buffer (shader-location = 1)
        glGenBuffers(1, &batch.vertexBuffer[i].vboId[1])
        glBindBuffer(GL_ARRAY_BUFFER, batch.vertexBuffer[i].vboId[1])
        glBufferData(GL_ARRAY_BUFFER, bufferElements*2*4*sizeof(Single), batch.vertexBuffer[i].texcoords, GL_DYNAMIC_DRAW)
        glEnableVertexAttribArray(RLGL.State.currentShader.locs[LOC_VERTEX_TEXCOORD01])
        glVertexAttribPointer(RLGL.State.currentShader.locs[LOC_VERTEX_TEXCOORD01], 2, GL_FLOAT, 0, 0, 0)

        '' Vertex color buffer (shader-location = 3)
        glGenBuffers(1, &batch.vertexBuffer[i].vboId[2])
        glBindBuffer(GL_ARRAY_BUFFER, batch.vertexBuffer[i].vboId[2])
        glBufferData(GL_ARRAY_BUFFER, bufferElements*4*4*sizeof(unsigned char), batch.vertexBuffer[i].colors, GL_DYNAMIC_DRAW)
        glEnableVertexAttribArray(RLGL.State.currentShader.locs[LOC_VERTEX_COLOR])
        glVertexAttribPointer(RLGL.State.currentShader.locs[LOC_VERTEX_COLOR], 4, GL_UNSIGNED_BYTE, GL_TRUE, 0, 0)

        '' Fill index buffer
        glGenBuffers(1, &batch.vertexBuffer[i].vboId[3])
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, batch.vertexBuffer[i].vboId[3])
#if defined(GRAPHICS_API_OPENGL_33)
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, bufferElements*6*sizeof(int), batch.vertexBuffer[i].indices, GL_STATIC_DRAW)
#ElseIf defined(GRAPHICS_API_OPENGL_ES2)
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, bufferElements*6*sizeof(short), batch.vertexBuffer[i].indices, GL_STATIC_DRAW)
#endif
    }

    TRACELOG(LOG_INFO, "RLGL: Render batch vertex buffers loaded successfully")

    '' Unbind the current VAO
    if (RLGL.ExtSupported.vao) glBindVertexArray(0)
    ''--------------------------------------------------------------------------------------------

    '' Init draw calls tracking system
    ''--------------------------------------------------------------------------------------------
    batch.draws = (DrawCall *)RL_MALLOC(DEFAULT_BATCH_DRAWCALLS*sizeof(DrawCall))

    for (int i = 0 i < DEFAULT_BATCH_DRAWCALLS i++)
    {
        batch.draws[i].mode = RL_QUADS
        batch.draws[i].vertexCount = 0
        batch.draws[i].vertexAlignment = 0
        ''batch.draws[i].vaoId = 0
        ''batch.draws[i].shaderId = 0
        batch.draws[i].textureId = RLGL.State.defaultTextureId
        ''batch.draws[i].RLGL.State.projection = MatrixIdentity()
        ''batch.draws[i].RLGL.State.modelview = MatrixIdentity()
    }

    batch.buffersCount = numBuffers    '' Record buffer count
    batch.drawsCounter = 1             '' Reset draws counter
    batch.currentDepth = -1.0f         '' Reset depth value
    ''--------------------------------------------------------------------------------------------

    return batch
}

'' Draw render batch
'' NOTE: We require a pointer to reset batch and increase current buffer (multi-buffer)
static Sub DrawRenderBatch(RenderBatch *batch)
{
    '' Update batch vertex buffers
    ''------------------------------------------------------------------------------------------------------------
    '' NOTE: If there is not vertex data, buffers doesn't need to be updated (vertexCount > 0)
    '' TODO: If no data changed on the CPU arrays --> No need to re-update GPU arrays (change flag required)
    if (batch->vertexBuffer[batch->currentBuffer].vCounter > 0)
    {
        '' Activate elements VAO
        if (RLGL.ExtSupported.vao) glBindVertexArray(batch->vertexBuffer[batch->currentBuffer].vaoId)

        '' Vertex positions buffer
        glBindBuffer(GL_ARRAY_BUFFER, batch->vertexBuffer[batch->currentBuffer].vboId[0])
        glBufferSubData(GL_ARRAY_BUFFER, 0, batch->vertexBuffer[batch->currentBuffer].vCounter*3*sizeof(Single), batch->vertexBuffer[batch->currentBuffer].vertices)
        ''glBufferData(GL_ARRAY_BUFFER, sizeof(single)*3*4*batch->vertexBuffer[batch->currentBuffer].elementsCount, batch->vertexBuffer[batch->currentBuffer].vertices, GL_DYNAMIC_DRAW)  '' Update all buffer

        '' Texture coordinates buffer
        glBindBuffer(GL_ARRAY_BUFFER, batch->vertexBuffer[batch->currentBuffer].vboId[1])
        glBufferSubData(GL_ARRAY_BUFFER, 0, batch->vertexBuffer[batch->currentBuffer].vCounter*2*sizeof(Single), batch->vertexBuffer[batch->currentBuffer].texcoords)
        ''glBufferData(GL_ARRAY_BUFFER, sizeof(single)*2*4*batch->vertexBuffer[batch->currentBuffer].elementsCount, batch->vertexBuffer[batch->currentBuffer].texcoords, GL_DYNAMIC_DRAW) '' Update all buffer

        '' Colors buffer
        glBindBuffer(GL_ARRAY_BUFFER, batch->vertexBuffer[batch->currentBuffer].vboId[2])
        glBufferSubData(GL_ARRAY_BUFFER, 0, batch->vertexBuffer[batch->currentBuffer].vCounter*4*sizeof(unsigned char), batch->vertexBuffer[batch->currentBuffer].colors)
        ''glBufferData(GL_ARRAY_BUFFER, sizeof(single)*4*4*batch->vertexBuffer[batch->currentBuffer].elementsCount, batch->vertexBuffer[batch->currentBuffer].colors, GL_DYNAMIC_DRAW)    '' Update all buffer

        '' NOTE: glMapBuffer() causes sync issue.
        '' If GPU is working with this buffer, glMapBuffer() will wait(stall) until GPU to finish its job.
        '' To asub waiting (idle), you can call first glBufferData() with NULL pointer before glMapBuffer().
        '' If you do that, the previous data in PBO will be discarded and glMapBuffer() returns a new
        '' allocated pointer immediately even if GPU is still working with the previous data.

        '' Another option: map the buffer object into client's memory
        '' Probably this code could be moved somewhere else...
        '' batch->vertexBuffer[batch->currentBuffer].vertices = (single *)glMapBuffer(GL_ARRAY_BUFFER, GL_READ_WRITE)
        '' if (batch->vertexBuffer[batch->currentBuffer].vertices)
        '' {
            '' Update vertex data
        '' }
        '' glUnmapBuffer(GL_ARRAY_BUFFER)

        '' Unbind the current VAO
        if (RLGL.ExtSupported.vao) glBindVertexArray(0)
    }
    ''------------------------------------------------------------------------------------------------------------

    '' Draw batch vertex buffers (considering VR stereo if required)
    ''------------------------------------------------------------------------------------------------------------
    Matrix matProjection = RLGL.State.projection
    Matrix matModelView = RLGL.State.modelview

    int eyesCount = 1
#if defined(SUPPORT_VR_SIMULATOR)
    if (RLGL.Vr.stereoRender) eyesCount = 2
#endif

    for (int eye = 0 eye < eyesCount eye++)
    {
#if defined(SUPPORT_VR_SIMULATOR)
        if (eyesCount == 2) SetStereoView(eye, matProjection, matModelView)
#endif
        '' Draw buffers
        if (batch->vertexBuffer[batch->currentBuffer].vCounter > 0)
        {
            '' Set current shader and upload current MVP matrix
            glUseProgram(RLGL.State.currentShader.id)

            '' Create modelview-projection matrix and upload to shader
            Matrix matMVP = MatrixMultiply(RLGL.State.modelview, RLGL.State.projection)
            glUniformMatrix4fv(RLGL.State.currentShader.locs[LOC_MATRIX_MVP], 1, false, MatrixToFloat(matMVP))

            if (RLGL.ExtSupported.vao) glBindVertexArray(batch->vertexBuffer[batch->currentBuffer].vaoId)
            else
            {
                '' Bind vertex attrib: position (shader-location = 0)
                glBindBuffer(GL_ARRAY_BUFFER, batch->vertexBuffer[batch->currentBuffer].vboId[0])
                glVertexAttribPointer(RLGL.State.currentShader.locs[LOC_VERTEX_POSITION], 3, GL_FLOAT, 0, 0, 0)
                glEnableVertexAttribArray(RLGL.State.currentShader.locs[LOC_VERTEX_POSITION])

                '' Bind vertex attrib: texcoord (shader-location = 1)
                glBindBuffer(GL_ARRAY_BUFFER, batch->vertexBuffer[batch->currentBuffer].vboId[1])
                glVertexAttribPointer(RLGL.State.currentShader.locs[LOC_VERTEX_TEXCOORD01], 2, GL_FLOAT, 0, 0, 0)
                glEnableVertexAttribArray(RLGL.State.currentShader.locs[LOC_VERTEX_TEXCOORD01])

                '' Bind vertex attrib: color (shader-location = 3)
                glBindBuffer(GL_ARRAY_BUFFER, batch->vertexBuffer[batch->currentBuffer].vboId[2])
                glVertexAttribPointer(RLGL.State.currentShader.locs[LOC_VERTEX_COLOR], 4, GL_UNSIGNED_BYTE, GL_TRUE, 0, 0)
                glEnableVertexAttribArray(RLGL.State.currentShader.locs[LOC_VERTEX_COLOR])

                glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, batch->vertexBuffer[batch->currentBuffer].vboId[3])
            }

            '' Setup some default shader values
            glUniform4f(RLGL.State.currentShader.locs[LOC_COLOR_DIFFUSE], 1.0f, 1.0f, 1.0f, 1.0f)
            glUniform1i(RLGL.State.currentShader.locs[LOC_MAP_DIFFUSE], 0)  '' Active default sampler2D: texture0

            '' Activate additional sampler textures
            '' Those additional textures will be common for all draw calls of the batch
            for (int i = 0 i < MAX_BATCH_ACTIVE_TEXTURES i++)
            {
                if (RLGL.State.activeTextureId[i] > 0)
                {
                    glActiveTexture(GL_TEXTURE0 + 1 + i)
                    glBindTexture(GL_TEXTURE_2D, RLGL.State.activeTextureId[i])
                }
            }

            '' Activate default sampler2D texture0 (one texture is always active for default batch shader)
            '' NOTE: Batch system accumulates calls by texture0 changes, additional textures are enabled for all the draw calls
            glActiveTexture(GL_TEXTURE0)

            for (int i = 0, vertexOffset = 0 i < batch->drawsCounter i++)
            {
                '' Bind current draw call texture, activated as GL_TEXTURE0 and binded to sampler2D texture0 by default
                glBindTexture(GL_TEXTURE_2D, batch->draws[i].textureId)

                if ((batch->draws[i].mode == RL_LINES) OrElse (batch->draws[i].mode == RL_TRIANGLES)) glDrawArrays(batch->draws[i].mode, vertexOffset, batch->draws[i].vertexCount)
                else
                {
#if defined(GRAPHICS_API_OPENGL_33)
                    '' We need to define the number of indices to be processed: quadsCount*6
                    '' NOTE: The final parameter tells the GPU the offset in bytes from the
                    '' start of the index buffer to the location of the first index to process
                    glDrawElements(GL_TRIANGLES, batch->draws[i].vertexCount/4*6, GL_UNSIGNED_INT, (GLsub *)(vertexOffset/4*6*sizeof(GLuint)))
#elseif defined(GRAPHICS_API_OPENGL_ES2)
                    glDrawElements(GL_TRIANGLES, batch->draws[i].vertexCount/4*6, GL_UNSIGNED_SHORT, (GLsub *)(vertexOffset/4*6*sizeof(GLushort)))
#endif
                }

                vertexOffset += (batch->draws[i].vertexCount + batch->draws[i].vertexAlignment)
            }

            if (!RLGL.ExtSupported.vao)
            {
                glBindBuffer(GL_ARRAY_BUFFER, 0)
                glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0)
            }

            glBindTexture(GL_TEXTURE_2D, 0)    '' Unbind textures
        }

        if (RLGL.ExtSupported.vao) glBindVertexArray(0) '' Unbind VAO

        glUseProgram(0)    '' Unbind shader program
    }
    ''------------------------------------------------------------------------------------------------------------

    '' Reset batch buffers
    ''------------------------------------------------------------------------------------------------------------
    '' Reset vertex counters for next frame
    batch->vertexBuffer[batch->currentBuffer].vCounter = 0
    batch->vertexBuffer[batch->currentBuffer].tcCounter = 0
    batch->vertexBuffer[batch->currentBuffer].cCounter = 0

    '' Reset depth for next draw
    batch->currentDepth = -1.0f

    '' Restore projection/modelview matrices
    RLGL.State.projection = matProjection
    RLGL.State.modelview = matModelView

    '' Reset RLGL.currentBatch->draws array
    for (int i = 0 i < DEFAULT_BATCH_DRAWCALLS i++)
    {
        batch->draws[i].mode = RL_QUADS
        batch->draws[i].vertexCount = 0
        batch->draws[i].textureId = RLGL.State.defaultTextureId
    }

    '' Reset active texture units for next batch
    for (int i = 0 i < MAX_BATCH_ACTIVE_TEXTURES i++) RLGL.State.activeTextureId[i] = 0

    '' Reset draws counter to one draw for the batch
    batch->drawsCounter = 1
    ''------------------------------------------------------------------------------------------------------------

    '' Change to next buffer in the list (in case of multi-buffering)
    batch->currentBuffer++
    if (batch->currentBuffer >= batch->buffersCount) batch->currentBuffer = 0
}

'' Unload default internal buffers vertex data from CPU and GPU
static Sub UnloadRenderBatch(RenderBatch batch)
{
    '' Unbind everything
    if (RLGL.ExtSupported.vao) glBindVertexArray(0)
    glDisableVertexAttribArray(0)
    glDisableVertexAttribArray(1)
    glDisableVertexAttribArray(2)
    glDisableVertexAttribArray(3)
    glBindBuffer(GL_ARRAY_BUFFER, 0)
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0)

    '' Unload all vertex buffers data
    for (int i = 0 i < batch.buffersCount i++)
    {
        '' Delete VBOs from GPU (VRAM)
        glDeleteBuffers(1, &batch.vertexBuffer[i].vboId[0])
        glDeleteBuffers(1, &batch.vertexBuffer[i].vboId[1])
        glDeleteBuffers(1, &batch.vertexBuffer[i].vboId[2])
        glDeleteBuffers(1, &batch.vertexBuffer[i].vboId[3])

        '' Delete VAOs from GPU (VRAM)
        if (RLGL.ExtSupported.vao) glDeleteVertexArrays(1, &batch.vertexBuffer[i].vaoId)

        '' Free vertex arrays memory from CPU (RAM)
        RL_FREE(batch.vertexBuffer[i].vertices)
        RL_FREE(batch.vertexBuffer[i].texcoords)
        RL_FREE(batch.vertexBuffer[i].colors)
        RL_FREE(batch.vertexBuffer[i].indices)
    }

    '' Unload arrays
    RL_FREE(batch.vertexBuffer)
    RL_FREE(batch.draws)
}

'' Set the active render batch for rlgl
static Sub SetRenderBatchActive(RenderBatch *batch)
{
    DrawRenderBatch(RLGL.currentBatch)
    RLGL.currentBatch = batch
}

'' Set default render batch for rlgl
static sub SetRenderBatchDefault()
{
    DrawRenderBatch(RLGL.currentBatch)
    RLGL.currentBatch = &RLGL.defaultBatch
}

'' Renders a 1x1 XY quad in NDC
static sub GenDrawQuad()
{
    unsigned int quadVAO = 0
    unsigned int quadVBO = 0

    Dim As Single vertices() = {
         '' Positions         Texcoords
        -1.0f,  1.0f, 0.0f,   0.0f, 1.0f,
        -1.0f, -1.0f, 0.0f,   0.0f, 0.0f,
         1.0f,  1.0f, 0.0f,   1.0f, 1.0f,
         1.0f, -1.0f, 0.0f,   1.0f, 0.0f,
    }

    '' Gen VAO to contain VBO
    glGenVertexArrays(1, &quadVAO)
    glBindVertexArray(quadVAO)

    '' Gen and fill vertex buffer (VBO)
    glGenBuffers(1, &quadVBO)
    glBindBuffer(GL_ARRAY_BUFFER, quadVBO)
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), &vertices, GL_STATIC_DRAW)

    '' Bind vertex attributes (position, texcoords)
    glEnableVertexAttribArray(0)
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5*sizeof(Single), (Sub *)0) '' Positions
    glEnableVertexAttribArray(1)
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5*sizeof(single), (Sub *)(3*sizeof(Single))) '' Texcoords

    '' Draw quad
    glBindVertexArray(quadVAO)
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4)
    glBindVertexArray(0)

    '' Delete buffers (VBO and VAO)
    glDeleteBuffers(1, &quadVBO)
    glDeleteVertexArrays(1, &quadVAO)
}

'' Renders a 1x1 3D cube in NDC
static sub GenDrawCube()
{
    unsigned int cubeVAO = 0
    unsigned int cubeVBO = 0

    Dim As Single vertices(...) = {
         '' Positions          Normals               Texcoords
        -1.0f, -1.0f, -1.0f,   0.0f,  0.0f, -1.0f,   0.0f, 0.0f,
         1.0f,  1.0f, -1.0f,   0.0f,  0.0f, -1.0f,   1.0f, 1.0f,
         1.0f, -1.0f, -1.0f,   0.0f,  0.0f, -1.0f,   1.0f, 0.0f,
         1.0f,  1.0f, -1.0f,   0.0f,  0.0f, -1.0f,   1.0f, 1.0f,
        -1.0f, -1.0f, -1.0f,   0.0f,  0.0f, -1.0f,   0.0f, 0.0f,
        -1.0f,  1.0f, -1.0f,   0.0f,  0.0f, -1.0f,   0.0f, 1.0f,
        -1.0f, -1.0f,  1.0f,   0.0f,  0.0f,  1.0f,   0.0f, 0.0f,
         1.0f, -1.0f,  1.0f,   0.0f,  0.0f,  1.0f,   1.0f, 0.0f,
         1.0f,  1.0f,  1.0f,   0.0f,  0.0f,  1.0f,   1.0f, 1.0f,
         1.0f,  1.0f,  1.0f,   0.0f,  0.0f,  1.0f,   1.0f, 1.0f,
        -1.0f,  1.0f,  1.0f,   0.0f,  0.0f,  1.0f,   0.0f, 1.0f,
        -1.0f, -1.0f,  1.0f,   0.0f,  0.0f,  1.0f,   0.0f, 0.0f,
        -1.0f,  1.0f,  1.0f,  -1.0f,  0.0f,  0.0f,   1.0f, 0.0f,
        -1.0f,  1.0f, -1.0f,  -1.0f,  0.0f,  0.0f,   1.0f, 1.0f,
        -1.0f, -1.0f, -1.0f,  -1.0f,  0.0f,  0.0f,   0.0f, 1.0f,
        -1.0f, -1.0f, -1.0f,  -1.0f,  0.0f,  0.0f,   0.0f, 1.0f,
        -1.0f, -1.0f,  1.0f,  -1.0f,  0.0f,  0.0f,   0.0f, 0.0f,
        -1.0f,  1.0f,  1.0f,  -1.0f,  0.0f,  0.0f,   1.0f, 0.0f,
         1.0f,  1.0f,  1.0f,   1.0f,  0.0f,  0.0f,   1.0f, 0.0f,
         1.0f, -1.0f, -1.0f,   1.0f,  0.0f,  0.0f,   0.0f, 1.0f,
         1.0f,  1.0f, -1.0f,   1.0f,  0.0f,  0.0f,   1.0f, 1.0f,
         1.0f, -1.0f, -1.0f,   1.0f,  0.0f,  0.0f,   0.0f, 1.0f,
         1.0f,  1.0f,  1.0f,   1.0f,  0.0f,  0.0f,   1.0f, 0.0f,
         1.0f, -1.0f,  1.0f,   1.0f,  0.0f,  0.0f,   0.0f, 0.0f,
        -1.0f, -1.0f, -1.0f,   0.0f, -1.0f,  0.0f,   0.0f, 1.0f,
         1.0f, -1.0f, -1.0f,   0.0f, -1.0f,  0.0f,   1.0f, 1.0f,
         1.0f, -1.0f,  1.0f,   0.0f, -1.0f,  0.0f,   1.0f, 0.0f,
         1.0f, -1.0f,  1.0f,   0.0f, -1.0f,  0.0f,   1.0f, 0.0f,
        -1.0f, -1.0f,  1.0f,   0.0f, -1.0f,  0.0f,   0.0f, 0.0f,
        -1.0f, -1.0f, -1.0f,   0.0f, -1.0f,  0.0f,   0.0f, 1.0f,
        -1.0f,  1.0f, -1.0f,   0.0f,  1.0f,  0.0f,   0.0f, 1.0f,
         1.0f,  1.0f,  1.0f,   0.0f,  1.0f,  0.0f,   1.0f, 0.0f,
         1.0f,  1.0f, -1.0f,   0.0f,  1.0f,  0.0f,   1.0f, 1.0f,
         1.0f,  1.0f,  1.0f,   0.0f,  1.0f,  0.0f,   1.0f, 0.0f,
        -1.0f,  1.0f, -1.0f,   0.0f,  1.0f,  0.0f,   0.0f, 1.0f,
        -1.0f,  1.0f,  1.0f,   0.0f,  1.0f,  0.0f,   0.0f, 0.0f
    }

    '' Gen VAO to contain VBO
    glGenVertexArrays(1, &cubeVAO)
    glBindVertexArray(cubeVAO)

    '' Gen and fill vertex buffer (VBO)
    glGenBuffers(1, &cubeVBO)
    glBindBuffer(GL_ARRAY_BUFFER, cubeVBO)
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW)

    '' Bind vertex attributes (position, normals, texcoords)
    glBindVertexArray(cubeVAO)
    glEnableVertexAttribArray(0)
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8*sizeof(Single), (Sub *)0) '' Positions
    glEnableVertexAttribArray(1)
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 8*sizeof(single), (Sub *)(3*sizeof(Single))) '' Normals
    glEnableVertexAttribArray(2)
    glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 8*sizeof(single), (Sub *)(6*sizeof(Single))) '' Texcoords
    glBindBuffer(GL_ARRAY_BUFFER, 0)
    glBindVertexArray(0)

    '' Draw cube
    glBindVertexArray(cubeVAO)
    glDrawArrays(GL_TRIANGLES, 0, 36)
    glBindVertexArray(0)

    '' Delete VBO and VAO
    glDeleteBuffers(1, &cubeVBO)
    glDeleteVertexArrays(1, &cubeVAO)
}

#if defined(SUPPORT_VR_SIMULATOR)
'' Set internal projection and modelview matrix depending on eyes tracking data
static sub SetStereoView(int eye, Matrix matProjection, Matrix matModelView)
{
    Matrix eyeProjection = matProjection
    Matrix eyeModelView = matModelView

    '' Setup viewport and projection/modelview matrices using tracking data
    rlViewport(eye*RLGL.State.framebufferWidth/2, 0, RLGL.State.framebufferWidth/2, RLGL.State.framebufferHeight)

    '' Apply view offset to modelview matrix
    eyeModelView = MatrixMultiply(matModelView, RLGL.Vr.config.eyesViewOffset[eye])

    '' Set current eye projection matrix
    eyeProjection = RLGL.Vr.config.eyesProjection[eye]

    SetMatrixModelview(eyeModelView)
    SetMatrixProjection(eyeProjection)
}
#endif  '' SUPPORT_VR_SIMULATOR

#endif  '' GRAPHICS_API_OPENGL_33 orelse GRAPHICS_API_OPENGL_ES2

#if defined(GRAPHICS_API_OPENGL_11)
'' Mipmaps data is generated after image data
'' NOTE: Only works with RGBA (4 bytes) data!
static int GenerateMipmaps(unsigned char *data, int baseWidth, int baseHeight)
{
    mipmapCount as Long = 1                '' Required mipmap levels count (including base level)
    width as Long = baseWidth
    height as Long = baseHeight
    size as Long = baseWidth*baseHeight*4  '' Size in bytes (will include mipmaps...), RGBA only

    '' Count mipmap levels required
    while ((width <> 1) && (height <> 1))
    {
        width /= 2
        height /= 2

        TRACELOGD("TEXTURE: Next mipmap size: %i x %i", width, height)

        mipmapCount++

        size += (width*height*4)       '' Add mipmap size (in bytes)
    }

    TRACELOGD("TEXTURE: Total mipmaps required: %i", mipmapCount)
    TRACELOGD("TEXTURE: Total size of data required: %i", size)

    unsigned char *temp = RL_REALLOC(data, size)

    if (temp <> NULL) data = temp
    else TRACELOG(LOG_WARNING, "TEXTURE: Failed to allocate required mipmaps memory")

    width = baseWidth
    height = baseHeight
    size = (width*height*4)

    '' Generate mipmaps
    '' NOTE: Every mipmap data is stored after data
    Color *image = (Color *)RL_MALLOC(width*height*sizeof(Color))
    Color *mipmap = NULL
    int offset = 0
    int j = 0

    for (int i = 0 i < size i += 4)
    {
        image[j].r = data[i]
        image[j].g = data[i + 1]
        image[j].b = data[i + 2]
        image[j].a = data[i + 3]
        j++
    }

    TRACELOGD("TEXTURE: Mipmap base size (%ix%i)", width, height)

    for (int mip = 1 mip < mipmapCount mip++)
    {
        mipmap = GenNextMipmap(image, width, height)

        offset += (width*height*4) '' Size of last mipmap
        j = 0

        width /= 2
        height /= 2
        size = (width*height*4)    '' Mipmap size to store after offset

        '' Add mipmap to data
        for (int i = 0 i < size i += 4)
        {
            data[offset + i] = mipmap[j].r
            data[offset + i + 1] = mipmap[j].g
            data[offset + i + 2] = mipmap[j].b
            data[offset + i + 3] = mipmap[j].a
            j++
        }

        RL_FREE(image)

        image = mipmap
        mipmap = NULL
    }

    RL_FREE(mipmap)       '' free mipmap data

    return mipmapCount
}

'' Manual mipmap generation (basic scaling algorithm)
static Color *GenNextMipmap(Color *srcData, int srcWidth, int srcHeight)
{
    x as long2, y2
    Color prow, pcol

    width as Long = srcWidth/2
    height as Long = srcHeight/2

    Color *mipmap = (Color *)RL_MALLOC(width*height*sizeof(Color))

    '' Scaling algorithm works perfectly (box-filter)
    for (y as long = 0 y < height y++)
    {
        y2 = 2*y

        for (x as Long = 0 x < Width x++)
        {
            x2 = 2*x

            prow.r = (srcData[y2*srcWidth + x2].r + srcData[y2*srcWidth + x2 + 1].r)/2
            prow.g = (srcData[y2*srcWidth + x2].g + srcData[y2*srcWidth + x2 + 1].g)/2
            prow.b = (srcData[y2*srcWidth + x2].b + srcData[y2*srcWidth + x2 + 1].b)/2
            prow.a = (srcData[y2*srcWidth + x2].a + srcData[y2*srcWidth + x2 + 1].a)/2

            pcol.r = (srcData[(y2+1)*srcWidth + x2].r + srcData[(y2+1)*srcWidth + x2 + 1].r)/2
            pcol.g = (srcData[(y2+1)*srcWidth + x2].g + srcData[(y2+1)*srcWidth + x2 + 1].g)/2
            pcol.b = (srcData[(y2+1)*srcWidth + x2].b + srcData[(y2+1)*srcWidth + x2 + 1].b)/2
            pcol.a = (srcData[(y2+1)*srcWidth + x2].a + srcData[(y2+1)*srcWidth + x2 + 1].a)/2

            mipmap[y*width + x].r = (prow.r + pcol.r)/2
            mipmap[y*width + x].g = (prow.g + pcol.g)/2
            mipmap[y*width + x].b = (prow.b + pcol.b)/2
            mipmap[y*width + x].a = (prow.a + pcol.a)/2
        }
    }

    TRACELOGD("TEXTURE: Mipmap generated successfully (%ix%i)", width, height)

    return mipmap
}
#endif

#if defined(RLGL_STANDALONE)
'' Load text data from file, returns a '\0' terminated string
'' NOTE: text chars array should be freed manually
char *LoadFileText(const char *fileName)
{
    char *text = NULL

    if (fileName <> NULL)
    {
        FILE *textFile = fopen(fileName, "rt")

        if (textFile <> NULL)
        {
            '' WARNING: When reading a file as 'text' file,
            '' text mode causes carriage return-linefeed translation...
            '' ...but using fseek() should return correct byte-offset
            fseek(textFile, 0, SEEK_END)
            size as Long = ftell(textFile)
            fseek(textFile, 0, SEEK_SET)

            if (size > 0)
            {
                text = (char *)RL_MALLOC((size + 1)*sizeof(char))
                count As long = fread(text, sizeof(char), size, textFile)

                '' WARNING: \r\n is converted to \n on reading, so,
                '' read bytes count gets reduced by the number of lines
                if (count < size) text = RL_REALLOC(text, count + 1)

                '' Zero-terminate the string
                text[count] = '\0'

                TRACELOG(LOG_INFO, "FILEIO: (%s] Text file loaded successfully", fileName)
            }
            else TRACELOG(LOG_WARNING, "FILEIO: (%s] Failed to read text file", fileName)

            fclose(textFile)
        }
        else TRACELOG(LOG_WARNING, "FILEIO: (%s] Failed to open text file", fileName)
    }
    else TRACELOG(LOG_WARNING, "FILEIO: File name provided is not valid")

    return text
}

'' Get pixel data size in bytes (image or texture)
'' NOTE: Size depends on pixel format
int GetPixelDataSize(width as Long, height as Long, format as Long)
{
    dataSize as Long = 0       '' Size in bytes
    int bpp = 0            '' Bits per pixel

    switch (format)
    {
        case UNCOMPRESSED_GRAYSCALE: bpp = 8  
        case UNCOMPRESSED_GRAY_ALPHA:
        case UNCOMPRESSED_R5G6B5:
        case UNCOMPRESSED_R5G5B5A1:
        case UNCOMPRESSED_R4G4B4A4: bpp = 16  
        case UNCOMPRESSED_R8G8B8A8: bpp = 32  
        case UNCOMPRESSED_R8G8B8: bpp = 24  
        case UNCOMPRESSED_R32: bpp = 32  
        case UNCOMPRESSED_R32G32B32: bpp = 32*3  
        case UNCOMPRESSED_R32G32B32A32: bpp = 32*4  
        case COMPRESSED_DXT1_RGB:
        case COMPRESSED_DXT1_RGBA:
        case COMPRESSED_ETC1_RGB:
        case COMPRESSED_ETC2_RGB:
        case COMPRESSED_PVRT_RGB:
        case COMPRESSED_PVRT_RGBA: bpp = 4  
        case COMPRESSED_DXT3_RGBA:
        case COMPRESSED_DXT5_RGBA:
        case COMPRESSED_ETC2_EAC_RGBA:
        case COMPRESSED_ASTC_4x4_RGBA: bpp = 8  
        case COMPRESSED_ASTC_8x8_RGBA: bpp = 2  
        case Else:  
    }

    dataSize = width*height*bpp/8  '' Total data size in bytes

    '' Most compressed formats works on 4x4 blocks,
    '' if texture is smaller, minimum dataSize is 8 or 16
    if ((width < 4) AndAlso (height < 4)) Then
       if ((format >= COMPRESSED_DXT1_RGB) andalso (format < COMPRESSED_DXT3_RGBA)) Then
       	dataSize = 8
       ElseIf ((format >= COMPRESSED_DXT3_RGBA) AndAlso (format < COMPRESSED_ASTC_8x8_RGBA)) Then
       	dataSize = 16
       EndIf
    EndIf

    return dataSize
}
#endif  '' RLGL_STANDALONE

#endif  '' RLGL_IMPLEMENTATION
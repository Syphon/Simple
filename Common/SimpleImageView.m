/*
 SimpleImageView.m
 Syphon (SDK)

 Copyright 2010-2014 bangnoise (Tom Butterworth) & vade (Anton Marini).
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.

 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SimpleImageView.h"
#ifdef SYPHON_SIMPLE_PROFILE_CORE
#import <OpenGL/gl3.h>
#else
#import <OpenGL/CGLMacro.h>
#endif

@interface SimpleImageView ()
@property (readwrite) BOOL needsReshape;
@property (readwrite, retain) NSError *error;
@end

#ifdef SYPHON_SIMPLE_PROFILE_CORE
static const char *vertex = "#version 150\n\
in vec2 vertCoord;\
in vec2 texCoord;\
out vec2 fragTexCoord;\
void main() {\
    fragTexCoord = texCoord;\
    gl_Position = vec4(vertCoord, 1.0, 1.0);\
}";

static const char *frag = "#version 150\n\
uniform sampler2DRect tex;\
in vec2 fragTexCoord;\
out vec4 color;\
void main() {\
    color = texture(tex, fragTexCoord);\
}";
#endif

@implementation SimpleImageView

@synthesize needsReshape = _needsReshape, image = _image, error = _error;

+ (NSError *)openGLError
{
    return [NSError errorWithDomain:@"info.v002.Syphon.Simple.error"
                               code:-1
                           userInfo:@{NSLocalizedDescriptionKey: @"OpenGL Error"}];
}

- (void)awakeFromNib
{
#ifdef SYPHON_SIMPLE_PROFILE_CORE
    NSOpenGLPixelFormatAttribute attrs[] =
    {
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAOpenGLProfile,
        NSOpenGLProfileVersion3_2Core,
        0
    };

    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];

    NSOpenGLContext* context = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];

    [self setPixelFormat:pixelFormat];

    [self setOpenGLContext:context];

    [pixelFormat release];
    [context release];
#endif

    self.needsReshape = YES;
    if ([NSView instancesRespondToSelector:@selector(setWantsBestResolutionOpenGLSurface:)])
    {
        // 10.7+
        [self setWantsBestResolutionOpenGLSurface:YES];
    }

    _imageSize = NSMakeSize(0, 0);
}

- (void)dealloc
{
#ifdef SYPHON_SIMPLE_PROFILE_CORE
    if (_program)
    {
        glDeleteProgram(_program);
    }
    if (_vao)
    {
        glDeleteVertexArrays(1, &_vao);
    }
    if (_vbo)
    {
        glDeleteBuffers(1, &_vbo);
    }
#endif
    [_image release];
    [_error release];
    [super dealloc];
}

- (void)prepareOpenGL
{
    [super prepareOpenGL];

    const GLint on = 1;
    [[self openGLContext] setValues:&on forParameter:NSOpenGLCPSwapInterval];
#ifdef SYPHON_SIMPLE_PROFILE_CORE
    GLuint vertShader = [self compileShader:vertex ofType:GL_VERTEX_SHADER];
    GLuint fragShader = [self compileShader:frag ofType:GL_FRAGMENT_SHADER];

    if (vertShader && fragShader)
    {
        _program = glCreateProgram();
        glAttachShader(_program, vertShader);
        glAttachShader(_program, fragShader);

        glDeleteShader(vertShader);
        glDeleteShader(fragShader);

        glLinkProgram(_program);
        GLint status;
        glGetProgramiv(_program, GL_LINK_STATUS, &status);
        if (status == GL_FALSE)
        {
            glDeleteProgram(_program);
            _program = 0;
        }
    }

    if (_program)
    {
        glUseProgram(_program);
        GLint tex = glGetUniformLocation(_program, "tex");
        glUniform1i(tex, 0);

        glGenVertexArrays(1, &_vao);
        glGenBuffers(1, &_vbo);

        GLint vertCoord = glGetAttribLocation(_program, "vertCoord");
        GLint texCoord = glGetAttribLocation(_program, "texCoord");

        glBindVertexArray(_vao);
        glBindBuffer(GL_ARRAY_BUFFER, _vbo);

        if (vertCoord != -1 && texCoord != -1)
        {
            glEnableVertexAttribArray(vertCoord);
            glVertexAttribPointer(vertCoord, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), NULL);

            glEnableVertexAttribArray(texCoord);
            glVertexAttribPointer(texCoord, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), (GLvoid *)(2 * sizeof(GLfloat)));
        }
        else
        {
            self.error = [[self class] openGLError];
        }

        glUseProgram(0);

        _imageSize = NSZeroSize;
        // TODO: maybe some of the above can stay bound
    }
    else
    {
        self.error = [[self class] openGLError];
    }
#endif
}

- (void)reshape
{
    self.needsReshape = YES;
    [super reshape];
}

- (NSSize)renderSize
{
    if ([NSView instancesRespondToSelector:@selector(convertRectToBacking:)])
    {
        // 10.7+
        return [self convertSizeToBacking:[self bounds].size];
    }
    else return [self bounds].size;
}

- (void)drawRect:(NSRect)dirtyRect
{
    SyphonImage *image = self.image;

    BOOL changed = self.needsReshape || !NSEqualSizes(_imageSize, image.textureSize);

#ifndef SYPHON_SIMPLE_PROFILE_CORE
    CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
#endif

    if (self.needsReshape)
    {
        NSSize frameSize = self.renderSize;

        glViewport(0, 0, frameSize.width, frameSize.height);

#ifndef SYPHON_SIMPLE_PROFILE_CORE
        // Setup OpenGL states
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(0.0, frameSize.width, 0.0, frameSize.height, -1, 1);

        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();

        glTranslated(frameSize.width * 0.5, frameSize.height * 0.5, 0.0);
#endif
        [[self openGLContext] update];

        self.needsReshape = NO;
    }

    if (image && changed)
    {
        _imageSize = image.textureSize;
#ifdef SYPHON_SIMPLE_PROFILE_CORE
        NSSize frameSize = self.renderSize;

        NSSize scaled;
        float wr = _imageSize.width / frameSize.width;
        float hr = _imageSize.height / frameSize.height;
        float ratio = (hr < wr ? wr : hr);
        scaled = NSMakeSize(ceilf(_imageSize.width / ratio), ceil(_imageSize.height / ratio));

        // When the view is aspect-restrained, these will always be 1.0
        float width = scaled.width / frameSize.width;
        float height = scaled.height / frameSize.height;

        glBindBuffer(GL_ARRAY_BUFFER, _vbo);

        GLfloat vertices[] = {
            -width, -height,    0.0,                0.0,
            -width,  height,    0.0,                _imageSize.height,
             width, -height,    _imageSize.width,   0.0,
             width,  height,    _imageSize.width,   _imageSize.height
        };

        glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

        glBindBuffer(GL_ARRAY_BUFFER, 0);
#endif
    }
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);

    if (image)
    {
#ifdef SYPHON_SIMPLE_PROFILE_CORE
        glUseProgram(_program);
        glBindTexture(GL_TEXTURE_RECTANGLE, image.textureName);

        glBindVertexArray(_vao);

        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

        glBindVertexArray(0);
        glBindTexture(GL_TEXTURE_RECTANGLE, 0);
        glUseProgram(0);
#else
        glEnable(GL_TEXTURE_RECTANGLE_EXT);

        glBindTexture(GL_TEXTURE_RECTANGLE_EXT, image.textureName);

        glColor4f(1.0, 1.0, 1.0, 1.0);

        NSSize frameSize = self.renderSize;
        NSSize scaled;
        float wr = _imageSize.width / frameSize.width;
        float hr = _imageSize.height / frameSize.height;
        float ratio;
        ratio = (hr < wr ? wr : hr);
        scaled = NSMakeSize((_imageSize.width / ratio), (_imageSize.height / ratio));

        GLfloat tex_coords[] =
        {
            0.0,                0.0,
            _imageSize.width,  0.0,
            _imageSize.width,  _imageSize.height,
            0.0,                _imageSize.height
        };

        float halfw = scaled.width * 0.5;
        float halfh = scaled.height * 0.5;

        GLfloat verts[] =
        {
            -halfw, -halfh,
            halfw, -halfh,
            halfw, halfh,
            -halfw, halfh
        };

        glEnableClientState( GL_TEXTURE_COORD_ARRAY );
        glTexCoordPointer(2, GL_FLOAT, 0, tex_coords );
        glEnableClientState(GL_VERTEX_ARRAY);
        glVertexPointer(2, GL_FLOAT, 0, verts );
        glDrawArrays( GL_TRIANGLE_FAN, 0, 4 );
        glDisableClientState( GL_TEXTURE_COORD_ARRAY );
        glDisableClientState(GL_VERTEX_ARRAY);

        glBindTexture(GL_TEXTURE_RECTANGLE_EXT, 0);
        glDisable(GL_TEXTURE_RECTANGLE_EXT);
#endif
    }
    [[self openGLContext] flushBuffer];
}

#ifdef SYPHON_SIMPLE_PROFILE_CORE
- (GLuint)compileShader:(const char *)source ofType:(GLenum)type
{
    GLuint shader = glCreateShader(type);

    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);

    GLint status;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);

    if (status == GL_FALSE)
    {
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}
#endif

@end

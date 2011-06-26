/*
    SimpleRenderer.m
	Syphon (SDK)
	
    Copyright 2010-2011 bangnoise (Tom Butterworth) & vade (Anton Marini).
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

#import "SimpleRenderer.h"
#import <OpenGL/CGLMacro.h>
#import <pthread.h>

@implementation SimpleRenderer

@synthesize rendersComposition = _rendersComposition;

- (id)initWithFile:(NSString *)path context:(CGLContextObj)context
{
	if (self = [super init])
	{
		cgl_ctx = CGLRetainContext(context);
		_needsRebuild = YES;
		_rendersComposition = YES;
		NSFileManager *fileManager = [[[NSFileManager alloc] init] autorelease];
		if ([fileManager fileExistsAtPath:path])
		{
			QCComposition *comp = [QCComposition compositionWithFile:path]; 
			if (comp)
			{
				CGColorSpaceRef cspace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);//CGColorSpaceCreateDeviceRGB();
				
				_renderer = [[QCRenderer alloc] initWithCGLContext:context
													   pixelFormat:CGLGetPixelFormat(context)
														colorSpace:cspace
													   composition:comp];
				CGColorSpaceRelease(cspace);
			}
		}
		_start = [NSDate timeIntervalSinceReferenceDate];
	}
	return self;
}

- (void)destroyResources
{
	CGLLockContext(cgl_ctx);
	if (_texture)
		glDeleteTextures(1, &_texture);
	if (_fbo)
		glDeleteFramebuffersEXT(1, &_fbo);
	if (_depthBuffer)
		glDeleteRenderbuffersEXT(1, &_depthBuffer);
	CGLUnlockContext(cgl_ctx);
	_texture = 0;
	_fbo = 0;
	_depthBuffer = 0;
	CGLReleaseContext(cgl_ctx);
}

- (void)finalize
{
	[self destroyResources];
	[super finalize];
}

- (void)dealloc
{
	[self destroyResources];
	[_renderer release];
	[super dealloc];
}

- (QCRenderer *)QCRenderer
{
	return _renderer;
}

- (void)setTextureSize:(NSSize)size
{
	_requestedSize = size;
	_needsRebuild = YES;
}

- (NSSize)textureSize
{
	return _requestedSize;
}

- (void)lockTexture
{
	CGLLockContext(cgl_ctx);
}

- (void)unlockTexture
{
	CGLUnlockContext(cgl_ctx);
}


- (GLuint)textureName
{
	return _texture;
}

- (BOOL)render
{
	CGLLockContext(cgl_ctx);
	// rebuild if we need to.
	if(_needsRebuild)
	{
		_currentSize = _requestedSize;
		
		GLuint oldTexture = self.textureName;
				
		if(oldTexture)
		{
			glDeleteTextures(1, &oldTexture);
		}
		if(_fbo)
		{
			glDeleteFramebuffersEXT(1, &_fbo);
			_fbo = 0;
		}
		if(_depthBuffer)
		{
			glDeleteRenderbuffersEXT(1, &_depthBuffer);
			_depthBuffer = 0;
		}
		
		// texture / color attachment
		glGenTextures(1, &_texture);
		glEnable(GL_TEXTURE_RECTANGLE_EXT);
		glBindTexture(GL_TEXTURE_RECTANGLE_EXT, _texture);
		glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA8, _currentSize.width, _currentSize.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
		glBindTexture(GL_TEXTURE_RECTANGLE_EXT, 0);
		
		// depth buffer
		glGenRenderbuffersEXT(1, &_depthBuffer);
		glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, _depthBuffer);
		glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_DEPTH_COMPONENT, _currentSize.width, _currentSize.height);
		glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, 0);
		
		// FBO and connect attachments
		glGenFramebuffersEXT(1, &_fbo);
		glBindFramebufferEXT(GL_FRAMEBUFFER, _fbo);
		glFramebufferTexture2DEXT(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_RECTANGLE_EXT, _texture, 0);
		glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER_EXT, _depthBuffer);
		// Draw black so we have output if the renderer isn't loaded
		glClearColor(0.0, 0.0, 0.0, 0.0);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		glBindFramebufferEXT(GL_FRAMEBUFFER, 0);
		
		GLenum status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER);
		if(status != GL_FRAMEBUFFER_COMPLETE)
		{
			NSLog(@"Simple Client: OpenGL error %04X", status);
			glDeleteTextures(1, &_texture);
			glDeleteFramebuffersEXT(1, &_fbo);
			glDeleteRenderbuffersEXT(1, &_depthBuffer);
			_texture = 0;
			_fbo = 0;
			_depthBuffer = 0;
			CGLUnlockContext(cgl_ctx);
			return NO;
		}
		
//		NSLog(@"created texture/FBO with size: %@", NSStringFromSize(_currentSize));
		
		_needsRebuild = NO;
	}
	
	// Render our QCRenderer into our FBO, which draws it to the texture.
	
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _fbo);
	
	glViewport(0, 0, _currentSize.width,  _currentSize.height);
	glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	glLoadIdentity();
	//	glOrtho(0, textureSize.width, 0, textureSize.height, -1, 1);
	
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glLoadIdentity();
	    
	// render QC.
	NSTimeInterval time = [NSDate timeIntervalSinceReferenceDate];
	
	time -= _start;	
	
	if (self.rendersComposition)
	{        
    	[self.QCRenderer renderAtTime:time arguments:nil];
	}
	else
	{
		glClearColor(0.0, 0.0, 0.0, 0.0);
		glClear(GL_COLOR_BUFFER_BIT);
	}
	// Restore OpenGL states
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
	
	glMatrixMode(GL_PROJECTION);
	glPopMatrix();
		
	// back to main rendering.
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
	CGLUnlockContext(cgl_ctx);
	return YES;
}
@end

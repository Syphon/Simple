/*
    SimpleServerGLView.m
	Syphon (SDK)
	
    Copyright 2010 bangnoise (Tom Butterworth) & vade (Anton Marini).
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

#import "SimpleServerGLView.h"
#import <OpenGL/CGLMacro.h>

@implementation SimpleServerGLView

@synthesize source = _source;

-(void) awakeFromNib
{	
	needsRebuild = YES;
	
	const GLint on = 1;
	[[self openGLContext] setValues:&on forParameter:NSOpenGLCPSwapInterval];	
}

- (void)reshape
{
	needsRebuild = YES;
	[super reshape];
}

- (void)update
{
	// Thread-safe update
	CGLLockContext([[self openGLContext] CGLContextObj]);
	[super update];
	CGLUnlockContext([[self openGLContext] CGLContextObj]);
}

- (void)drawRect:(NSRect)dirtyRect 
{	
	id <SimpleServerTextureSource> textureSource = self.source;
	
	CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
	
	CGLLockContext(cgl_ctx);
	
	[textureSource lockTexture];

	NSRect frame = self.frame;
	
	if (needsRebuild)
	{		
		
		// Setup OpenGL states
		glViewport(0, 0, frame.size.width, frame.size.height);
		
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		glOrtho(0.0, frame.size.width, 0.0, frame.size.height, -1, 1);
		
		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();
		
		glTranslated(frame.size.width * 0.5, frame.size.height * 0.5, 0.0);

		[[self openGLContext] update];
		
		needsRebuild = NO;
	}
	
	// Draw our renderer's texture
		
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);
	
	if (textureSource.textureName != 0)
	{
		glEnable(GL_TEXTURE_RECTANGLE_EXT);
		
		glBindTexture(GL_TEXTURE_RECTANGLE_EXT, textureSource.textureName);
		
		NSSize textureSize = textureSource.textureSize;
		
		glColor4f(1.0, 1.0, 1.0, 1.0);
		
		NSSize scaled;
		float wr = textureSize.width / frame.size.width;
		float hr = textureSize.height / frame.size.height;
		float ratio;
		ratio = (hr < wr ? wr : hr);
		scaled = NSMakeSize((textureSize.width / ratio), (textureSize.height / ratio));
		
		GLfloat tex_coords[] = 
		{
			0.0,	0.0,
			textureSize.width,	0.0,
			textureSize.width,	textureSize.height,
			0.0,	textureSize.height
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
	}

	[[self openGLContext] flushBuffer];

	[textureSource unlockTexture];

	CGLUnlockContext(cgl_ctx);
}

@end
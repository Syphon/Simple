/*
    SimpleClientGLView.m
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

#import "SimpleClientGLView.h"


@implementation SimpleClientGLView

@synthesize syClient;

-(void) awakeFromNib
{	
	const GLint on = 1;
	[[self openGLContext] setValues:&on forParameter:NSOpenGLCPSwapInterval];
}

- (void)drawRect:(NSRect)dirtyRect 
{
	[[self openGLContext] makeCurrentContext];
	
	CGLContextObj cgl_ctx = [[self openGLContext] CGLContextObj];
	
	NSRect frame = self.frame;
	glClearColor(0.0, 0.0, 0.0, 0.0);
	glClear(GL_COLOR_BUFFER_BIT);
		
	// Setup OpenGL states
	glViewport(0, 0, frame.size.width, frame.size.height);
	glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	glLoadIdentity();
	glOrtho(0.0, frame.size.width, 0.0, frame.size.height, -1, 1);
	
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glLoadIdentity();
	
	// Get a new frame from the client
	SyphonImage *image = [syClient newFrameImageForContext:cgl_ctx];
	if(image)
	{
		glEnable(GL_TEXTURE_RECTANGLE_ARB);
		glBindTexture(GL_TEXTURE_RECTANGLE_ARB, [image textureName]);
		// do a nearest linear interp.
		glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		
		glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);

		glColor4f(1.0, 1.0, 1.0, 1.0);
		
		// why do we need it ?
		glDisable(GL_BLEND);
		
		NSSize imageSize = [image textureSize];
		NSSize scaled;
		float wr = imageSize.width / frame.size.width;
		float hr = imageSize.height / frame.size.height;
		float ratio;
		ratio = (hr < wr ? wr : hr);
		scaled = NSMakeSize((imageSize.width / ratio), (imageSize.height / ratio));
		
		GLfloat tex_coords[] = 
		{
			0.0,	0.0,
			imageSize.width,	0.0,
			imageSize.width,	imageSize.height,
			0.0,	imageSize.height
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
		
		glTranslated(frame.size.width * 0.5, frame.size.height * 0.5, 0.0);
		
		glEnableClientState( GL_TEXTURE_COORD_ARRAY );
		glTexCoordPointer(2, GL_FLOAT, 0, tex_coords );
		glEnableClientState(GL_VERTEX_ARRAY);
		glVertexPointer(2, GL_FLOAT, 0, verts );
		glDrawArrays( GL_TRIANGLE_FAN, 0, 4 );
		glDisableClientState( GL_TEXTURE_COORD_ARRAY );
		glDisableClientState(GL_VERTEX_ARRAY);

		glBindTexture(GL_TEXTURE_RECTANGLE_ARB, 0);
		
		// We are responsible for releasing the frame
		[image release];
	}
	
	// Restore OpenGL states
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
	
	glMatrixMode(GL_PROJECTION);
	glPopMatrix();
	
	[[self openGLContext] flushBuffer];
}


@end

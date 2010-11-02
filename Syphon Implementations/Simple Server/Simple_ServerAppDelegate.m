/*
    Simple_ServerAppDelegate.m
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

#import "Simple_ServerAppDelegate.h"

@implementation Simple_ServerAppDelegate

@synthesize window;
@synthesize glView;

@synthesize FPS;

@synthesize renderer;

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return YES;
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// We need the CGLContext to create a server. Here we get it from our
	// NSOpenGLView
	CGLContextObj context = [[glView openGLContext] CGLContextObj];
	
	// Create a server. This is our only server so we don't give it a name.
	syServer = [[SyphonServer alloc] initWithName:nil context:context options:nil];
	
	// Init our renderer in the background as loading the composition takes some time
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		
		SimpleRenderer *newRenderer = [[SimpleRenderer alloc] initWithFile:[[NSBundle mainBundle] pathForResource:@"ServerDemo" ofType:@"qtz"] context:[[glView openGLContext] CGLContextObj]];
		
		// We use a simple protocol <SimpleServerTextureSource> so the view can get texture information from the renderer when it wants to draw
		[glView setSource:newRenderer];
		
		[newRenderer setTextureSize:[glView frame].size];
		
		self.renderer = newRenderer;
		[newRenderer release];
	});
	
	// A terrible FPS display
	fpsStart = [NSDate timeIntervalSinceReferenceDate];

	// NSTimer is not ideal for drawing video, but it's easy to use
	lameRenderingTimer = [NSTimer timerWithTimeInterval:1.0/60.0 target:self selector:@selector(render:) userInfo:nil repeats:YES];
	[lameRenderingTimer retain];
	[[NSRunLoop currentRunLoop] addTimer:lameRenderingTimer forMode:NSRunLoopCommonModes];
	
	// We link the size of our output to the size of our view
	[glView addObserver:self forKeyPath:@"frame" options:0 context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"frame"])
	{
		[self.renderer setTextureSize:[glView frame].size];
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (void) applicationWillTerminate:(NSNotification *)notification
{	
	// You should always stop a server so clients know it has gone
	[syServer stop];
}

// render timer
-(void) render:(NSTimer*) aTimer
{
	// Render our composition
	SimpleRenderer *theRenderer = self.renderer;
	[theRenderer render];
	
	// Monitor frame-rate
	fpsCount++;
	float elapsed = [NSDate timeIntervalSinceReferenceDate] - fpsStart;
	if (elapsed > 0.5)
	{
		self.FPS = fpsCount / elapsed;
		fpsCount = 0;
		fpsStart = [NSDate timeIntervalSinceReferenceDate];
	}
	
	// We only publish our frame if we have clients
	if ([syServer hasClients])
	{
		// lockTexture just stops the renderer from drawing until we're done with it
		[theRenderer lockTexture];
		
		// publish our frame to our server. We use the whole texture, but we could just publish a region of it
		CGLLockContext(syServer.context);
		[syServer publishFrameTexture:theRenderer.textureName
						textureTarget:GL_TEXTURE_RECTANGLE_EXT
						  imageRegion:NSMakeRect(0, 0, theRenderer.textureSize.width, theRenderer.textureSize.height)
					textureDimensions:theRenderer.textureSize
							  flipped:NO];
		CGLUnlockContext(syServer.context);
		// let the renderer resume drawing
		[theRenderer unlockTexture];
	}
	// Tell the view we have a new frame for it
	[glView setNeedsDisplay:YES];
}
@end

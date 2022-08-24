/*
    Simple_ServerAppDelegate.m
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

#import "Simple_ServerAppDelegate.h"

@implementation Simple_ServerAppDelegate {
    SyphonOpenGLServer *syServer;
    SimpleRenderer *renderer;
    NSTimer* lameRenderingTimer;    //yea, should use display link but this is a demo.

    NSUInteger FPS;
    NSTimeInterval fpsStart;
    NSUInteger fpsCount;
}

@synthesize window;
@synthesize glView;

@synthesize FPS;

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return YES;
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// We need the CGLContext to create a server. Here we get it from our NSOpenGLView

	CGLContextObj context = [[glView openGLContext] CGLContextObj];
	
	// Create a server.
    // - This is our only server so we don't give it a name.

	syServer = [[SyphonOpenGLServer alloc] initWithName:nil context:context options:nil];

    renderer = [[SimpleRenderer alloc] init];

	// A terrible FPS display
	fpsStart = [NSDate timeIntervalSinceReferenceDate];

	// NSTimer is not ideal for drawing video, but it's easy to use
	lameRenderingTimer = [NSTimer timerWithTimeInterval:1.0/60.0 target:self selector:@selector(render:) userInfo:nil repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:lameRenderingTimer forMode:NSRunLoopCommonModes];
}

- (void) applicationWillTerminate:(NSNotification *)notification
{	
	// You should always stop a server so clients know it has gone
	[syServer stop];
}

// render timer
-(void) render:(NSTimer*) aTimer
{
    // It's quite likely you won't want to tie your renderer to the view's
    // dimensions, but this is a useful way to show a server can vary its
    // frame size (just resize the window)
    NSSize frameSize = glView.renderSize;

    [self.glView.openGLContext makeCurrentContext];
    [syServer bindToDrawFrameOfSize:frameSize];

    [renderer render:frameSize];

    [syServer unbindAndPublish];

    SyphonOpenGLImage *image = [syServer newFrameImage];

    glView.image = image;

    [glView setNeedsDisplay:YES];

    // Monitor frame-rate

    fpsCount++;
    float elapsed = [NSDate timeIntervalSinceReferenceDate] - fpsStart;
    if (elapsed > 0.5)
    {
        self.FPS = fpsCount / elapsed;
        fpsCount = 0;
        fpsStart = [NSDate timeIntervalSinceReferenceDate];
    }
}

@end

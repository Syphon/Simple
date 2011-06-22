/*
    SimpleClientAppDelegate.m
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

#import "SimpleClientAppDelegate.h"

@interface SimpleClientAppDelegate (Private)
- (void)resizeWindowForCurrentVideo;
@end

@implementation SimpleClientAppDelegate

+ (NSSet *)keyPathsForValuesAffectingStatus
{
    return [NSSet setWithObjects:@"frameWidth", @"frameHeight", @"FPS", @"selectedServerDescriptions", nil];
}

- (void)dealloc
{
    [selectedServerDescriptions release];
    [super dealloc];
}

@synthesize FPS;

@synthesize frameWidth;

@synthesize frameHeight;

- (NSString *)status
{
    if (self.frameWidth && self.frameHeight)
    {
        return [NSString stringWithFormat:@"%u x %u : %u FPS", self.frameWidth, self.frameHeight, self.FPS];
    }
    else
    {
        return @"--";
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // We use an NSArrayController to populate the menu of available servers
    // Here we bind its content to SyphonServerDirectory's servers array
    [availableServersController bind:@"contentArray" toObject:[SyphonServerDirectory sharedDirectory] withKeyPath:@"servers" options:nil];
    
    // Slightly weird binding here, if anyone can neatly and non-weirdly improve on this then feel free...
    [self bind:@"selectedServerDescriptions" toObject:availableServersController withKeyPath:@"selectedObjects" options:nil];
    
    [[glView window] setContentMinSize:(NSSize){400.0,300.0}];
	[[glView window] setDelegate:self];
}

- (NSArray *)selectedServerDescriptions
{
    return selectedServerDescriptions;
}

- (void)setSelectedServerDescriptions:(NSArray *)descriptions
{
    if (![descriptions isEqualToArray:selectedServerDescriptions])
    {
        [descriptions retain];
        [selectedServerDescriptions release];
        selectedServerDescriptions = descriptions;
        // Stop our current client
        [syClient stop];
        [syClient release];
        // Reset our terrible FPS display
        fpsStart = [NSDate timeIntervalSinceReferenceDate];
        fpsCount = 0;
        self.FPS = 0;
        syClient = [[SyphonClient alloc] initWithServerDescription:[descriptions lastObject] options:nil newFrameHandler:^(SyphonClient *client) {
            // This gets called whenever the client receives a new frame.
            
            // The new-frame handler could be called from any thread, but because we update our UI we have
            // to do this on the main thread.
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                // First we track our framerate...
                fpsCount++;
                float elapsed = [NSDate timeIntervalSinceReferenceDate] - fpsStart;
                if (elapsed > 1.0)
                {
                    self.FPS = ceilf(fpsCount / elapsed);
                    fpsStart = [NSDate timeIntervalSinceReferenceDate];
                    fpsCount = 0;
                }
                // ...then we check to see if our dimensions display or window shape needs to be updated
                SyphonImage *frame = [client newFrameImageForContext:[[glView openGLContext] CGLContextObj]];
                
                NSSize imageSize = frame.textureSize;
                
                [frame release];
                
                BOOL changed = NO;
                if (self.frameWidth != imageSize.width)
                {
                    changed = YES;
                    self.frameWidth = imageSize.width;
                }
                if (self.frameHeight != imageSize.height)
                {
                    changed = YES;
                    self.frameHeight = imageSize.height;
                }
                if (changed)
                {
                    [[glView window] setContentAspectRatio:imageSize];
                    [self resizeWindowForCurrentVideo];
                }
                // ...then mark our view as needing display, it will get the frame when it's ready to draw
                [glView setNeedsDisplay:YES];
            }];
        }];
        
        // Our view uses the client to draw, so keep it up to date
        [glView setSyClient:syClient];
        
        // If we have a client we do nothing - wait until it outputs a frame
        
        // Otherwise clear the view
        if (syClient == nil)
        {
            self.frameWidth = 0;
            self.frameHeight = 0;
            [glView setNeedsDisplay:YES];
        }
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	[glView setSyClient:nil];
		
	[syClient stop];
	[syClient release];
	syClient = nil;
}

#pragma mark Window Sizing

- (NSSize)windowContentSizeForCurrentVideo
{
	NSSize imageSize = NSMakeSize(self.frameWidth, self.frameHeight);
	
	if (imageSize.width == 0 || imageSize.height == 0)
	{
		imageSize.width = 640;
		imageSize.height = 480;
	}

    return imageSize;
}

- (NSRect)frameRectForContentSize:(NSSize)contentSize
{
    // Make sure we are at least as big as the window's minimum content size
	NSSize minContentSize = [[glView window] contentMinSize];
	if (contentSize.height < minContentSize.height)
	{
		float scale = minContentSize.height / contentSize.height;
		contentSize.height *= scale;
		contentSize.width *= scale;
	}
	if (contentSize.width < minContentSize.width)
	{
		float scale = minContentSize.width / contentSize.width;
		contentSize.height *= scale;
		contentSize.width *= scale;
	}
    
    NSRect contentRect = (NSRect){[[glView window] frame].origin, contentSize};
    NSRect frameRect = [[glView window] frameRectForContentRect:contentRect];
    
    // Move the window up (or down) so it remains rooted at the top left
    float delta = [[glView window] frame].size.height - frameRect.size.height;
    frameRect.origin.y += delta;
    
    // Attempt to remain on-screen
    NSRect available = [[[glView window] screen] visibleFrame];
    if ((frameRect.origin.x + frameRect.size.width) > available.size.width)
    {
        frameRect.origin.x = available.size.width - frameRect.size.width;
    }
    if ((frameRect.origin.y + frameRect.size.height) > available.size.height)
    {
        frameRect.origin.y = available.size.height - frameRect.size.height;
    }

    return frameRect;
}

- (NSRect)windowWillUseStandardFrame:(NSWindow *)window defaultFrame:(NSRect)newFrame
{
	// We get this when the user hits the zoom box, if we're not already zoomed
	if ([window isEqual:[glView window]])
	{
		// Resize to the current video dimensions
        return [self frameRectForContentSize:[self windowContentSizeForCurrentVideo]];        
    }
	else
	{
		return newFrame;
	}
}

- (void)resizeWindowForCurrentVideo
{
    // Resize to the correct aspect ratio, keeping as close as possible to our current dimensions
    NSSize wantedContentSize = [self windowContentSizeForCurrentVideo];
    NSSize currentSize = [[[glView window] contentView] frame].size;
    float wr = wantedContentSize.width / currentSize.width;
    float hr = wantedContentSize.height / currentSize.height;
    NSUInteger widthScaledToHeight = wantedContentSize.width / hr;
    NSUInteger heightScaledToWidth = wantedContentSize.height / wr;
    if (widthScaledToHeight - currentSize.width < heightScaledToWidth - currentSize.height)
    {
        wantedContentSize.width /= hr;
        wantedContentSize.height /= hr;
    }
    else
    {
        wantedContentSize.width /= wr;
        wantedContentSize.height /= wr;        
    }
    
    NSRect newFrame = [self frameRectForContentSize:wantedContentSize];
    [[glView window] setFrame:newFrame display:YES animate:NO];
}

@end

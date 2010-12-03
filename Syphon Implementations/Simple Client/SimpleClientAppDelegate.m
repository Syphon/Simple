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
- (void)handleServerChange;
@end

@implementation SimpleClientAppDelegate

+ (NSSet *)keyPathsForValuesAffectingCurrentWindowVideoScalingAsPercentage
{
	return [NSSet setWithObject:@"currentWindowVideoScaling"];
}

@synthesize selectedServersUUID;

@synthesize FPS;

@synthesize frameWidth;

@synthesize frameHeight;

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[[glView window] setDelegate:self];
	// observe changes in the list of servers so we can build our UI.
	[[SyphonServerDirectory sharedDirectory] addObserver:self forKeyPath:@"servers" options:0 context:nil];
	[self handleServerChange];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	[glView setSyClient:nil];
	
	[[SyphonServerDirectory sharedDirectory] removeObserver:self forKeyPath:@"servers"];
	
	[syClient stop];
	[syClient release];
	syClient = nil;
}

#pragma mark Window Sizing

- (void)windowDidResize:(NSNotification *)notification
{
	if ([[notification object] isEqual:[glView window]])
	{
		[self didChangeValueForKey:@"currentWindowVideoScaling"];
	}
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize
{
	if ([sender isEqual:[glView window]])
	{
		[self willChangeValueForKey:@"currentWindowVideoScaling"];
		// If we have a current video frame, make the size conform to its aspect ratio
		// We can't just use NSWindow's aspectRatio method because our status bar is of a fixed size
		if (self.frameWidth > 0 && self.frameHeight > 0)
		{
			NSSize min = [sender minSize];
			if (frameSize.width < min.width)
				frameSize.width = min.width;
			if (frameSize.height < min.height)
				frameSize.height = min.height;
			
			NSRect windowFrame = [sender frame];
			NSUInteger contentHeight = [sender contentRectForFrameRect:windowFrame].size.height;
			NSUInteger frameExtraHeight = windowFrame.size.height - contentHeight;
			NSUInteger viewHeight = [glView frame].size.height;
			NSUInteger statusBarHeight = contentHeight - viewHeight;
			
			NSSize scaled;
			float wr = self.frameWidth / frameSize.width;
			float hr = self.frameHeight / (frameSize.height - frameExtraHeight - statusBarHeight);
			float ratio = (hr > wr ? wr : hr);
			scaled = NSMakeSize((self.frameWidth / ratio), (self.frameHeight / ratio) + statusBarHeight + frameExtraHeight);
			
			return scaled;
		}
		else
		{
			return frameSize;
		}
	}
	else
	{
		return frameSize;
	}
}

- (NSRect)windowFrameRectForCurrentVideo
{
	// Work out the proper size of our glView, the size of the rest of the window, combine them
	NSSize imageSize = NSMakeSize(self.frameWidth, self.frameHeight);
	NSRect windowFrame = [[glView window] frame];
	
	if (imageSize.width == 0 || imageSize.height == 0)
	{
		imageSize.width = 640;
		imageSize.height = 480;
	}

	NSRect originalContentRect = [[glView window] contentRectForFrameRect:windowFrame];
	NSUInteger originalContentHeight = originalContentRect.size.height;
	NSUInteger viewHeight = [glView frame].size.height;
	NSUInteger statusBarHeight = originalContentHeight - viewHeight;
	
	// Make sure we are at least as big as the window's minimum size
	NSSize minImageSize = [[glView window] minSize];
	minImageSize.width -= (windowFrame.size.width - originalContentRect.size.width);
	minImageSize.height -= statusBarHeight + (windowFrame.size.height - originalContentHeight);
	if (imageSize.height < minImageSize.height)
	{
		float scale = minImageSize.height / imageSize.height;
		imageSize.height *= scale;
		imageSize.width *= scale;
	}
	if (imageSize.width < minImageSize.width)
	{
		float scale = minImageSize.width / imageSize.width;
		imageSize.height *= scale;
		imageSize.width *= scale;
	}
	
	NSSize newContentSize = NSMakeSize(imageSize.width, imageSize.height + statusBarHeight);
	
	NSInteger delta = newContentSize.height - originalContentHeight;
	
	NSRect newContentRect = NSMakeRect(originalContentRect.origin.x, originalContentRect.origin.y, newContentSize.width, newContentSize.height);
	NSRect newFrame = [[glView window] frameRectForContentRect:newContentRect];
	
	// Move the window up (or down) so it remains rooted at the top left
	newFrame.origin.y -= delta;
	return newFrame;
}

- (NSRect)windowWillUseStandardFrame:(NSWindow *)window defaultFrame:(NSRect)newFrame
{
	// We get this when the user hits the zoom box, if we're not already zoomed
	if ([window isEqual:[glView window]])
	{
		// Resize to the current video
		NSRect preferred = [self windowFrameRectForCurrentVideo];
		// Move to the top left of the current screen, allowing for dock, etc
		NSRect available = [[window screen] visibleFrame];
		preferred.origin.x = available.origin.x;
		preferred.origin.y = available.origin.y + available.size.height - preferred.size.height;
		return preferred;
	}
	else
	{
		return newFrame;
	}

}

- (float)currentWindowVideoScaling
{
	NSUInteger contentWidth = [[glView window] contentRectForFrameRect:[[glView window] frame]].size.width;
	if (contentWidth && self.frameWidth)
		return (float)contentWidth / (float)self.frameWidth;
	else
		return 1.0f;
}

- (NSUInteger)currentWindowVideoScalingAsPercentage
{
	return self.currentWindowVideoScaling * 100;
}
- (void)resizeWindowForCurrentVideo
{
	[self willChangeValueForKey:@"currentWindowVideoScaling"];
	NSRect newFrame = [self windowFrameRectForCurrentVideo];
	[[glView window] setFrame:newFrame display:YES animate:NO];
	// did-change notice gets posted when we receive the delegate message
}

#pragma mark Clients

- (void)handleServerChange
{
	// clear out UI
	[availableServersMenu removeAllItems];
	BOOL selectedServerStillExists = NO;
	for(NSDictionary* serverDescription in [[SyphonServerDirectory sharedDirectory] servers])
	{
		// These are the keys we can use in the server description dictionary.
		NSString* name = [serverDescription objectForKey:SyphonServerDescriptionNameKey];
		NSString* appName = [serverDescription objectForKey:SyphonServerDescriptionAppNameKey];
		NSString *uuid = [serverDescription objectForKey:SyphonServerDescriptionUUIDKey];
		NSImage* appImage = [serverDescription objectForKey:SyphonServerDescriptionIconKey];
		
		NSString *title = [NSString stringWithString:appName];
		// A server may not have a name (usually if it is the only server in an application)
		if ([name length] > 0)
		{
			title = [name stringByAppendingFormat:@" - %@", title, nil];
		}
		
		// Create a new menu item for this server
		NSMenuItem* serverMenuItem = [[NSMenuItem alloc] initWithTitle:title action:@selector(setServer:) keyEquivalent:@""];
		[serverMenuItem setRepresentedObject:serverDescription];
		
		[serverMenuItem setImage:appImage];
		
		[[availableServersMenu menu] addItem:serverMenuItem];
		
		if([uuid isEqualToString:self.selectedServersUUID])
		{
			selectedServerStillExists = YES;
			[availableServersMenu selectItem:serverMenuItem];
		}
		
		[serverMenuItem release];
	}
	// If the server our current client was based on just died, set a new one
	if (self.selectedServersUUID == nil || selectedServerStillExists == NO)
	{
		self.FPS = 0;
		if ([availableServersMenu numberOfItems] > 0)
		{
			[self setServer:[availableServersMenu selectedItem]];
		} else {
			self.FPS = 0;
			self.frameWidth = 0;
			self.frameHeight = 0;			
			[syClient stop];
			[syClient release];
			syClient = nil;
			[glView setSyClient:nil];
			[glView setNeedsDisplay:YES];
		}
	}	
}

// Here we build our UI in response to changing bindings in our syClient, using KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
//	NSLog(@"Changes happened in Syphon Client : %@ change:%@", object, change);
	
	if([keyPath isEqualToString:@"servers"])
	{
		[self handleServerChange];
	}		
}

- (IBAction) setServer:(id)sender
{
	// In handleServerChange we set the represented objects of the menu items to be the server-descriptions we got from SyphonServerDirectory
	// so now we use that to create a new client.
	
	NSString *newUUID = [[sender representedObject] objectForKey:SyphonServerDescriptionUUIDKey];
	
	if (newUUID && [self.selectedServersUUID isEqualToString:newUUID])
	{
		// If our current client has been selected we can do nothing
		return;
	}
	
	self.selectedServersUUID = newUUID;
	// Stop our current client
	[syClient stop];
	[syClient release];
	// Reset our terrible FPS display
	fpsStart = [NSDate timeIntervalSinceReferenceDate];
	fpsCount = 0;
	self.FPS = 0;
	syClient = [[SyphonClient alloc] initWithServerDescription:[sender representedObject] options:nil newFrameHandler:^(SyphonClient *client) {
		// This gets called whenever the client receives a new frame.
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
			[self resizeWindowForCurrentVideo];
		}
		// ...then mark our view as needing display, it will get the frame when it's ready to draw
		[glView setNeedsDisplay:YES];
	}];
	// Our view uses the client to draw, so keep it up to date
	[glView setSyClient:syClient];
	// If we have no client we need to clear our display
	// If we have a client we do nothing - wait until it outputs a frame
	if (syClient == nil)
	{
		self.frameWidth = 0;
		self.frameHeight = 0;
		[glView setNeedsDisplay:YES];
	}
}

@end

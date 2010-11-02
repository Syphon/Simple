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

@synthesize selectedServersUUID;

@synthesize FPS;

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
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
	self.selectedServersUUID = [[sender representedObject] objectForKey:SyphonServerDescriptionUUIDKey];
	// Stop our current client
	[syClient stop];
	[syClient release];
	// Reset our terrible FPS display
	fpsStart = [NSDate timeIntervalSinceReferenceDate];
	fpsCount = 0;
	syClient = [[SyphonClient alloc] initWithServerDescription:[sender representedObject] options:nil newFrameHandler:^(SyphonClient *client) {
		// This gets called whenever the client receives a new frame.
		// First we track our framerate...
		fpsCount++;
		float elapsed = [NSDate timeIntervalSinceReferenceDate] - fpsStart;
		if (elapsed > 1.0)
		{
			self.FPS = fpsCount / elapsed;
			fpsStart = [NSDate timeIntervalSinceReferenceDate];
			fpsCount = 0;
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
		[glView setNeedsDisplay:YES];
	}
}

@end

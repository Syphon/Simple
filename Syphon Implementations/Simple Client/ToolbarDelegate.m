//
//  ToolbarDelegate.m
//  Simple Client
//
//  Created by Tom on 20/06/2011.
//  Copyright 2011 Tom Butterworth. All rights reserved.
//

#import "ToolbarDelegate.h"

@implementation ToolbarDelegate

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:@"ServersMenuItemIdentifier",
            NSToolbarFlexibleSpaceItemIdentifier, @"StatusItemIdentifier",
            NSToolbarFlexibleSpaceItemIdentifier, @"FixedWidthItemIdentifier", nil];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:@"ServersMenuItemIdentifier", NSToolbarFlexibleSpaceItemIdentifier, @"StatusItemIdentifier", @"FixedWidthItemIdentifier", nil];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
    if ([itemIdentifier isEqualToString:@"ServersMenuItemIdentifier"])
    {
        [item setLabel:@"Source"];
        [item setPaletteLabel:@"Source"];
        [item setToolTip:@"Select a Syphon Server"];
        [item setView:availableServersMenu];
        NSMenuItem *menuForm = [[[NSMenuItem alloc] init] autorelease];
        [menuForm setMenu:[availableServersMenu menu]];
        [item setMenuFormRepresentation:menuForm];
    }
    else if ([itemIdentifier isEqualToString:@"StatusItemIdentifier"])
    {
        [item setLabel:@"Status"];
        [item setPaletteLabel:@"Status"];
        [item setToolTip:@"Status"];
        [statusBox setCornerRadius:4.0];
        [item setView:statusBox];
        [item setMinSize:(NSSize){40.0, [statusBox frame].size.height}];
        [item setMaxSize:[statusBox frame].size];
    }
    else if ([itemIdentifier isEqualToString:@"FixedWidthItemIdentifier"])
    {
        // This keeps the status centered unless the window is small, at which point it shrinks out of the way
        NSView *empty = [[NSView alloc] initWithFrame:[availableServersMenu frame]];
        [item setView:empty];
        [item setMinSize:(NSSize){0.0, [empty frame].size.height}];
        [item setMaxSize:[empty frame].size];
    }
    else
    {
        NSLog(@"Unexpect toolbar item %@", itemIdentifier);
        item = nil;
    }
    return item;
}
@end

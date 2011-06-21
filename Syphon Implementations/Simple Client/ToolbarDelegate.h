//
//  ToolbarDelegate.h
//  Simple Client
//
//  Created by Tom on 20/06/2011.
//  Copyright 2011 Tom Butterworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ToolbarDelegate : NSObject <NSToolbarDelegate> {
@private
    IBOutlet NSPopUpButton  *availableServersMenu;
    IBOutlet NSBox *statusBox;
}

@end

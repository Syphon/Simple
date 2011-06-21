//
//  ServerDescriptionValueTransformer.m
//  Simple Client
//
//  Created by Tom on 20/06/2011.
//  Copyright 2011 Tom Butterworth. All rights reserved.
//

#import "ServerDescriptionValueTransformer.h"
#import <Syphon/Syphon.h>

@implementation ServerDescriptionValueTransformer
+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return NO; }

- (id)transformedValue:(id)value
{
	if ([value isKindOfClass:[NSArray class]])
	{
        NSMutableArray *transformed = [NSMutableArray arrayWithCapacity:[value count]];
        for (NSDictionary *description in value) {
            // These are the keys we can use in the server description dictionary.
            NSString* name = [description objectForKey:SyphonServerDescriptionNameKey];
            NSString* appName = [description objectForKey:SyphonServerDescriptionAppNameKey];
            
            NSString *title = [NSString stringWithString:appName];
            // A server may not have a name (usually if it is the only server in an application)
            if ([name length] > 0)
            {
                title = [name stringByAppendingFormat:@" - %@", title, nil];
            }
            [transformed addObject:title];
        }
        return transformed;
	}
	return nil;
}	
@end

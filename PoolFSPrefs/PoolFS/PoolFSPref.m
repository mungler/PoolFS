//
//  PoolFSPref.m
//  PoolFS
//
//  Created by Rory Sinclair on 02/06/2011.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "PoolFSPref.h"


@implementation PoolFSPref

- (void) mainViewDidLoad
{
	NSLog(@"well, we can debug at least...");
}

- (IBAction)doSomething:(id)sender
{
	NSLog(@"Hi there");

	// send notification
	NSDistributedNotificationCenter *center = [NSDistributedNotificationCenter defaultCenter];
	
	[center postNotificationName: kPoolFSPreferencesUpdated
						  object: observedObject
						userInfo: nil /* no dictionary */
			  deliverImmediately: YES];
	
} 

@end

// ================================================================
// Copyright (C) 2007 Google Inc.
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//      http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// ================================================================
//
//  LoopbackController.m
//  LoopbackFS
//
//  Created by ted on 12/27/07.
//
#import "PoolFS_Controller.h"
#import "PoolFS_Filesystem.h"
#import <MacFUSE/MacFUSE.h>
#import "NodeManager.h"

@implementation PoolFS_Controller

- (void)mountFailed:(NSNotification *)notification {
	NSLog(@"Got mountFailed notification.");
	
	NSDictionary* userInfo = [notification userInfo];
	NSError* error = [userInfo objectForKey:kGMUserFileSystemErrorKey];
	NSLog(@"kGMUserFileSystem Error: %@, userInfo=%@", error, [error userInfo]);  
	NSRunAlertPanel(@"Mount Failed", [error localizedDescription], nil, nil, nil);
	[[NSApplication sharedApplication] terminate:nil];
}

- (void)didMount:(NSNotification *)notification {
	NSLog(@"Got didMount notification.");
	
	NSDictionary* userInfo = [notification userInfo];
	NSString* mountPath = [userInfo objectForKey:kGMUserFileSystemMountPathKey];
	NSString* parentPath = [mountPath stringByDeletingLastPathComponent];
	[[NSWorkspace sharedWorkspace] selectFile:mountPath
					 inFileViewerRootedAtPath:parentPath];
}

- (void)didUnmount:(NSNotification*)notification {
	NSLog(@"Got didUnmount notification.");
	
	[[NSApplication sharedApplication] terminate:nil];
}

- (void)userPreferencesUpdated:(NSNotification*)notification {
	NSLog(@"got message from prefpane!");
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	//  NSOpenPanel* panel = [NSOpenPanel openPanel];
	//  [panel setCanChooseFiles:NO];
	//  [panel setCanChooseDirectories:YES];
	//  [panel setAllowsMultipleSelection:NO];
	//  int ret = [panel runModalForDirectory:@"/tmp" file:nil types:nil];
	//  if ( ret == NSCancelButton ) {
	//    exit(0);
	//  }
	//  NSArray* paths = [panel filenames];
	//  if ( [paths count] != 1 ) {
	//    exit(0);
	//  }
	//NSString* rootPath = [paths objectAtIndex:0];
	
	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(mountFailed:)
				   name:kGMUserFileSystemMountFailed object:nil];
	[center addObserver:self selector:@selector(didMount:)
				   name:kGMUserFileSystemDidMount object:nil];
	[center addObserver:self selector:@selector(didUnmount:)
				   name:kGMUserFileSystemDidUnmount object:nil];
	
	NSDistributedNotificationCenter* dcenter = [NSDistributedNotificationCenter defaultCenter];
	
	[dcenter addObserver:self selector:@selector(userPreferencesUpdated:)
				   name:kPoolFSPreferencesUpdated object:observedObject];
	
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	// use this if you dont have the plist already created
	//[defaults setObject:[NSArray arrayWithObjects:@"/Volumes/slice1", @"/Volumes/slice2", @"/Volumes/slice3", @"/Volumes/slice4", nil] forKey:@"nodes"];
	//[defaults setObject:[NSArray arrayWithObjects:@"abc/def/redundant", nil] forKey:@"redundant_paths"];
	
	NSArray* nodes = [defaults arrayForKey:@"nodes"];
	NSArray* redundantPaths = [defaults arrayForKey:@"redundant_paths"];
	
	NSLog(@"Using nodes: %@", nodes);
	NSLog(@"Redundant paths: %@", redundantPaths);
	
	NodeManager* manager = [[NodeManager alloc] initWithNodes:nodes andRedundantPaths:redundantPaths];
	
	NSString* mountPath = @"/Volumes/PoolFS";
	fs_delegate_ = [[PoolFS_Filesystem alloc] initWithPoolManager:manager];
	
	fs_ = [[GMUserFileSystem alloc] initWithDelegate:fs_delegate_ isThreadSafe:NO];
	
	NSMutableArray* options = [NSMutableArray array];
	  NSString* volArg = 
	  [NSString stringWithFormat:@"volicon=%@", 
	  [[NSBundle mainBundle] pathForResource:@"PoolFS" ofType:@"icns"]];
	  [options addObject:volArg];
	
	// Do not use the 'native_xattr' mount-time option unless the underlying
	// file system supports native extended attributes. Typically, the user
	// would be mounting an HFS+ directory through LoopbackFS, so we do want
	// this option in that case.
	[options addObject:@"native_xattr"];
	
	[options addObject:@"volname=PoolFS"];
	[fs_ mountAtPath:mountPath 
		 withOptions:options];
}


- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[fs_ unmount];
	[fs_ release];
	[fs_delegate_ release];
	return NSTerminateNow;
}

@end

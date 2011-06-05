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
//  LoopbackFS.m
//  LoopbackFS
//
//  Created by ted on 12/12/07.
//
// This is a simple but complete example filesystem that mounts a local 
// directory. You can modify this to see how the Finder reacts to returning
// specific error codes or not implementing a particular GMUserFileSystem
// operation.
//
// For example, you can mount "/tmp" in /Volumes/loop. Note: It is 
// probably not a good idea to mount "/" through this filesystem.

#import <sys/xattr.h>
#import <sys/stat.h>
#import "PoolFS_Filesystem.h"
#import <MacFUSE/MacFUSE.h>
#import "NSError+POSIX.h"
#import "NodeManager.h"

@implementation PoolFS_Filesystem

- (id)initWithPoolManager:(NodeManager *)manager {
	if ((self = [super init])) {
		_manager = [manager retain];
	}
	return self;
}

- (void) dealloc {
	[_manager release];
	[super dealloc];
}

#pragma mark Moving an Item

- (BOOL)moveItemAtPath:(NSString *)source 
                toPath:(NSString *)destination
                 error:(NSError **)error {
	
	NSLog(@"moveItemAtPath:%@ toPath:%@ START-----------------------", source, destination);
	
	// move the source path to the dest path on the source node (faster I/O)
	NSArray* sourceNodePaths = [_manager nodePathsForPath:source error:error];
	
	for (id sourceNodePath in sourceNodePaths) {
		
		NSString* node = [_manager nodeForPath:source error:error];
		
		NSString* destNodePath = [node stringByAppendingString:destination];
		
		[_manager createDirectoriesForNodePath:destNodePath error:error];
		
		// We use rename directly here since NSFileManager can sometimes fail to 
		// rename and return non-posix error codes.
		
		//NSLog(@"Moving: %@ to %@", sourceNodePath, destNodePath);
		
		int ret = rename([sourceNodePath UTF8String], [destNodePath UTF8String]);
		if ( ret < 0 ) {
			NSLog(@"failed to move with error code %d", ret);
			*error = [NSError errorWithPOSIXCode:errno];
		}
	}
	
	// next we check the number of source nodes == number of dest nodes 
	NSArray* destNodePaths = [_manager nodePathsForPath:destination error:error createNew:YES];

	int sourceCount = [sourceNodePaths count];
	int destCount = [destNodePaths count];

	if (sourceCount != destCount) {
	
		if (sourceCount > destCount) {
			// we're moving an item from a redundant directory to a non-redundant directory, purge one copy
			NSLog(@"moving from redundant to non-redundant - not yet implemented!");
		} else {
			// we're moving an item from a non-redundant directory to a redundant directory, create a redundant copy
			NSLog(@"moving from non-redundant to redundant");
			
			for (id destNodePath in destNodePaths) {
				if (![sourceNodePaths containsObject:destNodePath]) {
					[_manager createDirectoriesForNodePath:destNodePath error:error];
					NSLog(@"copying from %@ to %@",[sourceNodePaths objectAtIndex:0], destNodePath);
					[[NSFileManager defaultManager] copyItemAtPath:[sourceNodePaths objectAtIndex:0] toPath:destNodePath error:error];
				}
			}
		}
	}
	
	NSLog(@"moveItemAtPath:%@ toPath:%@ END-----------------------", source, destination);
	
	return YES; //TODO: handle errors properly
}

#pragma mark Removing an Item

- (BOOL)removeDirectoryAtPath:(NSString *)path error:(NSError **)error {
	// We need to special-case directories here and use the bsd API since 
	// NSFileManager will happily do a recursive remove :-(
	
	NSLog(@"removeDirectoryAtPath:%@",path);
	
	NSArray* nodePaths = [_manager nodePathsForPath:path error:error];
	
	//NSLog(@"found %d nodePaths for path: %@ - deleting", [nodePaths count], path);
	
	for (id nodePath in nodePaths) {
		
		int ret = rmdir([nodePath UTF8String]);
		if (ret < 0) {
			*error = [NSError errorWithPOSIXCode:errno];
			//return NO;
			//TODO: do something with this error
		}		
	}
	
	return YES; // TODO: handle errors properly
}

- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error {
	
	NSLog(@"removeItemAtPath:%@", path);
	
	// NOTE: If removeDirectoryAtPath is commented out, then this may be called
	// with a directory, in which case NSFileManager will recursively remove all
	// subdirectories. So be careful!
	
	for (id nodePath in [_manager nodePathsForPath:path error:error]) {
		[[NSFileManager defaultManager] removeItemAtPath:nodePath error:error];
	}
	
	return YES; // TODO: handle errors properly
}

#pragma mark Creating an Item

- (BOOL)createDirectoryAtPath:(NSString *)path 
                   attributes:(NSDictionary *)attributes
                        error:(NSError **)error {
	
	NSLog(@"createDirectoryAtPath:%@", path);
	
	NSArray* nodePaths = [_manager nodePathsForPath:path error:error createNew:YES];
	
	NSFileManager* fileManager = [NSFileManager defaultManager];
	
	for (id nodePath in nodePaths) {
		[fileManager createDirectoryAtPath:nodePath withIntermediateDirectories:YES attributes:attributes error:error];
	}
	
	return YES; // TODO: handle errors properly
}

- (BOOL)createFileAtPath:(NSString *)path 
              attributes:(NSDictionary *)attributes
                userData:(id *)userData
                   error:(NSError **)error {
	
	NSLog(@"createFileAtPath: %@", path);
	
	NSArray* nodePaths = [_manager nodePathsForPath:path error:error createNew:YES];
	
	for (id nodePath in nodePaths) {
		mode_t mode = [[attributes objectForKey:NSFilePosixPermissions] longValue];  
		int fd = creat([nodePath UTF8String], mode);
		if ( fd < 0 ) {
			*error = [NSError errorWithPOSIXCode:errno];
			NSLog(@"create failed");
			//return NO;
		}
		*userData = [NSNumber numberWithLong:fd];
		//NSLog(@"create succss");
		//return YES;
	}
	
	return YES; // TODO: handle errors correctly
	
}

#pragma mark Linking an Item

- (BOOL)linkItemAtPath:(NSString *)path
                toPath:(NSString *)otherPath
                 error:(NSError **)error {
	
	NSLog(@"linkItemAtPath:%@ toPath:%@", path, otherPath);
	
	NSArray* nodePaths = [_manager nodePathsForPath:path error:error createNew:YES];
	NSArray* otherNodePaths = [_manager nodePathsForPath:otherPath error:error createNew:YES forNodePaths:nodePaths];
	
	int i;
	
	for (i = 0; i < [nodePaths count]; i++) {
		
		// We use link rather than the NSFileManager equivalent because it will copy
		// the file rather than hard link if part of the root path is a symlink.
		
		int rc = link([[nodePaths objectAtIndex:i] UTF8String], [[otherNodePaths objectAtIndex:i] UTF8String]);
		if ( rc <  0 ) {
			*error = [NSError errorWithPOSIXCode:errno];
			//return NO;
		}
		//return YES;
	}
	
	return YES; // TODO: handle errors properly
	
}

#pragma mark Symbolic Links

- (BOOL)createSymbolicLinkAtPath:(NSString *)path 
             withDestinationPath:(NSString *)otherPath
                           error:(NSError **)error {
	
	NSLog(@"createSymbolicLinkAtPath:%@ withDestinationPath:%@", path, otherPath);
	
	NSArray* sourceNodePaths = [_manager nodePathsForPath:path error:error];
	NSArray* destNodePaths = [_manager nodePathsForPath:otherPath error:error createNew:YES forNodePaths:sourceNodePaths];
	
	NSFileManager* fileManager = [NSFileManager defaultManager];
	
	int i;
	for (i = 0; i < [sourceNodePaths count]; i++) {
		[fileManager createSymbolicLinkAtPath:[sourceNodePaths objectAtIndex:i] withDestinationPath:[destNodePaths objectAtIndex:i] error:error];
	}
	
	return YES; //TODO: handle errors properly  
}

- (NSString *)destinationOfSymbolicLinkAtPath:(NSString *)path
                                        error:(NSError **)error {
	
	NSLog(@"destinationOfSymbolicLinkAtPath:%@", path);
	return [[_manager nodePathsForPath:path error:error firstOnly:YES] objectAtIndex:0]; //TODO: ditch the array for firstOnly
}

#pragma mark File Contents

- (BOOL)openFileAtPath:(NSString *)path 
                  mode:(int)mode
              userData:(id *)userData
                 error:(NSError **)error {
	NSLog(@"openFileAtPath:%@ mode:%d", path, mode);
	NSString* p = [[_manager nodePathsForPath:path error:error firstOnly:YES] objectAtIndex:0]; //TODO: ditch the array for firstOnly
	int fd = open([p UTF8String], mode);
	if ( fd < 0 ) {
		*error = [NSError errorWithPOSIXCode:errno];
		return NO;
	}
	*userData = [NSNumber numberWithLong:fd];
	return YES;
}

- (void)releaseFileAtPath:(NSString *)path userData:(id)userData {
	NSLog(@"releaseFileAtPath:%@",path);
	NSNumber* num = (NSNumber *)userData;
	int fd = [num longValue];
	close(fd);
}

- (int)readFileAtPath:(NSString *)path 
             userData:(id)userData
               buffer:(char *)buffer 
                 size:(size_t)size 
               offset:(off_t)offset
                error:(NSError **)error {
	
	NSLog(@"readFileAtPath:%@",path);
	
	NSNumber* num = (NSNumber *)userData;
	int fd = [num longValue];
	int ret = pread(fd, buffer, size, offset);
	if ( ret < 0 ) {
		*error = [NSError errorWithPOSIXCode:errno];
		return -1;
	}
	return ret;
}

- (int)writeFileAtPath:(NSString *)path 
              userData:(id)userData
                buffer:(const char *)buffer
                  size:(size_t)size 
                offset:(off_t)offset
                 error:(NSError **)error {
	
	NSLog(@"writeFileAtPath:%@", path);
	
	NSArray* nodePaths = [_manager nodePathsForPath:path error:error createNew:YES];
	
	int ret;
	
	for (id nodePath in nodePaths) {
		NSFileHandle* handle = [NSFileHandle fileHandleForWritingAtPath:nodePath];
		
		int fd = [handle fileDescriptor];
		
		ret = pwrite(fd, buffer, size, offset);
		if ( ret < 0 ) {
			*error = [NSError errorWithPOSIXCode:errno];
			//return -1;
		}
		
	}
	
	return ret;
}

// TODO: need to fix this... needs thinking about
- (BOOL)exchangeDataOfItemAtPath:(NSString *)path1
                  withItemAtPath:(NSString *)path2
                           error:(NSError **)error {
	
	NSLog(@"exchangeDataOfItemAtPath:%@ withItemAtPath:%@ ***************************", path1, path2);
	
	//
	//	NSArray* paths1 = [_manager nodePathsForPath:path1 error:error];
	//	NSArray* paths2 = [_manager nodePathsForPath:path2 error:error];
	//	
	//	int i = 0;
	//	
	//	(for i = 0; i < [paths1 count]; i++)
	//	{
	//		
	//	}
	
	//  int ret = exchangedata([p1 UTF8String], [p2 UTF8String], 0);
	//  if ( ret < 0 ) {
	//    *error = [NSError errorWithPOSIXCode:errno];
	//    return NO;    
	//  }
	return YES;  
}

#pragma mark Directory Contents

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
	
	NSLog(@"contentsOfDirectoryAtPath:%@", path);
	
	NSArray* nodePaths = [_manager nodePathsForPath:path error:error];
	
	NSMutableArray* arr = [[NSMutableArray alloc] init];
	
	for (id nodePath in nodePaths) {
		[arr addObjectsFromArray:[[NSFileManager defaultManager] contentsOfDirectoryAtPath:nodePath error:error]];
	}
	
	// dedupe the result
	return [[NSSet setWithArray:arr] allObjects];
}

#pragma mark Getting and Setting Attributes

- (NSDictionary *)attributesOfItemAtPath:(NSString *)path
                                userData:(id)userData
                                   error:(NSError **)error {
	
	NSLog(@"attributesOfItemAtPath:%@",path);
	
	NSString* p = [[_manager nodePathsForPath:path error:error firstOnly:YES] objectAtIndex:0];
	NSDictionary* attribs = 
    [[NSFileManager defaultManager] attributesOfItemAtPath:p error:error];
	//NSLog(@"Attr: %@", attribs);
	
	return attribs;
}

- (NSDictionary *)attributesOfFileSystemForPath:(NSString *)path
                                          error:(NSError **)error {
	
	NSLog(@"attributesOfFileSystemForPath:%@", path);
	NSString* p = [[_manager nodePathsForPath:path error:error firstOnly:YES] objectAtIndex:0];
	NSDictionary* d =
    [[NSFileManager defaultManager] attributesOfFileSystemForPath:p error:error];
	if (d) {
		NSMutableDictionary* attribs = [NSMutableDictionary dictionaryWithDictionary:d];
		[attribs setObject:[NSNumber numberWithBool:YES]
					forKey:kGMUserFileSystemVolumeSupportsExtendedDatesKey];
		return attribs;
	}
	return nil;
}

- (BOOL)setAttributes:(NSDictionary *)attributes 
         ofItemAtPath:(NSString *)path
             userData:(id)userData
                error:(NSError **)error {
	NSLog(@"setAttributes:ofItemAtPath:%@",path);
	
	NSArray* nodePaths = [_manager nodePathsForPath:path error:error];
	
	for (id nodePath in nodePaths) {
		
		// TODO: Handle other keys not handled by NSFileManager setAttributes call.
		
		NSNumber* offset = [attributes objectForKey:NSFileSize];
		if ( offset ) {
			int ret = truncate([nodePath UTF8String], [offset longLongValue]);
			if ( ret < 0 ) {
				*error = [NSError errorWithPOSIXCode:errno];
				//return NO;    
			}
		}
		NSNumber* flags = [attributes objectForKey:kGMUserFileSystemFileFlagsKey];
		if (flags != nil) {
			int rc = chflags([nodePath UTF8String], [flags intValue]);
			if (rc < 0) {
				*error = [NSError errorWithPOSIXCode:errno];
				//return NO;
			}
		}
		[[NSFileManager defaultManager] setAttributes:attributes
										 ofItemAtPath:nodePath
												error:error];
		
	}
	
	return YES; //TODO: handle errors properly
}

#pragma mark Extended Attributes

- (NSArray *)extendedAttributesOfItemAtPath:(NSString *)path error:(NSError **)error {
	
	NSLog(@"extendedAttributesOfItemAtPath:%@",path);
	
	NSString* p = [[_manager nodePathsForPath:path error:error firstOnly:YES] objectAtIndex:0];
	
	ssize_t size = listxattr([p UTF8String], nil, 0, 0);
	if ( size < 0 ) {
		*error = [NSError errorWithPOSIXCode:errno];
		return nil;
	}
	NSMutableData* data = [NSMutableData dataWithLength:size];
	size = listxattr([p UTF8String], [data mutableBytes], [data length], 0);
	if ( size < 0 ) {
		*error = [NSError errorWithPOSIXCode:errno];
		return nil;
	}
	NSMutableArray* contents = [NSMutableArray array];
	char* ptr = (char *)[data bytes];
	while ( ptr < ((char *)[data bytes] + size) ) {
		NSString* s = [NSString stringWithUTF8String:ptr];
		[contents addObject:s];
		ptr += ([s length] + 1);
	}
	return contents;
}

- (NSData *)valueOfExtendedAttribute:(NSString *)name 
                        ofItemAtPath:(NSString *)path
                            position:(off_t)position
                               error:(NSError **)error {  
	
	NSLog(@"valueOfExtendedAttribute:ofItemAtPath:%@",path);
	
	NSString* p = [[_manager nodePathsForPath:path error:error firstOnly:YES] objectAtIndex:0];
	
	ssize_t size = getxattr([p UTF8String], [name UTF8String], nil, 0,
							position, 0);
	if ( size < 0 ) {
		*error = [NSError errorWithPOSIXCode:errno];
		return nil;
	}
	NSMutableData* data = [NSMutableData dataWithLength:size];
	size = getxattr([p UTF8String], [name UTF8String], 
					[data mutableBytes], [data length],
					position, 0);
	if ( size < 0 ) {
		*error = [NSError errorWithPOSIXCode:errno];
		return nil;
	}  
	return data;
}

- (BOOL)setExtendedAttribute:(NSString *)name 
                ofItemAtPath:(NSString *)path 
                       value:(NSData *)value
                    position:(off_t)position
					 options:(int)options
                       error:(NSError **)error {
	
	NSLog(@"setExtendedAttribute:ofItemAtPath:%@",path);
	
	// Setting com.apple.FinderInfo happens in the kernel, so security related 
	// bits are set in the options. We need to explicitly remove them or the call
	// to setxattr will fail.
	// TODO: Why is this necessary?
	
	options &= ~(XATTR_NOSECURITY | XATTR_NODEFAULT);
	
	NSArray* nodePaths = [_manager nodePathsForPath:path error:error];
	
	for (id nodePath in nodePaths) {
		
		int ret = setxattr([nodePath UTF8String], [name UTF8String], 
						   [value bytes], [value length], 
						   position, options);
		if ( ret < 0 ) {
			*error = [NSError errorWithPOSIXCode:errno];
			//return NO;
		}
	}
	
	
	return YES; //TODO: handle errors properly
}

- (BOOL)removeExtendedAttribute:(NSString *)name
                   ofItemAtPath:(NSString *)path
                          error:(NSError **)error {
	
	NSLog(@"removeExtendedAttribute:ofItemAtPath:%@",path);
	
	NSArray* nodePaths = [_manager nodePathsForPath:path error:error];
	
	int ret;
	
	for (id nodePath in nodePaths) {
		
		ret = removexattr([nodePath UTF8String], [name UTF8String], 0);
		if ( ret < 0 ) {
			*error = [NSError errorWithPOSIXCode:errno];
			//return NO;
		}
	}
	
	return YES; //TODO: handle errors properly
}

@end

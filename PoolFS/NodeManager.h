//
//  PoolManager.h
//  PoolFS
//
//  Created by Rory Sinclair on 26/05/2011.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NodeManager : NSObject {
	NSArray * _nodes;
	NSArray * _redundantPaths;
}

-(id) initWithNodes:(NSArray*)nodes andRedundantPaths:(NSArray*)redundantPaths;
-(void) dealloc;

-(NSString*) nodeForPath:(NSString*)path error:(NSError **)error;

// TODO: change these to return id so firstOnly can return a single path
-(NSArray*) nodePathsForPath:(NSString*)path error:(NSError **)error;
-(NSArray*) nodePathsForPath:(NSString*)path error:(NSError **)error firstOnly:(BOOL)firstOnly;
-(NSArray*) nodePathsForPath:(NSString*)path error:(NSError **)error createNew:(BOOL)createNew;
-(NSArray*) nodePathsForPath:(NSString*)path error:(NSError **)error createNew:(BOOL)createNew forNodePaths:(NSArray*)nodePaths;
-(NSArray*) nodePathsForPath:(NSString*)path error:(NSError **)error includePaths:(BOOL)includePaths;
-(NSArray*) nodePathsForPath:(NSString*)path error:(NSError **)error firstOnly:(BOOL)firstOnly createNew:(BOOL)createNew forNodePaths:(NSArray*)nodePaths includePaths:(BOOL)includePaths;

-(BOOL) createDirectoriesForNodePath:(NSString*)path error:(NSError**)error;

-(BOOL) isRedundantPath:(NSString*)path;

@end

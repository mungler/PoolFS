//
//  PoolFS_Filesystem.h
//  PoolFS
//
//  Created by Rory Sinclair on 02/06/2011.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//
// Filesystem operations.
//
#import <Foundation/Foundation.h>
#import "NodeManager.h"

@interface PoolFS_Filesystem : NSObject  {
	NodeManager* _manager;
}
- (id)initWithPoolManager:(NodeManager *)manager;
- (void)dealloc;

@end

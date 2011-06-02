//
//  PoolFS_Controller.h
//  PoolFS
//
//  Created by Rory Sinclair on 02/06/2011.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//
#import <Cocoa/Cocoa.h>

@class GMUserFileSystem;
@class PoolFS_Controller;

@interface PoolFS_Controller : NSObject {
  GMUserFileSystem* fs_;
  PoolFS_Controller* fs_delegate_;
}

@end


//
//  TMAppDelegate.h
//  TrackMe
//
//  Created by Frederik on 05/12/13.
//  Copyright (c) 2013 EMRG. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TMAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

- (IBAction)getWindowList:(id)sender;
- (IBAction)getMouseLocation:(id)sender;
- (void)logMouseLocation:(NSTimer *)timer;

@end

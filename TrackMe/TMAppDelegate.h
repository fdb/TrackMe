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
@property (assign) IBOutlet NSMenu *statusMenu;

- (IBAction)exportData:(id)sender;

@end

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

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

- (IBAction)saveAction:(id)sender;

@end

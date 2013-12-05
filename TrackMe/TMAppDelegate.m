//
//  TMAppDelegate.m
//  TrackMe
//
//  Created by Frederik on 05/12/13.
//  Copyright (c) 2013 EMRG. All rights reserved.
//

#import "TMAppDelegate.h"
#include <sqlite3.h>

sqlite3 *db;
sqlite3_stmt *insert_statement;
NSStatusItem * statusItem;

@implementation TMAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    int err;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *appSupportPath = [paths objectAtIndex:0];
    appSupportPath = [appSupportPath stringByAppendingPathComponent:@"TrackMe"];
    NSString *dbPath = [appSupportPath stringByAppendingPathComponent:@"trackme.db"];
    [[NSFileManager defaultManager] createDirectoryAtPath:appSupportPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    err = sqlite3_open([dbPath UTF8String], &db);
    if (err) {
        NSLog(@"Can't open database: %s", sqlite3_errmsg(db));
        sqlite3_close(db);
        exit(-1);
    }
    
    err = sqlite3_exec(db,
                       "CREATE TABLE IF NOT EXISTS mousepositions ("
                       "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                       "time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,"
                       "x INTEGER,"
                       "y INTEGER)", NULL, NULL, NULL);
    if (err) {
        NSLog(@"Can't create table mousepositions: %s", sqlite3_errmsg(db));
        sqlite3_close(db);
        exit(-1);
    }
    
    err = sqlite3_prepare_v2(db, "INSERT INTO mousepositions (X, Y) VALUES (?, ?)", -1, &insert_statement, NULL);
    if (err) {
        NSLog(@"Can't create prepare insert statement: %s", sqlite3_errmsg(db));
        sqlite3_close(db);
        exit(-1);
    }
    
    [self addAppAsLoginItem];
    
    [NSTimer scheduledTimerWithTimeInterval: 2 target:self selector:@selector(logMouseLocation:) userInfo:NULL repeats:true];
    
}

-(void)awakeFromNib{
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    [statusItem setMenu:_statusMenu];

    [statusItem setImage:[NSImage imageNamed:@"menu_icon"]];
    [statusItem setHighlightMode:YES];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    sqlite3_close(db);
}
                                                                              
- (void)logMouseLocation:(NSTimer *)timer
{
    NSPoint loc =[NSEvent mouseLocation];

    sqlite3_reset(insert_statement);
    sqlite3_clear_bindings(insert_statement);
    sqlite3_bind_int(insert_statement, 1, (int) loc.x);
    sqlite3_bind_int(insert_statement, 2, (int) loc.y);
    int err = sqlite3_step(insert_statement);
    if (err != SQLITE_DONE && err != SQLITE_OK) {
        NSLog(@"Can't insert mouse position: %s", sqlite3_errmsg(db));
    }
}

- (void)getWindowList:(id)sender
{
    CGWindowListOption listOptions = kCGWindowListOptionAll;
    CFArrayRef windowList = CGWindowListCopyWindowInfo(listOptions, kCGNullWindowID);
    NSLog(@"%@", windowList);

}

- (void)getMouseLocation:(id)sender
{
    
    NSPoint loc =[NSEvent mouseLocation];
    NSLog(@"X: %f Y: %f", loc.x, loc.y );
    
}


- (void) addAppAsLoginItem
{
	NSString * appPath = [[NSBundle mainBundle] bundlePath];
    
	// This will retrieve the path for the application
	// For example, /Applications/test.app
	CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:appPath];
    
	// Create a reference to the shared file list.
    // We are adding it to the current user only.
    // If we want to add it all users, use
    // kLSSharedFileListGlobalLoginItems instead of
    //kLSSharedFileListSessionLoginItems
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL,
                                                            kLSSharedFileListSessionLoginItems, NULL);
	if (loginItems) {
		//Insert an item to the list.
		LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems,
                                                                     kLSSharedFileListItemLast, NULL, NULL,
                                                                     url, NULL, NULL);
		if (item){
			CFRelease(item);
        }
	}
    
	CFRelease(loginItems);
}

- (void) deleteAppFromLoginItem
{
	NSString * appPath = [[NSBundle mainBundle] bundlePath];
    
	// This will retrieve the path for the application
	// For example, /Applications/test.app
	CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:appPath];
    
	// Create a reference to the shared file list.
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL,
                                                            kLSSharedFileListSessionLoginItems, NULL);
    
	if (loginItems) {
		UInt32 seedValue;
		//Retrieve the list of Login Items and cast them to
		// a NSArray so that it will be easier to iterate.
		NSArray  *loginItemsArray = (__bridge NSArray *)LSSharedFileListCopySnapshot(loginItems, &seedValue);
		int i = 0;
		for(i ; i< [loginItemsArray count]; i++){
			LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)[loginItemsArray
                                                                        objectAtIndex:i];
			//Resolve the item with URL
			if (LSSharedFileListItemResolve(itemRef, 0, (CFURLRef*) &url, NULL) == noErr) {
				NSString * urlPath = [(__bridge NSURL*)url path];
				if ([urlPath compare:appPath] == NSOrderedSame){
					LSSharedFileListItemRemove(loginItems,itemRef);
				}
			}
		}
	}
}

@end

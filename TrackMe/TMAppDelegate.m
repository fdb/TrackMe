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

- (IBAction)exportData:(id)sender
{
    NSArray* fileTypes = [[NSArray alloc] initWithObjects:@"csv", nil];
    
    NSSavePanel *panel = [NSSavePanel savePanel];
    [panel setTitle:@"Export data to CSV"];
    [panel setAllowedFileTypes:fileTypes];
    NSInteger clicked = [panel runModal];
    if (clicked == NSFileHandlingPanelOKButton) {
        [self doExport:[panel URL]];
    }
}

- (void)doExport:(NSURL *)path
{
    sqlite3_stmt *stmt;
    NSMutableString *csv = [NSMutableString string];
    [csv appendString:@"id,time,x,y"];
    int err = sqlite3_prepare_v2(db, "SELECT id, time, x, y FROM mousepositions", -1, &stmt, NULL);
    if (err) {
        NSLog(@"Can't export mouse positions: %s", sqlite3_errmsg(db));
    }
    
    int result = sqlite3_step(stmt);
    while (result == SQLITE_ROW) {
        int id = sqlite3_column_int(stmt, 0);
        const unsigned char *text = sqlite3_column_text(stmt, 1);
        NSString *timestamp = @"";
        if (text) {
            NSUInteger length = sqlite3_column_bytes(stmt, 1);
            timestamp = [[NSString alloc] initWithBytes:text length:length encoding:NSUTF8StringEncoding];
        }
        int x = sqlite3_column_int(stmt, 2);
        int y = sqlite3_column_int(stmt, 3);
        [csv appendString:[NSString stringWithFormat:@"\n%i,%@,%i,%i", id, timestamp, x, y]];
        result = sqlite3_step(stmt);
    }
    NSError *error;

    BOOL ok = [csv writeToURL:path atomically:YES
                        encoding:NSUTF8StringEncoding error:&error];
    if (!ok) {
        NSLog(@"Error writing file at %@\n%@",
              path, [error localizedFailureReason]);
    }
}

@end

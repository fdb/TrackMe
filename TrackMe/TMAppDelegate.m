#import "TMAppDelegate.h"
#include <sqlite3.h>

sqlite3 *db;
sqlite3_stmt *mouse_positions_stmt;
sqlite3_stmt *keystrokes_stmt;
NSStatusItem * statusItem;
id keyMonitor = NULL;
id mouseMonitor = NULL;

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
                       "CREATE TABLE IF NOT EXISTS mouse ("
                       "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                       "time TIMESTAMP DATETIME DEFAULT(STRFTIME('%Y-%m-%d %H:%M:%f', 'NOW')),"
                       "x INTEGER,"
                       "y INTEGER)", NULL, NULL, NULL);
    if (err) {
        NSLog(@"Can't create mouse table: %s", sqlite3_errmsg(db));
        sqlite3_close(db);
        exit(-1);
    }

    err = sqlite3_prepare_v2(db, "INSERT INTO mouse (X, Y) VALUES (?, ?)", -1, &mouse_positions_stmt, NULL);
    if (err) {
        NSLog(@"Can't prepare mouse insert statement: %s", sqlite3_errmsg(db));
        sqlite3_close(db);
        exit(-1);
    }

    err = sqlite3_exec(db,
                       "CREATE TABLE IF NOT EXISTS keys ("
                       "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                       "time TIMESTAMP DATETIME DEFAULT(STRFTIME('%Y-%m-%d %H:%M:%f', 'NOW')),"
                       "key TEXT)", NULL, NULL, NULL);
    if (err) {
        NSLog(@"Can't create keys table: %s", sqlite3_errmsg(db));
        sqlite3_close(db);
        exit(-1);
    }

    err = sqlite3_prepare_v2(db, "INSERT INTO keys (key) VALUES (?)", -1, &keystrokes_stmt, NULL);
    if (err) {
        NSLog(@"Can't prepare keys insert statement: %s", sqlite3_errmsg(db));
        sqlite3_close(db);
        exit(-1);
    }

    [self addAppAsLoginItem];

    BOOL logMouse = [[NSUserDefaults standardUserDefaults] boolForKey:@"LogMouse"];
    BOOL logKeys = [[NSUserDefaults standardUserDefaults] boolForKey:@"LogKeys"];
    [[self logMouseMenu] setState:logMouse ? NSControlStateValueOn : NSControlStateValueOff];
    [[self logKeysMenu] setState:logKeys ? NSControlStateValueOn : NSControlStateValueOff];

    NSDictionary *options = @{(__bridge id)kAXTrustedCheckOptionPrompt: (id)kCFBooleanFalse};
    BOOL accessibilityEnabled = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);

    if (accessibilityEnabled) {
        if (logMouse) {
            [self startLoggingMouse];
        }
        if (logKeys) {
            [self startLoggingKeys];
        }
        if (!logMouse && !logKeys) {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:@"OK"];
            [alert setMessageText:@"TrackMe isn't logging anything."];
            [alert setInformativeText:@"Both mouse and key logging is turned off. Please enable one or both of them."];
            [alert setAlertStyle:NSAlertStyleWarning];
            [alert runModal];

        }
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Open accessibility settings"];
        [alert setMessageText:@"Enable access for assistive devices."];
        [alert setInformativeText:@"TrackMe needs access for assistive devices. Unlock the panel and enable TrackMe. Afterwards, start the app again."];
        [alert setAlertStyle:NSAlertStyleCritical];
        [alert runModal];

        NSString *urlString = @"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility";
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];

        [NSApp terminate:self];
    }
}

-(void)awakeFromNib
{
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    [statusItem setMenu:_statusMenu];
    NSImage* icon =[NSImage imageNamed:@"menu_icon"];
    icon.template = YES;
    statusItem.button.image = icon;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    sqlite3_close(db);
}

- (void)addAppAsLoginItem
{
	NSString * appPath = [[NSBundle mainBundle] bundlePath];
	CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:appPath];
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	if (loginItems) {
		LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems,
                                                                     kLSSharedFileListItemLast, NULL, NULL,
                                                                     url, NULL, NULL);
		if (item) {
			CFRelease(item);
        }
	}
	CFRelease(loginItems);
}

- (IBAction)toggleMouseLogging:(id)sender
{
    NSInteger state = [(NSMenuItem *)sender state];
    BOOL isLogging;
    if (state == NSControlStateValueOn) {
        [sender setState:NSControlStateValueOff];
        [self stopLoggingMouse];
        isLogging = false;
    } else {
        [sender setState:NSControlStateValueOn];
        [self startLoggingMouse];
        isLogging = true;
    }
    [[NSUserDefaults standardUserDefaults] setBool:isLogging forKey:@"LogMouse"];
}

- (void)startLoggingMouse
{
    [self stopLoggingMouse];
    NSLog(@"Start logging mouse");
    mouseMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskMouseMoved handler:^(NSEvent *event) {
        [self logMouseMoved:event];
    }];
}

- (void)stopLoggingMouse
{
    if (mouseMonitor != NULL) {
        NSLog(@"Stop logging mouse");
        [NSEvent removeMonitor:mouseMonitor];
        mouseMonitor = NULL;
    }
}

- (void)logMouseMoved:(NSEvent *)event
{
    NSPoint loc =[NSEvent mouseLocation];

    sqlite3_reset(mouse_positions_stmt);
    sqlite3_clear_bindings(mouse_positions_stmt);
    sqlite3_bind_int(mouse_positions_stmt, 1, (int) loc.x);
    sqlite3_bind_int(mouse_positions_stmt, 2, (int) loc.y);
    int err = sqlite3_step(mouse_positions_stmt);
    if (err != SQLITE_DONE && err != SQLITE_OK) {
        NSLog(@"Can't insert mouse position: %s", sqlite3_errmsg(db));
    }
}

- (IBAction)toggleKeyLogging:(id)sender
{
    NSInteger state = [(NSMenuItem *)sender state];
    BOOL isLogging;
    if (state == NSControlStateValueOn) {
        [sender setState:NSControlStateValueOff];
        [self stopLoggingKeys];
        isLogging = false;
    } else {
        [sender setState:NSControlStateValueOn];
        [self startLoggingKeys];
        isLogging = true;
    }
    [[NSUserDefaults standardUserDefaults] setBool:isLogging forKey:@"LogKeys"];
}

- (void)startLoggingKeys
{
    [self stopLoggingKeys];
    NSLog(@"Start logging keys");
    keyMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^(NSEvent *event) {
        [self logKeyDown:event];
    }];
}

- (void)stopLoggingKeys
{
    if (keyMonitor != NULL) {
        NSLog(@"Stop logging keys");
        [NSEvent removeMonitor:keyMonitor];
        keyMonitor = NULL;
    }
}

- (void)logKeyDown:(NSEvent *)event
{
    if (event.characters.length == 0) return;
    const char *chars = [event.characters UTF8String];
    int nChars = sizeof(chars);
    sqlite3_reset(keystrokes_stmt);
    sqlite3_clear_bindings(keystrokes_stmt);
    sqlite3_bind_text(keystrokes_stmt, 1, chars, nChars, NULL);
    int err = sqlite3_step(keystrokes_stmt);
    if (err != SQLITE_DONE && err != SQLITE_OK) {
        NSLog(@"Can't insert key stroke: %s", sqlite3_errmsg(db));
    }
}

- (IBAction)exportData:(id)sender
{
    NSArray* fileTypes = [[NSArray alloc] initWithObjects:@"csv", nil];

    NSSavePanel *panel = [NSSavePanel savePanel];
    [panel setTitle:@"Export data to CSV"];
    [panel setAllowedFileTypes:fileTypes];
    NSInteger clicked = [panel runModal];
    if (clicked == NSModalResponseOK) {
        NSInteger tag = [sender tag];
        if (tag == 1) {
            [self doExportMouseData:[panel URL]];
        } else {
            [self doExportKeysData:[panel URL]];
        }
    }
}

- (void)doExportMouseData:(NSURL *)path
{
    sqlite3_stmt *stmt;
    NSMutableString *csv = [NSMutableString string];
    [csv appendString:@"id,time,x,y"];
    int err = sqlite3_prepare_v2(db, "SELECT id, time, x, y FROM mouse", -1, &stmt, NULL);
    if (err) {
        NSLog(@"Can't export mouse data: %s", sqlite3_errmsg(db));
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

- (void)doExportKeysData:(NSURL *)path
{
    sqlite3_stmt *stmt;
    NSMutableString *csv = [NSMutableString string];
    [csv appendString:@"id,time,key"];
    int err = sqlite3_prepare_v2(db, "SELECT id, time, key FROM keys", -1, &stmt, NULL);
    if (err) {
        NSLog(@"Can't export key data: %s", sqlite3_errmsg(db));
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
        const unsigned char *key = sqlite3_column_text(stmt, 2);
        [csv appendString:[NSString stringWithFormat:@"\n%i,%@,%s", id, timestamp, key]];
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

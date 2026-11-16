#import "Patches/ProfileOverview/ProfileOverview.h"
#include <dlfcn.h>

// Chromium keeps every profile's site icons in a Favicons database; macOS's SQLite reads it, loaded when needed.
typedef struct sqlite3 sqlite3;
typedef struct sqlite3_stmt sqlite3_stmt;
static struct {
    int (*open)(const char *, sqlite3 **, int, const char *);
    int (*prepare)(sqlite3 *, const char *, int, sqlite3_stmt **, const char **);
    int (*bind)(sqlite3_stmt *, int, const char *, int, void (*)(void *));
    int (*step)(sqlite3_stmt *);
    const void *(*blob)(sqlite3_stmt *, int);
    int (*bytes)(sqlite3_stmt *, int);
    int (*finalize)(sqlite3_stmt *);
    int (*close)(sqlite3 *);
} DPSQL;

static const int DPSQLReadOnly = 0x01, DPSQLURI = 0x40, DPSQLRow = 100;
static NSMutableDictionary<NSString *, id> *DPLookedUp;  // URL to icon, or NSNull when no database has one.

static BOOL DPLoadSQLite(void) {
    if (DPSQL.open) return YES;
    void *lib = dlopen("/usr/lib/libsqlite3.dylib", RTLD_LAZY);
    if (!lib) return NO;
    const char *names[] = {"sqlite3_open_v2", "sqlite3_prepare_v2", "sqlite3_bind_text", "sqlite3_step", "sqlite3_column_blob", "sqlite3_column_bytes", "sqlite3_finalize", "sqlite3_close"};
    void **slots = (void **)&DPSQL;
    for (int i = 0; i < 8; i++)
        if (!(slots[i] = dlsym(lib, names[i]))) return (BOOL)(DPSQL.open = NULL);
    return YES;
}

static NSArray<NSString *> *DPFaviconFiles(void) {
    NSString *data = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/Dia/User Data"];
    NSMutableArray *files = [NSMutableArray new];
    for (NSString *folder in [NSFileManager.defaultManager contentsOfDirectoryAtPath:data error:nil]) {
        NSString *file = [[data stringByAppendingPathComponent:folder] stringByAppendingPathComponent:@"Favicons"];
        if ([NSFileManager.defaultManager fileExistsAtPath:file]) [files addObject:file];
    }
    return files;
}

static NSImage *DPQuery(sqlite3 *db, NSString *match, BOOL like) {
    NSString *sql = [NSString stringWithFormat:@"SELECT b.image_data FROM icon_mapping m JOIN favicon_bitmaps b ON b.icon_id = m.icon_id "
                                                "WHERE m.page_url %@ ? ORDER BY abs(b.width - 32) LIMIT 1", like ? @"LIKE" : @"="];
    sqlite3_stmt *statement = NULL;
    if (DPSQL.prepare(db, sql.UTF8String, -1, &statement, NULL) != 0) return nil;
    DPSQL.bind(statement, 1, match.UTF8String, -1, (void (*)(void *))-1);
    NSImage *image = nil;
    if (DPSQL.step(statement) == DPSQLRow) {
        int length = DPSQL.bytes(statement, 0);
        if (length > 0) image = [[NSImage alloc] initWithData:[NSData dataWithBytes:DPSQL.blob(statement, 0) length:length]];
    }
    DPSQL.finalize(statement);
    return image;
}

// The page's own icon, else any page on the same site.
void DPOverviewLookUpIcons(NSArray<NSString *> *urls) {
    if (!DPLookedUp) DPLookedUp = [NSMutableDictionary new];
    NSMutableArray<NSString *> *missing = [NSMutableArray new];
    for (NSString *url in urls)  // A tab with no address, like a new tab, gives NSNull.
        if ([url isKindOfClass:NSString.class] && url.length && !DPLookedUp[url]) [missing addObject:url];
    if (!missing.count || !DPLoadSQLite()) return;
    NSMutableArray<NSValue *> *dbs = [NSMutableArray new];
    for (NSString *file in DPFaviconFiles()) {
        sqlite3 *db = NULL;
        NSString *uri = [@"file:" stringByAppendingString:[[file stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet] stringByAppendingString:@"?mode=ro"]];
        if (DPSQL.open(uri.UTF8String, &db, DPSQLReadOnly | DPSQLURI, NULL) == 0) [dbs addObject:[NSValue valueWithPointer:db]];
        else if (db) DPSQL.close(db);
    }
    for (NSString *url in missing) {
        NSURL *parsed = [NSURL URLWithString:url];
        NSString *site = parsed.host ? [NSString stringWithFormat:@"%@://%@/%%", parsed.scheme, parsed.host] : nil;
        NSImage *icon = nil;
        for (NSValue *db in dbs) if ((icon = DPQuery(db.pointerValue, url, NO))) break;
        for (NSValue *db in dbs) if (!icon && site && (icon = DPQuery(db.pointerValue, site, YES))) break;
        DPLookedUp[url] = icon ?: NSNull.null;
    }
    for (NSValue *db in dbs) DPSQL.close(db.pointerValue);
}

NSImage *DPOverviewSiteIcon(NSString *url) {
    id icon = [url isKindOfClass:NSString.class] ? DPLookedUp[url] : nil;
    return [icon isKindOfClass:NSImage.class] ? icon : nil;
}

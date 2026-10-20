@import Cocoa;
@import LuaSkin;

#import "DFZAXSource.h"
#import "DFZController.h"
#import "DFZServer.h"

static LSRefTable refTable = LUA_NOREF;
// The dylib outlives a Hammerspoon config reload (new lua_State, same
// process): the running backend lives here, not in the Lua state.
static DFZController *sController;
static DFZServer *sServer;

static void stopBackend(void) {
    [sServer stop];
    [sController stop];
    sServer = nil;
    sController = nil;
}

static NSString *luaString(lua_State *L, int index) {
    const char *value = lua_tostring(L, index);
    return value ? [NSString stringWithUTF8String:value] : nil;
}

// Accepts both a set ({title = true}) and a list ({"title"}) of titles.
static NSSet<NSString *> *titlesField(lua_State *L, int index, const char *field) {
    NSMutableSet<NSString *> *titles = [NSMutableSet set];
    if (lua_getfield(L, index, field) == LUA_TTABLE) {
        lua_pushnil(L);
        while (lua_next(L, -2) != 0) {
            NSString *title = nil;
            if (lua_type(L, -1) == LUA_TSTRING) {
                title = luaString(L, -1);
            } else if (lua_type(L, -2) == LUA_TSTRING && lua_toboolean(L, -1)) {
                title = luaString(L, -2);
            }
            if (title) {
                [titles addObject:title];
            }
            lua_pop(L, 1);
        }
    }
    lua_pop(L, 1);
    return titles;
}

static NSString *defaultSocketPath(void) {
    const char *override = getenv("DFZF_HS_SOCKET");
    NSString *path = override && *override ? [NSString stringWithUTF8String:override] : nil;
    if (path) {
        return path;
    }
    return [NSHomeDirectory() stringByAppendingPathComponent:@".local/state/dfzf/hs.sock"];
}

static int pushFailure(lua_State *L, NSString *message) {
    lua_pushnil(L);
    lua_pushstring(L, message.UTF8String);
    return 2;
}

/// hs._dfzf.start(config) -> true | nil, error
/// config: socketPath, identityTitles, popupTitles, floatingTitles, popupRatio, maximize.
static int dfzf_start(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    stopBackend();

    DFZConfig *config = [DFZConfig new];
    config.identityTitles = titlesField(L, 1, "identityTitles");
    config.popupTitles = titlesField(L, 1, "popupTitles");
    config.floatingTitles = titlesField(L, 1, "floatingTitles");
    if (lua_getfield(L, 1, "popupRatio") == LUA_TNUMBER) {
        config.popupRatio = lua_tonumber(L, -1);
    }
    lua_pop(L, 1);
    if (lua_getfield(L, 1, "maximize") != LUA_TNIL) {
        config.maximize = lua_toboolean(L, -1);
    }
    lua_pop(L, 1);
    NSString *socketPath = defaultSocketPath();
    if (lua_getfield(L, 1, "socketPath") == LUA_TSTRING) {
        socketPath = luaString(L, -1) ?: socketPath;
    }
    lua_pop(L, 1);

    DFZController *controller = [[DFZController alloc] initWithSource:[DFZAXSource new] config:config];
    NSString *error = nil;
    if (![controller start:&error]) {
        return pushFailure(L, error ?: @"dfzf: cannot start the window source");
    }
    DFZServer *server = [[DFZServer alloc] initWithPath:socketPath
                                                handler:^NSString *(NSData *request, BOOL *ok) {
                                                    return [controller handleRequest:request ok:ok];
                                                }];
    if (![server start:&error]) {
        [controller stop];
        return pushFailure(L, error ?: @"dfzf: cannot start the socket server");
    }
    sController = controller;
    sServer = server;
    lua_pushboolean(L, 1);
    return 1;
}

static int dfzf_stop(lua_State *L) {
    (void)L;
    stopBackend();
    return 0;
}

static int dfzf_isRunning(lua_State *L) {
    lua_pushboolean(L, sServer != nil);
    return 1;
}

// Collected with the lua_State on reload: the next config starts afresh.
static int dfzf_gc(lua_State *L) {
    (void)L;
    stopBackend();
    return 0;
}

static const luaL_Reg moduleLib[] = {
    {"start", dfzf_start},
    {"stop", dfzf_stop},
    {"isRunning", dfzf_isRunning},
    {NULL, NULL},
};

static const luaL_Reg moduleMetaLib[] = {
    {"__gc", dfzf_gc},
    {NULL, NULL},
};

int luaopen_hs__dfzf(lua_State *L);
int luaopen_hs__dfzf(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibrary:"hs._dfzf" functions:moduleLib metaFunctions:moduleMetaLib];
    return 1;
}

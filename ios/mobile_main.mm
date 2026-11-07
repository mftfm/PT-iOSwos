#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <filesystem>
#include <string>

int PTGameMain(int argc, char** argv);
#import "import_controller.h"

// Create Documents/Game on first launch so it is visible in Files when
// UIFileSharingEnabled and LSSupportsOpeningDocumentsInPlace are enabled.
// Users can copy their three game files here and the normal startup check
// below will detect them on the next launch.
static NSURL* PTPrepareGameFolder(NSURL* documents) {
    NSFileManager* fileManager = NSFileManager.defaultManager;
    NSURL* gameFolder = [documents URLByAppendingPathComponent:@"Game" isDirectory:YES];
    NSError* error = nil;

    if (![fileManager createDirectoryAtURL:gameFolder
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:&error]) {
        NSLog(@"[PT] Could not create Documents/Game: %@", error.localizedDescription);
        return gameFolder;
    }

    NSURL* readme = [gameFolder URLByAppendingPathComponent:@"README.txt"];
    if (![fileManager fileExistsAtPath:readme.path]) {
        NSString* instructions = @"P.T. GAME DATA\n\nCopy these three files directly into this Game folder:\n\nchunk1.psarc\ntexture.qar\npathid_list_ps4.bin\n\nClose and reopen P.T. after copying the files.\n";

        if (![instructions writeToURL:readme
                            atomically:YES
                              encoding:NSUTF8StringEncoding
                                 error:&error]) {
            NSLog(@"[PT] Could not write Game/README.txt: %@", error.localizedDescription);
        }
    }

    return gameFolder;
}

int main(int argc, char** argv) {
    @autoreleasepool {
        SDL_SetHint(SDL_HINT_TOUCH_MOUSE_EVENTS,"0");
        SDL_SetHint(SDL_HINT_MOUSE_TOUCH_EVENTS,"0");
        NSURL* documents = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
        if (!documents) {
            NSLog(@"[PT] Could not resolve the app Documents directory.");
            return 1;
        }
        NSURL* game = PTPrepareGameFolder(documents);
        NSURL* bundledGame = [NSBundle.mainBundle.bundleURL URLByAppendingPathComponent:@"Game" isDirectory:YES];
        if (!PTIOSHasGame(game) && PTIOSHasGame(bundledGame)) game = bundledGame;
        if (!PTIOSHasGame(game)) {
            if (!SDL_Init(SDL_INIT_VIDEO)) return 1;
            SDL_Window* bootstrap = SDL_CreateWindow("P.T.", 1000, 500, SDL_WINDOW_FULLSCREEN);
            if (!bootstrap) return 1;
            UIWindow* window = (__bridge UIWindow*)SDL_GetPointerProperty(SDL_GetWindowProperties(bootstrap), SDL_PROP_WINDOW_UIKIT_WINDOW_POINTER, nullptr);
            UIViewController* original = window.rootViewController;
            PTImportController* importer = [PTImportController new]; importer.destination = game;
            window.rootViewController = importer; [window makeKeyAndVisible];
            while (!importer.ready) {
                SDL_PumpEvents();
                [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
            }
            window.rootViewController = original;
            SDL_DestroyWindow(bootstrap);
            SDL_Quit();
        }
        std::string path = game.path.UTF8String;
        char name[] = "PT"; char flag[] = "--game";
        char offline[] = "--no-update-check";
        char* args[] = {name,flag,path.data(),offline,nullptr};
        return PTGameMain(4,args);
    }
}

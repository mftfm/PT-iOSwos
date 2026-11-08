#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <filesystem>
#include <string>

int PTGameMain(int argc, char** argv);
#import "import_controller.h"

int main(int argc, char** argv) {
    @autoreleasepool {
        SDL_SetHint(SDL_HINT_TOUCH_MOUSE_EVENTS,"0");
        SDL_SetHint(SDL_HINT_MOUSE_TOUCH_EVENTS,"0");
        NSURL* documents = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
        NSURL* game = [documents URLByAppendingPathComponent:@"Game" isDirectory:YES];
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

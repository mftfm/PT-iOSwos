// Exercise the production overlay against SDL's real UIKit -> Metal root replacement.
#import <UIKit/UIKit.h>
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <SDL3/SDL_metal.h>
void PTInitTouchGamepad(void);
void PTAttachTouchControls(SDL_Window*);
void PTIOSUseFullscreen(SDL_Window*);
static UIView* Overlay(UIView* view) {
    for(UIView* child in view.subviews) if([child.accessibilityIdentifier isEqualToString:@"pt.touch.controls"]) return child;
    return nil;
}
static void Check(bool value,const char* message) { if(!value){SDL_Log("TOUCH_REGRESSION_FAIL: %s",message);abort();} }
int main(int argc,char**argv) {
 @autoreleasepool {
    Check(SDL_Init(SDL_INIT_VIDEO|SDL_INIT_GAMEPAD),"SDL_Init");
    SDL_Window* window=SDL_CreateWindow("Touch layer regression",1000,500,SDL_WINDOW_FULLSCREEN|SDL_WINDOW_METAL);
    Check(window!=nullptr,"window");
    UIWindow* native=(__bridge UIWindow*)SDL_GetPointerProperty(SDL_GetWindowProperties(window),SDL_PROP_WINDOW_UIKIT_WINDOW_POINTER,nullptr);
    PTIOSUseFullscreen(window);
    Check((SDL_GetWindowFlags(window)&SDL_WINDOW_FULLSCREEN)!=0,"fullscreen policy");
    int native_w=0,native_h=0;SDL_GetWindowSizeInPixels(window,&native_w,&native_h);
    SDL_SetWindowFullscreen(window,false);SDL_SetWindowSize(window,320,180);
    PTIOSUseFullscreen(window);PTIOSUseFullscreen(window);
    int restored_w=0,restored_h=0;SDL_GetWindowSizeInPixels(window,&restored_w,&restored_h);
    Check(native_w==restored_w && native_h==restored_h,"restore fullscreen drawable after desktop resize");
    PTInitTouchGamepad();
    Check(Overlay(native.rootViewController.view)==nil,"early gamepad setup must not add UIKit views");
    int pre_surface_count=0;
    SDL_JoystickID* pre_surface_ids=SDL_GetGamepads(&pre_surface_count);
    Check(pre_surface_count==1,"virtual gamepad exists before Metal surface creation");
    SDL_free(pre_surface_ids);
    UIView* before=native.rootViewController.view;
    SDL_MetalView metal=SDL_Metal_CreateView(window);
    Check(metal!=nullptr,"Metal surface");
    Check(native.rootViewController.view!=before,"test must replace root just like Vulkan");
    Check(Overlay(native.rootViewController.view)==nil,"overlay must remain absent during SDL root replacement");
    PTAttachTouchControls(window);
    UIView* overlay=Overlay(native.rootViewController.view);
    Check(overlay!=nil,"overlay restored above Metal");
    int count=0;SDL_JoystickID* ids=SDL_GetGamepads(&count);Check(count==1,"one virtual gamepad after reattachment");
    SDL_Gamepad* pad=SDL_OpenGamepad(ids[0]);SDL_free(ids);Check(pad!=nullptr,"virtual gamepad recognized");
    Check(SDL_GetGamepadVendor(pad)==0x045e && SDL_GetGamepadProduct(pad)==0x028e,"Xbox virtual pad identity");
    Check(SDL_strcmp(SDL_GetHint(SDL_HINT_TOUCH_MOUSE_EVENTS),"0")==0,"no duplicate touch mouse");
    UIView* look=nil;
    for(UIView* child in overlay.subviews) if([child.accessibilityIdentifier isEqualToString:@"pt.touch.look"]) look=child;
    Check(look!=nil,"look stick");
    Check(!look.isOpaque,"touch stick must preserve transparency");
    [look setValue:[NSValue valueWithCGPoint:CGPointMake(.8,.4)] forKey:@"position"];
    [look performSelector:NSSelectorFromString(@"reset")];
    Check(CGPointEqualToPoint([[look valueForKey:@"position"] CGPointValue],CGPointZero),"stick reset clears visual state");
    UIButton* action=nil;
    for(UIView* child in overlay.subviews) if([child isKindOfClass:UIButton.class] && [child.accessibilityLabel isEqualToString:@"Action"])action=(UIButton*)child;
    Check(action!=nil,"action button");
    Check(!action.isOpaque,"translucent action button must preserve transparency");
    [action sendActionsForControlEvents:UIControlEventTouchDown];SDL_UpdateGamepads();
    Check(SDL_GetGamepadButton(pad,SDL_GAMEPAD_BUTTON_SOUTH),"touch down reaches SDL gamepad");
    [action sendActionsForControlEvents:UIControlEventTouchUpInside];SDL_UpdateGamepads();
    Check(!SDL_GetGamepadButton(pad,SDL_GAMEPAD_BUTTON_SOUTH),"release reaches SDL gamepad");
    [action sendActionsForControlEvents:UIControlEventTouchDown];SDL_UpdateGamepads();
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];SDL_UpdateGamepads();
    Check(!SDL_GetGamepadButton(pad,SDL_GAMEPAD_BUTTON_SOUTH),"focus loss releases held button");
    [action sendActionsForControlEvents:UIControlEventTouchDown];SDL_UpdateGamepads();
    [action sendActionsForControlEvents:UIControlEventTouchCancel];SDL_UpdateGamepads();
    Check(!SDL_GetGamepadButton(pad,SDL_GAMEPAD_BUTTON_SOUTH),"touch cancellation releases button");
    [action sendActionsForControlEvents:UIControlEventTouchDown];SDL_UpdateGamepads();
    [action sendActionsForControlEvents:UIControlEventTouchDragExit];SDL_UpdateGamepads();
    Check(!SDL_GetGamepadButton(pad,SDL_GAMEPAD_BUTTON_SOUTH),"drag outside releases button");
    SDL_Metal_DestroyView(metal);PTAttachTouchControls(window);
    Check(Overlay(native.rootViewController.view)!=nil,"overlay survives Metal surface removal");
    ids=SDL_GetGamepads(&count);SDL_free(ids);Check(count==1,"no duplicate virtual pads");
    SDL_Log("TOUCH_REGRESSION_PASS: fullscreen recovery, Metal replacement, virtual gamepad, press/release, focus reset, no duplicate pads");
    UILabel* label=[[UILabel alloc] initWithFrame:CGRectMake(140,28,550,70)];
    label.text=@"Touch controls · SDL + Metal regression passed";label.textColor=UIColor.whiteColor;label.numberOfLines=0;
    [native.rootViewController.view addSubview:label];
    bool running=true;while(running){SDL_Event e;while(SDL_PollEvent(&e))if(e.type==SDL_EVENT_QUIT)running=false;PTAttachTouchControls(window);SDL_Delay(10);}
    SDL_CloseGamepad(pad);SDL_DestroyWindow(window);SDL_Quit();
    return 0;
 }
}

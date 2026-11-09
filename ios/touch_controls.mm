#import <UIKit/UIKit.h>
#include <SDL3/SDL.h>
#include <cmath>
#include "input_display_policy.h"

static SDL_Joystick* touchPad;
static void ResetPad() {
    if (!touchPad) return;
    for (int axis=0;axis<SDL_GAMEPAD_AXIS_COUNT;++axis) SDL_SetJoystickVirtualAxis(touchPad,axis,axis>=SDL_GAMEPAD_AXIS_LEFT_TRIGGER ? -32768 : 0);
    for (int button=0;button<SDL_GAMEPAD_BUTTON_COUNT;++button) SDL_SetJoystickVirtualButton(touchPad,button,false);
}
@interface PTStick : UIView
@property(nonatomic) int axis;
@property(nonatomic) CGPoint position;
@property(nonatomic,strong) UITouch* activeTouch;
- (void)reset;
@end
@implementation PTStick
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super initWithFrame:frame])) { self.multipleTouchEnabled=NO; self.backgroundColor=UIColor.clearColor; self.opaque=NO; }
    return self;
}
- (void)drawRect:(CGRect)rect {
    CGContextRef c=UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(c,[UIColor colorWithWhite:1 alpha:0.25].CGColor);
    CGContextSetLineWidth(c,1.5); CGContextStrokeEllipseInRect(c,CGRectInset(self.bounds,6,6));
    CGContextSetFillColorWithColor(c,[UIColor colorWithWhite:1 alpha:0.2].CGColor);
    CGPoint center=CGPointMake(CGRectGetMidX(self.bounds)+self.position.x*40,CGRectGetMidY(self.bounds)+self.position.y*40);
    CGContextFillEllipseInRect(c,CGRectMake(center.x-21,center.y-21,42,42));
}
- (void)updateTouch:(UITouch*)touch {
    CGPoint p=[touch locationInView:self];
    float x=(p.x-CGRectGetMidX(self.bounds))/60, y=(p.y-CGRectGetMidY(self.bounds))/60;
    float length=std::hypot(x,y); if(length>1){x/=length;y/=length;}
    self.position=CGPointMake(x,y);
    const auto value=pt::ios::TouchStick(x,y,self.axis==SDL_GAMEPAD_AXIS_RIGHTX);
    if(touchPad){SDL_SetJoystickVirtualAxis(touchPad,self.axis,(Sint16)(value.x*32767)); SDL_SetJoystickVirtualAxis(touchPad,self.axis+1,(Sint16)(value.y*32767));}
    [self setNeedsDisplay];
}
- (void)touchesBegan:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    if (!self.activeTouch) { self.activeTouch=touches.anyObject; [self updateTouch:self.activeTouch]; }
}
- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    if (self.activeTouch && [touches containsObject:self.activeTouch]) [self updateTouch:self.activeTouch];
}
- (void)reset {
    self.activeTouch=nil; self.position=CGPointZero;
    if(touchPad){SDL_SetJoystickVirtualAxis(touchPad,self.axis,0);SDL_SetJoystickVirtualAxis(touchPad,self.axis+1,0);}
    [self setNeedsDisplay];
}
- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    if ([touches containsObject:self.activeTouch]) [self reset];
}
- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event { [self reset]; }
- (void)didMoveToWindow { [super didMoveToWindow]; if (!self.window) [self reset]; }
@end
@interface PTControls : UIView
@property(nonatomic) PTStick* left;
@property(nonatomic) PTStick* right;
@property(nonatomic) NSMutableArray<UIButton*>* buttons;
@end
static __weak PTControls* activeControls;
@implementation PTControls
- (UIView*)hitTest:(CGPoint)point withEvent:(UIEvent*)event {
    UIView* result=[super hitTest:point withEvent:event]; return result==self ? nil : result;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.backgroundColor=UIColor.clearColor; self.opaque=NO; self.multipleTouchEnabled=YES;
        self.left=[[PTStick alloc] initWithFrame:CGRectZero]; self.left.axis=SDL_GAMEPAD_AXIS_LEFTX; self.left.accessibilityIdentifier=@"pt.touch.move"; [self addSubview:self.left];
        self.right=[[PTStick alloc] initWithFrame:CGRectZero]; self.right.axis=SDL_GAMEPAD_AXIS_RIGHTX; self.right.accessibilityIdentifier=@"pt.touch.look"; [self addSubview:self.right];
        self.buttons=[NSMutableArray new];
        NSArray* labels=@[@"A",@"B",@"ZOOM",@"Ⅱ"];
        int tags[]={SDL_GAMEPAD_BUTTON_SOUTH,SDL_GAMEPAD_BUTTON_EAST,SDL_GAMEPAD_BUTTON_RIGHT_STICK,SDL_GAMEPAD_BUTTON_START};
        for(int i=0;i<4;++i){
            UIButton* button=[UIButton buttonWithType:UIButtonTypeCustom]; button.tag=tags[i];
            button.accessibilityLabel=(@[@"Action",@"Back",@"Zoom",@"Pause"])[i];
            [button setTitle:labels[i] forState:UIControlStateNormal]; button.titleLabel.font=[UIFont systemFontOfSize:i==0?24:11 weight:UIFontWeightMedium];
            button.backgroundColor=[UIColor colorWithWhite:1 alpha:0.12]; button.opaque=NO; button.layer.cornerRadius=24;
            button.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.25].CGColor; button.layer.borderWidth=1;
            [button addTarget:self action:@selector(down:) forControlEvents:UIControlEventTouchDown|UIControlEventTouchDragEnter];
            [button addTarget:self action:@selector(up:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel|UIControlEventTouchDragExit];
            [self addSubview:button]; [self.buttons addObject:button];
        }
        for (NSNotificationName name in @[UIApplicationWillResignActiveNotification,UIApplicationDidEnterBackgroundNotification,UIApplicationDidBecomeActiveNotification,UIDeviceOrientationDidChangeNotification,UIWindowDidResignKeyNotification])
            [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reset) name:name object:nil];
    } return self;
}
- (void)reset { ResetPad(); [self.left reset]; [self.right reset]; for (UIButton* b in self.buttons) { b.highlighted=NO; b.selected=NO; } }
- (void)didMoveToWindow { [super didMoveToWindow]; if (!self.window) [self reset]; }
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; ResetPad(); }
- (void)down:(UIButton*)button { if(!touchPad)return; SDL_SetJoystickVirtualButton(touchPad,(int)button.tag,true); }
- (void)up:(UIButton*)button { if(!touchPad)return; SDL_SetJoystickVirtualButton(touchPad,(int)button.tag,false); }
- (void)layoutSubviews {
    [super layoutSubviews]; UIEdgeInsets s=self.safeAreaInsets; CGFloat w=self.bounds.size.width,h=self.bounds.size.height;
    self.left.frame=CGRectMake(s.left+28,h-s.bottom-154,130,130);
    self.right.frame=CGRectMake(w-s.right-196,h-s.bottom-154,130,130);
    self.buttons[0].frame=CGRectMake(w-s.right-60,h-s.bottom-104,48,48);
    self.buttons[1].frame=CGRectMake(w-s.right-60,h-s.bottom-48,44,36);
    self.buttons[2].frame=CGRectMake(w-s.right-128,h-s.bottom-216,72,40);
    self.buttons[3].frame=CGRectMake(w-s.right-60,s.top+16,44,36);
}
@end
void PTAttachTouchControls(SDL_Window* window) {
    SDL_SetHint(SDL_HINT_TOUCH_MOUSE_EVENTS,"0");
    SDL_SetHint(SDL_HINT_MOUSE_TOUCH_EVENTS,"0");
    if (!touchPad) {
    if (!SDL_InitSubSystem(SDL_INIT_GAMEPAD)) { SDL_Log("touch: gamepad init failed: %s", SDL_GetError()); return; }
    SDL_VirtualJoystickDesc desc; SDL_INIT_INTERFACE(&desc);
    desc.type=SDL_JOYSTICK_TYPE_GAMEPAD; desc.naxes=SDL_GAMEPAD_AXIS_COUNT; desc.nbuttons=SDL_GAMEPAD_BUTTON_COUNT;
    desc.axis_mask=(1u<<SDL_GAMEPAD_AXIS_COUNT)-1; desc.button_mask=(1u<<SDL_GAMEPAD_BUTTON_COUNT)-1;
    desc.name="P.T. Touch Xbox Controller";
    desc.vendor_id=0x045e; desc.product_id=0x028e;
    desc.Cleanup=[](void*) { touchPad=nullptr; };
    SDL_JoystickID id=SDL_AttachVirtualJoystick(&desc);
    if (!id) { SDL_Log("touch: virtual gamepad failed: %s", SDL_GetError()); return; }
    touchPad=SDL_OpenJoystick(id);
    if (!touchPad) { SDL_DetachVirtualJoystick(id); SDL_Log("touch: open gamepad failed: %s", SDL_GetError()); return; }
    ResetPad();
    SDL_Log("touch: virtual gamepad attached (%u)", id);
    }
    UIWindow* uiwindow=(__bridge UIWindow*)SDL_GetPointerProperty(SDL_GetWindowProperties(window),SDL_PROP_WINDOW_UIKIT_WINDOW_POINTER,nullptr);
    UIView* host=uiwindow.rootViewController.view;
    if (!host) return;
    CGRect full=uiwindow.windowScene.coordinateSpace.bounds;
    if (!CGRectIsEmpty(full) && !CGRectEqualToRect(uiwindow.frame,full)) {
        uiwindow.frame=full; SDL_Log("ios: restored fullscreen UIKit window");
    }
    if (!CGRectEqualToRect(host.frame,uiwindow.bounds)) {
        host.frame=uiwindow.bounds; [host setNeedsLayout]; [host layoutIfNeeded];
        SDL_Log("ios: restored fullscreen render view");
    }
    PTControls* controls=activeControls;
    if (!controls) {
        controls=[[PTControls alloc] initWithFrame:host.bounds];
        controls.accessibilityIdentifier=@"pt.touch.controls";
        controls.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        activeControls=controls;
    }
    if (controls.superview!=host) {
        [controls reset];
        [controls removeFromSuperview];
        controls.frame=host.bounds;
        [host addSubview:controls];
        [controls setNeedsLayout];
        SDL_Log("touch: overlay attached to %s", NSStringFromClass(host.class).UTF8String);
    } else if (!CGRectEqualToRect(controls.frame,host.bounds)) {
        [controls reset]; controls.frame=host.bounds; [controls setNeedsLayout];
    }
    if (host.subviews.lastObject!=controls) {
        [host bringSubviewToFront:controls];
    }
}

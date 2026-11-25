#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface Workbench : WKWebView
@property BOOL child;
@end
@implementation Workbench
- (BOOL)performKeyEquivalent:(NSEvent *)event {
    return self.child ? NO : [super performKeyEquivalent:event];
}
@end

@interface Check : NSObject <NSApplicationDelegate, WKNavigationDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) Workbench *view;
@property(nonatomic, strong) id monitor;
@property int pass;
@property int nativeMinimizes;
@property int waitCount;
@end

@implementation Check
- (void)minimize:(id)sender { self.nativeMinimizes++; [self.window miniaturize:nil]; }
- (void)post:(NSString *)key code:(unsigned short)code {
    NSEvent *event=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagCommand timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:self.window.windowNumber context:nil characters:key charactersIgnoringModifiers:key isARepeat:NO keyCode:code];
    [NSApp postEvent:event atStart:NO];
}
- (void)applicationDidFinishLaunching:(NSNotification *)n {
    NSMenu *menu=[NSMenu new], *sub=[[NSMenu alloc] initWithTitle:@"Window"];
    NSMenuItem *top=[NSMenuItem new]; top.submenu=sub; [menu addItem:top];
    [sub addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    [sub addItemWithTitle:@"Minimize" action:@selector(minimize:) keyEquivalent:@"m"].target=self;
    NSApp.mainMenu=menu;
    self.window=[[NSWindow alloc] initWithContentRect:NSMakeRect(150,150,400,120) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskMiniaturizable backing:NSBackingStoreBuffered defer:NO];
    self.view=[[Workbench alloc] initWithFrame:self.window.contentView.bounds configuration:[WKWebViewConfiguration new]];
    self.view.navigationDelegate=self; [self.window.contentView addSubview:self.view]; self.window.title=@"Workbench shortcut check";
    self.monitor=[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event){
        if (!self.pass || !(event.modifierFlags&NSEventModifierFlagCommand) || event.window!=self.window || !self.window.keyWindow || self.window.attachedSheet || self.window.firstResponder!=self.view) return event;
        SEL action=@selector(performKeyEquivalent:);
        BOOL handled=((BOOL(*)(id,SEL,NSEvent *))class_getMethodImplementation(WKWebView.class,action))(self.view,action,event);
        return handled ? nil : event;
    }];
    [self.window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES];
    [self.view loadHTMLString:@"<textarea autofocus>Keyboard</textarea>" baseURL:nil];
}
- (void)webView:(WKWebView *)v didFinishNavigation:(WKNavigation *)navigation { [self checkPass]; }
- (void)checkPass {
    self.view.child=self.pass!=0; [self.window deminiaturize:nil]; [self.window makeKeyAndOrderFront:nil];
    [self.window makeFirstResponder:self.view]; self.nativeMinimizes=0;
    [self.view evaluateJavaScript:@"var t=document.querySelector('textarea'); t.focus(); t.setSelectionRange(0,0)" completionHandler:^(id _,NSError *error){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,500*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
            if(!NSApp.active || !self.window.keyWindow || self.window.firstResponder!=self.view) {
                if (++self.waitCount<180) { [self checkPass]; return; }
                puts("inconclusive: window lacks foreground keyboard focus"); [NSApp terminate:nil]; return;
            }
            self.waitCount=0; [self post:@"a" code:0];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,400*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
                [self.view evaluateJavaScript:@"t.selectionStart===0 && t.selectionEnd===t.value.length" completionHandler:^(id selected,NSError *err){
                    [self post:@"m" code:46];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,800*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
                        printf("case=%s selectAll=%d minimizeActions=%d minimized=%d\n",self.pass?"fixed":"stock",[selected boolValue],self.nativeMinimizes,self.window.miniaturized);
                        if(self.pass++==0) [self checkPass]; else [NSApp terminate:nil];
                    });
                }];
            });
        });
    }];
}
@end
int main(void){ @autoreleasepool{
    NSApplication *app=NSApplication.sharedApplication;
    [app setActivationPolicy:NSApplicationActivationPolicyRegular]; Check *check=[Check new]; app.delegate=check;
    NSString *dir=NSBundle.mainBundle.bundlePath.stringByDeletingLastPathComponent;
    freopen([[dir stringByAppendingPathComponent:@"system-keys.log"] fileSystemRepresentation],"w",stdout); setbuf(stdout,NULL);
    [app run];
} }

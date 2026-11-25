#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import <WebKit/WebKit.h>

static BOOL child, forwardKey, inside, monitored; static int currentCase;
static int menuCount;
@interface Workbench : WKWebView @end
@implementation Workbench
- (BOOL)performKeyEquivalent:(NSEvent *)e {
    BOOL b=child ? NO : [super performKeyEquivalent:e]; printf("equivalent %s: %d\n", e.charactersIgnoringModifiers.UTF8String,b); return b;
}
@end

@interface Parent : NSView @end
@implementation Parent
- (void)keyDown:(NSEvent *)e { printf("parent %s\n", e.charactersIgnoringModifiers.UTF8String); [NSApp.mainMenu performKeyEquivalent:e]; }
@end
@interface Probe : NSObject <NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate>
@property NSWindow *window;
@property Workbench *view;
@property NSMenu *shortcuts;
@end
@implementation Probe
- (void)handleMenu:(id)sender {
    menuCount++;
    NSEvent *e = NSApp.currentEvent;
    printf("menu key=%s type=%lu responder=%s inside=%d\n", e.charactersIgnoringModifiers.UTF8String, (unsigned long)e.type, object_getClassName(self.window.firstResponder),inside);
    if (forwardKey && !inside && e.type==NSEventTypeKeyDown) {
        inside=YES;
        [self.window.firstResponder keyDown:e];
        inside=NO;
    }
}
- (void)userContentController:(WKUserContentController *)c didReceiveScriptMessage:(WKScriptMessage *)m {
    printf("DOM %s\n", [m.body description].UTF8String);
}
- (void)applicationDidFinishLaunching:(NSNotification *)n {
    NSMenu *bar=[[NSMenu alloc] initWithTitle:@"Main"];
    NSMenuItem *header=[[NSMenuItem alloc] initWithTitle:@"Probe" action:nil keyEquivalent:@""];
    NSMenu *sub=[[NSMenu alloc] initWithTitle:@"Probe"];
    for(NSString *key in @[@"0",@"1"]) {
        NSMenuItem *item=[sub addItemWithTitle:[@"Panel " stringByAppendingString:key] action:@selector(handleMenu:) keyEquivalent:key]; item.target=self;
    }
    self.shortcuts=sub; header.submenu=sub; [bar addItem:header]; NSApp.mainMenu=bar;
    self.window=[[NSWindow alloc] initWithContentRect:NSMakeRect(50,50,500,200) styleMask:(NSWindowStyleMaskTitled|NSWindowStyleMaskClosable) backing:NSBackingStoreBuffered defer:NO];
    WKWebViewConfiguration *config=[WKWebViewConfiguration new];
    [config.userContentController addScriptMessageHandler:self name:@"probe"];
    self.view=[[Workbench alloc] initWithFrame:self.window.contentView.bounds configuration:config]; self.view.navigationDelegate=self;
    if(!child) self.window.contentView=[[Parent alloc] initWithFrame:self.window.contentView.bounds]; [self.window.contentView addSubview:self.view];
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
        if (monitored && (event.modifierFlags & NSEventModifierFlagCommand) && self.window.isKeyWindow && self.window.firstResponder==self.view){
            SEL sel=@selector(performKeyEquivalent:);
            BOOL handled=((BOOL(*)(id,SEL,NSEvent *))class_getMethodImplementation(WKWebView.class,sel))(self.view,sel,event);
            printf("monitor %s =>%d\n",event.charactersIgnoringModifiers.UTF8String,handled);
            if(handled)return nil;
        }
        return event;
    }];
    self.window.title=@"Shortcut diagnostics";[self.window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES]; [self.window makeFirstResponder:self.view];
    [self.view loadHTMLString:@"<textarea autofocus>editor</textarea><script>document.addEventListener('keydown',e=>{webkit.messageHandlers.probe.postMessage(e.key+':'+e.metaKey); if(e.metaKey && e.key==='0')e.preventDefault()},true)</script>" baseURL:nil];
}
- (void)webView:(WKWebView *)wv didFinishNavigation:(WKNavigation *)nav {
    [self.window makeFirstResponder:wv]; [wv evaluateJavaScript:@"document.querySelector('textarea').focus()" completionHandler:^(id value,NSError *e){
        [self watchForFocus];
    }];
}
- (void)watchForFocus {
    if (!self.window.isKeyWindow || !NSApp.isActive) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,500*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[self watchForFocus];}); return;
    }
    for (int n=0;n<4;n++){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (n*2300+200)*NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            currentCase=n; child=n!=0; monitored=n==3; forwardKey=NO;
            printf("CASE=%d active=%d key=%d\n",n,NSApp.active,self.window.keyWindow);
            for(int k=0;k<2;k++)[self.shortcuts itemAtIndex:k].keyEquivalent=n==2?@"":[NSString stringWithFormat:@"%d",k];
            for(int i=0;i<4;i++){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(i+1)*320*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
                NSString *key=i%2?@"1":@"0"; NSEvent *e=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagCommand timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:self.window.windowNumber context:nil characters:key charactersIgnoringModifiers:key isARepeat:NO keyCode:i%2?18:29];[NSApp postEvent:e atStart:NO];
            });}
        });
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC),dispatch_get_main_queue(),^{printf("done\n");[NSApp terminate:nil];});
}
@end
int main(int argc,char **argv) { @autoreleasepool {
    NSString *root=[[[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent] copy]; NSString *mode=[[NSString stringWithContentsOfFile:[root stringByAppendingPathComponent:@"probe-mode"] encoding:NSUTF8StringEncoding error:NULL] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; freopen([[root stringByAppendingPathComponent:[NSString stringWithFormat:@"monitor-%@.log",mode]] fileSystemRepresentation],"w",stdout); setvbuf(stdout,NULL,_IONBF,0); child=![mode isEqualToString:@"content"]; forwardKey=[mode isEqualToString:@"forward"];
    NSApplication *app=[NSApplication sharedApplication]; [app setActivationPolicy:NSApplicationActivationPolicyRegular];
    Probe *p=[Probe new]; app.delegate=p; [app run];
} }

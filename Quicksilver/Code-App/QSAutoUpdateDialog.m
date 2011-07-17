#import "QSAutoUpdateDialog.h"
#import "QSRegistry.h"
#import "QSApp.h"
#import "QSHelp.h"
#import "QSPlugIn.h"
#import "QSHandledSplitView.h"
#import <QSCore/QSResourceManager.h>
#import <WebKit/WebKit.h>
#import "QSPlugInManager.h"

@interface QSAutoUpdateDialogEntry : NSObject {
  QSPlugIn *plugin;
  NSString *action;
}
+ (QSAutoUpdateDialogEntry *)entryForPlugin:(QSPlugIn *)aPlugin;
@property (retain, nonatomic) NSString *action;
@property (retain, nonatomic) QSPlugIn *plugin;
- (NSString *)text;
- (NSImage *)image;
- (NSArray *)actions;
- (NSString *)currentVersion;
- (NSString *)newVersion;
/*- (NSString *)age;
- (NSString *)description;
 */
@end
@implementation QSAutoUpdateDialogEntry

@synthesize action, plugin;

- (id) init
{
  self = [super init];
  if (self != nil) {
    self.action = @"Whatever";
  }
  return self;
}
- (void) dealloc
{
  self.action = nil;
  self.plugin = nil;
  [super dealloc];
}

+ (QSAutoUpdateDialogEntry *)entryForPlugin:(QSPlugIn *)aPlugin {
  QSAutoUpdateDialogEntry *result = [[[self alloc] init] autorelease];
  result.plugin = aPlugin;
  return result;
}
- (NSString *)text {
  return [plugin text] ?: @"No plugin!";
}
- (NSImage *)image {
  return [plugin image];
}
- (NSString *)sortName {
  return [plugin text] ?: @"";
}
+ (NSString *)escape:(NSString*)s {
  s = [s stringByReplacing:@"&" with:@"&amp;"];
  s = [s stringByReplacing:@"<" with:@"&lt;"];
  s = [s stringByReplacing:@">" with:@"&gt;"];
  s = [s stringByReplacing:@"\"" with:@"&quot;"];
  s = [s stringByReplacing:@"'" with:@"&apos;"];
  return s;
}
- (NSString *)infoHTML {
  NSString *text = [NSString stringWithFormat:@"<h1>bundle</h1><pre>%@</pre><h1>data</h1><pre>%@</pre><h1>info</h1><pre>%@</pre>",
                    [[self class] escape:[[plugin bundle] description]],
                    [[self class] escape:[[plugin data] description]],
                    [[self class] escape:[[plugin info] description]]];
  return [NSString stringWithFormat:@"<html><link rel=\"stylesheet\" href=\"resource:QSStyle.css\"><body>%@</body></html>", text];
}

- (NSArray *)actions {
  return [NSArray arrayWithObjects:@"Update", @"Ask again next time", @"Skip version", nil];
}
- (NSString *)currentVersion {
  return [[plugin bundle] description];
}
- (NSString *)newVersion {
  return [[plugin data] description];
}

@end


@implementation QSAutoUpdateDialog
@synthesize updates;
+ (QSAutoUpdateDialog *)sharedInstance {
	static QSAutoUpdateDialog * _sharedInstance;
	if (!_sharedInstance) _sharedInstance = [[[self class] allocWithZone:[self zone]] init];
	return _sharedInstance;
}
- (id)init {
	if ((self = [self initWithWindowNibName:@"QSAutoUpdateDialog"])) {
    advancedPanelVisible = NO;
    NSArray *plugs = [[QSPlugInManager sharedInstance] knownPlugInsWithWebInfo];
    NSMutableArray *updatesFromPlugs = [NSMutableArray arrayWithCapacity:[plugs count]];
    for (QSPlugIn *plugin in plugs) {
      [updatesFromPlugs addObject:[QSAutoUpdateDialogEntry entryForPlugin:plugin]];
    }
    self.updates = updatesFromPlugs;
	}
	return self;
}
- (void) dealloc
{
  self.updates = nil;
  [super dealloc];
}
- (void)windowDidLoad {
  [super windowDidLoad];
  NSSortDescriptor* aSortDesc = [[NSSortDescriptor alloc] initWithKey:@"sortName" ascending:YES selector:@selector(caseInsensitiveCompare:)];
	[updateArrayController setSortDescriptors:[NSArray arrayWithObject: aSortDesc]];
	[aSortDesc release];
	[updateArrayController rearrangeObjects];
  [[[self window] contentView] addSubview:advancedPanel];
  NSRect panelPosition = [advancedPanel frame];
  advancedPanelHeight = panelPosition.size.height;
  panelPosition.origin.x = 0;
  panelPosition.origin.y = NSMinY([showAdvancedPanelButton frame]);
  panelPosition.size.height = 0;
  panelPosition.size.width = [[self window] frame].size.width;
  [advancedPanel setFrame:panelPosition];
  [[updateInfoView preferences] setDefaultTextEncodingName:@"utf-8"];
	[[updateInfoView window] useOptimizedDrawing:NO];
	[updateArrayController addObserver:self forKeyPath:@"selectedObjects" options:0 context:nil];
	[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];  
}

- (void)showWindow:(id)sender {
	[self window];
	//[(QSDockingWindow *)[self window] show:sender];
	[super showWindow:sender];
}

- (void)hideWindow:(id)sender {
	[[self window] close];
}

- (BOOL)advancedPanelVisible {
  return advancedPanelVisible;
}
- (void) setAdvancedPanelVisible:(BOOL)newValue {
  if (advancedPanelVisible == newValue) return;
  [self willChangeValueForKey:@"advancedPanelVisible"];
  advancedPanelVisible = newValue;
  [self didChangeValueForKey:@"advancedPanelVisible"];
  NSRect rect;
  CGFloat delta = newValue ? advancedPanelHeight : -advancedPanelHeight;
  [[tableView tableColumnWithIdentifier:@"action"] setHidden:!newValue];
  NSMutableArray *animations = [NSMutableArray arrayWithCapacity:4];
#define ANIMATE_ADD(VIEW, CHANGES, LIST, RECT, ...) { \
		RECT = [(VIEW) frame]; \
	  CHANGES; \
    [(LIST) addObject:[NSDictionary dictionaryWithObjectsAndKeys: \
                      [NSValue valueWithRect:(RECT)], NSViewAnimationEndFrameKey, \
                      (VIEW), NSViewAnimationTargetKey, ## __VA_ARGS__, \
                      nil]]; \
	}
  ANIMATE_ADD(showAdvancedPanelButton, rect.origin.y += delta, animations, rect);
  ANIMATE_ADD(showAdvancedPanelButton2, rect.origin.y += delta, animations, rect);
  ANIMATE_ADD(splitView, rect.origin.y += delta; rect.size.height -= delta, animations, rect);
  ANIMATE_ADD(advancedPanel, rect.size.height = newValue ? delta : 3, animations, rect);
  NSViewAnimation *theAnim = [[NSViewAnimation alloc] initWithViewAnimations:animations];
  [theAnim setDuration:([[NSApp currentEvent] modifierFlags] & NSShiftKeyMask) ? 1.5 : 0.3];
  [theAnim setFrameRate:0.f];
  [theAnim startAnimation];
  [theAnim release];
}
- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id)listener {
	if ([[[request URL] scheme] isEqualToString:@"applewebdata"] || [[[request URL] scheme] isEqualToString:@"about"]) {
		[listener use];
	} else {
		[[NSWorkspace sharedWorkspace] openURL:[request URL]];
		[listener ignore];
	}
}

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource {
	if ([[[request URL] scheme] isEqualToString:@"resource"]) {
		NSString *path = [[request URL] resourceSpecifier];
		request = [[request mutableCopy] autorelease];
		[(NSMutableURLRequest *)request setURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:[path stringByDeletingPathExtension] ofType:[path pathExtension]]]];
	}
	return request;
}
- (void)updateWithHTMLString:(NSString *)html {
  [[updateInfoView mainFrame] loadHTMLString:html baseURL:nil];
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if (object == updateArrayController)  {
		NSArray *selection = [updateArrayController selectedObjects];
		BOOL isMainThread = [NSThread isMainThread];
		NSString *htmlString;
		if ([selection count] == 1) {
			htmlString = [[selection objectAtIndex:0] infoHTML];
		} else {
			htmlString = @"";
		}
		if (isMainThread) {
			[self updateWithHTMLString:htmlString];
		} else {
			[self performSelectorOnMainThread:@selector(updateWithHTMLString:) withObject:htmlString waitUntilDone:NO];
		}
	}
}
@end

#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#import <Cocoa/Cocoa.h>

@interface QSAutoUpdateDialog : NSWindowController {
  NSArray *updates;
  IBOutlet NSArrayController *updateArrayController;
  IBOutlet NSView *advancedPanel;
  IBOutlet NSTableView *tableView;
  IBOutlet NSButton *showAdvancedPanelButton;
  IBOutlet NSButton *showAdvancedPanelButton2;
  IBOutlet NSSplitView *splitView;
  IBOutlet WebView *updateInfoView;
  BOOL advancedPanelVisible;
  CGFloat advancedPanelHeight;
}
+ (QSAutoUpdateDialog *)sharedInstance;

@property (assign, nonatomic) BOOL advancedPanelVisible;
@property (copy, nonatomic) NSArray *updates;
@end

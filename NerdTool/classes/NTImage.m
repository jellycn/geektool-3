//
//  NTImage.m
//  NerdTool
//
//  Created by Kevin Nygaard on 7/21/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "NTImage.h"
#import "NTLog.h"
#import "LogTextField.h"
#import "LogWindow.h"

#import "defines.h"
#import "NSDictionary+IntAndBoolAccessors.h"


@implementation NTImage
#pragma mark Properties
- (NSString *)logTypeName
{
    return @"Image";
}

- (BOOL)needsDisplayUIBox
{
    return NO;
}

- (NSString *)preferenceNibName
{
    return @"imagePrefs";
}

- (NSString *)displayNibName
{
    return @"imageWindow";
}

- (NSDictionary *)defaultProperties
{    
    NSDictionary *defaultProperties = [[NSDictionary alloc]initWithObjectsAndKeys:
                                       NSLocalizedString(@"New image log",nil),@"name",
                                       [NSNumber numberWithBool:YES],@"enabled",
                                       NSLocalizedString(@"Default",nil),@"group",
                                       
                                       [NSNumber numberWithInt:16],@"x",
                                       [NSNumber numberWithInt:38],@"y",
                                       [NSNumber numberWithInt:280],@"w",
                                       [NSNumber numberWithInt:150],@"h",
                                       [NSNumber numberWithBool:NO],@"alwaysOnTop",
                                       [NSNumber numberWithBool:NO],@"shadowWindow",
                                       
                                       [NSNumber numberWithInt:10],@"refresh",
                                       @"",@"imageURL",
                                       [NSNumber numberWithInt:TOP_LEFT],@"pictureAlignment",
                                       [NSNumber numberWithInt:100],@"transparency",
                                       [NSNumber numberWithInt:PROPORTIONALLY],@"imageFit",
                                       nil];
    
    return [defaultProperties autorelease];
}

#pragma mark Interface
- (void)setupInterfaceBindingsWithObject:(id)bindee
{
    [imageURL setEditable:YES];
    [refresh setEditable:YES];
    
    [refresh bind:@"value" toObject:bindee withKeyPath:@"selection.properties.refresh" options:nil];
    [imageURL bind:@"value" toObject:bindee withKeyPath:@"selection.properties.imageURL" options:nil];
    [alignment bind:@"selectedIndex" toObject:bindee withKeyPath:@"selection.properties.pictureAlignment" options:nil];
    [opacity bind:@"value" toObject:bindee withKeyPath:@"selection.properties.transparency" options:nil];
    [scaling bind:@"selectedIndex" toObject:bindee withKeyPath:@"selection.properties.imageFit" options:nil];
}

- (void)destroyInterfaceBindings
{
    [refresh unbind:@"value"];
    [imageURL unbind:@"value"];
    [alignment unbind:@"value"];
    [opacity unbind:@"value"];
    [scaling unbind:@"value"];
}

#pragma mark Observing
- (void)setupPreferenceObservers
{
    [self addObserver:self forKeyPath:@"properties.refresh" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.imageURL" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.pictureAlignment" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.transparency" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"properties.imageFit" options:0 context:NULL];
    [super setupPreferenceObservers];
}

- (void)removePreferenceObservers
{
    [self removeObserver:self forKeyPath:@"properties.refresh"];
    [self removeObserver:self forKeyPath:@"properties.imageURL"];
    [self removeObserver:self forKeyPath:@"properties.pictureAlignment"];
    [self removeObserver:self forKeyPath:@"properties.transparency"];
    [self removeObserver:self forKeyPath:@"properties.imageFit"];
    [super removePreferenceObservers];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"properties.enabled"] || [keyPath isEqualToString:@"active"])
    {
        if (windowController) [self destroyLogProcess];
        if (![[self active]boolValue] || ![properties boolForKey:@"enabled"]) return;
        
        [self createLogProcess];
        [self setupLogWindowAndDisplay];
    }
    // check if our LogProcess is alive
    else if (!windowController) return;
    else if ([keyPath isEqualToString:@"properties.shadowWindow"] || [keyPath isEqualToString:@"properties.imageURL"])
    {
        [self setupLogWindowAndDisplay];
    }
    else if ([keyPath isEqualToString:@"properties.refresh"])
    {
        timerNeedsUpdate = YES;
        [self updateWindow];
    }    
    else
    {
        timerNeedsUpdate = NO;
        [self updateWindow];
    }
    
    if (postActivationRequest)
    {
        postActivationRequest = NO;
        if(!highlightSender) return;
        [[self highlightSender]observeValueForKeyPath:@"selectedObjects" ofObject:self change:nil context:nil];
    }
}

#pragma mark Window Management
- (void)createWindow
{        
    [super createWindow];
}

- (void)updateWindow
{    
    [[window imageView]setImageAlignment:[self imageAlignment]];
    [[window imageView]setImageScaling:[self imageFit]];
    if (timerNeedsUpdate) [self updateTimer];
    
    [super updateWindow];
}

#pragma mark Task
- (void)updateCommand:(NSTimer*)timer
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
    [NSThread detachNewThreadSelector:@selector(setImage:) toTarget:self withObject:[properties objectForKey:@"imageURL"]];            
    [pool release];
}

#pragma mark -
#pragma mark Local Methods
#pragma mark File handling
- (IBAction)fileChoose:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel beginSheetForDirectory:[[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES) objectAtIndex:0]stringByAppendingPathComponent:[[NSProcessInfo processInfo]processName]] file:nil types:nil modalForWindow:[NSApp mainWindow] modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
    [NSApp endSheet:sheet];
    if (returnCode == NSOKButton)
    {
        if (![[sheet filenames]count]) return;        
        [[self properties]setObject:[[[sheet URLs]objectAtIndex:0]absoluteString] forKey:@"imageURL"];
    }
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    if (returnCode == NSAlertDefaultReturn) [sheet close];
}

#pragma mark Image handling
- (void)setImage:(NSString*)urlStr
{    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
    NSImage *myImage = [[NSImage alloc]initByReferencingURL:[NSURL URLWithString:urlStr]];
    [[window imageView]setImage:myImage];
    [myImage release];
    [pool release];
}

- (int)imageFit
{
    switch ([properties integerForKey:@"imageFit"])
    {
        case PROPORTIONALLY:
            return NSScaleProportionally;
            break;
        case TO_FIT:
            return NSScaleToFit;
            break;
        case NONE:
            return NSScaleNone;
            break;
    }
    return NSScaleNone;
}

- (int)imageAlignment
{
    switch ([properties integerForKey:@"pictureAlignment"])
    {
        case TOP_LEFT:
            return NSImageAlignTopLeft;
            break;
        case TOP:
            return NSImageAlignTop;
            break;
        case TOP_RIGHT:
            return NSImageAlignTopRight;
            break;
        case LEFT:
            return NSImageAlignLeft;
            break;
        case CENTER:
            return NSImageAlignCenter;
            break;
        case RIGHT:
            return NSImageAlignRight;
            break;
        case BOTTOM_LEFT:
            return NSImageAlignBottomLeft;
            break;
        case BOTTOM:
            return NSImageAlignBottom;
            break;
        case BOTTOM_RIGHT:
            return NSImageAlignBottomRight;
            break;
    }
    return NSImageAlignTopLeft;
}

@end
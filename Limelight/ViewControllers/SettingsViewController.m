//
//  SettingsViewController.m
//  Moonlight
//
//  Created by Diego Waxemberg on 10/27/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "SettingsViewController.h"
#import "TemporarySettings.h"
#import "DataManager.h"

#import <VideoToolbox/VideoToolbox.h>

@implementation SettingsViewController {
    NSInteger _bitrate;
    NSInteger _width;
    NSInteger _height;
}

@dynamic overrideUserInterfaceStyle;

static NSString* resolutionFormat = @"Resolution: %dx%d (%d:%d)";
static const int widthTable[] = {
    640,
    800,
    1024,
    1152,
    1280,
    1280,
    1600,
    1600,
    1920,
    1920,
    2048,
    2560
};
static const int heightTable[] = {
    480,
    600,
    768,
    864,
    720,
    960,
    900,
    1200,
    1080,
    1440,
    1536,
    1440
};

static NSString* bitrateFormat = @"Bitrate: %.1f Mbps";
static const int bitrateTable[] = {
    500,
    1000,
    1500,
    2000,
    2500,
    3000,
    4000,
    5000,
    6000,
    7000,
    8000,
    9000,
    10000,
    12000,
    15000,
    18000,
    20000,
    30000,
    40000,
    50000,
    60000,
    70000,
    80000,
    100000,
    120000,
    150000,
};

-(int)getSliderValueForBitrate:(NSInteger)bitrate {
    int i;
    
    for (i = 0; i < (sizeof(bitrateTable) / sizeof(*bitrateTable)); i++) {
        if (bitrate <= bitrateTable[i]) {
            return i;
        }
    }
    
    // Return the last entry in the table
    return i - 1;
}

-(void)viewDidLayoutSubviews {
    // On iPhone layouts, this view is rooted at a ScrollView. To make it
    // scrollable, we'll update content size here.
    if (self.scrollView != nil) {
        CGFloat highestViewY = 0;
        
        // Enumerate the scroll view's subviews looking for the
        // highest view Y value to set our scroll view's content
        // size.
        for (UIView* view in self.scrollView.subviews) {
            // UIScrollViews have 2 default child views
            // which represent the horizontal and vertical scrolling
            // indicators. Ignore any views we don't recognize.
            if (![view isKindOfClass:[UILabel class]] &&
                ![view isKindOfClass:[UISegmentedControl class]] &&
                ![view isKindOfClass:[UISlider class]]) {
                continue;
            }
            
            CGFloat currentViewY = view.frame.origin.y + view.frame.size.height;
            if (currentViewY > highestViewY) {
                highestViewY = currentViewY;
            }
        }
        
        // Add a bit of padding so the view doesn't end right at the button of the display
        self.scrollView.contentSize = CGSizeMake(self.scrollView.contentSize.width,
                                                 highestViewY + 20);
    }
}

// Adjust the subviews for the safe area on the iPhone X.
- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    
    if (@available(iOS 11.0, *)) {
        for (UIView* view in self.view.subviews) {
            // HACK: The official safe area is much too large for our purposes
            // so we'll just use the presence of any safe area to indicate we should
            // pad by 20.
            if (self.view.safeAreaInsets.left >= 20 || self.view.safeAreaInsets.right >= 20) {
                view.frame = CGRectMake(view.frame.origin.x + 20, view.frame.origin.y, view.frame.size.width, view.frame.size.height);
            }
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Always run settings in dark mode because we want the light fonts
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }
    
    DataManager* dataMan = [[DataManager alloc] init];
    TemporarySettings* currentSettings = [dataMan getSettings];
    
    // Ensure we pick a bitrate that falls exactly onto a slider notch
    _bitrate = bitrateTable[[self getSliderValueForBitrate:[currentSettings.bitrate intValue]]];

    NSInteger resolution = (int)self.resolutionSlider.value + 1;
    if (currentSettings.resolution) {
        resolution = [currentSettings.resolution integerValue];
    }
    
    NSInteger framerate;
    switch ([currentSettings.framerate integerValue]) {
        case 30:
            framerate = 0;
            break;
        default:
        case 60:
            framerate = 1;
            break;
        case 120:
            framerate = 2;
            break;
    }
    
    // Only show the 120 FPS option if we have a > 60-ish Hz display
    bool enable120Fps = false;
    if (@available(iOS 10.3, tvOS 10.3, *)) {
        if ([UIScreen mainScreen].maximumFramesPerSecond > 62) {
            enable120Fps = true;
        }
    }
    if (!enable120Fps) {
        [self.framerateSelector removeSegmentAtIndex:2 animated:NO];
    }
    
    // Only show the 1536p option for "recent" devices. We'll judge that by whether
    // they support HEVC decoding (A9 or later).
    if (@available(iOS 11.0, tvOS 11.0, *)) {
        if (!VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)) {
            self.resolutionSlider.maximumValue = 12;
        }
    } else {
        self.resolutionSlider.maximumValue = 12;
    }
    
    // Disable the HEVC and HDR selector if HEVC is not supported by the hardware
    // or the version of iOS. See comment in Connection.m for reasoning behind
    // the iOS 11.3 check.
    if (@available(iOS 11.3, tvOS 11.3, *)) {
        if (VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)) {
            [self.hevcSelector setSelectedSegmentIndex:currentSettings.useHevc ? 1 : 0];
            [self.hdrSelector setSelectedSegmentIndex:currentSettings.enableHdr ? 1 : 0];
        }
        else {
            [self.hevcSelector removeAllSegments];
            [self.hevcSelector insertSegmentWithTitle:@"Unsupported on this device" atIndex:0 animated:NO];
            [self.hevcSelector setEnabled:NO];
            [self.hdrSelector removeAllSegments];
            [self.hdrSelector insertSegmentWithTitle:@"Unsupported on this device" atIndex:0 animated:NO];
            [self.hdrSelector setEnabled:NO];
        }
    }
    else {
        [self.hevcSelector removeAllSegments];
        [self.hevcSelector insertSegmentWithTitle:@"Requires iOS 11.3 or later" atIndex:0 animated:NO];
        [self.hevcSelector setEnabled:NO];
        [self.hdrSelector removeAllSegments];
        [self.hdrSelector insertSegmentWithTitle:@"Requires iOS 11.3 or later" atIndex:0 animated:NO];
        [self.hdrSelector setEnabled:NO];
    }
    [self.touchModeSelector setSelectedSegmentIndex:currentSettings.absoluteTouchMode ? 1 : 0];
    [self.touchModeSelector addTarget:self action:@selector(touchModeChanged) forControlEvents:UIControlEventValueChanged];
    [self.statsOverlaySelector setSelectedSegmentIndex:currentSettings.statsOverlay ? 1 : 0];
    [self.btMouseSelector setSelectedSegmentIndex:currentSettings.btMouseSupport ? 1 : 0];
    [self.optimizeSettingsSelector setSelectedSegmentIndex:currentSettings.optimizeGames ? 1 : 0];
    [self.multiControllerSelector setSelectedSegmentIndex:currentSettings.multiController ? 1 : 0];
    [self.audioOnPCSelector setSelectedSegmentIndex:currentSettings.playAudioOnPC ? 1 : 0];
    NSInteger onscreenControls = [currentSettings.onscreenControls integerValue];
    [self.framerateSelector setSelectedSegmentIndex:framerate];
    [self.framerateSelector addTarget:self action:@selector(newResolutionFpsChosen) forControlEvents:UIControlEventValueChanged];
    [self.onscreenControlSelector setSelectedSegmentIndex:onscreenControls];
    [self.onscreenControlSelector setEnabled:!currentSettings.absoluteTouchMode];
    [self.resolutionSlider setMinimumValue:0];
    [self.resolutionSlider setMaximumValue:(sizeof(widthTable) / sizeof(*widthTable)) - 1];
    [self.resolutionSlider setValue:resolution];
    [self.resolutionSlider addTarget:self action:@selector(resolutionSliderMoved) forControlEvents:UIControlEventValueChanged];
    [self.bitrateSlider setMinimumValue:0];
    [self.bitrateSlider setMaximumValue:(sizeof(bitrateTable) / sizeof(*bitrateTable)) - 1];
    [self.bitrateSlider setValue:[self getSliderValueForBitrate:_bitrate] animated:YES];
    [self.bitrateSlider addTarget:self action:@selector(bitrateSliderMoved) forControlEvents:UIControlEventValueChanged];
    [self resolutionSliderMoved];
    [self updateBitrateText];
}

- (void) touchModeChanged {
    // Disable on-screen controls in absolute touch mode
    [self.onscreenControlSelector setEnabled:[self.touchModeSelector selectedSegmentIndex] == 0];
}

- (void) newResolutionFpsChosen {
    NSInteger fps = [self getChosenFrameRate];
    NSInteger width = [self getChosenStreamWidth];
    NSInteger height = [self getChosenStreamHeight];
    NSInteger defaultBitrate;
    
    // This table prefers 16:10 resolutions because they are
    // only slightly more pixels than the 16:9 equivalents, so
    // we don't want to bump those 16:10 resolutions up to the
    // next 16:9 slot.
    //
    // This logic is shamelessly stolen from Moonlight Qt:
    // https://github.com/moonlight-stream/moonlight-qt/blob/master/app/settings/streamingpreferences.cpp
    
    if (width * height <= 640 * 360) {
        defaultBitrate = 1000 * (fps / 30.0);
    }
    // This covers 1280x720 and 1280x800 too
    else if (width * height <= 1366 * 768) {
        defaultBitrate = 5000 * (fps / 30.0);
    }
    else if (width * height <= 1920 * 1200) {
        defaultBitrate = 10000 * (fps / 30.0);
    }
    else if (width * height <= 2560 * 1600) {
        defaultBitrate = 20000 * (fps / 30.0);
    }
    else /* if (width * height <= 3840 * 2160) */ {
        defaultBitrate = 40000 * (fps / 30.0);
    }
    
    // We should always be exactly on a slider position with default bitrates
    _bitrate = MIN(defaultBitrate, 100000);
    assert(bitrateTable[[self getSliderValueForBitrate:_bitrate]] == _bitrate);
    [self.bitrateSlider setValue:[self getSliderValueForBitrate:_bitrate] animated:YES];
    
    [self updateBitrateText];
}

- (void) resolutionSliderMoved {
    assert(self.resolutionSlider.value < (sizeof(widthTable) / sizeof(*widthTable)));
    _width = widthTable[(int)self.resolutionSlider.value];
    _height = heightTable[(int)self.resolutionSlider.value];
    [self updateResolutionText];
}

- (void) updateResolutionText {
    NSInteger gcd = [self greatestCommonDivisorM:_width N:_height];
    [self.resolutionLabel setText:[NSString stringWithFormat:resolutionFormat, _width, _height, _width / gcd, _height / gcd]];
}

- (void) bitrateSliderMoved {
    assert(self.bitrateSlider.value < (sizeof(bitrateTable) / sizeof(*bitrateTable)));
    _bitrate = bitrateTable[(int)self.bitrateSlider.value];
    [self updateBitrateText];
}

- (void) updateBitrateText {
    // Display bitrate in Mbps
    [self.bitrateLabel setText:[NSString stringWithFormat:bitrateFormat, _bitrate / 1000.]];
}

- (NSInteger) getChosenFrameRate {
    switch ([self.framerateSelector selectedSegmentIndex]) {
        case 0:
            return 30;
        case 1:
            return 60;
        case 2:
            return 120;
        default:
            abort();
    }
}

- (NSInteger) getChosenStreamHeight {
    return heightTable[(int)self.resolutionSlider.value];
}

- (NSInteger) getChosenStreamWidth {
    return widthTable[(int)self.resolutionSlider.value];
}

- (void) saveSettings {
    DataManager* dataMan = [[DataManager alloc] init];
    NSInteger resolution = (int)self.resolutionSlider.value;
    NSInteger framerate = [self getChosenFrameRate];
    NSInteger height = [self getChosenStreamHeight];
    NSInteger width = [self getChosenStreamWidth];
    NSInteger onscreenControls = [self.onscreenControlSelector selectedSegmentIndex];
    BOOL optimizeGames = [self.optimizeSettingsSelector selectedSegmentIndex] == 1;
    BOOL multiController = [self.multiControllerSelector selectedSegmentIndex] == 1;
    BOOL audioOnPC = [self.audioOnPCSelector selectedSegmentIndex] == 1;
    BOOL useHevc = [self.hevcSelector selectedSegmentIndex] == 1;
    BOOL enableHdr = [self.hdrSelector selectedSegmentIndex] == 1;
    BOOL btMouseSupport = [self.btMouseSelector selectedSegmentIndex] == 1;
    BOOL absoluteTouchMode = [self.touchModeSelector selectedSegmentIndex] == 1;
    BOOL statsOverlay = [self.statsOverlaySelector selectedSegmentIndex] == 1;
    [dataMan saveSettingsWithBitrate:_bitrate
                          resolution:resolution
                           framerate:framerate
                              height:height
                               width:width
                    onscreenControls:onscreenControls
                       optimizeGames:optimizeGames
                     multiController:multiController
                           audioOnPC:audioOnPC
                             useHevc:useHevc
                           enableHdr:enableHdr
                      btMouseSupport:btMouseSupport
                   absoluteTouchMode:absoluteTouchMode
                        statsOverlay:statsOverlay];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger) greatestCommonDivisorM:(NSInteger)m N:(NSInteger)n {
    NSInteger t, r;

    if (m < n) {
        t = m;
        m = n;
        n = t;
    }
    r = m % n;

    if (r == 0) {
        return n;
    } else {
        return [self greatestCommonDivisorM:n N:r];

    }
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
}


@end

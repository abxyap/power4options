#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <substrate.h>
#import <dlfcn.h>
#import <spawn.h>

#define DEFAULTS_PATH @"/var/jb/Library/PreferenceBundles/Power4OptionsPref.bundle/Slider.plist"
#define USER_PREFS_PATH @"/var/jb/User/Library/Preferences/alias20.power4options.plist"

@interface NSDistributedNotificationCenter : NSNotificationCenter
@end

@interface PHActionSlider : UIView {
	int _style;
	UIImageView* _knobImageView;
}
@property (readwrite) NSString *trackText;
-(void)setKnobImage:(id)arg1;
-(void)gUICache;
- (UIImageView*)knobImageView;
- (void)setNewKnobImage:(UIImage*)image;
- (UIView *)_knobView;
- (int)style;
-(void)executeToSB:(NSString *)commandValue;
@end

@interface _UIActionSlider : UIView {
	UIImageView* _knobImageView;
}

@property (readwrite) NSString *trackText;
@property (readwrite) UIImage *knobImage;

- (UIView*)_knobView;
- (UIImageView*)knobImageView;
- (void)setNewKnobImage:(UIImage*)image;
- (void)knobTapped;

@end

@interface SBUIPowerDownView : UIView {
	_UIActionSlider* _actionSlider;
}
@end

@interface SBPowerDownView : SBUIPowerDownView
-(void)gUICache;
-(void)showLoadingView;
-(void)_cancelButtonTapped;
@end

@interface SBPowerDownViewController : NSObject
@end

@interface PTPreferences : NSObject {
	NSArray *_modes;
	NSDictionary *_preferences;
}

@property (readonly) NSDictionary *preferences;
@property (readonly) NSArray *modes;

- (NSString*)modeForIndex:(int)index;
- (id)valueForSpecifier:(NSString*)specifier mode:(NSString*)mode;
- (UIImage*)iconForMode:(NSString*)mode;
- (UIColor*)tintColorForMode:(NSString*)mode;
- (NSArray*)trackTexts;
- (void)setPowerDownTrackText:(NSString*)trackText;

@end

@interface FBSystemService : NSObject
+(id)sharedInstance;
- (void)shutdownAndReboot:(BOOL)arg1;
- (void)exitAndRelaunch:(BOOL)arg1;

@end

static PTPreferences* kPTPreferences = nil;
// static BOOL kUseApps = false;
static BOOL kEnabled = false;
static BOOL kUseSBReload = false;
static int kCurrentIndex = 0;

static UIWindow * ourWin = nil;

@implementation PTPreferences
static void reconcilePreferences(NSMutableDictionary *defaults, NSMutableDictionary *customPrefs,
								 NSString *preferenceSpecifier, NSString *entryToReplace) {
	NSArray *defaultModes = [defaults allKeys]; //Array of modes listed in defaults

	for (int i = 0; i < [defaultModes count]; i++) {
		NSString *mode = [defaultModes objectAtIndex: i];
		NSString *customPrefsKey = [mode stringByAppendingString: preferenceSpecifier]; //Get key for given mode using
																						//preference specifier
		
		id preferenceObject = [customPrefs objectForKey: customPrefsKey];
		if (preferenceObject && !(([preferenceObject isKindOfClass: [NSString class]]) 
			&& ([preferenceObject isEqualToString: @""]))) {
			//Don't replace blank strings! Return to the placeholder (default)	
			[[defaults objectForKey: mode] setObject: preferenceObject forKey: entryToReplace];	
		}
	}
}

- (PTPreferences*)init {
	if ((self = [super init])) {
		NSMutableDictionary *defaults = [[NSMutableDictionary alloc] initWithContentsOfFile: DEFAULTS_PATH];
		NSMutableDictionary *customPrefs = [[NSMutableDictionary alloc] initWithContentsOfFile: USER_PREFS_PATH];
		if (customPrefs) {
			reconcilePreferences(defaults, customPrefs, @"-Toggle", @"enabled");
			reconcilePreferences(defaults, customPrefs, @"-String", @"string");
		}
		_preferences = [[NSDictionary alloc] initWithDictionary: defaults];
		_modes = [_preferences allKeys];
	}
	return self;	
}

- (NSString*)modeForIndex:(int)index {
	for (int i = 0; i < [self.modes count]; i++) {
		int loopingIndex = [[self valueForSpecifier: @"index" mode: [self.modes objectAtIndex: i]] intValue];
		if (loopingIndex == index) {
			return [self.modes objectAtIndex: i];
		}
	}
	return nil;
}

- (id)valueForSpecifier:(NSString*)specifier mode:(NSString*)mode {
	return [[_preferences objectForKey: mode] objectForKey: specifier];
}

- (UIImage*)iconForMode:(NSString*)mode {
	NSString *pathToIcon = [self valueForSpecifier: @"icon" mode: mode];
	// NSLog(@"[Power4Options] iconForMode path: %@", pathToIcon);
	UIImage *icon = [UIImage imageWithContentsOfFile: pathToIcon];
	return icon;
}

- (UIColor*)tintColorForMode:(NSString*)mode {
	NSString *colorString = [self valueForSpecifier: @"color" mode: mode];
	
	if ([colorString isEqualToString: @"red"]) {
		return [UIColor redColor];
	} else if ([colorString isEqualToString: @"orange"]) {
		return [UIColor orangeColor];
	} else if ([colorString isEqualToString: @"cyan"]) {
		return [UIColor cyanColor];
	} else if ([colorString isEqualToString: @"purple"]) {
		return [UIColor purpleColor];
	} else if ([colorString isEqualToString: @"gray"]) {
		return [UIColor grayColor];
	} else if ([colorString isEqualToString: @"black"]) {
		return [UIColor blackColor];
	} else if ([colorString isEqualToString: @"lightGray"]) {
		return [UIColor lightGrayColor];
	} else if ([colorString isEqualToString: @"blue"]) {
		return [UIColor blueColor];
	} else if ([colorString isEqualToString: @"magenta"]) {
		return [UIColor magentaColor];
	} else if ([colorString isEqualToString: @"brown"]) {
		return [UIColor brownColor];
	} else if ([colorString isEqualToString: @"green"]) {
		return [UIColor greenColor];
	} else {
		return nil;
	}
}

- (NSArray*)trackTexts {
	NSMutableArray *_trackTexts = [NSMutableArray new];
	
	for (int i = 0; i < [self.modes count]; i++) {
		[_trackTexts addObject: [self valueForSpecifier: @"string" mode: [self modeForIndex: i]]];
	}
	
	return [[NSArray alloc] initWithArray: _trackTexts];
}

- (void)setPowerDownTrackText:(NSString*)trackText {
	NSMutableDictionary *tempDict = [_preferences mutableCopy];
	[[tempDict objectForKey: @"PowerDown"] setObject: trackText forKey: @"string"];
	
	_preferences = [[NSDictionary alloc] initWithDictionary: tempDict];
}
@end

static int nextValidIndex() {
	BOOL firstValuePassed = NO;
	
  //Stop when the loop is complete (i has reached its initial value again)
	for (int i = (kCurrentIndex + 1); i != kCurrentIndex; i++) {
		if (i == [kPTPreferences.modes count]) {
			i = 0; //Reset if we have reached the end of the modes list
		}

		BOOL enabled = [[kPTPreferences valueForSpecifier: @"enabled" mode: [kPTPreferences modeForIndex: i]] boolValue];
		//Check if mode is enabled
		
		if (enabled) {
			return i;
		}
		
		firstValuePassed = YES;
	}
	return -1;
}

static void updatePrefs(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    // NSLog(@"[Power4Options] Received updatePrefs notification");
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/jb/var/mobile/Library/Preferences/alias20.power4options.plist"];
	// if([prefs objectForKey:@"useApps"]) {
	// 	kUseApps = [[prefs objectForKey:@"useApps"] boolValue];
	// } else {
	// 	kUseApps = true;
	// }	

	if([prefs objectForKey:@"enabled"]) {
		kEnabled = [[prefs objectForKey:@"enabled"] boolValue];
	} else {
		kEnabled = true;
	}	

	if([prefs objectForKey:@"useSbreload"]) {
		kUseSBReload = [[prefs objectForKey:@"useSbreload"] boolValue];
	} else {
		kUseSBReload = true;
	}
	
}

static void renewPrefs(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    // NSLog(@"[Power4Options] Received reloadPrefs notification");
	PTPreferences *ptp = [PTPreferences new];
	kPTPreferences = ptp;
}

static void doRespring(void) {
	if(kUseSBReload) {
		pid_t pid;
		int status;
		const char *argv[] = {"sbreload", NULL};
		posix_spawn(&pid, "/var/jb/usr/bin/sbreload", NULL, NULL, (char* const*)argv, NULL);
		waitpid(pid, &status, WEXITED);
	} else {
		pid_t pid;
		int status;
		const char *argv[] = {"killall", "-9", "backboardd", NULL};
		posix_spawn(&pid, "/var/jb/usr/bin/killall", NULL, NULL, (char* const*)argv, NULL);
		waitpid(pid, &status, WEXITED);
	}
}

static void doReboot(void) {
	pid_t pid;
	int status;
	const char *argv[] = {"p4octl", "--reboot", NULL};
	posix_spawn(&pid, "/var/jb/usr/local/bin/p4octl", NULL, NULL, (char* const*)argv, NULL);
	waitpid(pid, &status, WEXITED);
}

static void doSafeMode(void) {
	pid_t pid;
	int status;
	const char *argv[] = {"p4octl", "--safemode", NULL};
	posix_spawn(&pid, "/var/jb/usr/local/bin/p4octl", NULL, NULL, (char* const*)argv, NULL);
	waitpid(pid, &status, WEXITED);
}

static void doUserSpaceReboot(void) {
	pid_t pid;
	int status;
	const char *argv[] = {"p4octl", "--userspacereboot", NULL};
	posix_spawn(&pid, "/var/jb/usr/local/bin/p4octl", NULL, NULL, (char* const*)argv, NULL);
	waitpid(pid, &status, WEXITED);
}

static void doLDRestart(void) {
	pid_t pid;
	int status;
	const char *argv[] = {"p4octl", "--ldrestart", NULL};
	posix_spawn(&pid, "/var/jb/usr/local/bin/p4octl", NULL, NULL, (char* const*)argv, NULL);
	waitpid(pid, &status, WEXITED);
}

static void doUICache(void) {
	pid_t pid;
	int status;
	const char *argv[] = {"p4octl", "--uicache", NULL};
	posix_spawn(&pid, "/var/jb/usr/local/bin/p4octl", NULL, NULL, (char* const*)argv, NULL);
	waitpid(pid, &status, WEXITED);
}


%group ICHooks 
%hook PHActionSlider
-(void)layoutSubviews {
	%orig;
	//style 1 = poweroff slider, style 3 = sos slider
	if(kEnabled && [self style] == 1) {
		// int slideStyle = [self style];
		// NSLog(@"[Power4Options] slideStyle: %d", slideStyle);

		NSString *modeString = [kPTPreferences modeForIndex: kCurrentIndex];
	
		NSString *_trackText = [kPTPreferences valueForSpecifier: @"string" mode: modeString];
		UIImage *_knobImage = [kPTPreferences iconForMode: modeString];

		self.trackText = _trackText;
		[self setNewKnobImage: _knobImage];

		UITapGestureRecognizer *knobTap = [[UITapGestureRecognizer alloc] initWithTarget: self action:@selector(knobTapped)];
		knobTap.numberOfTapsRequired = 1;
		[[self _knobView] addGestureRecognizer: knobTap];

	}
}

//Sandbox: InCallService(17536) deny(1) process-fork.... then, send command to springboard instead.
-(void)_slideCompleted:(bool)arg1 {

	if(kEnabled && arg1 && [self style] == 1) {	
		NSString *modeString = [kPTPreferences modeForIndex: kCurrentIndex];
		if ([modeString isEqualToString: @"PowerDown"]) {
			// NSLog(@"[Power4Options] PowerDown selected.");
			%orig;
		} else if ([modeString isEqualToString: @"Reboot"]) {
			[self executeToSB:modeString];
		} else if ([modeString isEqualToString: @"UserSpaceReboot"]) {
			[self executeToSB:modeString];
		} else if ([modeString isEqualToString: @"LDRestart"]) {
			[self executeToSB:modeString];
		} else if ([modeString isEqualToString: @"Respring"]) {
			[self executeToSB:modeString];
		} else if ([modeString isEqualToString: @"SafeMode"]) {
			[self executeToSB:modeString];
		} else if ([modeString isEqualToString: @"UICache"]) {
			[self executeToSB:modeString];
		} else {
			// NSLog(@"[Power4Options] Unknown selected.");
			%orig;
		}
	} else {
		%orig(arg1);
	}
}
%new 
-(void)executeToSB:(NSString *)commandValue {
	NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
	[userInfo setObject:commandValue forKey:@"cmd"];
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"alias20.power4options.executer" object:nil userInfo:userInfo];
}

%new
- (UIImageView*)knobImageView {
	return MSHookIvar<UIImageView*>(self, "_knobImageView");
}

%new
- (void)setNewKnobImage:(UIImage*)image {
	image = [image imageWithRenderingMode: UIImageRenderingModeAlwaysTemplate];
	[self knobImageView].image = image;
	[self knobImageView].tintColor = [kPTPreferences tintColorForMode: [kPTPreferences modeForIndex: kCurrentIndex]];
}

%new
- (void)knobTapped {
	int _nextValidIndex = nextValidIndex();
	
	if (_nextValidIndex != -1) {
		kCurrentIndex = _nextValidIndex; //Switch indicies for next mode
		NSString *modeString = [kPTPreferences modeForIndex: kCurrentIndex];
	
		NSString *_trackText = [kPTPreferences valueForSpecifier: @"string" mode: modeString];
		UIImage *_knobImage = [kPTPreferences iconForMode: modeString];
	
		self.trackText = _trackText;
		[self setNewKnobImage: _knobImage];
	}
}
%end

%hook PHSOSViewController
-(void)buttonPressed:(id)arg1 {
	if(kEnabled) {
		kCurrentIndex = 0;
	}
	%orig;
}
%end

// %hook SBPowerDownViewController
// -(void)viewWillAppear:(id)arg1 {
// 	%orig;
// 	if(kEnabled) {
// 		SBPowerDownView *SBPDView = [self valueForKey:@"_powerDownView"];
// 		if(SBPDView) {
// 			_UIActionSlider *actionSlider = MSHookIvar<_UIActionSlider*>(SBPDView, "_actionSlider");

// 			UITapGestureRecognizer *knobTap = [[UITapGestureRecognizer alloc] initWithTarget: actionSlider action:@selector(knobTapped)];
// 			knobTap.numberOfTapsRequired = 1;
// 			[[actionSlider _knobView] addGestureRecognizer: knobTap];
// 		}
// 	}
// }

// %hook PHSlidingView
// -(id)_createPowerDownSlider {
// 	id ret = %orig;

// 	UITapGestureRecognizer *knobTap = [[UITapGestureRecognizer alloc] initWithTarget: actionSlider action:@selector(knobTapped)];
// 	knobTap.numberOfTapsRequired = 1;
// 	[(UIView *)ret addGestureRecognizer: knobTap];

// 	return ret;
// }
// %end

// %hook PHActionSlider
// -(void)layoutSubviews {
// 	%orig;

	
// }
// %end

%end

%group SBHooks 
// %hook SBIconModel
// -(BOOL)isIconVisible:(id)arg1 {
// 	NSString *str1 = @"Apple";
// 	NSArray *array = [NSArray arrayWithObjects:objects count:count];
// }
// %end


%hook _UIActionSlider
-(void)layoutSubviews {
	%orig;
	if(kEnabled) {
		NSString *modeString = [kPTPreferences modeForIndex: kCurrentIndex];
	
		NSString *_trackText = [kPTPreferences valueForSpecifier: @"string" mode: modeString];
		UIImage *_knobImage = [kPTPreferences iconForMode: modeString];

		self.trackText = _trackText;
		[self setNewKnobImage: _knobImage];
	}
}

%new
- (UIImageView*)knobImageView {
	return MSHookIvar<UIImageView*>(self, "_knobImageView");
}

%new
- (void)setNewKnobImage:(UIImage*)image {
	image = [image imageWithRenderingMode: UIImageRenderingModeAlwaysTemplate];
	[self knobImageView].image = image;
	[self knobImageView].tintColor = [kPTPreferences tintColorForMode: [kPTPreferences modeForIndex: kCurrentIndex]];
}

%new
- (void)knobTapped {
	int _nextValidIndex = nextValidIndex();
	
	if (_nextValidIndex != -1) {
		kCurrentIndex = _nextValidIndex; //Switch indicies for next mode
		NSString *modeString = [kPTPreferences modeForIndex: kCurrentIndex];
	
		NSString *_trackText = [kPTPreferences valueForSpecifier: @"string" mode: modeString];
		UIImage *_knobImage = [kPTPreferences iconForMode: modeString];
	
		self.trackText = _trackText;
		[self setNewKnobImage: _knobImage];
	}
}
%end

%hook SBPowerDownViewController
-(void)viewWillAppear:(id)arg1 {
	%orig;
	if(kEnabled) {
		SBPowerDownView *SBPDView = [self valueForKey:@"_powerDownView"];
		if(SBPDView) {
			_UIActionSlider *actionSlider = MSHookIvar<_UIActionSlider*>(SBPDView, "_actionSlider");

			UITapGestureRecognizer *knobTap = [[UITapGestureRecognizer alloc] initWithTarget: actionSlider action:@selector(knobTapped)];
			knobTap.numberOfTapsRequired = 1;
			[[actionSlider _knobView] addGestureRecognizer: knobTap];
		}
	}
}
%end

%hook SBPowerDownView
-(void)_powerDownSliderDidCompleteSlide {
	if(!kEnabled) {
		%orig;
		return;
	}
	
	NSString *modeString = [kPTPreferences modeForIndex: kCurrentIndex];
	if ([modeString isEqualToString: @"PowerDown"]) {
		// NSLog(@"[Power4Options] PowerDown selected.");
		%orig;
	} else if ([modeString isEqualToString: @"Reboot"]) {
		doReboot();
	} else if ([modeString isEqualToString: @"UserSpaceReboot"]) {
		// NSLog(@"[Power4Options] UserSpaceReboot selected.");
		doUserSpaceReboot();
	} else if ([modeString isEqualToString: @"LDRestart"]) {
		// NSLog(@"[Power4Options] LDRestart selected.");
		doLDRestart();
	} else if ([modeString isEqualToString: @"Respring"]) {
		doRespring();
	} else if ([modeString isEqualToString: @"SafeMode"]) {
		doSafeMode();
		// NSLog(@"[Power4Options] SafeMode selected.");
	} else if ([modeString isEqualToString: @"UICache"]) {
		doUICache();//[self gUICache];
	} else {
		%orig;
	}
}

%new 
-(void)showLoadingView {
	ourWin = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

	[ourWin setWindowLevel:1000 * 666.666];
	[ourWin makeKeyAndVisible];
	UIView *ourView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
	ourView.center = CGPointMake(CGRectGetWidth(ourWin.bounds) / 2, CGRectGetHeight(ourWin.bounds) / 2);
	UIColor *gray = [UIColor grayColor];
	[ourView setBackgroundColor:gray];
	[ourView setAlpha: 0.25];
	CALayer *ourLayer = [ourView layer];
	[ourLayer setCornerRadius: 15.0];

	UIActivityIndicatorView * activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
	activityView.frame = CGRectMake(0, 0, 80, 80);
	activityView.center = CGPointMake(CGRectGetWidth(ourWin.bounds) / 2, CGRectGetHeight(ourWin.bounds) / 2);
	[activityView setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleLarge];
	[activityView startAnimating];
	[ourWin addSubview:activityView];
	[ourView setUserInteractionEnabled:NO];

	[ourWin addSubview: ourView];
}

%new 
-(void)gUICache {
	// [self showLoadingView];
	doUICache();
	[ourWin setHidden:YES];
	ourWin = nil;
}

-(void)_cancelButtonTapped {
	if(kEnabled) {
		kCurrentIndex = 0;
	}
	%orig;
}
%end
%end

%ctor {
	@autoreleasepool {
		CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
		CFNotificationCenterAddObserver(center, NULL, updatePrefs, CFSTR("alias20.power4options.prefschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		updatePrefs(0, 0, 0, 0, 0);

		PTPreferences *ptp = [PTPreferences new];
		kPTPreferences = ptp;

		CFNotificationCenterRef center2 = CFNotificationCenterGetDarwinNotifyCenter();
		CFNotificationCenterAddObserver(center2, NULL, renewPrefs, CFSTR("alias20.power4options.prefschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);

		NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
		if([bundleID isEqualToString:@"com.apple.springboard"]) {
			[[NSDistributedNotificationCenter defaultCenter] addObserverForName:@"alias20.power4options.executer" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
				// NSLog(@"[Power4Options] notification.userInfo: %@", notification.userInfo);
				NSString *cmd = [notification.userInfo objectForKey:@"cmd"];
				if([cmd isEqualToString:@"Reboot"]) {
					doReboot();
				}
				if([cmd isEqualToString:@"UserSpaceReboot"]) {
					doUserSpaceReboot();
				}
				if([cmd isEqualToString:@"LDRestart"]) {
					doLDRestart();
				}
				if([cmd isEqualToString:@"Respring"]) {
					doRespring();
				}
				if([cmd isEqualToString:@"SafeMode"]) {
					doSafeMode();
				}
				if([cmd isEqualToString:@"UICache"]) {
					doUICache();
				}
			}];

			%init(SBHooks);
		}

		if([bundleID isEqualToString:@"com.apple.InCallService"]) {
			%init(ICHooks);
		}
	}
}
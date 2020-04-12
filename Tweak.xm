// CacheClearerX by alex_png
// Fork from CacheClearer by julioverne & RPetrich
// Clean your app’s cache or reset your apps through the storage section in the settings
// Or clear the cache by 3D Touching/Force Touching an app’s icon and selecting the option from the shortcut menu

#import <dlfcn.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "Tweak.h"
#import <AudioToolbox/AudioServices.h>

// I left the original headers here

extern const char *__progname;

// For the 3D Touch/Force Touch method
@interface SUUtility : NSObject
+ (BOOL)freeCachedSpaceSynchronous:(unsigned long long)arg1 timeout:(double)arg2;
@end

// For the storage settings method 
@interface PSSpecifier : NSObject
+ (instancetype)deleteButtonSpecifierWithName:(NSString *)name target:(id)target action:(SEL)action;
- (void)setProperty:(id)value forKey:(NSString *)key;
- (id)propertyForKey:(NSString *)key;
- (void)setConfirmationAction:(SEL)action;
@property (nonatomic, readonly) NSString *identifier;
+ (id)emptyGroupSpecifier;
@end

@interface PSViewController : UIViewController {
@public
	PSSpecifier *_specifier;
}
@end

@interface PSListController : PSViewController {
@public
	NSMutableArray *_specifiers;
}
- (NSArray *)specifiers;
- (void)showConfirmationViewForSpecifier:(PSSpecifier *)specifier;
@end

@interface UsageDetailController : PSListController
- (BOOL)isAppController;
@end

@interface LSBundleProxy : NSObject
@property (nonatomic, readonly) NSURL *dataContainerURL;
@end

@interface LSApplicationProxy : LSBundleProxy
+ (instancetype)applicationProxyForIdentifier:(NSString *)identifier;
@property (nonatomic, readonly) NSString *localizedShortName;
@property (nonatomic, readonly) NSString *itemName;
@property (nonatomic, readonly) NSNumber *dynamicDiskUsage;
@end

typedef const struct __SBSApplicationTerminationAssertion *SBSApplicationTerminationAssertionRef;

extern "C" SBSApplicationTerminationAssertionRef SBSApplicationTerminationAssertionCreateWithError(void *unknown, NSString *bundleIdentifier, int reason, int *outError);
extern "C" void SBSApplicationTerminationAssertionInvalidate(SBSApplicationTerminationAssertionRef assertion);
extern "C" NSString *SBSApplicationTerminationAssertionErrorString(int error);

#define NSLog(...)

@interface PSStorageApp : NSObject
@property (nonatomic,readonly) NSString * appIdentifier;
@property (nonatomic,readonly) LSApplicationProxy * appProxy;
@end

@interface STStorageAppDetailController : PSListController
{
	PSStorageApp* _storageApp;
}
@end

@interface UISUserInterfaceStyleMode : NSObject
@property (nonatomic, assign) long long modeValue;
@end

// Preferences Stuff
static NSMutableDictionary *settings;
static BOOL useShortcut;
static BOOL useHaptic;
static BOOL useShortcutAlert;

// Preferences Update
static void refreshPrefs() {
	CFArrayRef keyList = CFPreferencesCopyKeyList(CFSTR("com.alexpng.cacheclearerx"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	if (keyList) {
		settings = (NSMutableDictionary *)CFBridgingRelease(CFPreferencesCopyMultiple(keyList, CFSTR("com.alexpng.cacheclearerx"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
		CFRelease(keyList);
	} else {
		settings = nil;
	}
	if (!settings) {
		settings = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.alexpng.cacheclearerx.plist"];
	}
	useShortcut = [([settings objectForKey:@"useShortcut"] ?: @(NO)) boolValue];
	useHaptic = [([settings objectForKey:@"useHaptic"] ?: @(NO)) boolValue];
	useShortcutAlert = [([settings objectForKey:@"useShortcutAlert"] ?: @(NO)) boolValue];
	}
static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
  refreshPrefs();
}


// Specify the buttons and actions to the storage settings 
%hook STStorageAppDetailController
- (NSArray*)specifiers
{
	NSArray* ret = %orig;
	NSMutableArray* _specifiers = [ret mutableCopy];
		PSSpecifier* specifier;
		specifier = [PSSpecifier emptyGroupSpecifier];
        [_specifiers addObject:specifier];
		
		specifier = [PSSpecifier deleteButtonSpecifierWithName:@"Reset App" target:self action:@selector(resetDiskContent)];
		[specifier setConfirmationAction:@selector(clearCaches)];
		[_specifiers addObject:specifier];
		specifier = [PSSpecifier deleteButtonSpecifierWithName:@"Clear App's Cache" target:self action:@selector(clearCaches)];
		[specifier setConfirmationAction:@selector(clearCaches)];
		[_specifiers addObject:specifier];
		
		ret = [_specifiers copy];
		MSHookIvar<NSArray*>(self, "_specifiers") = ret;
	return ret;
}

// Cache path
static void ClearDirectoryURLContents(NSURL *url)
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSDirectoryEnumerator *enumerator = [fm enumeratorAtURL:url includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:nil];
	NSURL *child;
	while ((child = [enumerator nextObject])) {
		[fm removeItemAtURL:child error:NULL];
	}
}

// Alert after completion
static void ShowMessage(NSString *message)
{

	UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"CacheClearerX" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[av show];
	[av release];

}

// For App Reset
%new
- (void)resetDiskContent
{
	PSStorageApp* _storageApp = MSHookIvar<PSStorageApp*>(self, "_storageApp");	
	NSString *identifier = _storageApp.appIdentifier;
	LSApplicationProxy *app = [LSApplicationProxy applicationProxyForIdentifier:identifier];
	NSString *title = app.localizedShortName;
	NSNumber *originalDynamicSize = [[app.dynamicDiskUsage retain] autorelease];
	NSURL *dataContainer = app.dataContainerURL;
	SBSApplicationTerminationAssertionRef assertion = SBSApplicationTerminationAssertionCreateWithError(NULL, identifier, 1, NULL);
	ClearDirectoryURLContents([dataContainer URLByAppendingPathComponent:@"tmp" isDirectory:YES]);
	NSURL *libraryURL = [dataContainer URLByAppendingPathComponent:@"Library" isDirectory:YES];
	ClearDirectoryURLContents(libraryURL);
	[[NSFileManager defaultManager] createDirectoryAtURL:[libraryURL URLByAppendingPathComponent:@"Preferences" isDirectory:YES] withIntermediateDirectories:YES attributes:nil error:NULL];
	ClearDirectoryURLContents([dataContainer URLByAppendingPathComponent:@"Documents" isDirectory:YES]);
	if (assertion) {
		SBSApplicationTerminationAssertionInvalidate(assertion);
	}
	NSNumber *newDynamicSize = [LSApplicationProxy applicationProxyForIdentifier:identifier].dynamicDiskUsage;
	if ([newDynamicSize isEqualToNumber:originalDynamicSize]) {
		ShowMessage([NSString stringWithFormat:@"%@ was already reset, no disk space was reclaimed.", title]);
	} else {
		ShowMessage([NSString stringWithFormat:@"%@ is now restored to a fresh state. Reclaimed %@ bytes!", title, [NSNumber numberWithDouble:[originalDynamicSize doubleValue] - [newDynamicSize doubleValue]]]);
	}
}

// For Clear Cache 
%new
- (void)clearCaches
{
	PSStorageApp* _storageApp = MSHookIvar<PSStorageApp*>(self, "_storageApp");	
	NSString *identifier = _storageApp.appIdentifier;
	LSApplicationProxy *app = [LSApplicationProxy applicationProxyForIdentifier:identifier];
	NSString *title = app.localizedShortName;
	NSNumber *originalDynamicSize = [[app.dynamicDiskUsage retain] autorelease];
	NSURL *dataContainer = app.dataContainerURL;
	SBSApplicationTerminationAssertionRef assertion = SBSApplicationTerminationAssertionCreateWithError(NULL, identifier, 1, NULL);
	ClearDirectoryURLContents([dataContainer URLByAppendingPathComponent:@"tmp" isDirectory:YES]);
	ClearDirectoryURLContents([[dataContainer URLByAppendingPathComponent:@"Library" isDirectory:YES] URLByAppendingPathComponent:@"Caches" isDirectory:YES]);
	ClearDirectoryURLContents([[[dataContainer URLByAppendingPathComponent:@"Library" isDirectory:YES] URLByAppendingPathComponent:@"Application Support" isDirectory:YES] URLByAppendingPathComponent:@"Dropbox" isDirectory:YES]);
	if (assertion) {
		SBSApplicationTerminationAssertionInvalidate(assertion);
	}
	NSNumber *newDynamicSize = [LSApplicationProxy applicationProxyForIdentifier:identifier].dynamicDiskUsage;
	if ([newDynamicSize isEqualToNumber:originalDynamicSize]) {
		ShowMessage([NSString stringWithFormat:@"Cache for %@ was already empty, no disk space was reclaimed.", title]);
	} else {
		ShowMessage([NSString stringWithFormat:@"Reclaimed %@ bytes!\n%@ may use more data or run slower on next launch to repopulate the cache.", [NSNumber numberWithDouble:[originalDynamicSize doubleValue] - [newDynamicSize doubleValue]], title]);
	}
}

%end

// Adding 3D Touch/Force Touch shortcut
%hook SBIconView
- (void)setApplicationShortcutItems:(NSArray *)arg1 {
	NSMutableArray *newItems = [[NSMutableArray alloc] init];

	for (SBSApplicationShortcutItem *item in arg1) {
		[newItems addObject:item];
	}

if (@available(iOS 13, *)) {
BOOL darkEnabled;

darkEnabled = ([UITraitCollection currentTraitCollection].userInterfaceStyle == UIUserInterfaceStyleDark);
  
	  if (darkEnabled) {
     if (useShortcut) {
	NSData *clearImageData = UIImagePNGRepresentation([[UIImage imageWithContentsOfFile:@"/Library/Application Support/CacheClearerX/white.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]);

	SBSApplicationShortcutItem *clearCache = [%c(SBSApplicationShortcutItem) alloc];
    clearCache.localizedTitle = @"Clear Cache";
	clearCache.type = @"com.alexpng.cacheclearerx";
	[clearCache setIcon:[[SBSApplicationShortcutCustomImageIcon alloc] initWithImagePNGData:clearImageData]];

	[newItems addObject:clearCache];
      }
	%orig(newItems);

    } else if (!darkEnabled) {
      if (useShortcut) {

	NSData *clearImageData = UIImagePNGRepresentation([[UIImage imageWithContentsOfFile:@"/Library/Application Support/CacheClearerX/black.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]);

	SBSApplicationShortcutItem *clearCache = [%c(SBSApplicationShortcutItem) alloc];
    clearCache.localizedTitle = @"Clear Cache";
	clearCache.type = @"com.alexpng.cacheclearerx";
	[clearCache setIcon:[[SBSApplicationShortcutCustomImageIcon alloc] initWithImagePNGData:clearImageData]];

	[newItems addObject:clearCache];
    }
	%orig(newItems);
    }
  }
}

// Shortcut action
+ (void)activateShortcut:(SBSApplicationShortcutItem*)item withBundleIdentifier:(NSString*)bundleID forIconView:(SBIconView *)iconView {
	if([[item type] isEqualToString:@"com.alexpng.cacheclearerx"]) {	

// Haptic feedback
   if (useHaptic) {
AudioServicesPlaySystemSound(1519);
}

// Completion alert
   if (useShortcutAlert) {
	UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"CacheClearerX" message:@"Cache has been cleared. The app may use more data or run slower on next launch to repopulate the cache."  delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[av show];
	[av release];
}
dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			[%c(SUUtility) freeCachedSpaceSynchronous:999999999999 timeout:3600];
});

		return;
		%orig;
   }
}

%end

%ctor {
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback) PreferencesChangedCallback, CFSTR("com.alexpng.cacheclearerx.prefschanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	refreshPrefs();

dlopen("/System/Library/PrivateFrameworks/SoftwareUpdateServices.framework/SoftwareUpdateServices", RTLD_LAZY);

	dlopen("/System/Library/PreferenceBundles/StorageSettings.bundle/StorageSettings", RTLD_LAZY);

}
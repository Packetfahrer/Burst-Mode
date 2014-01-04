#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>

#define isiOS7 (kCFCoreFoundationVersionNumber > 793.00)
#define PREF_PATH @"/var/mobile/Library/Preferences/com.PS.BurstMode.plist"
#define LoadPlist NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
#define PLIST_PATH @"/Library/PreferenceBundles/BurstModeSettings.bundle/BurstMode.plist"
#define Id [[spec properties] objectForKey:@"id"]
#define setAvailable(available, spec) 	[spec setProperty:[NSNumber numberWithBool:available] forKey:@"enabled"]; \
										[self reloadSpecifier:spec animated:YES];
#define orig 	[self setPreferenceValue:value specifier:spec]; \
				[[NSUserDefaults standardUserDefaults] synchronize];
		
#define AddSpecBeforeSpec(spec, afterSpecName) \
if (![self specifierForID:spec.identifier] && [value boolValue]) \
	[self insertSpecifier:spec afterSpecifierID:afterSpecName animated:YES]; \
else if ([self specifierForID:spec.identifier] && ![value boolValue]) \
	[self removeSpecifierID:spec.identifier animated:YES];


@interface BurstModePreferenceController : PSListController {
	PSSpecifier *firstSpec;
	PSSpecifier *burstModeSpec;
	PSSpecifier *limitSpec;
	PSSpecifier *spaceSpec;
	PSSpecifier *holdTimeSliderSpec;
	PSSpecifier *space2Spec;
	PSSpecifier *intervalSliderSpec;
	PSSpecifier *burstModeSafeSpec;
	PSSpecifier *miscSpec;
	PSSpecifier *disableIrisSpec;
	PSSpecifier *disableAnimSpec;
	PSSpecifier *liveWellSpec;
	PSSpecifier *allowFlashSpec;
	PSSpecifier *allowHDRSpec;
	PSSpecifier *descriptionSpec;
}
@property (nonatomic, retain) PSSpecifier *firstSpec;
@property (nonatomic, retain) PSSpecifier *burstModeSpec;
@property (nonatomic, retain) PSSpecifier *limitSpec;
@property (nonatomic, retain) PSSpecifier *spaceSpec;
@property (nonatomic, retain) PSSpecifier *holdTimeSliderSpec;
@property (nonatomic, retain) PSSpecifier *space2Spec;
@property (nonatomic, retain) PSSpecifier *intervalSliderSpec;
@property (nonatomic, retain) PSSpecifier *burstModeSafeSpec;
@property (nonatomic, retain) PSSpecifier *miscSpec;
@property (nonatomic, retain) PSSpecifier *disableIrisSpec;
@property (nonatomic, retain) PSSpecifier *disableAnimSpec;
@property (nonatomic, retain) PSSpecifier *liveWellSpec;
@property (nonatomic, retain) PSSpecifier *allowFlashSpec;
@property (nonatomic, retain) PSSpecifier *allowHDRSpec;
@property (nonatomic, retain) PSSpecifier *descriptionSpec;
@end

@implementation BurstModePreferenceController

@synthesize firstSpec;
@synthesize burstModeSpec;
@synthesize limitSpec;
@synthesize spaceSpec;
@synthesize holdTimeSliderSpec;
@synthesize space2Spec;
@synthesize intervalSliderSpec;
@synthesize burstModeSafeSpec;
@synthesize miscSpec;
@synthesize disableIrisSpec;
@synthesize disableAnimSpec;
@synthesize liveWellSpec;
@synthesize allowFlashSpec;
@synthesize allowHDRSpec;
@synthesize descriptionSpec;

- (void)hideKeyboard
{
	[[super view] endEditing:YES];
}

- (void)addBtn
{
	UIBarButtonItem *hideKBBtn = [[UIBarButtonItem alloc]
        initWithTitle:@"Hide KB" style:UIBarButtonItemStyleBordered
        target:self action:@selector(hideKeyboard)];
	((UINavigationItem *)[super navigationItem]).rightBarButtonItem = hideKBBtn;
	[hideKBBtn release];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	if (!isiOS7)
		[self addBtn];
}

- (void)viewDidUnload
{
	if (!isiOS7) {
		NSMutableArray *specs = [NSMutableArray arrayWithArray:[self loadSpecifiersFromPlistName:@"BurstMode" target:self]];
		for (PSSpecifier *spec in specs) {
			if ([Id length] > 0)
			spec = nil;
		}
	}
    [super viewDidUnload];
}

- (void)setBurstMode:(id)value specifier:(PSSpecifier *)spec
{
	orig
	
	AddSpecBeforeSpec(self.limitSpec, @"BurstMode")
	AddSpecBeforeSpec(self.spaceSpec, @"PLC")
	AddSpecBeforeSpec(self.holdTimeSliderSpec, @"Space")
	AddSpecBeforeSpec(self.space2Spec, @"HoldTimeSlider")
	AddSpecBeforeSpec(self.intervalSliderSpec, @"Space2")
	AddSpecBeforeSpec(self.burstModeSafeSpec, @"IntervalSlider")
	AddSpecBeforeSpec(self.miscSpec, @"BurstModeSafe")
	AddSpecBeforeSpec(self.disableIrisSpec, @"Misc")
	AddSpecBeforeSpec(self.disableAnimSpec, @"DisableIris")
	AddSpecBeforeSpec(self.liveWellSpec, @"DisableAnim")
	AddSpecBeforeSpec(self.allowFlashSpec, @"LiveWell")
	AddSpecBeforeSpec(self.allowHDRSpec, @"AllowFlash")
	AddSpecBeforeSpec(self.descriptionSpec, @"AllowHDR")
	
	LoadPlist
	[self.spaceSpec setProperty:[NSString stringWithFormat:@"Delay: %.2f s", [dict objectForKey:@"HoldTime"] ? [[dict objectForKey:@"HoldTime"] floatValue] : 1.2f] forKey:@"footerText"];
	[self reloadSpecifier:self.spaceSpec animated:NO];
	[self.space2Spec setProperty:[NSString stringWithFormat:@"Interval: %.2f s", [dict objectForKey:@"Interval"] ? [[dict objectForKey:@"Interval"] floatValue] : .8f] forKey:@"footerText"];
	[self reloadSpecifier:self.space2Spec animated:NO];
}

- (void)setBurstModeSafe:(id)value specifier:(PSSpecifier *)spec
{
	orig
	system("killall Camera");
}

- (void)setHoldTime:(id)value specifier:(PSSpecifier *)spec
{
	orig
	[self.spaceSpec setProperty:[NSString stringWithFormat:@"Delay: %.2f s", [value floatValue]] forKey:@"footerText"];
	[self reloadSpecifier:self.spaceSpec animated:NO];
}

- (void)setInterval:(id)value specifier:(PSSpecifier *)spec
{
	orig
	[self.space2Spec setProperty:[NSString stringWithFormat:@"Interval: %.2f s", [value floatValue]] forKey:@"footerText"];
	[self reloadSpecifier:self.space2Spec animated:NO];
}

- (NSArray *)specifiers
{
	if (_specifiers == nil) {
		NSMutableArray *specs = [NSMutableArray arrayWithArray:[self loadSpecifiersFromPlistName:@"BurstMode" target:self]];
		LoadPlist
		
		for (PSSpecifier *spec in specs) {
			if ([Id isEqualToString:@"first"])
                self.firstSpec = spec;
			if ([Id isEqualToString:@"BurstMode"])
                self.burstModeSpec = spec;
            if ([Id isEqualToString:@"PLC"])
                self.limitSpec = spec;
            if ([Id isEqualToString:@"Space"])
                self.spaceSpec = spec;
            if ([Id isEqualToString:@"HoldTimeSlider"])
                self.holdTimeSliderSpec = spec;
            if ([Id isEqualToString:@"Space2"])
                self.space2Spec = spec;
            if ([Id isEqualToString:@"IntervalSlider"])
                self.intervalSliderSpec = spec;
            if ([Id isEqualToString:@"BurstModeSafe"])
                self.burstModeSafeSpec = spec;
            if ([Id isEqualToString:@"Misc"])
                self.miscSpec = spec;
            if ([Id isEqualToString:@"DisableIris"])
                self.disableIrisSpec = spec;
            if ([Id isEqualToString:@"DisableAnim"])
                self.disableAnimSpec = spec;
            if ([Id isEqualToString:@"LiveWell"])
                self.liveWellSpec = spec;
            if ([Id isEqualToString:@"AllowFlash"])
                self.allowFlashSpec = spec;
            if ([Id isEqualToString:@"AllowHDR"])
                self.allowHDRSpec = spec;
            if ([Id isEqualToString:@"Description"])
            	self.descriptionSpec = spec;
        	}
       		
       		[self.spaceSpec setProperty:[NSString stringWithFormat:@"Delay: %.2f s", [dict objectForKey:@"HoldTime"] ? [[dict objectForKey:@"HoldTime"] floatValue] : 1.2f] forKey:@"footerText"];
			[self reloadSpecifier:self.spaceSpec animated:NO];
       		[self.space2Spec setProperty:[NSString stringWithFormat:@"Interval: %.2f s", [dict objectForKey:@"Interval"] ? [[dict objectForKey:@"Interval"] floatValue] : .8f] forKey:@"footerText"];
			[self reloadSpecifier:self.space2Spec animated:NO];
			
			if (![[dict objectForKey:@"BurstModeEnabled"] boolValue] || isiOS7) {
        		[specs removeObject:self.limitSpec];
        		[specs removeObject:self.spaceSpec];
        		[specs removeObject:self.holdTimeSliderSpec];
        		[specs removeObject:self.space2Spec];
        		[specs removeObject:self.intervalSliderSpec];
        		[specs removeObject:self.burstModeSafeSpec];
        		[specs removeObject:self.miscSpec];
        		[specs removeObject:self.disableIrisSpec];
        		[specs removeObject:self.disableAnimSpec];
        		[specs removeObject:self.liveWellSpec];
        		[specs removeObject:self.allowFlashSpec];
        		[specs removeObject:self.allowHDRSpec];
       			[specs removeObject:self.descriptionSpec];
       		}
       		
       		if (isiOS7) {
       			[specs removeObject:self.burstModeSpec];
       			[self.firstSpec setProperty:@"Preferences is not needed for iOS 7\n\nThe tweak will enable iPhone 5s\' Burst Mode style for your device. (With photos count indicator & faster performance)\n\nThere\'s an issue for iPad, you may temporary fix them by forcing iPhone UI for Camera app because Apple didn't design Burst Mode to be functional on iPad, I\'m working on this.\n\n© 2013 - 2014 Thuchapol Unprasert\n(@PoomSmart)" forKey:@"footerText"];
       			[self reloadSpecifier:self.firstSpec animated:NO];
       		}
        
        	_specifiers = [specs copy];
 	}
	return _specifiers;
}

@end


#import <UIKit/UIKit.h>

#define isiOS7 (kCFCoreFoundationVersionNumber > 793.00)

@interface PLCameraButton : UIButton
@end

@interface PLCameraButtonBar : UIToolbar
@property(retain, nonatomic) PLCameraButton* cameraButton;
@end

@interface PLCameraView : UIView
@property(retain, nonatomic) UIToolbar* bottomButtonBar;
- (BOOL)hasInFlightCaptures;
- (void)_shutterButtonClicked;
- (void)setHDRIsOn:(BOOL)on;
- (void)resumePreview;
- (void)_setShouldShowFocus:(BOOL)focus;
- (void)hideStaticClosedIris;
- (void)_updatePreviewWellImage:(id)image;
- (void)_setOverlayControlsEnabled:(BOOL)enabled;
- (void)_setFlashMode:(int)mode;
- (void)_clearFocusViews;
- (void)_setBottomBarEnabled:(BOOL)enabled;
- (void)setCameraButtonsEnabled:(BOOL)enabled;
- (void)takePictureOpenIrisAnimationFinished;
@end

@interface PLCameraButton (BurstMode)
- (void)burst;
- (void)takePhoto;
@end

@interface PLCameraController : NSObject
@property(assign, nonatomic, getter=isHDREnabled) BOOL HDREnabled;
+ (id)sharedInstance;
- (PLCameraView *)delegate;
- (BOOL)isCapturingVideo;
- (BOOL)isFocusLockSupported;
- (void)setFaceDetectionEnabled:(BOOL)enabled;
- (void)setFocusDisabled:(BOOL)disabled;
- (void)_lockFocus:(BOOL)focus lockExposure:(BOOL)exposure lockWhiteBalance:(BOOL)whiteBalance;
@end

@interface UIApplication (FrontFlash)
- (void)setBacklightLevel:(float)level;
@end

%group iOS6

#define cont [%c(PLCameraController) sharedInstance]
#define isCapturingVideo [cont isCapturingVideo]

static BOOL BurstMode;
static BOOL BurstModeSafe;
static BOOL DisableIris;
static BOOL DisableAnim;
static BOOL LiveWell;
static BOOL AllowFlash;
static BOOL AllowHDR;

static BOOL isPhotoCamera = NO;
static BOOL isFrontCamera = NO;
static BOOL isBackCamera = NO;
static BOOL hasFrontFlash = NO;
static BOOL disableIris = NO;
static BOOL burst = NO;
static BOOL counterAnimate = NO;
static BOOL ignoreCapture = NO;
static BOOL noAutofocus = NO;

static float previousBacklightLevel;
static float Interval;
static float HoldTime;
static unsigned int limitedPhotosCount;

static NSTimer* BMPressTimer;
static NSTimer* BMHoldTimer;

static UIView *counterBG = nil;
static UILabel *counter = nil;

static unsigned int photoCount = 0;

static void hideCounter()
{
	if (burst) {
		counterAnimate = YES;
		[UIView animateWithDuration:0.9f delay:0.0f options:0
            animations:^{
    			counterBG.alpha = 0.0f;
    			counter.alpha = 0.0f;
            }
        	completion:^(BOOL finished) {
				[counterBG setHidden:YES];
				[counter setText:@"000"];
        	}];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3*NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
        	burst = NO;
        });
		photoCount = 0;
		counterAnimate = NO;
	}
}

static void invalidateTimer()
{
	if (BMHoldTimer != nil) {
       	[BMHoldTimer invalidate];
        BMHoldTimer = nil;
    }
    if (BMPressTimer != nil) {
        [BMPressTimer invalidate];
        BMPressTimer = nil;
   	}
}

static void cleanup()
{
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.25*NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
		if (!isCapturingVideo) {
			[[cont delegate] _setBottomBarEnabled:YES];
			[[cont delegate] _setOverlayControlsEnabled:YES];
			[[cont delegate] setCameraButtonsEnabled:YES];
		}
		[cont setFocusDisabled:NO];
		if ([cont isFocusLockSupported] && noAutofocus)
			[cont _lockFocus:NO lockExposure:NO lockWhiteBalance:NO];
		[[cont delegate] _setShouldShowFocus:YES];
		if ([cont respondsToSelector:@selector(setFaceDetectionEnabled:)])
			[cont setFaceDetectionEnabled:YES];
	});
	noAutofocus = NO;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.65*NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
		disableIris = NO;
	});
}

static void FrontFlashCleanup()
{
	if (hasFrontFlash && isFrontCamera) {
		for (UIView *view in [UIApplication sharedApplication].keyWindow.subviews) {
			if (view.tag == 9596) {
				[UIView animateWithDuration:0.5f delay:0.0f options:0
                animations:^{
    				view.alpha = 0.0f;
            	}
        		completion:^(BOOL finished) {
					[view removeFromSuperview];
					[view release];
					[[UIApplication sharedApplication] setBacklightLevel:previousBacklightLevel];
					GSEventSetBacklightLevel(previousBacklightLevel);
        		}];
			}
		}
	}
}

static void BurstModeLoader()
{
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.PS.BurstMode.plist"];
	#define readOption(prename, name, defaultValue) \
		name = [dict objectForKey:prename] ? [[dict objectForKey:prename] boolValue] : defaultValue;
		
	readOption(@"BurstModeEnabled", BurstMode, NO)
	readOption(@"BurstModeSafeEnabled", BurstModeSafe, YES)
	readOption(@"DisableIrisEnabled", DisableIris, NO)
	readOption(@"DisableAnimEnabled", DisableAnim, NO)
	readOption(@"LiveWellEnabled", LiveWell, NO)
	readOption(@"AllowFlashEnabled", AllowFlash, NO)
	readOption(@"AllowHDREnabled", AllowHDR, NO)
	id PLC = [dict objectForKey:@"PhotoLimitCount"];
	limitedPhotosCount = PLC ? [PLC intValue] : 0;
	id HTValue = [dict objectForKey:@"HoldTime"];
	HoldTime = HTValue ? [HTValue floatValue] : 1.2f;
	id IntervalValue = [dict objectForKey:@"Interval"];
	Interval = IntervalValue ? [IntervalValue floatValue] : 0.8f;
}

%hook PLCameraButton

- (id)initWithDefaultSize
{
	self = %orig;
	if (self) {
		if (BurstMode) {
			[self addTarget:self action:@selector(sendPressed) forControlEvents:UIControlEventTouchDown];
			[self addTarget:self action:@selector(sendReleased) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
		}
	}
	return self;
}

%new
- (void)sendPressed
{
	if (isPhotoCamera) {
		if (BurstMode) {
			BMHoldTimer = [NSTimer scheduledTimerWithTimeInterval:HoldTime target:self selector:@selector(burst) userInfo:nil repeats:NO];
			[BMHoldTimer retain];
		}
	}
}

%new
- (void)takePhoto
{
	if (BurstModeSafe) {
		if (![[cont delegate] hasInFlightCaptures])
			[[cont delegate] performSelectorOnMainThread:@selector(_shutterButtonClicked) withObject:nil waitUntilDone:YES];
	} else
		[[cont delegate] performSelectorOnMainThread:@selector(_shutterButtonClicked) withObject:nil waitUntilDone:NO];
}

%new
- (void)burst
{
	if (isPhotoCamera) {
		if (counterAnimate)
			return;
		noAutofocus = YES;
		burst = YES;
		[counter setHidden:NO];
		[counterBG setHidden:NO];
		counter.alpha = 1.0f;
		counterBG.alpha = 0.4f;
		if (hasFrontFlash)
			previousBacklightLevel = [UIScreen mainScreen].brightness;
		disableIris = DisableIris;
		[PLCameraView cancelPreviousPerformRequestsWithTarget:self selector:@selector(autofocus) object:nil];
		if ([cont isFocusLockSupported] && noAutofocus)
			[cont _lockFocus:YES lockExposure:NO lockWhiteBalance:NO];
		[cont setFocusDisabled:YES];
		[[cont delegate] _setShouldShowFocus:NO];
		if (isBackCamera && !AllowFlash)
			[[cont delegate] _setFlashMode:-1];
		if (!AllowHDR)
			[[cont delegate] setHDRIsOn:NO];
		if ([cont respondsToSelector:@selector(setFaceDetectionEnabled:)])
			[cont setFaceDetectionEnabled:NO];
		[self takePhoto];
		BMPressTimer = [NSTimer scheduledTimerWithTimeInterval:Interval target:self selector:@selector(takePhoto) userInfo:nil repeats:YES];
		[BMPressTimer retain];
	}
}

%new
- (void)sendReleased
{
	if (isPhotoCamera) {
		if (BurstMode) {
			invalidateTimer();
			ignoreCapture = burst;
			cleanup();
   			FrontFlashCleanup();
    		hideCounter();
    	}
	}
}

%end

%hook PLCameraView

- (void)_handleVolumeButtonUp
{
	%orig;
	if (isPhotoCamera) {
		if (BurstMode)
			[(PLCameraButton *)[(PLCameraButtonBar *)self.bottomButtonBar cameraButton] sendActionsForControlEvents:UIControlEventTouchUpInside];
	}
}

- (void)_handleVolumeButtonDown
{
	if (isPhotoCamera) {
		if (BurstMode)
			[(PLCameraButton *)[(PLCameraButtonBar *)self.bottomButtonBar cameraButton] sendActionsForControlEvents:UIControlEventTouchDown];
		else
			%orig;
	} else
		%orig;
}

- (void)_shutterButtonClicked
{
	if (BurstMode) {
		if (isPhotoCamera) {
			if (ignoreCapture) {
				ignoreCapture = NO;
				return;
			}
		}
	}
	%orig;
}

- (void)dealloc
{
	invalidateTimer();
	if (counter != nil) {
		[counter removeFromSuperview];
		[counter release];
		counter = nil;
	}
	if (counterBG != nil) {
		[counterBG removeFromSuperview];
		[counterBG release];
		counterBG = nil;
	}
	%orig;
}

- (void)viewDidAppear
{
	%orig;
	if (BurstMode) {
		if (!counter) {
			counter = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 60.0f, 20.0f)];
			counter.text = @"000";
			[counter setFont:[UIFont fontWithName:@"HelveticaNeue" size:20.0f]];
			counter.textColor = [UIColor whiteColor];
			counter.backgroundColor = [UIColor clearColor];
			[counter setAutoresizingMask:2];
			[counter setHidden:YES];
		}
		if (!counterBG) {
			counterBG = [[UIView alloc] initWithFrame:CGRectMake(-28.0f, -48.0f, 56.0f, 56.0f)];
			counterBG.alpha = 0.4f;
			counterBG.backgroundColor = [UIColor blackColor];
			counterBG.layer.cornerRadius = 28.0f;
			[counterBG setHidden:YES];
		}
		UIView *textOverlayView = MSHookIvar<UIView *>(self, "_textOverlayView");
		[counterBG addSubview:counter];
		counter.center = CGPointMake(28.0f, 28.0f);
		counter.textAlignment = UITextAlignmentCenter;
		[textOverlayView addSubview:counterBG];
	}
}

- (void)_setupAnimatePreviewDown:(id)down flipImage:(BOOL)image panoImage:(BOOL)image3 snapshotFrame:(CGRect)frame
{
	if (BurstMode) {
		if (isPhotoCamera && !isCapturingVideo && burst) {
			if (DisableAnim)
				return;
			%orig;
			return;
		}
	}
	%orig;
}

- (void)openIrisWithDidFinishSelector:(SEL)openIrisWith withDuration:(float)duration
{
	if (BurstMode) {
		if (isPhotoCamera && DisableIris && disableIris && burst && !isCapturingVideo) {
			[self hideStaticClosedIris];
			[self takePictureOpenIrisAnimationFinished];
			return;
		}
		%orig;
		return;
	}
	%orig;
}

- (void)closeIrisWithDidFinishSelector:(SEL)closeIrisWith withDuration:(float)duration
{
	if (BurstMode) {
		if (isPhotoCamera && DisableIris && disableIris && burst && !isCapturingVideo) {
			[self _clearFocusViews];
			[self resumePreview];
			return;
		}
		%orig;
		return;
	}
	%orig;
}

%end

%hook PLCameraController

- (void)_setCameraMode:(int)mode cameraDevice:(int)device
{
	isPhotoCamera = (mode == 0);
	isBackCamera = (isPhotoCamera && device == 0);
	isFrontCamera = (isPhotoCamera && device == 1);
	%orig;
}

- (BOOL)isHDREnabled
{
	BOOL enabled = %orig;
	if (BurstMode) {
		if (isPhotoCamera) {
			if (enabled)
				counterBG.frame = CGRectMake(0.0f, -63.0f, 56.0f, 56.0f);
			else
				counterBG.frame = CGRectMake(-28.0f, -48.0f, 56.0f, 56.0f);
		}
	}
	return enabled;
}

- (void)capturePhoto
{
	if (BurstMode) {
		if (isPhotoCamera) {
			if (burst) {
				photoCount++;
				if (limitedPhotosCount > 0) {
					if (photoCount == limitedPhotosCount)
						invalidateTimer();
				}
				char cString[4];
        		sprintf(cString, "%d", photoCount);
				NSString *s = [[[NSString alloc] initWithUTF8String:cString] autorelease];
				if (photoCount <= 9)
					[counter setText:[@"00" stringByAppendingString:s]];
				else if (photoCount >= 10 && photoCount <= 99)
					[counter setText:[@"0" stringByAppendingString:s]];
				else if (photoCount >= 100)
					[counter setText:s];
				if (DisableIris) {
					if (LiveWell) {
						NSMutableArray *imgArray = MSHookIvar<NSMutableArray *>([self delegate], "_previewWellImages");
						if ([imgArray count] > 0)
							[[self delegate] _updatePreviewWellImage:(UIImage *)[imgArray lastObject]];
					}
				}
			}
		}
	}
	%orig;
}

- (void)autofocus
{
	if (BurstMode) {
		if (isPhotoCamera) {
			if (noAutofocus && burst)
				return;
		}
	}
	%orig;
}

- (void)_autofocus:(BOOL)focus autoExpose:(BOOL)expose
{
	if (BurstMode) {
		if (isPhotoCamera) {
			if (noAutofocus && burst)
				return;
		}
	}
	%orig;
}

%end

static void PostNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	BurstModeLoader();
}

%end

%group iOS7

%hook PUPhotoBrowserControllerPadSpec

- (id)avalancheReviewControllerSpec
{
	return [[%c(PUAvalancheReviewControllerPhoneSpec) alloc] autorelease];
}

%end

%hook CAMCameraSpec

- (BOOL)shouldCreateAvalancheIndicator
{
	return YES;
}

%end

%hook PLCameraController

- (BOOL)supportsAvalancheForDevice:(int)device
{
	return YES;
}

%end

%end


%ctor {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	if (isiOS7) {
		%init(iOS7);
	}
	else {
		hasFrontFlash = NO;
		void *openFrontFlash = dlopen("/Library/MobileSubstrate/DynamicLibraries/FrontFlash.dylib", RTLD_LAZY);
		if (openFrontFlash != NULL)
			hasFrontFlash = YES;
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PostNotification, CFSTR("com.PS.BurstMode.settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		BurstModeLoader();
		%init(iOS6);
	}
	[pool drain];
}
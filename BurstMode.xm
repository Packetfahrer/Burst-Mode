#import "BurstMode.h"

static BOOL BurstMode;
static BOOL AllowFlash;
static BOOL AllowHDR;
static BOOL expFormat;
static BOOL Fast7;
static BOOL animInd;

static BOOL hasFrontFlash = NO;
static BOOL isFrontCamera = NO;

static unsigned int limitedPhotosCount;
static float previousBacklightLevel;

static void FrontFlashCleanup()
{
	if (hasFrontFlash && isFrontCamera) {
		for (UIView *view in [UIApplication sharedApplication].keyWindow.subviews) {
			if (view.tag == 9596) {
				[UIView animateWithDuration:.45 delay:0 options:0
                animations:^{
    				view.alpha = 0;
            	}
        		completion:^(BOOL finished) {
        			if (finished) {
						[view removeFromSuperview];
						[view release];
						[[UIApplication sharedApplication] setBacklightLevel:previousBacklightLevel];
						GSEventSetBacklightLevel(previousBacklightLevel);
					}
        		}];
			}
		}
	}
}

%group iOS6

#define cont [%c(PLCameraController) sharedInstance]
#define isCapturingVideo [cont isCapturingVideo]

static BOOL BurstModeSafe;
static BOOL DisableIris;
static BOOL DisableAnim;
static BOOL LiveWell;

static BOOL isPhotoCamera = NO;
static BOOL isBackCamera = NO;
static BOOL disableIris = NO;
static BOOL burst = NO;
static BOOL counterAnimate = NO;
static BOOL ignoreCapture = NO;
static BOOL noAutofocus = NO;

static float Interval;
static float HoldTime;

static NSTimer* BMPressTimer;
static NSTimer* BMHoldTimer;

static UIView *counterBG = nil;
static UILabel *counter = nil;

static unsigned int photoCount = 0;

static void hideCounter()
{
	if (burst) {
		counterAnimate = YES;
		[UIView animateWithDuration:.9 delay:0 options:0
            animations:^{
    			counterBG.alpha = 0;
    			counter.alpha = 0;
            }
        	completion:^(BOOL finished) {
				counterBG.hidden = YES;
				counter.text = @"000";
        	}];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, .3*NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
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
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, .65*NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
		disableIris = NO;
	});
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
	readOption(@"expFormat", expFormat, NO)
	readOption(@"Fast7", Fast7, NO)
	readOption(@"AnimInd", animInd, NO)
	id PLC = [dict objectForKey:@"PhotoLimitCount"];
	limitedPhotosCount = PLC ? [PLC intValue] : 0;
	id HTValue = [dict objectForKey:@"HoldTime"];
	HoldTime = HTValue ? [HTValue floatValue] : 1.2;
	id IntervalValue = [dict objectForKey:@"Interval"];
	Interval = IntervalValue ? [IntervalValue floatValue] : .8;
}

%hook PLCameraButton

- (id)initWithDefaultSize
{
	self = %orig;
	if (self) {
		[self addTarget:self action:@selector(sendPressed) forControlEvents:UIControlEventTouchDown];
		[self addTarget:self action:@selector(sendReleased) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
	}
	return self;
}

%new
- (void)sendPressed
{
	if (isPhotoCamera) {
		BMHoldTimer = [NSTimer scheduledTimerWithTimeInterval:HoldTime target:self selector:@selector(burst) userInfo:nil repeats:NO];
		[BMHoldTimer retain];
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
		counter.hidden = NO;
		counterBG.hidden = NO;
		counter.alpha = 1;
		counterBG.alpha = .4;
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
		invalidateTimer();
		ignoreCapture = burst;
		cleanup();
   		FrontFlashCleanup();
    	hideCounter();
	}
}

%end

%hook PLCameraView

- (void)_handleVolumeButtonUp
{
	%orig;
	if (isPhotoCamera)
		[(PLCameraButton *)[(PLCameraButtonBar *)self.bottomButtonBar cameraButton] sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (void)_handleVolumeButtonDown
{
	if (isPhotoCamera)
		[(PLCameraButton *)[(PLCameraButtonBar *)self.bottomButtonBar cameraButton] sendActionsForControlEvents:UIControlEventTouchDown];
	else
		%orig;
}

- (void)_shutterButtonClicked
{
	if (isPhotoCamera) {
		if (ignoreCapture) {
			ignoreCapture = NO;
			return;
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
	if (!counter) {
		counter = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 60, 20)];
		counter.text = @"000";
		[counter setFont:[UIFont fontWithName:@"HelveticaNeue" size:20]];
		counter.textColor = [UIColor whiteColor];
		counter.backgroundColor = [UIColor clearColor];
		counter.autoresizingMask = 2;
		counter.hidden = YES;
	}
	if (!counterBG) {
		counterBG = [[UIView alloc] initWithFrame:CGRectMake(-28, -48, 56, 56)];
		counterBG.alpha = .4;
		counterBG.backgroundColor = [UIColor blackColor];
		counterBG.layer.cornerRadius = 28;
		counterBG.hidden = YES;
	}
	UIView *textOverlayView = MSHookIvar<UIView *>(self, "_textOverlayView");
	[counterBG addSubview:counter];
	counter.center = CGPointMake(28, 28);
	counter.textAlignment = UITextAlignmentCenter;
	[textOverlayView addSubview:counterBG];
}

- (void)_setupAnimatePreviewDown:(id)down flipImage:(BOOL)image panoImage:(BOOL)image3 snapshotFrame:(CGRect)frame
{
	if (isPhotoCamera && !isCapturingVideo && burst) {
		if (DisableAnim)
			return;
	}
	%orig;
}

- (void)openIrisWithDidFinishSelector:(SEL)openIrisWith withDuration:(float)duration
{
	if (isPhotoCamera && DisableIris && disableIris && burst && !isCapturingVideo) {
		[self hideStaticClosedIris];
		[self takePictureOpenIrisAnimationFinished];
		return;
	}
	%orig;
}

- (void)closeIrisWithDidFinishSelector:(SEL)closeIrisWith withDuration:(float)duration
{
	if (isPhotoCamera && DisableIris && disableIris && burst && !isCapturingVideo) {
		[self _clearFocusViews];
		[self resumePreview];
		return;
	}
	%orig;
}

%end

%hook PLCameraController

- (BOOL)isHDREnabled
{
	BOOL enabled = %orig;
	if (isPhotoCamera) {
		if (enabled)
			counterBG.frame = CGRectMake(0, -63, 56, 56);
		else
			counterBG.frame = CGRectMake(-28, -48, 56, 56);
	}
	return enabled;
}

- (void)capturePhoto
{
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
	%orig;
}

- (void)autofocus
{
	if (isPhotoCamera) {
		if (noAutofocus && burst)
			return;
	}
	%orig;
}

- (void)_autofocus:(BOOL)focus autoExpose:(BOOL)expose
{
	if (isPhotoCamera) {
		if (noAutofocus && burst)
			return;
	}
	%orig;
}

%end

%end

%group iOS7

%hook CAMAvalancheIndicatorView

- (void)_updateCountLabelWithNumberOfPhotos
{
	if (!expFormat) {
		%orig;
		return;
	}
	int photoCount = MSHookIvar<int>(self, "__numberOfPhotos");
	UILabel *label = MSHookIvar<UILabel *>(self, "__countLabel");
	char cString[4];
    sprintf(cString, "%d", photoCount);
	NSString *s = [[[NSString alloc] initWithUTF8String:cString] autorelease];
	if (photoCount <= 9)
		[label setText:[@"00" stringByAppendingString:s]];
	else if (photoCount >= 10 && photoCount <= 99)
		[label setText:[@"0" stringByAppendingString:s]];
	else if (photoCount >= 100)
		[label setText:s];
}

- (void)incrementWithCaptureAnimation:(BOOL)animated
{
	%orig(animInd ? NO : animated);
}

%end

%hook CAMAvalancheSession

%new
- (void)fakeSetNum:(unsigned)fake
{
	MSHookIvar<unsigned>(self, "_numberOfPhotos") = fake;
}

%end

%hook PLCameraView

static BOOL hook7 = NO;

- (void)_updateHDR:(int)mode
{
	%orig(hook7 && [self HDRIsOn] && AllowHDR ? 1 : mode);
}

- (void)_updateFlashMode:(int)mode
{
	%orig(hook7 && self.flashMode == 1 && AllowFlash ? 1 : mode);
}

/*- (void)_setupCaptureTimer
{
	dispatch_source_t captureTimer = MSHookIvar<dispatch_source_t>(self, "__captureTimer");
	if (captureTimer != nil)
		[self _teardownCaptureTimer];
	dispatch_queue_t timedCaptureQueue = MSHookIvar<dispatch_queue_t>(self, "__timedCaptureQueue");
	if (timedCaptureQueue == nil) {
		dispatch_queue_t global = dispatch_get_global_queue(0x2, 0x0);
		dispatch_retain(global);
		timedCaptureQueue = global;
	}
	captureTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0x0, 0x0, timedCaptureQueue);
	dispatch_source_set_timer(captureTimer, dispatch_time(0x0, 0x0), 0x0, 1);
	dispatch_source_set_event_handler(captureTimer, nil);
	[self _captureTimerFired];
	%orig;
	dispatch_source_set_timer(MSHookIvar<dispatch_source_t>(self, "__captureTimer"), dispatch_time(0x0, 5), 10000, 10000);
}*/

- (void)_captureTimerFired
{
	unsigned orig = self._avalancheSession.numberOfPhotos;
	if (limitedPhotosCount > 0) {
		if (orig == limitedPhotosCount)
			return;
	}
	hook7 = YES;
	if (expFormat) {
		if (self._avalancheSession.numberOfPhotos > 997) {
			[self._avalancheSession fakeSetNum:1];
			%orig;
			[self._avalancheSession fakeSetNum:orig];
		} else
			%orig;
	} else
		%orig;
	hook7 = NO;
}

- (void)_beginTimedCapture
{
	previousBacklightLevel = [UIScreen mainScreen].brightness;
	%orig;
}

- (void)_completeTimedCapture
{
	hook7 = YES;
	%orig;
	hook7 = NO;
	FrontFlashCleanup();
}

%end

%hook CAMCameraSpec

- (BOOL)shouldCreateAvalancheIndicator
{
	return YES;
}

%end

Boolean (*old_MGGetBoolAnswer)(CFStringRef);
Boolean replaced_MGGetBoolAnswer(CFStringRef string)
{
	#define k(key) CFEqual(string, CFSTR(key))
	if (k("RearFacingCameraBurstCapability") || k("FrontFacingCameraBurstCapability"))
		return YES;
	return old_MGGetBoolAnswer(string);
}


%end

%group Fast7

%hook CAMAvalancheSession

- (void)_setState:(int)state
{
	MSHookIvar<int>(self, "_state") = state;
	[self _didTransitionToState:state];
}

%end

%hook CAMAvalancheIndicatorView

- (void)_updateCountLabelWithNumberOfPhotos
{
	if (!expFormat) {
		int photoCount = MSHookIvar<int>(self, "__numberOfPhotos");
		UILabel *label = MSHookIvar<UILabel *>(self, "__countLabel");
		char cString[4];
		sprintf(cString, "%03ld", (long)photoCount);
		NSString *s = [[[NSString alloc] initWithUTF8String:cString] autorelease];
		[label setText:s];
		return;
	}
	%orig;
}

%end

%hook PLCameraController

- (void)startTimedCapture
{
	%orig;
	if ([self.currentDevice isFaceDetectionSupported])
		[self setFaceDetectionEnabled:NO];
}

- (void)continueTimedCapture
{
	if (![self performingTimedCapture])
		return;
	[MSHookIvar<AVCaptureStillImageOutput *>(self, "_avCaptureOutputPhoto") setShutterSound:0];
}

- (void)finishTimedCapture
{
	%orig;
	if ([self.currentDevice isFaceDetectionSupported])
		[self setFaceDetectionEnabled:YES];
}

%end

%hook PLCameraView

- (void)_extendAvalancheSession
{
	if ([self._avalancheSession extend])
		return;
	[self _finalizeAndBeginNewAvalancheSession];
}

- (void)_finalizeExistingAvalancheSession
{
	[[self _avalancheIndicator] reset];
	[self._avalancheSession finalizeWithAnalysis:YES];
	[self._avalancheSession release];
}

- (void)_ensureValidAvalancheSession
{
	if (self._avalancheSession.state > 1)
		return;
	[self _finalizeAndBeginNewAvalancheSession];
}

%end

%end

%group Common

%hook PLCameraController

- (void)_setCameraMode:(int)mode cameraDevice:(int)device
{
	isPhotoCamera = (mode == 0);
	isBackCamera = (isPhotoCamera && device == 0);
	isFrontCamera = (isPhotoCamera && device == 1);
	%orig;
}

%end

%end

static void PostNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	system("killall Camera MobileSlideShow");
	BurstModeLoader();
}

%ctor {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PostNotification, CFSTR("com.PS.BurstMode.settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	BurstModeLoader();
	if (!BurstMode) {
		[pool drain];
		return;
	}
	hasFrontFlash = (dlopen("/Library/MobileSubstrate/DynamicLibraries/FrontFlash.dylib", RTLD_LAZY | RTLD_NOLOAD) != NULL);
	%init(Common);
	if (isiOS7) {
		MSHookFunction(((BOOL *)MSFindSymbol(NULL, "_MGGetBoolAnswer")), (BOOL *)replaced_MGGetBoolAnswer, (BOOL **)&old_MGGetBoolAnswer);
		if (Fast7) {
			%init(Fast7);
		}
		%init(iOS7);
	}
	else {
		if ([[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.Preferences"]) {
			[pool drain];
			return;
		}
		%init(iOS6);
	}
	[pool drain];
}
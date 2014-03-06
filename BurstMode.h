#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#define isiOS7 (kCFCoreFoundationVersionNumber > 793.00)
#define IPAD (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)

@interface PLCameraButton : UIButton
@end

@interface PLCameraButtonBar : UIToolbar
@property(retain, nonatomic) PLCameraButton* cameraButton;
@end

@interface CAMAvalancheSession : NSObject
@property(readonly, assign, nonatomic) unsigned numberOfPhotos;
@property(assign, nonatomic) int state;
- (BOOL)extend;
- (void)finalizeWithAnalysis:(BOOL)arg;
- (void)_didTransitionToState:(int)state;
@end

@interface CAMAvalancheSession (BurstMode)
- (void)fakeSetNum:(unsigned)fake;
@end

@interface PLCameraView : UIView
@property(assign, nonatomic) int flashMode;
@property(assign, nonatomic) BOOL HDRIsOn;
@property(retain, nonatomic) UIToolbar* bottomButtonBar;
- (BOOL)hasInFlightCaptures;
- (void)_shutterButtonClicked;
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

@interface CAMAvalancheIndicatorView : UIView
- (void)reset;
@end

@interface PLCameraView (iOS7)
@property(readonly, assign, nonatomic) CAMAvalancheSession* _avalancheSession;
@property(readonly, assign, nonatomic) CAMAvalancheIndicatorView *_avalancheIndicator;
- (void)_finalizeAndBeginNewAvalancheSession;
@end

@interface PLCameraButton (BurstMode)
- (void)burst;
- (void)takePhoto;
@end

@interface PLCameraController : NSObject
@property(assign, nonatomic, getter=isHDREnabled) BOOL HDREnabled;
@property(assign, nonatomic) AVCaptureDevice *currentDevice;
+ (id)sharedInstance;
- (PLCameraView *)delegate;
- (BOOL)isCapturingVideo;
- (BOOL)isFocusLockSupported;
- (void)setFaceDetectionEnabled:(BOOL)enabled;
- (void)setFocusDisabled:(BOOL)disabled;
- (void)_lockFocus:(BOOL)focus lockExposure:(BOOL)exposure lockWhiteBalance:(BOOL)whiteBalance;
@end

@interface PLCameraController (iOS7)
- (BOOL)performingTimedCapture;
@end

@interface UIApplication (FrontFlash)
- (void)setBacklightLevel:(float)level;
@end

@interface PUAvalancheReviewControllerPhoneSpec : NSObject
@end

@interface PUPhotoBrowserController
- (id)_toolbarButtonForIdentifier:(NSString *)ident;
@end

@interface AVCaptureStillImageOutput (Addition)
- (void)setShutterSound:(unsigned long)soundID;
@end

@interface AVCaptureDevice (Addition)
- (BOOL)isFaceDetectionSupported;
@end

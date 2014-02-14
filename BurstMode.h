#import <UIKit/UIKit.h>

#define isiOS7 (kCFCoreFoundationVersionNumber > 793.00)
#define IPAD (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)

@interface PLCameraButton : UIButton
@end

@interface PLCameraButtonBar : UIToolbar
@property(retain, nonatomic) PLCameraButton* cameraButton;
@end

@interface CAMAvalancheSession
@property(readonly, assign, nonatomic) unsigned numberOfPhotos;
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

@interface PLCameraView (iOS7)
@property(readonly, assign, nonatomic) CAMAvalancheSession* _avalancheSession;
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

@interface PUAvalancheReviewControllerPhoneSpec : NSObject
@end

@interface PUPhotoBrowserController
- (id)_toolbarButtonForIdentifier:(NSString *)ident;
@end
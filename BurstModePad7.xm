#import "BurstMode.h"

%hook PUPhotoBrowserControllerPadSpec

- (id)avalancheReviewControllerSpec
{
	return [[[PUAvalancheReviewControllerPhoneSpec alloc] init] autorelease];
}

%end

%hook PUPhotoBrowserController

- (id)_navbarButtonForIdentifier:(NSString *)ident
{
	if ([ident isEqualToString:@"PUPHOTOBROWSER_BUTTON_REVIEW"])
		return [self _toolbarButtonForIdentifier:ident];
	return %orig;

}

%end


%ctor {
	if (IPAD && isiOS7) {
		%init;
	}
}
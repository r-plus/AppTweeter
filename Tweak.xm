@interface TWTweetComposeViewController : UIViewController
@property (nonatomic, copy) id completionHandler;
- (BOOL)setInitialText:(NSString *)text;
- (BOOL)addImage:(UIImage *)addImage;
- (BOOL)addURL:(NSURL *)iTunesURL;
@end

@interface UIWindow (forTweet)
+ (id)keyWindow;
- (id)_firstResponder;
@end

@interface ASApplicationPageView : UIView
- (void)_tellAFriendAction:(id)action;
- (id)applicationImage;
- (id)defaultStoreOffer;
- (id)storeOffers;
- (id)priceDisplay;
- (id)itemDictionary;
- (void)tweetFired;
@end

@interface AppTweeterHandler : NSObject <UIActionSheetDelegate>
@property (nonatomic, assign) ASApplicationPageView *pageView;
@end

static TWTweetComposeViewController *tweetComposer;
static UIWindow *tweetWindow;
static UIWindow *tweetFormerKeyWindow;
static BOOL sendMail = NO;

@implementation AppTweeterHandler
@synthesize pageView;
- (void)actionSheet:(id)sheet clickedButtonAtIndex:(int)index
{
  if (index == 0) {
    sendMail = YES;
    [pageView _tellAFriendAction:nil];
  } else if (index == 1) {
    [pageView tweetFired];
  }
  [self release];
}
@end

%hook ASApplicationPageView
- (void)_tellAFriendAction:(id)action
{
  [action setSelected:NO];
  if (sendMail) {
    %orig;
    sendMail = NO;
    return;
  }
  AppTweeterHandler *handler = [[AppTweeterHandler alloc] init];
  handler.pageView = self;

  UIActionSheet *sheet = [[[UIActionSheet alloc] initWithTitle:nil delegate:handler cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil] autorelease];
  [sheet addButtonWithTitle:@"Mail"];
  [sheet addButtonWithTitle:@"Tweet"];
  [sheet setCancelButtonIndex:[sheet addButtonWithTitle:@"Cancel"]];
  [sheet setAlertSheetStyle:UIBarStyleBlackTranslucent];
  [sheet showInView:self];
}
   
%new(v@:)
- (void)tweetFired
{
  id SUItem = MSHookIvar<id>(self, "_item");
  id SSItemOffer = [SUItem defaultStoreOffer];
  NSDictionary *appInfoDict = [SUItem itemDictionary];
  NSDictionary *dict = MSHookIvar<NSDictionary *>(SSItemOffer, "_offerDictionary");

  // AppName
  NSString *appName = [SUItem title];
  // Price
  NSString *price = [[[appInfoDict objectForKey:@"store-offers"] objectForKey:@"STDQ"] objectForKey:@"price-display"];
  // URL
  NSURL *url = [NSURL URLWithString:[appInfoDict objectForKey:@"url"]];
  // Author
  NSString *author = [[appInfoDict objectForKey:@"company"] objectForKey:@"title"];
  // version
  NSString *version = [appInfoDict objectForKey:@"version"];
  // bundle-id
  //NSLog(@"bundle-id = %@", [appInfoDict objectForKey:@"bundle-id"]);
  // rating
  NSString *rating = [[appInfoDict objectForKey:@"rating"] objectForKey:@"label"];
  // size
  NSUInteger appSize = [[dict objectForKey:@"size"] intValue];
  float appSizeSI;
  if (appSize / 1024 / 1024 / 1024)
    appSizeSI = (float)appSize / 1024 / 1024 / 1024;
  else if (appSize / 1024 / 1024)
    appSizeSI = (float)appSize / 1024 / 1024;
  else if (appSize / 1024)
    appSizeSI = (float)appSize / 1024;
  NSString *SIByte = appSize / 1024 / 1024 / 1024 ? @"GB" : appSize / 1024 / 1024 ? @"MB" : @"KB";
  // minOS
  NSString *minOS = [[[dict objectForKey:@"supported-device-types"] objectAtIndex:0] objectForKey:@"minimum-product-version"];
  // app image
  UIImage *applicationImage = [self applicationImage];
  // pref
  NSDictionary *prefDict = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/jp.r-plus.apptweeter.plist"];
  id addImageExist = [prefDict objectForKey:@"addImage"];
  BOOL addImage = addImageExist ? [addImageExist boolValue] : YES;
  id authorExist = [prefDict objectForKey:@"addAuthor"];
  BOOL addAuthor = authorExist ? [authorExist boolValue] : YES;
  id appSizeExist = [prefDict objectForKey:@"addAppSize"];
  BOOL addAppSize = appSizeExist ? [appSizeExist boolValue] : YES;
  id minOSExist = [prefDict objectForKey:@"addRequire"];
  BOOL addMinOS = minOSExist ? [minOSExist boolValue] : NO;
  id ratingExist = [prefDict objectForKey:@"addRating"];
  BOOL addRating = ratingExist ? [ratingExist boolValue] : NO;
  // string
  NSMutableString *initialString = [NSMutableString stringWithFormat:@"%@ v%@ %@", appName, version, price];
  if (addAuthor && author != NULL)
    [initialString appendFormat:@" by %@", author];
  if (addAppSize)
    [initialString appendFormat:@" %1.1f%@", appSizeSI, SIByte];
  if (addMinOS)
    [initialString appendFormat:@" Required iOS%@", minOS];
  if (addRating)
    [initialString appendFormat:@" Rating %@", rating];
  // tweet code from libactivator
  tweetComposer = [[objc_getClass("TWTweetComposeViewController") alloc] init];
  if (!tweetComposer)
    return;
  if (tweetWindow)
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideTweetWindow) object:nil];
  else
    tweetWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  tweetWindow.windowLevel = UIWindowLevelStatusBar;
  [tweetFormerKeyWindow release];
  tweetFormerKeyWindow = [[UIWindow keyWindow] retain];
  UIViewController *vct = [[UIViewController alloc] init];//ActivatorEmptyViewController
  //vct.interfaceOrientation = [(SpringBoard *)[UIApplication sharedApplication] activeInterfaceOrientation];
  tweetWindow.rootViewController = vct;

  // add
  if (addImage)
    [tweetComposer addImage:applicationImage];
  [tweetComposer addURL:url];
  // FIXME: does not set text just length. Why?
  while (![tweetComposer setInitialText:initialString]) {
    //NSLog(@"string length = %d", [initialString length]);
    //NSLog(@"initialString = %@", initialString);
    [initialString deleteCharactersInRange:NSMakeRange([initialString length] - 1, 1)];
  }

  tweetComposer.completionHandler = ^(int result) {
    [[tweetWindow _firstResponder] resignFirstResponder];
    [tweetFormerKeyWindow makeKeyWindow];
    [tweetFormerKeyWindow release];
    tweetFormerKeyWindow = nil;
    [self performSelector:@selector(hideTweetWindow) withObject:nil afterDelay:0.5];
    [vct dismissModalViewControllerAnimated:YES];
    [tweetComposer release];
    tweetComposer = nil;
  };
  [tweetWindow makeKeyAndVisible];
  [vct presentModalViewController:tweetComposer animated:YES];
  [vct release];
}

%new(v@:)
- (void)hideTweetWindow
{
  tweetWindow.hidden = YES;
  [tweetWindow release];
  tweetWindow = nil;
}
%end

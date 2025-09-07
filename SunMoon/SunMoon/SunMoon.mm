#line 1 "/Users/macxk/Desktop/SunMoon/SunMoon/SunMoon.xm"




#if TARGET_OS_SIMULATOR
#error Do not support the simulator, please use the real iPhone Device.
#endif

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>


@interface GifSwitchView : UIView
@property (nonatomic, assign) BOOL isOn;
@property (nonatomic, strong) UIView *trackView;
@property (nonatomic, strong) UIView *thumbView;
@property (nonatomic, strong) UIImageView *gifImageView;
@property (nonatomic, strong) CAGradientLayer *trackGradient;
@property (nonatomic, weak) UISwitch *originalSwitch;
@property (nonatomic, strong) NSData *onGifData;
@property (nonatomic, strong) NSData *offGifData;

- (instancetype)initWithSwitch:(UISwitch *)switchControl;
- (void)updateAppearanceAnimated:(BOOL)animated;
- (void)switchTapped;
- (void)loadGifData;
- (void)playGifAnimation:(NSData *)gifData;
- (CAKeyframeAnimation *)createGifAnimationFromData:(NSData *)gifData;
@end

@implementation GifSwitchView

- (instancetype)initWithSwitch:(UISwitch *)switchControl {
    self = [super initWithFrame:switchControl.frame];
    if (self) {
        self.originalSwitch = switchControl;
        self.isOn = switchControl.isOn;
        [self setupViews];
        [self loadGifData];
        [self updateAppearanceAnimated:NO];

        
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(switchTapped)];
        [self addGestureRecognizer:tapGesture];
    }
    return self;
}

- (void)setupViews {
    
    self.trackView = [[UIView alloc] init];
    self.trackView.layer.cornerRadius = self.frame.size.height / 2;
    self.trackView.clipsToBounds = YES;
    [self addSubview:self.trackView];
    
    
    self.trackGradient = [CAGradientLayer layer];
    self.trackGradient.colors = @[
        (id)[UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0].CGColor
    ];
    self.trackGradient.startPoint = CGPointMake(0, 0);
    self.trackGradient.endPoint = CGPointMake(1, 1);
    [self.trackView.layer addSublayer:self.trackGradient];

    
    CGFloat thumbSize = self.frame.size.height - 8;
    self.thumbView = [[UIView alloc] init];
    self.thumbView.layer.cornerRadius = thumbSize / 2;
    self.thumbView.clipsToBounds = YES;
    self.thumbView.backgroundColor = [UIColor whiteColor];
    
    
    self.thumbView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.thumbView.layer.shadowOffset = CGSizeMake(0, 2);
    self.thumbView.layer.shadowRadius = 4;
    self.thumbView.layer.shadowOpacity = 0.3;

    [self addSubview:self.thumbView];
    
    
    self.gifImageView = [[UIImageView alloc] init];
    self.gifImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.gifImageView.clipsToBounds = YES;
    self.gifImageView.layer.cornerRadius = thumbSize / 2;
    [self.thumbView addSubview:self.gifImageView];
}

- (void)loadGifData {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSURL *onGifURL = [NSURL URLWithString:@"https://qny.smzdm.com/202003/25/5e7b0c063347b585.gif"];
        NSData *onData = [NSData dataWithContentsOfURL:onGifURL];
        
        
        NSURL *offGifURL = [NSURL URLWithString:@"https://n.sinaimg.cn/sinakd20118/490/w245h245/20250314/9aea-gif9ddf8cb0e1a9b900b278ac1dc05faf99.gif"];
        NSData *offData = [NSData dataWithContentsOfURL:offGifURL];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.onGifData = onData;
            self.offGifData = offData;
            
            
            [self playGifAnimation:self.isOn ? self.onGifData : self.offGifData];
        });
    });
}

- (void)playGifAnimation:(NSData *)gifData {
    if (!gifData) return;
    
    
    [self.gifImageView.layer removeAnimationForKey:@"gifAnimation"];
    
    
    CAKeyframeAnimation *animation = [self createGifAnimationFromData:gifData];
    if (animation) {
        [self.gifImageView.layer addAnimation:animation forKey:@"gifAnimation"];
    }
}

- (CAKeyframeAnimation *)createGifAnimationFromData:(NSData *)gifData {
    if (!gifData) return nil;
    
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)gifData, NULL);
    if (!source) return nil;
    
    size_t frameCount = CGImageSourceGetCount(source);
    if (frameCount <= 1) {
        CFRelease(source);
        return nil;
    }
    
    NSMutableArray *images = [NSMutableArray array];
    NSMutableArray *frameDurations = [NSMutableArray array];
    CGFloat totalDuration = 0;
    
    
    for (size_t i = 0; i < frameCount; i++) {
        CGImageRef frameImage = CGImageSourceCreateImageAtIndex(source, i, NULL);
        if (frameImage) {
            [images addObject:(__bridge id)frameImage];
            CFRelease(frameImage);
        }
        
        
        CFDictionaryRef frameProperties = CGImageSourceCopyPropertiesAtIndex(source, i, NULL);
        CGFloat frameDuration = 0.1; 
        
        if (frameProperties) {
            CFDictionaryRef gifProperties = (CFDictionaryRef)CFDictionaryGetValue(frameProperties, kCGImagePropertyGIFDictionary);
            if (gifProperties) {
                CFNumberRef delayTime = (CFNumberRef)CFDictionaryGetValue(gifProperties, kCGImagePropertyGIFUnclampedDelayTime);
                if (!delayTime) {
                    delayTime = (CFNumberRef)CFDictionaryGetValue(gifProperties, kCGImagePropertyGIFDelayTime);
                }
                if (delayTime) {
                    CFNumberGetValue(delayTime, kCFNumberCGFloatType, &frameDuration);
                }
            }
            CFRelease(frameProperties);
        }
        
        if (frameDuration < 0.02) frameDuration = 0.1;
        
        [frameDurations addObject:@(frameDuration)];
        totalDuration += frameDuration;
    }
    
    CFRelease(source);
    
    if (images.count == 0) return nil;
    
    
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"contents"];
    animation.values = images;
    animation.duration = totalDuration;
    animation.repeatCount = HUGE_VALF;
    animation.removedOnCompletion = NO;
    animation.fillMode = kCAFillModeForwards;
    animation.calculationMode = kCAAnimationDiscrete;
    
    return animation;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    
    self.trackView.frame = self.bounds;
    self.trackGradient.frame = self.trackView.bounds;

    
    CGFloat thumbSize = self.frame.size.height - 8;
    CGFloat thumbY = 4;
    CGFloat trackPadding = 4;
    CGFloat thumbX = self.isOn ? (self.frame.size.width - thumbSize - trackPadding) : trackPadding;
    self.thumbView.frame = CGRectMake(thumbX, thumbY, thumbSize, thumbSize);
    
    
    self.gifImageView.frame = self.thumbView.bounds;
}

- (void)updateAppearanceAnimated:(BOOL)animated {
    void (^updateBlock)(void) = ^{
        
        if (self.isOn) {
            
            self.trackGradient.colors = @[
                (id)[UIColor colorWithRed:0.2 green:0.8 blue:1.0 alpha:1.0].CGColor,
                (id)[UIColor colorWithRed:0.1 green:0.6 blue:0.9 alpha:1.0].CGColor
            ];
        } else {
            
            self.trackGradient.colors = @[
                (id)[UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0].CGColor,
                (id)[UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0].CGColor
            ];
        }

        [self layoutSubviews];
        
        
        [self playGifAnimation:self.isOn ? self.onGifData : self.offGifData];
    };

    if (animated) {
        
        [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseInOut animations:updateBlock completion:nil];
    } else {
        updateBlock();
    }
}

- (void)switchTapped {
    self.isOn = !self.isOn;

    
    [self.originalSwitch setOn:self.isOn animated:YES];
    [self.originalSwitch sendActionsForControlEvents:UIControlEventValueChanged];

    
    [self updateAppearanceAnimated:YES];
}

@end


static const void *GifSwitchViewKey = &GifSwitchViewKey;



#include <substrate.h>
#if defined(__clang__)
#if __has_feature(objc_arc)
#define _LOGOS_SELF_TYPE_NORMAL __unsafe_unretained
#define _LOGOS_SELF_TYPE_INIT __attribute__((ns_consumed))
#define _LOGOS_SELF_CONST const
#define _LOGOS_RETURN_RETAINED __attribute__((ns_returns_retained))
#else
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif
#else
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif

__asm__(".linker_option \"-framework\", \"CydiaSubstrate\"");

@class UISwitch; 
static void (*_logos_orig$_ungrouped$UISwitch$didMoveToSuperview)(_LOGOS_SELF_TYPE_NORMAL UISwitch* _LOGOS_SELF_CONST, SEL); static void _logos_method$_ungrouped$UISwitch$didMoveToSuperview(_LOGOS_SELF_TYPE_NORMAL UISwitch* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$_ungrouped$UISwitch$removeFromSuperview)(_LOGOS_SELF_TYPE_NORMAL UISwitch* _LOGOS_SELF_CONST, SEL); static void _logos_method$_ungrouped$UISwitch$removeFromSuperview(_LOGOS_SELF_TYPE_NORMAL UISwitch* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$_ungrouped$UISwitch$setOn$animated$)(_LOGOS_SELF_TYPE_NORMAL UISwitch* _LOGOS_SELF_CONST, SEL, BOOL, BOOL); static void _logos_method$_ungrouped$UISwitch$setOn$animated$(_LOGOS_SELF_TYPE_NORMAL UISwitch* _LOGOS_SELF_CONST, SEL, BOOL, BOOL); static void (*_logos_orig$_ungrouped$UISwitch$setFrame$)(_LOGOS_SELF_TYPE_NORMAL UISwitch* _LOGOS_SELF_CONST, SEL, CGRect); static void _logos_method$_ungrouped$UISwitch$setFrame$(_LOGOS_SELF_TYPE_NORMAL UISwitch* _LOGOS_SELF_CONST, SEL, CGRect); static void (*_logos_orig$_ungrouped$UISwitch$setOn$)(_LOGOS_SELF_TYPE_NORMAL UISwitch* _LOGOS_SELF_CONST, SEL, BOOL); static void _logos_method$_ungrouped$UISwitch$setOn$(_LOGOS_SELF_TYPE_NORMAL UISwitch* _LOGOS_SELF_CONST, SEL, BOOL); 

#line 255 "/Users/macxk/Desktop/SunMoon/SunMoon/SunMoon.xm"


static void _logos_method$_ungrouped$UISwitch$didMoveToSuperview(_LOGOS_SELF_TYPE_NORMAL UISwitch* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    _logos_orig$_ungrouped$UISwitch$didMoveToSuperview(self, _cmd);

    if (self.superview) {
        
        GifSwitchView *existingGifSwitch = objc_getAssociatedObject(self, GifSwitchViewKey);
        if (existingGifSwitch) {
            return;
        }

        
        GifSwitchView *gifSwitch = [[GifSwitchView alloc] initWithSwitch:self];
        gifSwitch.frame = self.frame;
        gifSwitch.autoresizingMask = self.autoresizingMask;

        
        self.alpha = 0.0;

        
        [self.superview addSubview:gifSwitch];

        
        objc_setAssociatedObject(self, GifSwitchViewKey, gifSwitch, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void _logos_method$_ungrouped$UISwitch$removeFromSuperview(_LOGOS_SELF_TYPE_NORMAL UISwitch* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    
    GifSwitchView *gifSwitch = objc_getAssociatedObject(self, GifSwitchViewKey);
    if (gifSwitch) {
        [gifSwitch.gifImageView.layer removeAnimationForKey:@"gifAnimation"];
        [gifSwitch removeFromSuperview];
        objc_setAssociatedObject(self, GifSwitchViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    _logos_orig$_ungrouped$UISwitch$removeFromSuperview(self, _cmd);
}

static void _logos_method$_ungrouped$UISwitch$setOn$animated$(_LOGOS_SELF_TYPE_NORMAL UISwitch* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, BOOL on, BOOL animated) {
    _logos_orig$_ungrouped$UISwitch$setOn$animated$(self, _cmd, on, animated);

    
    GifSwitchView *gifSwitch = objc_getAssociatedObject(self, GifSwitchViewKey);
    if (gifSwitch) {
        gifSwitch.isOn = on;
        [gifSwitch updateAppearanceAnimated:animated];
    }
}

static void _logos_method$_ungrouped$UISwitch$setFrame$(_LOGOS_SELF_TYPE_NORMAL UISwitch* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, CGRect frame) {
    _logos_orig$_ungrouped$UISwitch$setFrame$(self, _cmd, frame);

    
    GifSwitchView *gifSwitch = objc_getAssociatedObject(self, GifSwitchViewKey);
    if (gifSwitch) {
        gifSwitch.frame = frame;
    }
}

static void _logos_method$_ungrouped$UISwitch$setOn$(_LOGOS_SELF_TYPE_NORMAL UISwitch* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, BOOL on) {
    _logos_orig$_ungrouped$UISwitch$setOn$(self, _cmd, on);

    
    GifSwitchView *gifSwitch = objc_getAssociatedObject(self, GifSwitchViewKey);
    if (gifSwitch) {
        gifSwitch.isOn = on;
        [gifSwitch updateAppearanceAnimated:NO];
    }
}


static __attribute__((constructor)) void _logosLocalInit() {
{Class _logos_class$_ungrouped$UISwitch = objc_getClass("UISwitch"); { MSHookMessageEx(_logos_class$_ungrouped$UISwitch, @selector(didMoveToSuperview), (IMP)&_logos_method$_ungrouped$UISwitch$didMoveToSuperview, (IMP*)&_logos_orig$_ungrouped$UISwitch$didMoveToSuperview);}{ MSHookMessageEx(_logos_class$_ungrouped$UISwitch, @selector(removeFromSuperview), (IMP)&_logos_method$_ungrouped$UISwitch$removeFromSuperview, (IMP*)&_logos_orig$_ungrouped$UISwitch$removeFromSuperview);}{ MSHookMessageEx(_logos_class$_ungrouped$UISwitch, @selector(setOn:animated:), (IMP)&_logos_method$_ungrouped$UISwitch$setOn$animated$, (IMP*)&_logos_orig$_ungrouped$UISwitch$setOn$animated$);}{ MSHookMessageEx(_logos_class$_ungrouped$UISwitch, @selector(setFrame:), (IMP)&_logos_method$_ungrouped$UISwitch$setFrame$, (IMP*)&_logos_orig$_ungrouped$UISwitch$setFrame$);}{ MSHookMessageEx(_logos_class$_ungrouped$UISwitch, @selector(setOn:), (IMP)&_logos_method$_ungrouped$UISwitch$setOn$, (IMP*)&_logos_orig$_ungrouped$UISwitch$setOn$);}} }
#line 328 "/Users/macxk/Desktop/SunMoon/SunMoon/SunMoon.xm"

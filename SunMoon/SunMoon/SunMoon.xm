// SunMoon - 动态GIF开关效果
// 将所有iOS开关替换为带有动态GIF动画的开关
// 作者: MacXK

#if TARGET_OS_SIMULATOR
#error Do not support the simulator, please use the real iPhone Device.
#endif

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>

// 自定义GIF动画开关视图
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

        // 添加点击手势
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(switchTapped)];
        [self addGestureRecognizer:tapGesture];
    }
    return self;
}

- (void)setupViews {
    // 轨道视图
    self.trackView = [[UIView alloc] init];
    self.trackView.layer.cornerRadius = self.frame.size.height / 2;
    self.trackView.clipsToBounds = YES;
    [self addSubview:self.trackView];
    
    // 轨道渐变背景
    self.trackGradient = [CAGradientLayer layer];
    self.trackGradient.colors = @[
        (id)[UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0].CGColor
    ];
    self.trackGradient.startPoint = CGPointMake(0, 0);
    self.trackGradient.endPoint = CGPointMake(1, 1);
    [self.trackView.layer addSublayer:self.trackGradient];

    // 拇指视图（GIF容器）
    CGFloat thumbSize = self.frame.size.height - 8;
    self.thumbView = [[UIView alloc] init];
    self.thumbView.layer.cornerRadius = thumbSize / 2;
    self.thumbView.clipsToBounds = YES;
    self.thumbView.backgroundColor = [UIColor whiteColor];
    
    // 添加阴影效果
    self.thumbView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.thumbView.layer.shadowOffset = CGSizeMake(0, 2);
    self.thumbView.layer.shadowRadius = 4;
    self.thumbView.layer.shadowOpacity = 0.3;

    [self addSubview:self.thumbView];
    
    // GIF图像视图
    self.gifImageView = [[UIImageView alloc] init];
    self.gifImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.gifImageView.clipsToBounds = YES;
    self.gifImageView.layer.cornerRadius = thumbSize / 2;
    [self.thumbView addSubview:self.gifImageView];
}

- (void)loadGifData {
    // 异步加载GIF数据
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 开启状态GIF
        NSURL *onGifURL = [NSURL URLWithString:@"https://qny.smzdm.com/202003/25/5e7b0c063347b585.gif"];
        NSData *onData = [NSData dataWithContentsOfURL:onGifURL];
        
        // 关闭状态GIF
        NSURL *offGifURL = [NSURL URLWithString:@"https://n.sinaimg.cn/sinakd20118/490/w245h245/20250314/9aea-gif9ddf8cb0e1a9b900b278ac1dc05faf99.gif"];
        NSData *offData = [NSData dataWithContentsOfURL:offGifURL];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.onGifData = onData;
            self.offGifData = offData;
            
            // 播放对应状态的GIF
            [self playGifAnimation:self.isOn ? self.onGifData : self.offGifData];
        });
    });
}

- (void)playGifAnimation:(NSData *)gifData {
    if (!gifData) return;
    
    // 移除当前动画
    [self.gifImageView.layer removeAnimationForKey:@"gifAnimation"];
    
    // 创建并播放新的GIF动画
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
    
    // 提取GIF帧和时长
    for (size_t i = 0; i < frameCount; i++) {
        CGImageRef frameImage = CGImageSourceCreateImageAtIndex(source, i, NULL);
        if (frameImage) {
            [images addObject:(__bridge id)frameImage];
            CFRelease(frameImage);
        }
        
        // 获取帧时长
        CFDictionaryRef frameProperties = CGImageSourceCopyPropertiesAtIndex(source, i, NULL);
        CGFloat frameDuration = 0.1; // 默认时长
        
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
    
    // 创建关键帧动画
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

    // 布局轨道
    self.trackView.frame = self.bounds;
    self.trackGradient.frame = self.trackView.bounds;

    // 布局拇指
    CGFloat thumbSize = self.frame.size.height - 8;
    CGFloat thumbY = 4;
    CGFloat trackPadding = 4;
    CGFloat thumbX = self.isOn ? (self.frame.size.width - thumbSize - trackPadding) : trackPadding;
    self.thumbView.frame = CGRectMake(thumbX, thumbY, thumbSize, thumbSize);
    
    // 布局GIF视图
    self.gifImageView.frame = self.thumbView.bounds;
}

- (void)updateAppearanceAnimated:(BOOL)animated {
    void (^updateBlock)(void) = ^{
        // 根据状态更新轨道颜色
        if (self.isOn) {
            // 开启状态：亮色渐变
            self.trackGradient.colors = @[
                (id)[UIColor colorWithRed:0.2 green:0.8 blue:1.0 alpha:1.0].CGColor,
                (id)[UIColor colorWithRed:0.1 green:0.6 blue:0.9 alpha:1.0].CGColor
            ];
        } else {
            // 关闭状态：暗色渐变
            self.trackGradient.colors = @[
                (id)[UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0].CGColor,
                (id)[UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0].CGColor
            ];
        }

        [self layoutSubviews];
        
        // 切换GIF动画
        [self playGifAnimation:self.isOn ? self.onGifData : self.offGifData];
    };

    if (animated) {
        // 弹簧动画效果
        [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseInOut animations:updateBlock completion:nil];
    } else {
        updateBlock();
    }
}

- (void)switchTapped {
    self.isOn = !self.isOn;

    // 更新原始开关并触发事件
    [self.originalSwitch setOn:self.isOn animated:YES];
    [self.originalSwitch sendActionsForControlEvents:UIControlEventValueChanged];

    // 更新外观
    [self updateAppearanceAnimated:YES];
}

@end

// 关联对象键
static const void *GifSwitchViewKey = &GifSwitchViewKey;

// Hook UISwitch 替换为GIF版本
%hook UISwitch

- (void)didMoveToSuperview {
    %orig;

    if (self.superview) {
        // 检查是否已经有GIF开关，避免重复
        GifSwitchView *existingGifSwitch = objc_getAssociatedObject(self, GifSwitchViewKey);
        if (existingGifSwitch) {
            return;
        }

        // 创建GIF开关视图
        GifSwitchView *gifSwitch = [[GifSwitchView alloc] initWithSwitch:self];
        gifSwitch.frame = self.frame;
        gifSwitch.autoresizingMask = self.autoresizingMask;

        // 隐藏原始开关
        self.alpha = 0.0;

        // 添加GIF开关到相同的父视图
        [self.superview addSubview:gifSwitch];

        // 存储引用用于清理
        objc_setAssociatedObject(self, GifSwitchViewKey, gifSwitch, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (void)removeFromSuperview {
    // 清理GIF开关
    GifSwitchView *gifSwitch = objc_getAssociatedObject(self, GifSwitchViewKey);
    if (gifSwitch) {
        [gifSwitch.gifImageView.layer removeAnimationForKey:@"gifAnimation"];
        [gifSwitch removeFromSuperview];
        objc_setAssociatedObject(self, GifSwitchViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    %orig;
}

- (void)setOn:(BOOL)on animated:(BOOL)animated {
    %orig;

    // 更新GIF开关状态
    GifSwitchView *gifSwitch = objc_getAssociatedObject(self, GifSwitchViewKey);
    if (gifSwitch) {
        gifSwitch.isOn = on;
        [gifSwitch updateAppearanceAnimated:animated];
    }
}

- (void)setFrame:(CGRect)frame {
    %orig;

    // 更新GIF开关框架
    GifSwitchView *gifSwitch = objc_getAssociatedObject(self, GifSwitchViewKey);
    if (gifSwitch) {
        gifSwitch.frame = frame;
    }
}

- (void)setOn:(BOOL)on {
    %orig;

    // 更新GIF开关状态（无动画）
    GifSwitchView *gifSwitch = objc_getAssociatedObject(self, GifSwitchViewKey);
    if (gifSwitch) {
        gifSwitch.isOn = on;
        [gifSwitch updateAppearanceAnimated:NO];
    }
}

%end

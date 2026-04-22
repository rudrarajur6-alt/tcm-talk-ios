//
//  SlackTextViewController
//  https://github.com/slackhq/SlackTextViewController
//
//  Copyright 2014-2016 Slack Technologies, Inc.
//  Licence: MIT-Licence
//

#import "SLKTextInputbar.h"
#import "SLKTextView.h"
#import "SLKInputAccessoryView.h"
#import "SLKDefaultTypingIndicatorView.h"

#import "SLKTextView+SLKAdditions.h"
#import "UIView+SLKAdditions.h"

#import "SLKUIConstants.h"

NSString * const SLKTextInputbarDidMoveNotification                 = @"SLKTextInputbarDidMoveNotification";
NSString * const SLKTextInputbarContentSizeDidChangeNotification    = @"SLKTextInputbarContentSizeDidChangeNotification";

CGFloat const SLKTextInputbarMinButtonWidth         = 44.0;
CGFloat const SLKTextInputbarMinButtonHeight        = 44.0;
CGFloat const SLKTextInputbarTypingIndicatorHeight  = 24.0;

@interface SLKTextInputbar ()

@property (nonatomic, strong) NSLayoutConstraint *textViewBottomMarginC;
@property (nonatomic, strong) NSLayoutConstraint *contentViewHC;
@property (nonatomic, strong) NSLayoutConstraint *leftButtonWC;
@property (nonatomic, strong) NSLayoutConstraint *leftButtonHC;
@property (nonatomic, strong) NSLayoutConstraint *leftMarginWC;
@property (nonatomic, strong) NSLayoutConstraint *leftButtonBottomMarginC;
@property (nonatomic, strong) NSLayoutConstraint *rightButtonWC;
@property (nonatomic, strong) NSLayoutConstraint *rightButtonHC;
@property (nonatomic, strong) NSLayoutConstraint *rightMarginWC;
@property (nonatomic, strong) NSLayoutConstraint *rightButtonTopMarginC;
@property (nonatomic, strong) NSLayoutConstraint *rightButtonBottomMarginC;
@property (nonatomic, strong) NSLayoutConstraint *editorContentViewHC;
@property (nonatomic, strong) NSLayoutConstraint *typingIndicatorViewHC;
@property (nonatomic, strong) NSLayoutConstraint *typingIndicatorViewTextViewPaddingConstraint;
@property (nonatomic, strong) NSArray *charCountLabelVCs;

@property (nonatomic, assign) UIEdgeInsets defaultInsets;

@property (nonatomic, strong) UILabel *charCountLabel;

@property (nonatomic) CGPoint previousOrigin;

@property (nonatomic, strong) Class textViewClass;
@property (nonatomic, strong) Class typingIndicatorClass;

@property (nonatomic, getter=isHidden) BOOL hidden; // Required override

@end

@implementation SLKTextInputbar
@synthesize textView = _textView;
@synthesize contentView = _contentView;
@synthesize inputAccessoryView = _inputAccessoryView;
@synthesize hidden = _hidden;

#pragma mark - Initialization

- (instancetype)initWithTextViewClass:(Class)textViewClass
{
    if (self = [super init]) {
        self.textViewClass = textViewClass;
        [self slk_commonInit];
    }
    return self;
}

- (instancetype)initWithTextViewClass:(Class)textViewClass withTypingIndicatorViewClass:(Class)typingIndicatorClass
{
    if (self = [super init]) {
        self.textViewClass = textViewClass;
        self.typingIndicatorClass = typingIndicatorClass;
        [self slk_commonInit];
    }
    return self;
}

- (id)init
{
    if (self = [super init]) {
        [self slk_commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (self = [super initWithCoder:coder]) {
        [self slk_commonInit];
    }
    return self;
}

- (void)slk_commonInit
{
    self.charCountLabelNormalColor = [UIColor lightGrayColor];
    self.charCountLabelWarningColor = [UIColor redColor];
    
    self.autoHideRightButton = YES;
    self.editorContentViewHeight = 38.0;
    self.defaultInsets = UIEdgeInsetsMake(5.0, 8.0, 5.0, 8.0);
    self.contentInset = _defaultInsets;

    // Since iOS 11, it is required to call -layoutSubviews before adding custom subviews
    // so private UIToolbar subviews don't interfere on the touch hierarchy
    [self layoutSubviews];

    [self addSubview:self.typingView];
    [self addSubview:self.editorContentView];
    [self addSubview:self.leftButton];
    [self addSubview:self.rightButton];
    [self addSubview:self.textView];
    [self addSubview:self.charCountLabel];
    [self addSubview:self.contentView];

    [self slk_setupViewConstraints];
    [self slk_updateConstraintConstants];
    
    self.counterStyle = SLKCounterStyleNone;
    self.counterPosition = SLKCounterPositionTop;
    
    [self slk_registerNotifications];
    
    [self slk_registerTo:self.layer forSelector:@selector(position)];
    [self slk_registerTo:self.leftButton.imageView forSelector:@selector(image)];
    [self slk_registerTo:self.rightButton.titleLabel forSelector:@selector(font)];
}


#pragma mark - UIView Overrides

- (void)layoutIfNeeded
{
    if (self.constraints.count == 0 || !self.window) {
        return;
    }
    
    [self slk_updateConstraintConstants];
    [super layoutIfNeeded];
}

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(UIViewNoIntrinsicMetric, [self minimumInputbarHeight]);
}

+ (BOOL)requiresConstraintBasedLayout
{
    return YES;
}

- (void)safeAreaInsetsDidChange
{
    UIEdgeInsets safeAreaInsets = self.safeAreaInsets;
    self.contentInset = UIEdgeInsetsMake(_defaultInsets.top + safeAreaInsets.top,
                                         _defaultInsets.left + safeAreaInsets.left,
                                         _defaultInsets.bottom + safeAreaInsets.bottom,
                                         _defaultInsets.right + safeAreaInsets.right);
}


#pragma mark - Getters

- (SLKTextView *)textView
{
    if (!_textView) {
        Class class = self.textViewClass ? : [SLKTextView class];
        
        _textView = [[class alloc] init];
        _textView.translatesAutoresizingMaskIntoConstraints = NO;
        _textView.font = [UIFont systemFontOfSize:15.0];
        _textView.maxNumberOfLines = [self slk_defaultNumberOfLines];
        
        _textView.keyboardType = UIKeyboardTypeTwitter;
        _textView.returnKeyType = UIReturnKeyDefault;
        _textView.enablesReturnKeyAutomatically = YES;
        _textView.scrollIndicatorInsets = UIEdgeInsetsMake(0.0, -1.0, 0.0, 1.0);
        _textView.textContainerInset = UIEdgeInsetsMake(8.0, 4.0, 8.0, 0.0);
        _textView.layer.cornerRadius = 5.0;
        _textView.layer.borderWidth = 0.5;
        _textView.layer.borderColor =  [UIColor colorWithRed:200.0/255.0 green:200.0/255.0 blue:205.0/255.0 alpha:1.0].CGColor;
    }
    return _textView;
}

- (UIView *)contentView
{
    if (!_contentView) {
        _contentView = [UIView new];
        _contentView.translatesAutoresizingMaskIntoConstraints = NO;
        _contentView.backgroundColor = [UIColor clearColor];
        _contentView.clipsToBounds = YES;
    }
    return _contentView;
}

- (SLKInputAccessoryView *)inputAccessoryView
{
    if (!_inputAccessoryView) {
        _inputAccessoryView = [[SLKInputAccessoryView alloc] initWithFrame:CGRectZero];
        _inputAccessoryView.backgroundColor = [UIColor clearColor];
        _inputAccessoryView.userInteractionEnabled = NO;
    }
    
    return _inputAccessoryView;
}

- (UIButton *)leftButton
{
    if (!_leftButton) {
        _leftButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _leftButton.translatesAutoresizingMaskIntoConstraints = NO;
        _leftButton.titleLabel.font = [UIFont systemFontOfSize:15.0];
    }
    return _leftButton;
}

- (UIButton *)rightButton
{
    if (!_rightButton) {
        _rightButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _rightButton.translatesAutoresizingMaskIntoConstraints = NO;
        _rightButton.titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
        _rightButton.enabled = NO;
        
        NSString *title = NSLocalizedString(@"Send", nil);
        
        [_rightButton setTitle:title forState:UIControlStateNormal];
    }
    return _rightButton;
}

- (UIView *)editorContentView
{
    if (!_editorContentView) {
        _editorContentView = [UIView new];
        _editorContentView.translatesAutoresizingMaskIntoConstraints = NO;
        _editorContentView.backgroundColor = self.backgroundColor;
        _editorContentView.clipsToBounds = YES;
        _editorContentView.hidden = YES;
        
        [_editorContentView addSubview:self.editorTitle];
        [_editorContentView addSubview:self.editorLeftButton];
        [_editorContentView addSubview:self.editorRightButton];
    }
    return _editorContentView;
}

- (UILabel *)editorTitle
{
    if (!_editorTitle) {
        _editorTitle = [UILabel new];
        _editorTitle.translatesAutoresizingMaskIntoConstraints = NO;
        _editorTitle.textAlignment = NSTextAlignmentCenter;
        _editorTitle.backgroundColor = [UIColor clearColor];
        _editorTitle.font = [UIFont boldSystemFontOfSize:15.0];
        
        NSString *title = NSLocalizedString(@"Editing Message", nil);
        
        _editorTitle.text = title;
    }
    return _editorTitle;
}

- (UIButton *)editorLeftButton
{
    if (!_editorLeftButton) {
        _editorLeftButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _editorLeftButton.translatesAutoresizingMaskIntoConstraints = NO;
        _editorLeftButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        _editorLeftButton.titleLabel.font = [UIFont systemFontOfSize:15.0];
        
        NSString *title = NSLocalizedString(@"Cancel", nil);
        
        [_editorLeftButton setTitle:title forState:UIControlStateNormal];
    }
    return _editorLeftButton;
}

- (UIButton *)editorRightButton
{
    if (!_editorRightButton) {
        _editorRightButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _editorRightButton.translatesAutoresizingMaskIntoConstraints = NO;
        _editorRightButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        _editorRightButton.titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
        _editorRightButton.enabled = NO;
        
        NSString *title = NSLocalizedString(@"Save", nil);
        
        [_editorRightButton setTitle:title forState:UIControlStateNormal];
    }
    return _editorRightButton;
}

- (UILabel *)charCountLabel
{
    if (!_charCountLabel) {
        _charCountLabel = [UILabel new];
        _charCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _charCountLabel.backgroundColor = [UIColor clearColor];
        _charCountLabel.textAlignment = NSTextAlignmentRight;
        _charCountLabel.font = [UIFont systemFontOfSize:11.0];
        
        _charCountLabel.hidden = NO;
    }
    return _charCountLabel;
}

- (UIView *)typingView
{
    if (!_typingView) {
        if (self.typingIndicatorClass == nil) {
            _typingView = [[SLKDefaultTypingIndicatorView alloc] init];
        } else {
            Class class = self.typingIndicatorClass;

            _typingView = [[class alloc] init];
            _typingView.translatesAutoresizingMaskIntoConstraints = NO;
            _typingView.clipsToBounds = YES;

            [_typingView addObserver:self forKeyPath:@"visible" options:NSKeyValueObservingOptionNew context:nil];
        }
    }
    return _typingView;
}

- (BOOL)isHidden
{
    return _hidden;
}

- (CGFloat)minimumInputbarHeight
{
    CGFloat minimumHeight = self.textView.intrinsicContentSize.height;
    minimumHeight += self.contentInset.top;
    minimumHeight += self.slk_bottomMargin;
    minimumHeight += [self slk_typingIndicatorHeight];

    return minimumHeight;
}

- (CGFloat)appropriateHeight
{
    CGFloat height = 0.0;
    CGFloat minimumHeight = [self minimumInputbarHeight];
    
    if (self.textView.numberOfLines == 1) {
        height = minimumHeight;
    }
    else if (self.textView.numberOfLines < self.textView.maxNumberOfLines) {
        height = [self slk_inputBarHeightForLines:self.textView.numberOfLines];
    }
    else {
        height = [self slk_inputBarHeightForLines:self.textView.maxNumberOfLines];
    }
    
    if (height < minimumHeight) {
        height = minimumHeight;
    }
    
    if (self.isEditing) {
        height += self.editorContentViewHeight;
    }
    
    return roundf(height);
}

- (BOOL)limitExceeded
{
    NSString *text = [self.textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (self.maxCharCount > 0 && text.length > self.maxCharCount) {
        return YES;
    }
    return NO;
}

- (CGFloat)slk_inputBarHeightForLines:(NSUInteger)numberOfLines
{
    CGFloat height = self.textView.intrinsicContentSize.height;

    // Since the intrinsicContentSize (see SLKTextView) contains the lineHeight, we remove it here again
    height -= self.textView.font.lineHeight;

    height += roundf(self.textView.font.lineHeight * numberOfLines);
    height += roundf(self.textView.font.leading * numberOfLines);
    height += self.contentInset.top;
    height += self.slk_bottomMargin;
    height += [self slk_typingIndicatorHeight];

    return height;
}

- (CGFloat)slk_bottomMargin
{
    CGFloat margin = self.contentInset.bottom;
    margin += self.slk_contentViewHeight;
    
    return margin;
}

- (CGFloat)slk_contentViewHeight
{
    if (!self.editing) {
        return CGRectGetHeight(self.contentView.frame);
    }
    
    return 0.0;
}

- (CGFloat)slk_textViewHeight
{
    return [self slk_contentViewHeight] - [self slk_typingIndicatorHeight];
}

- (CGFloat)slk_typingIndicatorHeight
{
    return self.typingIndicatorViewHC.constant + self.typingIndicatorViewTextViewPaddingConstraint.constant;
}

- (CGFloat)slk_appropriateRightButtonWidth
{
    if (self.autoHideRightButton) {
        if (self.textView.text.length == 0) {
            return 0.0;
        }
    }
    
    CGFloat width = [self.rightButton intrinsicContentSize].width;
    width = (width >= SLKTextInputbarMinButtonWidth) ? width : SLKTextInputbarMinButtonWidth;
    return width;
}

- (CGFloat)slk_appropriateRightButtonMargin
{
    if (self.autoHideRightButton) {
        if (self.textView.text.length == 0) {
            return 0.0;
        }
    }
    
    return self.contentInset.right;
}

- (NSUInteger)slk_defaultNumberOfLines
{
    if (SLK_IS_IPAD) {
        return 8;
    }
    else {
        return 6;
    }
}


#pragma mark - Setters

- (void)setBackgroundColor:(UIColor *)color
{
    self.barTintColor = color;

    self.editorContentView.backgroundColor = color;
}

- (void)setAutoHideRightButton:(BOOL)hide
{
    if (self.autoHideRightButton == hide) {
        return;
    }
    
    _autoHideRightButton = hide;
    
    self.rightButtonWC.constant = [self slk_appropriateRightButtonWidth];
    self.rightMarginWC.constant = [self slk_appropriateRightButtonMargin];

    [self layoutIfNeeded];
}

- (void)setContentInset:(UIEdgeInsets)insets
{
    if (UIEdgeInsetsEqualToEdgeInsets(self.contentInset, insets)) {
        return;
    }
    
    if (UIEdgeInsetsEqualToEdgeInsets(self.contentInset, UIEdgeInsetsZero)) {
        _contentInset = insets;
        return;
    }
    
    _contentInset = insets;
    
    // Add new constraints
    [self removeConstraints:self.constraints];
    [self.editorContentView removeConstraints:self.editorContentView.constraints];
    [self slk_setupViewConstraints];
    [self setCounterPosition:_counterPosition];
    
    // Add constant values and refresh layout
    [self slk_updateConstraintConstants];
    
    [super layoutIfNeeded];
}

- (void)setEditing:(BOOL)editing
{
    if (self.isEditing == editing) {
        return;
    }
    
    _editing = editing;
    _editorContentView.hidden = !editing;
    
    self.contentViewHC.active = editing;
    
    [super setNeedsLayout];
    [super layoutIfNeeded];
}

- (void)setHidden:(BOOL)hidden
{
    // We don't call super here, since we want to avoid to visually hide the view.
    // The hidden render state is handled by the view controller.
    
    _hidden = hidden;
    
    if (!self.isEditing) {
        self.contentViewHC.active = hidden;
        
        [self slk_updateConstraintConstants];
        [super setNeedsLayout];
        [super layoutIfNeeded];
    }
}

- (void)setCounterPosition:(SLKCounterPosition)counterPosition
{
    // Clears the previous constraints
    if (_charCountLabelVCs.count > 0) {
        [self removeConstraints:_charCountLabelVCs];
        _charCountLabelVCs = nil;
    }
    
    _counterPosition = counterPosition;
    
    NSDictionary *views = @{@"rightButton": self.rightButton,
                            @"charCountLabel": self.charCountLabel
                            };
    
    NSDictionary *metrics = @{@"top" : @(self.contentInset.top),
                              @"bottom" : @(-self.slk_bottomMargin/2.0)
                              };
    
    // Constraints are different depending of the counter's position type
    if (counterPosition == SLKCounterPositionBottom) {
        _charCountLabelVCs = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[charCountLabel]-(bottom)-[rightButton]" options:0 metrics:metrics views:views];
    }
    else {
        _charCountLabelVCs = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(top@750)-[charCountLabel]-(>=0)-|" options:0 metrics:metrics views:views];
    }
    
    [self addConstraints:self.charCountLabelVCs];
}


#pragma mark - Text Editing

- (BOOL)canEditText:(NSString *)text
{
    if ((self.isEditing && [self.textView.text isEqualToString:text]) || self.isHidden) {
        return NO;
    }
    
    return YES;
}

- (void)beginTextEditing
{
    if (self.isEditing || self.isHidden) {
        return;
    }
    
    self.editing = YES;
    
    [self slk_updateConstraintConstants];
    
    if (!self.isFirstResponder) {
        [self layoutIfNeeded];
    }
}

- (void)endTextEdition
{
    if (!self.isEditing || self.isHidden) {
        return;
    }
    
    self.editing = NO;
    
    [self slk_updateConstraintConstants];
}


#pragma mark - Character Counter

- (void)slk_updateCounter
{
    NSString *text = [self.textView.text stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSString *counter = nil;
    
    if (self.counterStyle == SLKCounterStyleNone) {
        counter = [NSString stringWithFormat:@"%lu", (unsigned long)text.length];
    }
    if (self.counterStyle == SLKCounterStyleSplit) {
        counter = [NSString stringWithFormat:@"%lu/%lu", (unsigned long)text.length, (unsigned long)self.maxCharCount];
    }
    if (self.counterStyle == SLKCounterStyleCountdown) {
        counter = [NSString stringWithFormat:@"%ld", (long)(text.length - self.maxCharCount)];
    }
    if (self.counterStyle == SLKCounterStyleCountdownReversed)
    {
        counter = [NSString stringWithFormat:@"%ld", (long)(self.maxCharCount - text.length)];
    }
    if (self.counterStyle == SLKCounterStyleLimitExceeded)
    {
        counter = [self limitExceeded] ? [NSString stringWithFormat:@"%ld", (long)(self.maxCharCount - text.length)] : @"";
    }
    
    self.charCountLabel.text = counter;
    self.charCountLabel.textColor = [self limitExceeded] ? self.charCountLabelWarningColor : self.charCountLabelNormalColor;
}


#pragma mark - Notification Events

- (void)slk_didChangeTextViewText:(NSNotification *)notification
{
    SLKTextView *textView = (SLKTextView *)notification.object;
    
    // Skips this it's not the expected textView.
    if (![textView isEqual:self.textView]) {
        return;
    }
    
    // Updates the char counter label
    if (self.maxCharCount > 0) {
        [self slk_updateCounter];
    }
    
    if (self.autoHideRightButton && !self.isEditing)
    {
        CGFloat rightButtonNewWidth = [self slk_appropriateRightButtonWidth];
        
        // Only updates if the width did change
        if (self.rightButtonWC.constant == rightButtonNewWidth) {
            return;
        }
        
        self.rightButtonWC.constant = rightButtonNewWidth;
        self.rightMarginWC.constant = [self slk_appropriateRightButtonMargin];
        [self.rightButton layoutIfNeeded]; // Avoids the right button to stretch when animating the constraint changes
        
        BOOL bounces = self.bounces && [self.textView isFirstResponder];
        
        if (self.window) {
            [self slk_animateLayoutIfNeededWithBounce:bounces
                                              options:UIViewAnimationOptionCurveEaseInOut|UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction
                                           animations:NULL];
        }
        else {
            [self layoutIfNeeded];
        }
    }
}

- (void)slk_didChangeTextViewContentSize:(NSNotification *)notification
{
    if (self.maxCharCount > 0) {
        BOOL shouldHide = (self.textView.numberOfLines == 1) || self.editing;
        self.charCountLabel.hidden = shouldHide;
    }
}

- (void)slk_didChangeContentSizeCategory:(NSNotification *)notification
{
    if (!self.textView.isDynamicTypeEnabled) {
        return;
    }
    
    [self layoutIfNeeded];
}


#pragma mark - View Auto-Layout

- (void)slk_setupViewConstraints
{
    NSDictionary *metrics = @{
        @"top" : @(self.contentInset.top),
        @"left" : @(self.contentInset.left),
        @"right" : @(self.contentInset.right),
        @"buttonMargin" : @(MIN(self.contentInset.left, self.contentInset.right)),
    };

    NSDictionary *viewsEditor = @{
        @"label": self.editorTitle,
        @"leftButton": self.editorLeftButton,
        @"rightButton": self.editorRightButton,
    };

    [_editorContentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(left)-[leftButton(60)]-(<=buttonMargin)-[label(>=0)]-(buttonMargin)-[rightButton(60)]-(<=right)-|" options:0 metrics:metrics views:viewsEditor]];
    [_editorContentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[leftButton]|" options:0 metrics:metrics views:viewsEditor]];
    [_editorContentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[rightButton]|" options:0 metrics:metrics views:viewsEditor]];
    [_editorContentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[label]|" options:0 metrics:metrics views:viewsEditor]];

    NSDictionary *views = @{@"textView": self.textView,
                            @"leftButton": self.leftButton,
                            @"rightButton": self.rightButton,
                            @"editorContentView": self.editorContentView,
                            @"charCountLabel": self.charCountLabel,
                            @"contentView": self.contentView,
                            @"typingView": self.typingView
                            };

    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(left)-[leftButton(0)]-(<=buttonMargin)-[textView]-(buttonMargin)-[rightButton(0)]-(right)-|" options:0 metrics:metrics views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(>=0)-[leftButton(0)]-(0@750)-|" options:0 metrics:metrics views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(>=0)-[rightButton(0)]-(<=0)-|" options:0 metrics:metrics views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(left@250)-[charCountLabel(<=50@1000)]-(right@750)-|" options:0 metrics:metrics views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(50)-[typingView]|" options:0 metrics:metrics views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[editorContentView]|" options:0 metrics:metrics views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[contentView]|" options:0 metrics:metrics views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[contentView(0)]|" options:0 metrics:metrics views:views]];

    NSArray<NSLayoutConstraint *> *verticalTypingIndicatorTextViewContraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[editorContentView(0)]-(<=top)-[typingView(0)]-(<=0)-[textView(0@999)]-(0)-|" options:0 metrics:metrics views:views];
    self.typingIndicatorViewTextViewPaddingConstraint = verticalTypingIndicatorTextViewContraints[4];
    [self addConstraints:verticalTypingIndicatorTextViewContraints];

    self.textViewBottomMarginC = [self slk_constraintForAttribute:NSLayoutAttributeBottom firstItem:self secondItem:self.textView];
    self.editorContentViewHC = [self slk_constraintForAttribute:NSLayoutAttributeHeight firstItem:self.editorContentView secondItem:nil];
    self.typingIndicatorViewHC = [self slk_constraintForAttribute:NSLayoutAttributeHeight firstItem:self.typingView secondItem:nil];

    self.contentViewHC = [self slk_constraintForAttribute:NSLayoutAttributeHeight firstItem:self.contentView secondItem:nil];;
    self.contentViewHC.active = NO; // Disabled by default, so the height is calculated with the height of its subviews
    
    self.leftButtonWC = [self slk_constraintForAttribute:NSLayoutAttributeWidth firstItem:self.leftButton secondItem:nil];
    self.leftButtonHC = [self slk_constraintForAttribute:NSLayoutAttributeHeight firstItem:self.leftButton secondItem:nil];
    self.leftButtonBottomMarginC = [self slk_constraintForAttribute:NSLayoutAttributeBottom firstItem:self secondItem:self.leftButton];

    self.leftMarginWC = [[self slk_constraintsForAttribute:NSLayoutAttributeLeading] firstObject];
    
    self.rightButtonWC = [self slk_constraintForAttribute:NSLayoutAttributeWidth firstItem:self.rightButton secondItem:nil];
    self.rightButtonHC = [self slk_constraintForAttribute:NSLayoutAttributeHeight firstItem:self.rightButton secondItem:nil];
    self.rightMarginWC = [[self slk_constraintsForAttribute:NSLayoutAttributeTrailing] firstObject];
    
    self.rightButtonTopMarginC = [self slk_constraintForAttribute:NSLayoutAttributeTop firstItem:self.rightButton secondItem:self];
    self.rightButtonBottomMarginC = [self slk_constraintForAttribute:NSLayoutAttributeBottom firstItem:self secondItem:self.rightButton];
}

- (void)slk_updateConstraintConstants
{
    CGFloat zero = 0.0;
    
    self.textViewBottomMarginC.constant = self.slk_bottomMargin;

    if (self.isEditing)
    {
        self.editorContentViewHC.constant = self.editorContentViewHeight;
        
        self.leftButtonWC.constant = zero;
        self.leftButtonHC.constant = zero;
        self.leftMarginWC.constant = zero;
        self.leftButtonBottomMarginC.constant = zero;

        self.rightButtonWC.constant = zero;
        self.rightButtonHC.constant = zero;
        self.rightMarginWC.constant = zero;
    }
    else {
        self.editorContentViewHC.constant = zero;

        // When the inputbar is hidden, we need to hide the buttons as well
        if (self->_hidden) {
            self.leftButtonHC.constant = zero;
            self.rightButtonHC.constant = zero;

            return;
        }
        
        CGSize leftButtonSize = [self.leftButton imageForState:self.leftButton.state].size;
        CGSize rightButtonSize = [self.rightButton imageForState:self.rightButton.state].size;
        
        if (leftButtonSize.width > 0) {
            leftButtonSize.width = (leftButtonSize.width >= SLKTextInputbarMinButtonWidth) ? leftButtonSize.width : SLKTextInputbarMinButtonWidth;

            float leftButtonHeight = (leftButtonSize.height >= SLKTextInputbarMinButtonHeight) ? leftButtonSize.height : SLKTextInputbarMinButtonHeight;
            self.leftButtonHC.constant = roundf(leftButtonHeight);
            self.leftButtonBottomMarginC.constant = roundf((self.intrinsicContentSize.height - leftButtonHeight) / 2.0) + self.slk_textViewHeight / 2.0;
        }
        
        self.leftButtonWC.constant = roundf(leftButtonSize.width);
        self.leftMarginWC.constant = (leftButtonSize.width > 0) ? self.contentInset.left : 16;
        
        self.rightButtonWC.constant = [self slk_appropriateRightButtonWidth];
        self.rightMarginWC.constant = [self slk_appropriateRightButtonMargin];

        float rightButtonHeight = (rightButtonSize.height >= SLKTextInputbarMinButtonHeight) ? rightButtonSize.height : SLKTextInputbarMinButtonHeight;
        self.rightButtonHC.constant = roundf(rightButtonHeight);
        self.rightButtonBottomMarginC.constant = roundf((self.intrinsicContentSize.height - rightButtonHeight) / 2.0) + self.slk_textViewHeight / 2.0;
    }
}


#pragma mark - Observers

- (void)slk_registerTo:(id)object forSelector:(SEL)selector
{
    if (object) {
        [object addObserver:self forKeyPath:NSStringFromSelector(selector) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
    }
}

- (void)slk_unregisterFrom:(id)object forSelector:(SEL)selector
{
    if (object) {
        [object removeObserver:self forKeyPath:NSStringFromSelector(selector)];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([object isEqual:self.layer] && [keyPath isEqualToString:NSStringFromSelector(@selector(position))]) {
        
        if (!CGPointEqualToPoint(self.previousOrigin, self.frame.origin)) {
            self.previousOrigin = self.frame.origin;
            [[NSNotificationCenter defaultCenter] postNotificationName:SLKTextInputbarDidMoveNotification object:self userInfo:@{@"origin": [NSValue valueWithCGPoint:self.previousOrigin]}];
        }
    }
    else if ([object isEqual:self.leftButton.imageView] && [keyPath isEqualToString:NSStringFromSelector(@selector(image))]) {
        
        UIImage *newImage = change[NSKeyValueChangeNewKey];
        UIImage *oldImage = change[NSKeyValueChangeOldKey];
        
        if (![newImage isEqual:oldImage]) {
            [self slk_updateConstraintConstants];
        }
    }
    else if ([object isEqual:self.rightButton.titleLabel] && [keyPath isEqualToString:NSStringFromSelector(@selector(font))]) {
        
        [self slk_updateConstraintConstants];
    }
    else if ([object conformsToProtocol:@protocol(SLKVisibleViewProtocol)] && [keyPath isEqualToString:@"visible"]) {
        [self slk_animateLayoutIfNeededWithBounce:NO options:UIViewAnimationOptionCurveEaseInOut|UIViewAnimationOptionLayoutSubviews|UIViewAnimationOptionBeginFromCurrentState animations:^{
            if (self.typingView.isVisible) {
                self.typingIndicatorViewHC.constant = SLKTextInputbarTypingIndicatorHeight;
                self.typingIndicatorViewTextViewPaddingConstraint.constant = self.contentInset.top;
            } else {
                self.typingIndicatorViewHC.constant = 0;
                self.typingIndicatorViewTextViewPaddingConstraint.constant = 0;
            }

            // Make sure we update the scrollView position in the viewController as well
            [[NSNotificationCenter defaultCenter] postNotificationName:SLKTextInputbarContentSizeDidChangeNotification object:self];
        }];
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


#pragma mark - NSNotificationCenter registration

- (void)slk_registerNotifications
{
    [self slk_unregisterNotifications];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(slk_didChangeTextViewText:) name:UITextViewTextDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(slk_didChangeTextViewContentSize:) name:SLKTextViewContentSizeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(slk_didChangeContentSizeCategory:) name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void)slk_unregisterNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextViewTextDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SLKTextViewContentSizeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
}


#pragma mark - Lifeterm

- (void)dealloc
{
    [self slk_unregisterNotifications];
    
    [self slk_unregisterFrom:self.layer forSelector:@selector(position)];
    [self slk_unregisterFrom:self.leftButton.imageView forSelector:@selector(image)];
    [self slk_unregisterFrom:self.rightButton.titleLabel forSelector:@selector(font)];

    [self.typingView removeObserver:self forKeyPath:@"visible"];
}

@end

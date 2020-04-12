@interface SBIcon : NSObject
@property(nonatomic, copy, readonly) NSString *displayName;

- (void)setBadge:(id)arg1;
@end

@interface SBIconView : UIView {
  SBIcon *_icon;
}
@property(nonatomic, retain) SBIcon *icon;

- (void)setApplicationShortcutItems:(NSArray *)arg1;
@end

@interface SBSApplicationShortcutIcon : NSObject
@end

@interface SBSApplicationShortcutCustomImageIcon : SBSApplicationShortcutIcon
- (id)initWithImagePNGData:(id)arg1;
@end

@interface SBSApplicationShortcutItem : NSObject {
  NSString *_localizedTitle;
  NSString *_localizedSubtitle;
  NSString *_type;
  SBSApplicationShortcutIcon *_icon;
}

@property(nonatomic, copy) NSString *localizedTitle;
@property(nonatomic, copy) NSString *type;
@property(nonatomic, copy) SBSApplicationShortcutIcon *icon;
@property(nonatomic, copy) NSString *localizedSubtitle;
- (NSString *)localizedTitle;
- (void)setLocalizedTitle:(NSString *)arg1;
- (void)setType:(NSString *)arg1;
- (NSString *)type;
- (SBSApplicationShortcutIcon *)icon;
- (void)setIcon:(SBSApplicationShortcutIcon *)arg1;
- (NSString *)localizedSubtitle;
- (void)setLocalizedSubtitle:(NSString *)arg1;
@end
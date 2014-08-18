//
// Created by matt on 7/11/12.
//

#import "MGMushParser.h"
#import "UIColor+MGExpanded.h"

@implementation MGMushParser {
  NSMutableAttributedString *working;
  UIFont *bold, *italic, *monospace;
}

+ (NSAttributedString *)attributedStringFromMush:(NSString *)markdown
                                            font:(UIFont *)font
                                           color:(UIColor *)color {
  MGMushParser *parser = [[MGMushParser alloc] init];
  parser.mush = markdown;
  parser.baseColor = color;
  parser.baseFont = font;
  if ([UILabel instancesRespondToSelector:@selector(attributedText)]) {
    [parser parse];
  } else {
    [parser strip];
  }
  return parser.attributedString;
}

- (void)parse {

  // apply base colour and font
  id base = @{
    NSForegroundColorAttributeName:self.baseColor,
    NSFontAttributeName:self.baseFont,
    NSParagraphStyleAttributeName:NSParagraphStyle.defaultParagraphStyle
  };
  [working addAttributes:base range:(NSRange){0, working.length}];

  // patterns
  id boldParser = @{
    @"regex":@"(\\*{2})(.+?)(\\*{2})",
    @"replace":@[@"", @1, @""],
    @"attributes":@[@{ }, @{ NSFontAttributeName:bold }, @{ }]
  };

  id italicParser = @{
    @"regex":@"(/{2})(.+?)(/{2})",
    @"replace":@[@"", @1, @""],
    @"attributes":@[@{ }, @{ NSFontAttributeName:italic }, @{ }]
  };

  id underlineParser = @{
    @"regex":@"(_{2})(.+?)(_{2})",
    @"replace":@[@"", @1, @""],
    @"attributes":@[@{ }, @{ NSUnderlineStyleAttributeName:@(NSUnderlineStyleSingle) }, @{ }]
  };

  id monospaceParser = @{
    @"regex":@"(`)(.+?)(`)",
    @"replace":@[@"", @1, @""],
    @"attributes":@[@{ }, @{ NSFontAttributeName:monospace }, @{ }]
  };

  id colourParser = @{
    @"regex":@"(\\{#)(.+?)(\\|)(.+?)(\\})",
    @"replace":@[@"", @"", @"", @3, @""],
    @"attributes":@[@{ }, @{ }, @{ }, @{ NSForegroundColorAttributeName:@1 }, @{ }]
  };

  id bgColourParser = @{
    @"regex":@"(\\{bg#)(.+?)(\\|)(.+?)(\\})",
    @"replace":@[@"", @"", @"", @3, @""],
    @"attributes":@[@{ }, @{ }, @{ }, @{ NSBackgroundColorAttributeName:@1 }, @{ }]
  };

  [self applyParser:boldParser];
  [self applyParser:italicParser];
  [self applyParser:underlineParser];
  [self applyParser:monospaceParser];
  [self applyParser:colourParser];
  [self applyParser:bgColourParser];
}

- (void)strip {

  // patterns
  id boldParser = @{
    @"regex":@"(\\*{2})(.+?)(\\*{2})",
    @"replace":@[@"", @1, @""]
  };

  id italicParser = @{
    @"regex":@"(/{2})(.+?)(/{2})",
    @"replace":@[@"", @1, @""]
  };

  id underlineParser = @{
    @"regex":@"(_{2})(.+?)(_{2})",
    @"replace":@[@"", @1, @""]
  };

  id monospaceParser = @{
    @"regex":@"(`)(.+?)(`)",
    @"replace":@[@"", @1, @""]
  };

  id colourParser = @{
    @"regex":@"(\\{)(.+?)(\\|)(.+?)(\\})",
    @"replace":@[@"", @"", @"", @3, @""]
  };

  id bgColourParser = @{
    @"regex":@"(\\{bg)(.+?)(\\|)(.+?)(\\})",
    @"replace":@[@"", @"", @"", @3, @""]
  };

  [self applyParser:boldParser];
  [self applyParser:italicParser];
  [self applyParser:underlineParser];
  [self applyParser:monospaceParser];
  [self applyParser:colourParser];
  [self applyParser:bgColourParser];
}

- (void)applyParser:(NSDictionary *)parser {
  id regex = [NSRegularExpression regularExpressionWithPattern:parser[@"regex"]
      options:0 error:nil];
  NSString *markdown = working.string.copy;

  __block int nudge = 0;
  [regex enumerateMatchesInString:markdown options:0
      range:(NSRange){0, markdown.length}
      usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags,
          BOOL *stop) {

        NSMutableArray *substrs = @[].mutableCopy;
        NSMutableArray *replacements = @[].mutableCopy;

        // fetch match substrings
        for (int i = 0; i < match.numberOfRanges - 1; i++) {
          NSRange nudged = [match rangeAtIndex:i + 1];
          nudged.location -= nudge;
          substrs[i] = [working attributedSubstringFromRange:nudged].mutableCopy;
        }

        // make replacement substrings
        for (int i = 0; i < match.numberOfRanges - 1; i++) {
          NSString *repstr = parser[@"replace"][i];
          replacements[i] = [repstr isKindOfClass:NSNumber.class]
              ? substrs[repstr.intValue]
              : [[NSMutableAttributedString alloc] initWithString:repstr];
        }

        // apply attributes
        for (int i = 0; i < match.numberOfRanges - 1; i++) {
          id attributes = parser[@"attributes"][i];
          if (![attributes count]) {
            continue;
          }
          NSMutableDictionary *attributesCopy = [attributes mutableCopy];
          for (NSString *attributeName in attributes) {
            // convert any colour attributes from hex
            if ([attributeName isEqualToString:NSForegroundColorAttributeName] ||
                [attributeName isEqualToString:NSBackgroundColorAttributeName] ||
                [attributeName isEqualToString:NSUnderlineColorAttributeName] ||
                [attributeName isEqualToString:NSStrikethroughColorAttributeName]) {
              id hex = [substrs[[attributes[attributeName] intValue]] string];
              UIColor *color = [UIColor colorWithHexString:hex];
              attributesCopy[attributeName] = color;
            }
          }
          NSMutableAttributedString *repl = replacements[i];
          [repl addAttributes:attributesCopy range:(NSRange){0, repl.length}];
        }

        // replace
        for (int i = 0; i < match.numberOfRanges - 1; i++) {
          NSRange nudged = [match rangeAtIndex:i + 1];
          nudged.location -= nudge;
          nudge += [substrs[i] length] - [replacements[i] length];
          [working replaceCharactersInRange:nudged
              withAttributedString:replacements[i]];
        }
      }];
}

#pragma mark - Setters

- (void)setMush:(NSString *)mush {
  _mush = mush;
  working = [[NSMutableAttributedString alloc] initWithString:mush];
}

- (void)setBaseFont:(UIFont *)font {
    _baseFont = font;

    if (!font) {
        return;
    }

    CGFloat size = font.pointSize;
    CFStringRef name = (__bridge CFStringRef)font.fontName;
    NSString *fontCacheKey = [NSString stringWithFormat:@"%@-%@", name, @(size)];

    monospace = [UIFont fontWithName:@"CourierNewPSMT" size:size];
    bold = MGMushParser.boldFontCache[fontCacheKey];
    italic = MGMushParser.italicFontCache[fontCacheKey];

    if (!bold || !italic) {
        // base ctfont
        CTFontRef ctBase = CTFontCreateWithName(name, size, NULL);

        // bold ctFont
        CTFontRef ctBold = CTFontCreateCopyWithSymbolicTraits(ctBase, 0, NULL,
                                                              kCTFontBoldTrait, kCTFontBoldTrait);
        CFStringRef boldName = CTFontCopyName(ctBold, kCTFontPostScriptNameKey);
        bold = [UIFont fontWithName:(__bridge NSString *)boldName size:size] ?: font;

        // italic font
        CTFontRef ctItalic = CTFontCreateCopyWithSymbolicTraits(ctBase, 0, NULL,
                                                                kCTFontItalicTrait, kCTFontItalicTrait);
        CFStringRef italicName = CTFontCopyName(ctItalic, kCTFontPostScriptNameKey);
        italic = [UIFont fontWithName:(__bridge NSString *)italicName size:size] ?: font;

        if (bold) {
            MGMushParser.boldFontCache[fontCacheKey] = bold;
        }
        if (italic) {
            MGMushParser.italicFontCache[fontCacheKey] = italic;
        }
        if (ctBase) {
            CFRelease(ctBase);
        }
        if (ctBold) {
            CFRelease(ctBold);
        }
        if (ctItalic) {
            CFRelease(ctItalic);
        }
        if (boldName) {
            CFRelease(boldName);
        }
        if (italicName) {
            CFRelease(italicName);
        }
    }
}

#pragma mark - Getters

- (NSAttributedString *)attributedString {
  return working;
}

#pragma mark - Font Caches

+ (NSMutableDictionary *)boldFontCache {
    static NSMutableDictionary *boldFontCache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        boldFontCache = NSMutableDictionary.new;
    });
    return boldFontCache;
}

+ (NSMutableDictionary *)italicFontCache {
    static NSMutableDictionary *italicFontCache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        italicFontCache = NSMutableDictionary.new;
    });
    return italicFontCache;
}

@end

//
//  ICUTemplateMatcher.h
//
//  Created by Matt Gemmell on 19/05/2008.
//  Copyright 2008 Instinctive Code. All rights reserved.
//

#import "MGTemplateEngine.h"

/*
 This is an example Matcher for MGTemplateEngine, implemented using libicucore on Leopard, 
 via the RegexKitLite library: http://regexkit.sourceforge.net/#RegexKitLite
 
 This project includes everything you need, as long as you're building on Mac OS X 10.5 or later.
 
 Other matchers can easily be implemented using the MGTemplateEngineMatcher protocol,
 if you prefer to use another regex framework, or use another matching method entirely.
 */

@interface ICUTemplateMatcher : NSObject <MGTemplateEngineMatcher> {
	MGTemplateEngine *engine;
	NSString *markerStart;
	NSString *markerEnd;
	NSString *exprStart;
	NSString *exprEnd;
	NSString *filterDelimiter;
	NSString *templateString;
	NSString *regex;
}

@property(weak, nonatomic) MGTemplateEngine *engine;
@property(retain, nonatomic) NSString *markerStart;
@property(retain, nonatomic) NSString *markerEnd;
@property(retain, nonatomic) NSString *exprStart;
@property(retain, nonatomic) NSString *exprEnd;
@property(retain, nonatomic) NSString *filterDelimiter;
@property(retain, nonatomic) NSString *templateString;
@property(retain, nonatomic) NSString *regex;

+ (ICUTemplateMatcher *)matcherWithTemplateEngine:(MGTemplateEngine *)theEngine;

- (NSArray *)argumentsFromString:(NSString *)argString;

@end

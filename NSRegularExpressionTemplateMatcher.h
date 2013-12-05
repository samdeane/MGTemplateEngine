//
//  NSRegularExpressionTemplateMatcher.h
//
//  Created by Sam Deane on 05/12/2013.
//  Copyright 2013 Elegant Chaos. All rights reserved.
//

#import "MGTemplateEngine.h"

/*
 This is an example Matcher for MGTemplateEngine, implemented using the modern 10.7+ NSReguarExpression API.
 */

@interface NSRegularExpressionTemplateMatcher : NSObject <MGTemplateEngineMatcher>

@property(weak, nonatomic) MGTemplateEngine *engine;
@property(retain, nonatomic) NSString *markerStart;
@property(retain, nonatomic) NSString *markerEnd;
@property(retain, nonatomic) NSString *exprStart;
@property(retain, nonatomic) NSString *exprEnd;
@property(retain, nonatomic) NSString *filterDelimiter;
@property(retain, nonatomic) NSString *templateString;
@property(retain, nonatomic) NSRegularExpression *regex;
@property(retain, nonatomic) NSRegularExpression *argsPattern;
@property(retain, nonatomic) NSRegularExpression *filterArgDelimPattern;

+ (instancetype)matcherWithTemplateEngine:(MGTemplateEngine *)theEngine;

- (NSArray *)argumentsFromString:(NSString *)argString;

@end

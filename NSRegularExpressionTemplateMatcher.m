//
//  NSRegularExpressionTemplateMatcher.m
//
//  Created by Sam Deane on 05/12/2013.
//  Copyright 2013 Elegant Chaos. All rights reserved.
//

#import "NSRegularExpressionTemplateMatcher.h"

@implementation NSRegularExpressionTemplateMatcher


+ (NSRegularExpressionTemplateMatcher *)matcherWithTemplateEngine:(MGTemplateEngine *)theEngine
{
	return [[NSRegularExpressionTemplateMatcher alloc] initWithTemplateEngine:theEngine];
}


- (id)initWithTemplateEngine:(MGTemplateEngine *)theEngine
{
	if ((self = [super init]) != nil) {
		self.engine = theEngine; // weak ref
	}
	
	return self;
}

- (void)engineSettingsChanged
{
	// This method is a good place to cache settings from the engine.
    MGTemplateEngine* e = self.engine;
	self.markerStart = e.markerStartDelimiter;
	self.markerEnd = e.markerEndDelimiter;
	self.exprStart = e.expressionStartDelimiter;
	self.exprEnd = e.expressionEndDelimiter;
	self.filterDelimiter = e.filterDelimiter;
	self.templateString = e.templateContents;
	
	// Note: the \Q ... \E syntax causes everything inside it to be treated as literals.
	// This help us in the case where the marker/filter delimiters have special meaning 
	// in regular expressions; notably the "$" character in the default marker start-delimiter.
	// Note: the (?m) syntax makes ICU enable multiline matching.
	NSString *basePattern = @"(\\Q%@\\E)(?:\\s+)?(.*?)(?:(?:\\s+)?\\Q%@\\E(?:\\s+)?(.*?))?(?:\\s+)?\\Q%@\\E";
	NSString *mrkrPattern = [NSString stringWithFormat:basePattern, self.markerStart, self.filterDelimiter, self.markerEnd];
	NSString *exprPattern = [NSString stringWithFormat:basePattern, self.exprStart, self.filterDelimiter, self.exprEnd];
	NSString* pattern = [NSString stringWithFormat:@"(?m)(?:%@|%@)", mrkrPattern, exprPattern];
    NSError* error;
    self.regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionAnchorsMatchLines error:&error];
    NSString *argsPattern = @"\"(.*?)(?<!\\\\)\"|'(.*?)(?<!\\\\)'|(\\S+)";
    self.argsPattern = [NSRegularExpression regularExpressionWithPattern:argsPattern options:NSRegularExpressionAnchorsMatchLines error:&error];
    NSString *filterArgDelimPattern = @":(?:\\s+)?";
    self.filterArgDelimPattern = [NSRegularExpression regularExpressionWithPattern:filterArgDelimPattern options:NSRegularExpressionAnchorsMatchLines error:&error];
    
}

- (NSRange)matchString:(NSString*)string inRegex:(NSRegularExpression*)regex inRange:(NSRange)range capture:(NSInteger)capture
{
    NSTextCheckingResult* match = [[regex matchesInString:string options:0 range:range] firstObject];
    NSRange result;
    if (match)
        result = [match rangeAtIndex:capture];
    else
        result = NSMakeRange(NSNotFound, 0);
    
    if ((int)result.location == -1)
        result.location = NSNotFound;
    
    return result;
}

- (NSDictionary *)firstMarkerWithinRange:(NSRange)range
{
	NSRange matchRange = [self matchString:self.templateString inRegex:self.regex inRange:range capture:0];
	NSMutableDictionary *markerInfo = nil;
	if (matchRange.length > 0) {
		markerInfo = [NSMutableDictionary dictionary];
		markerInfo[MARKER_RANGE_KEY] = [NSValue valueWithRange:matchRange];
		
		// Found a match. Obtain marker string.
		NSString *matchString = [self.templateString substringWithRange:matchRange];
		NSRange localRange = NSMakeRange(0, [matchString length]);
		//NSLog(@"mtch: \"%@\"", matchString);
		
		// Find type of match
		NSString *matchType = nil;
		NSRange mrkrSubRange = [self matchString:matchString inRegex:self.regex inRange:localRange capture:1];
		BOOL isMarker = (mrkrSubRange.length > 0); // only matches if match has marker-delimiters
		int offset = 0;
		if (isMarker) {
			matchType = MARKER_TYPE_MARKER;
		} else  {
			matchType = MARKER_TYPE_EXPRESSION;
			offset = 3;
		}
		markerInfo[MARKER_TYPE_KEY] = matchType;
		
		// Split marker string into marker-name and arguments.
		NSRange markerRange = [self matchString:matchString inRegex:self.regex inRange:localRange capture:2 + offset];
		if (markerRange.length > 0) {
			NSString *markerString = [matchString substringWithRange:markerRange];
			NSArray *markerComponents = [self argumentsFromString:markerString];
			if (markerComponents && [markerComponents count] > 0) {
				markerInfo[MARKER_NAME_KEY] = markerComponents[0];
				NSUInteger count = [markerComponents count];
				if (count > 1) {
					markerInfo[MARKER_ARGUMENTS_KEY] = [markerComponents subarrayWithRange:NSMakeRange(1, count - 1)];
				}
			}
			
			// Check for filter.
			NSRange filterRange = [self matchString:matchString inRegex:self.regex inRange:localRange capture:3 + offset];
			if (filterRange.length > 0) {
				// Found a filter. Obtain filter string.
				NSString *filterString = [matchString substringWithRange:filterRange];
				
				// Convert first : plus any immediately-following whitespace into a space.
				localRange = NSMakeRange(0, [filterString length]);
				NSString *space = @" ";
				NSRange filterArgDelimRange = [self matchString:filterString inRegex:self.filterArgDelimPattern inRange:localRange
																 capture:0];
				if (filterArgDelimRange.length > 0) {
					// Replace found text with space.
					filterString = [NSString stringWithFormat:@"%@%@%@", 
									[filterString substringWithRange:NSMakeRange(0, filterArgDelimRange.location)], 
									space, 
									[filterString substringWithRange:NSMakeRange(NSMaxRange(filterArgDelimRange),
																				 localRange.length - NSMaxRange(filterArgDelimRange))]];
				}
				
				// Split into filter-name and arguments.
				NSArray *filterComponents = [self argumentsFromString:filterString];
				if (filterComponents && [filterComponents count] > 0) {
					markerInfo[MARKER_FILTER_KEY] = filterComponents[0];
					NSUInteger count = [filterComponents count];
					if (count > 1) {
						markerInfo[MARKER_FILTER_ARGUMENTS_KEY] = [filterComponents subarrayWithRange:NSMakeRange(1, count - 1)];
					}
				}
			}
		}
	}
	
	return markerInfo;
}


- (NSArray *)argumentsFromString:(NSString *)argString
{
	// Extract arguments from argString, taking care not to break single- or double-quoted arguments,
	// including those containing \-escaped quotes.
	NSMutableArray *args = [NSMutableArray array];
	
	NSInteger location = 0;
	while (location != NSNotFound) {
		NSRange searchRange  = NSMakeRange(location, [argString length] - location);
		NSRange entireRange = [self matchString:argString inRegex:self.argsPattern
											  inRange:searchRange capture:0];
		NSRange matchedRange = [self matchString:argString inRegex:self.argsPattern
											   inRange:searchRange capture:1];
		if (matchedRange.length == 0) {
			matchedRange = [self matchString:argString inRegex:self.argsPattern
										   inRange:searchRange capture:2];
			if (matchedRange.length == 0) {
				matchedRange = [self matchString:argString inRegex:self.argsPattern
											   inRange:searchRange capture:3];
			}
		}
		
		location = NSMaxRange(entireRange) + ((entireRange.length == 0) ? 1 : 0);
		if (matchedRange.length > 0) {
			[args addObject:[argString substringWithRange:matchedRange]];
		} else {
			location = NSNotFound;
		}
	}
	
	return args;
}


@end

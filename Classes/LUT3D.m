//
//  LUT3D.m
//  DropLUT
//
//  Created by Wil Gieseler on 12/15/13.
//  Copyright (c) 2013 Wil Gieseler. All rights reserved.
//

#import "LUT3D.h"

@interface LUT3D()
@property NSMutableArray *latticeArray;
@end

@implementation LUT3D

- (instancetype)initWithSize:(NSUInteger)size
             inputLowerBound:(double)inputLowerBound
             inputUpperBound:(double)inputUpperBound
                latticeArray:(NSMutableArray *)latticeArray{
    if (self = [super initWithSize:size inputLowerBound:inputLowerBound inputUpperBound:inputUpperBound]) {
        self.latticeArray = latticeArray;
    }
    return self;
}

+ (instancetype)LUTOfSize:(NSUInteger)size
          inputLowerBound:(double)inputLowerBound
          inputUpperBound:(double)inputUpperBound{
    return [[self alloc] initWithSize:size
                              inputLowerBound:inputLowerBound
                              inputUpperBound:inputUpperBound
                                 latticeArray:[LUT3D blankLatticeArrayOfSize:size]];
}

- (void) LUTLoopWithBlock:( void ( ^ )(size_t r, size_t g, size_t b) )block{
    dispatch_apply([self size], dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0) , ^(size_t r){
        dispatch_apply([self size], dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0) , ^(size_t g){
            for (int b = 0; b < [self size]; b++) {
                block(r, g, b);
            }
        });
    });
}

- (LUT *)LUTByCombiningWithLUT:(LUT *)otherLUT {
    LUT3D *newLUT = [LUT3D LUTOfSize:[self size] inputLowerBound:[self inputLowerBound] inputUpperBound:[self inputUpperBound]];
    [newLUT copyMetaPropertiesFromLUT:self];

    [newLUT LUTLoopWithBlock:^(size_t r, size_t g, size_t b) {
        LUTColor *startColor = [self colorAtR:r g:g b:b];
        LUTColor *newColor = [otherLUT colorAtColor:startColor];
        [newLUT setColor:newColor r:r g:g b:b];
    }];


    return newLUT;
}

- (instancetype)LUT3DByExtractingColorOnlyWith1DReverseStrictness:(BOOL)strictness{
    LUT1D *selfLUT1D = [self LUT1D];

    if([selfLUT1D isReversibleWithStrictness:strictness] == NO){
        return nil;
    }

    LUT1D *reversed1D = [[selfLUT1D LUTByResizingToSize:2048] LUT1DByReversingWithStrictness:strictness];

    if(reversed1D == nil){
        return nil;
    }

    LUT3D *extractedLUT = (LUT3D *)[self LUTByCombiningWithLUT:reversed1D];
    [extractedLUT copyMetaPropertiesFromLUT:self];

    return extractedLUT;
}

- (instancetype)LUT3DByExtractingContrastOnly{
    return [[self LUT1D] LUT3DOfSize:[self size]];
}

- (LUT1D *)LUT1D{
    LUT1D *lut1D = [LUT1D LUTOfSize:[self size] inputLowerBound:[self inputLowerBound] inputUpperBound:[self inputUpperBound]];
    [lut1D copyMetaPropertiesFromLUT:self];

    [lut1D LUTLoopWithBlock:^(size_t r, size_t g, size_t b) {
        LUTColor *color = [self colorAtR:r g:g b:b];
        [lut1D setColor:color r:r g:g b:b];
    }];

    return lut1D;
}

- (instancetype)LUT3DBySwizzling1DChannelsWithMethod:(LUT1DSwizzleChannelsMethod)method
                                        strictness:(BOOL)strictness{
    if(![[self LUT1D] isReversibleWithStrictness:strictness]){
        return nil;
    }
    LUT3D *extractedColorLUT = [self LUT3DByExtractingColorOnlyWith1DReverseStrictness:strictness];
    LUT1D *contrastLUT = [[self LUT1D] LUT1DBySwizzling1DChannelsWithMethod:method];
    LUT3D *newLUT = (LUT3D *)[extractedColorLUT LUTByCombiningWithLUT:contrastLUT];
    [newLUT copyMetaPropertiesFromLUT:self];
    return newLUT;
}

- (instancetype)LUT3DByConvertingToMonoWithConversionMethod:(LUTMonoConversionMethod)conversionMethod{
    LUT3D *newLUT = [LUT3D LUTOfSize:[self size] inputLowerBound:[self inputLowerBound] inputUpperBound:[self inputUpperBound]];
    [newLUT copyMetaPropertiesFromLUT:self];

    typedef LUTColor* (^converter)(LUTColor *);

    converter convertToMonoBlock;

    if(conversionMethod == LUTMonoConversionMethodAverageRGB){
        convertToMonoBlock = ^(LUTColor *color){double average = (color.red+color.green+color.blue)/3.0; return [LUTColor colorWithRed:average green:average blue:average];};
    }
    else if (conversionMethod == LUTMonoConversionMethodRedCopiedToRGB){
        convertToMonoBlock = ^(LUTColor *color){return [LUTColor colorWithRed:color.red green:color.red blue:color.red];};
    }
    else if (conversionMethod == LUTMonoConversionMethodGreenCopiedToRGB){
        convertToMonoBlock = ^(LUTColor *color){return [LUTColor colorWithRed:color.green green:color.green blue:color.green];};
    }
    else if (conversionMethod == LUTMonoConversionMethodBlueCopiedToRGB){
        convertToMonoBlock = ^(LUTColor *color){return [LUTColor colorWithRed:color.blue green:color.blue blue:color.blue];};
    }


    [newLUT LUTLoopWithBlock:^(size_t r, size_t g, size_t b) {
        [newLUT setColor:convertToMonoBlock([self colorAtR:r g:g b:b])
                       r:r
                       g:g
                       b:b];
    }];

    return newLUT;

}

+ (M13OrderedDictionary *)LUTMonoConversionMethods{
    return M13OrderedDictionaryFromOrderedArrayWithDictionaries(@[@{@"Averaged RGB":@(LUTMonoConversionMethodAverageRGB)},
                                                                  @{@"Copy Red Channel":@(LUTMonoConversionMethodRedCopiedToRGB)},
                                                                  @{@"Copy Green Channel":@(LUTMonoConversionMethodGreenCopiedToRGB)},
                                                                  @{@"Copy Blue Channel":@(LUTMonoConversionMethodBlueCopiedToRGB)}]);
}





+ (NSMutableArray *)blankLatticeArrayOfSize:(NSUInteger)size {
    NSMutableArray *blankArray = [NSMutableArray arrayWithCapacity:size];
    for (int i = 0; i < size; i++) {
        blankArray[i] = [NSNull null];
    }

    NSMutableArray *rArray = [blankArray mutableCopy];
    for (int i = 0; i < size; i++) {
        NSMutableArray *gArray = [blankArray mutableCopy];
        for (int j = 0; j < size; j++) {
            gArray[j] = [blankArray mutableCopy]; // bArray
        }
        rArray[i] = gArray;
    }

    return rArray;
}

- (void)setColor:(LUTColor *)color r:(NSUInteger)r g:(NSUInteger)g b:(NSUInteger)b {
    _latticeArray[r][g][b] = color;
}

- (LUTColor *)colorAtR:(NSUInteger)r g:(NSUInteger)g b:(NSUInteger)b {
    LUTColor *color = _latticeArray[r][g][b];
    if ([color isEqual:[NSNull null]]) {
        return nil;
    }
    return color;
}

- (NSMutableArray *)latticeArrayCopy{
    return [[self latticeArray] mutableCopy];
}

- (bool)equalsLUT:(LUT *)comparisonLUT{
    if(isLUT1D(comparisonLUT)){
        return NO;
    }
    else{
        //it's LUT3D
        if([self size] != [comparisonLUT size]){
            return NO;
        }
        else{
            return [[self latticeArray] isEqualToArray:[(LUT3D *)comparisonLUT latticeArray]];
        }
    }
}

- (LUTColor *)colorAtInterpolatedR:(double)redPoint g:(double)greenPoint b:(double)bluePoint {
    NSUInteger cubeSize = self.size;

    if ((redPoint < 0   || redPoint     > self.size - 1) ||
        (greenPoint < 0 || greenPoint   > self.size - 1) ||
        (bluePoint < 0  || bluePoint    > self.size - 1)) {
        @throw [NSException exceptionWithName:@"InvalidInputs"
                                       reason:[NSString stringWithFormat:@"Tried to access out-of-bounds lattice point r:%f g:%f b:%f", redPoint, greenPoint, bluePoint]
                                     userInfo:nil];
    }

    double lowerRedPoint = clamp(floor(redPoint), 0, cubeSize-1);
    double upperRedPoint = clamp(lowerRedPoint + 1, 0, cubeSize-1);

    double lowerGreenPoint = clamp(floor(greenPoint), 0, cubeSize-1);
    double upperGreenPoint = clamp(lowerGreenPoint + 1, 0, cubeSize-1);

    double lowerBluePoint = clamp(floor(bluePoint), 0, cubeSize-1);
    double upperBluePoint = clamp(lowerBluePoint + 1, 0, cubeSize-1);

    LUTColor *C000 = [self colorAtR:lowerRedPoint g:lowerGreenPoint b:lowerBluePoint];
    LUTColor *C010 = [self colorAtR:lowerRedPoint g:lowerGreenPoint b:upperBluePoint];
    LUTColor *C100 = [self colorAtR:upperRedPoint g:lowerGreenPoint b:lowerBluePoint];
    LUTColor *C001 = [self colorAtR:lowerRedPoint g:upperGreenPoint b:lowerBluePoint];
    LUTColor *C110 = [self colorAtR:upperRedPoint g:lowerGreenPoint b:upperBluePoint];
    LUTColor *C111 = [self colorAtR:upperRedPoint g:upperGreenPoint b:upperBluePoint];
    LUTColor *C101 = [self colorAtR:upperRedPoint g:upperGreenPoint b:lowerBluePoint];
    LUTColor *C011 = [self colorAtR:lowerRedPoint g:upperGreenPoint b:upperBluePoint];

    LUTColor *C00  = [C000 lerpTo:C100 amount:1.0 - (upperRedPoint - redPoint)];
    LUTColor *C10  = [C010 lerpTo:C110 amount:1.0 - (upperRedPoint - redPoint)];
    LUTColor *C01  = [C001 lerpTo:C101 amount:1.0 - (upperRedPoint - redPoint)];
    LUTColor *C11  = [C011 lerpTo:C111 amount:1.0 - (upperRedPoint - redPoint)];

    LUTColor *C1 = [C01 lerpTo:C11 amount:1.0 - (upperBluePoint - bluePoint)];
    LUTColor *C0 = [C00 lerpTo:C10 amount:1.0 - (upperBluePoint - bluePoint)];

    return [C0 lerpTo:C1 amount:1.0 - (upperGreenPoint - greenPoint)];
}



- (id)copyWithZone:(NSZone *)zone{
    LUT3D *copiedLUT = [super copyWithZone:zone];
    [copiedLUT setLatticeArray:[[self latticeArray] mutableCopyWithZone:zone]];

    return copiedLUT;
}


@end

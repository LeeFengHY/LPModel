//
//  LLModel.h
//  LPModel
//
//  Created by QFWangLP on 2016/11/8.
//  Copyright © 2016年 LeeFengHY. All rights reserved.
//

#import <Foundation/Foundation.h>
#if __has_include(<LLModel/LLModel.h>)
FOUNDATION_EXPORT double LLModelVersionNumber;
FOUNDATION_EXPORT const unsigned char LLModelVersionString[];
#import <LLModel/NSObject+LLModel.h>
#import <LLModel/LLClassInfo.h>
#else
#import "NSObject+LLModel.h"
#import "LLClassInfo.h"
#endif

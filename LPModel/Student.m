//
//  Student.m
//  LPModel
//
//  Created by QFWangLP on 2016/11/15.
//  Copyright © 2016年 LeeFengHY. All rights reserved.
//

#import "Student.h"

@implementation Student

+ (nullable NSDictionary<NSString *, id> *)modelCustomPropertyMapper
{
    return @{@"stuId":@[@"id",@"ID"]};
}
@end

//
//  ViewController.m
//  LPModel
//
//  Created by QFWangLP on 2016/11/7.
//  Copyright © 2016年 LeeFengHY. All rights reserved.
//

#import "ViewController.h"
#import "Student.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
#if 0
    NSString *str = @"hello";
    str = @"hello1";
    void (^print)(void) = ^{
        NSLog(@"block=str======%p=====%@",str,str);
    };
    str = @"hello2";
    print();
    NSLog(@"block=str======%p=====%@",str,str);
#endif

    // Do any additional setup after loading the view, typically from a nib.
    NSDictionary *dic = @{@"name":@"LeeFengHY",@"age":@[@"1",@"2"],@"gender":@"Men",@"id":@"10086"};
    Student *stu1 = [Student ll_modelWithDictionary:dic];
    NSLog(@"%@",[stu1 ll_modelDescription]);
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

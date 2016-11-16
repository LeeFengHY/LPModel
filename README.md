# LLModel iOS JSON

## 手动安装
1. 下载该Demo将LLModel文件夹内的所有内容(拖放)到你的工程。

## 使用方法--dictionary
```objc
- (void)viewDidLoad {
    [super viewDidLoad];
    NSDictionary *dic = @{@"name":@"LeeFengHY",@"age":@[@"1",@"2"],@"gender":@"Men",@"id":@"10086"};
    Student *stu1 = [Student ll_modelWithDictionary:dic];
    NSLog(@"%@",[stu1 ll_modelDescription]);
}

```
##系统要求
该项目最低支持 `iOS 6.0` 和 `Xcode 7.0`。

##写在结尾
*喜欢的给我点个赞, 不胜感激。

*有问题的欢迎加我QQ578545715交流,谢谢!

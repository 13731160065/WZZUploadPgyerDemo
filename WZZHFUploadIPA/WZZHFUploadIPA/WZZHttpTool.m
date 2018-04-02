//
//  WZZHttpTool.m
//  WZZHttpTool
//
//  Created by 王泽众 on 2017/5/20.
//  Copyright © 2017年 wzz. All rights reserved.
//

#import "WZZHttpTool.h"
#import <CommonCrypto/CommonDigest.h>

#define WZZHTTPTOOLBOUNDARY @"${wzzhttptoolboundary}"

static WZZHttpTool * wzzHttpTool;

@interface WZZHttpTool ()<NSURLSessionDelegate, NSURLSessionDataDelegate>
{
    NSURLSession * downloadSession;//下载会话
//    UIBackgroundTaskIdentifier backDownloadId;//后台下载id
}

@end

@implementation WZZHttpTool

//MARK:单例
+ (instancetype)shareInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        wzzHttpTool = [[WZZHttpTool alloc] init];
        
        //请求体类型
        wzzHttpTool.bodyType = WZZHttpToolBodyType_default;
        
        //下载会话
        NSURLSessionConfiguration * conf = [NSURLSessionConfiguration defaultSessionConfiguration];
        wzzHttpTool->downloadSession = [NSURLSession sessionWithConfiguration:conf delegate:wzzHttpTool delegateQueue:nil];
        
        //加载下载数据
        [self loadDownloadData];
    });
    return wzzHttpTool;
}

//MARK:通用普通请求
+ (void)requestWithMethod:(NSString *)method
                      url:(NSString *)url
               httpHeader:(NSDictionary *)headerDic
                 httpBody:(NSDictionary *)bodyDic
                 bodyType:(WZZHttpToolBodyType)bodyType
             successBlock:(void (^)(id))successBlock
              failedBlock:(void (^)(NSError *))failedBlock {
    [self requestWithMethod:method url:url httpHeader:headerDic httpBody:bodyDic bodyType:bodyType fromFile:nil successBlock:successBlock failedBlock:failedBlock];
}

//MARK:POST请求带上传文件
+ (void)requestWithMethod:(NSString *)method
                      url:(NSString *)url
               httpHeader:(NSDictionary *)headerDic
                 httpBody:(NSDictionary *)bodyDic
                 bodyType:(WZZHttpToolBodyType)bodyType
                 fromFile:(id)formFile
             successBlock:(void (^)(id))successBlock
              failedBlock:(void (^)(NSError *))failedBlock {
    //链接
    NSMutableURLRequest * req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    
    //请求方法
    if (method) {
        req.HTTPMethod = method;
    }
    
    //判断请求体
    if (bodyType == WZZHttpToolBodyType_textPlain) {
        //请求体
        if (bodyDic) {
            NSArray * arr = bodyDic.allKeys;
            NSMutableArray * bodyArr = [NSMutableArray array];
            for (int i = 0; i < arr.count; i++) {
                NSString * key = arr[i];
                NSString * value = bodyDic[key];
                [bodyArr addObject:[NSString stringWithFormat:@"%@=%@", key, value]];
            }
            NSString * bodyStr = [bodyArr componentsJoinedByString:@"&"];
            req.HTTPBody = [bodyStr dataUsingEncoding:NSUTF8StringEncoding];
        }
        
        //请求头
        if (headerDic) {
            req.allHTTPHeaderFields = headerDic;
        }
    } else if (bodyType == WZZHttpToolBodyType_jsonData) {
        //请求体
        if (bodyDic) {
            NSError * err;
            req.HTTPBody = [NSJSONSerialization dataWithJSONObject:bodyDic options:0 error:&err];
            if (err) {
                if (failedBlock) {
                    failedBlock(err);
                }
                return;
            }
        }
        
        //请求头
        NSMutableDictionary * hDic = [NSMutableDictionary dictionaryWithDictionary:@{@"Content-Type":@"application/json"}];
        if (headerDic) {
            [hDic addEntriesFromDictionary:headerDic];
        }
        req.allHTTPHeaderFields = hDic;
    }
    
    //判断是否表单提交
    if (formFile) {
        //formFile有东西，是multipart形式的请求
        //表单头标志
        NSArray * formDataArr = formFile;
        if (formDataArr.count) {
            //添加multipart请求头
            NSMutableDictionary * hDic = [NSMutableDictionary dictionaryWithDictionary:headerDic];
            hDic[@"Content-Type"] = [NSString stringWithFormat:@"multipart/form-data boundary=%@", WZZHTTPTOOLBOUNDARY];
            req.allHTTPHeaderFields = hDic;
        }
        
        //body数据
        NSMutableData * mutiData = [NSMutableData data];
        //表单普通数据字符串
        NSMutableString * bodyStr = [NSMutableString stringWithString:@""];
        
        //表单中普通参数
        NSArray * bodyKeyArr = [bodyDic allKeys];
        for (int i = 0; i < bodyKeyArr.count; i++) {
            NSString * key = bodyKeyArr[i];
            NSString * value = bodyDic[key];
            [bodyStr appendFormat:
             @"--%@\r\n"
             "Content-Disposition: form-data; name=\"%@\"\r\n"
             "\r\n"
             "%@\r\n"
             , WZZHTTPTOOLBOUNDARY, key, value];
        }
        NSData * normalData = [bodyStr dataUsingEncoding:NSUTF8StringEncoding];
        [mutiData appendData:normalData];
        
        //表单中文件
        for (int i = 0; i < formDataArr.count; i++) {
            NSMutableString * headerStr = [NSMutableString string];
            NSDictionary * dic = formDataArr[i];
            NSData * data = dic[@"data"];
            NSURL * url = dic[@"url"];
            NSString * name = dic[@"name"];
            NSString * key = dic[@"key"];
            NSString * type = dic[@"type"];
            
            //文件字符串
            NSString * file = nil;
            //数据
            if (data) {
                file = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            }
            //url
            if (url) {
                file = url.absoluteString;
            }
            
            //拼接头部数据
            [headerStr appendFormat:
             @"--%@\r\n"
             "Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n"
             "Content-Type: %@\r\n"
             "\r\n"
             , WZZHTTPTOOLBOUNDARY, key, name, type];//file
            
            //拼接头部数据
            [mutiData appendData:[headerStr dataUsingEncoding:NSUTF8StringEncoding]];
            //拼接上传数据
            [mutiData appendData:data];
            //拼接尾部换行
            [mutiData appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
            
        }
        
        //最后拼接结尾
        if (bodyDic.count || formDataArr.count) {
            NSString * endStr = [NSString stringWithFormat:@"--%@--", WZZHTTPTOOLBOUNDARY];
            [mutiData appendData:[endStr dataUsingEncoding:NSUTF8StringEncoding]];
        }
        
        //请求体
        req.HTTPBody = mutiData;
    }
    
    //请求会话
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                          delegate:[self shareInstance]
                                                     delegateQueue:[NSOperationQueue mainQueue]];
    //请求任务
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSError * err2;
        if (error) {
            if (failedBlock) {
                failedBlock(error);
            }
        } else {
            id responseObj = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&err2];
            if (err2) {
                NSString * dataStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                if (successBlock) {
                    successBlock(dataStr?dataStr:data);
                }
            } else {
                if (successBlock) {
                    successBlock(responseObj);
                }
            }
        }
    }];
    
    //执行任务
    [dataTask resume];
}

//MARK:GET请求
+ (void)GET:(NSString *)url
successBlock:(void (^)(id))successBlock
failedBlock:(void (^)(NSError *))failedBlock {
    [self GET:url urlParamDic:nil successBlock:successBlock failedBlock:failedBlock];
}

//MARK:GET请求，参数字典
+ (void)GET:(NSString *)url
urlParamDic:(NSDictionary *)urlParamDic
successBlock:(void(^)(id httpResponse))successBlock
failedBlock:(void(^)(NSError * httpError))failedBlock {
    if (urlParamDic) {
        NSArray * arr = urlParamDic.allKeys;
        NSMutableArray * bodyArr = [NSMutableArray array];
        for (int i = 0; i < arr.count; i++) {
            NSString * key = arr[i];
            NSString * value = urlParamDic[key];
            [bodyArr addObject:[NSString stringWithFormat:@"%@=%@", key, value]];
        }
        NSString * bodyStr = [bodyArr componentsJoinedByString:@"&"];
        url = [url stringByAppendingFormat:@"%@%@", [url containsString:@"?"]?@"&":@"?", bodyStr];
    }
    url = [url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    [self requestWithMethod:@"GET" url:url httpHeader:nil httpBody:nil bodyType:[WZZHttpTool shareInstance].bodyType successBlock:^(id httpResponse) {
        if (successBlock) {
            successBlock(httpResponse);
        }
    } failedBlock:^(NSError *httpError) {
        if (failedBlock) {
            failedBlock(httpError);
        }
    }];
}

//MARK:POST请求
+ (void)POST:(NSString *)url
    httpBody:(NSDictionary *)bodyDic
successBlock:(void(^)(id httpResponse))successBlock
 failedBlock:(void(^)(NSError * httpError))failedBlock {
    [self requestWithMethod:@"POST" url:url httpHeader:nil httpBody:bodyDic bodyType:[WZZHttpTool shareInstance].bodyType successBlock:^(id httpResponse) {
        if (successBlock) {
            successBlock(httpResponse);
        }
    } failedBlock:^(NSError *httpError) {
        if (failedBlock) {
            failedBlock(httpError);
        }
    }];
}

//MARK:POST请求带文件
+ (void)POST:(NSString *)url
 addFormData:(void(^)(WZZPOSTFormData *))formDataBlock
    httpBody:(NSDictionary *)bodyDic
successBlock:(void(^)(id httpResponse))successBlock
 failedBlock:(void(^)(NSError * httpError))failedBlock {
    //创建请求头
    NSMutableDictionary * headerDic = [NSMutableDictionary dictionary];
    
    //表单数据
    WZZPOSTFormData * data = [[WZZPOSTFormData alloc] init];
    if (formDataBlock) {
        formDataBlock(data);
    }
    NSArray * formDataArr = data.formDataArray;
    
    [self requestWithMethod:@"POST" url:url httpHeader:headerDic httpBody:bodyDic bodyType:[WZZHttpTool shareInstance].bodyType fromFile:formDataArr successBlock:^(id httpResponse) {
        if (successBlock) {
            successBlock(httpResponse);
        }
    } failedBlock:^(NSError *httpError) {
        if (failedBlock) {
            failedBlock(httpError);
        }
    }];
}

//MARK:PUT请求
+ (void)PUT:(NSString *)url
   httpBody:(NSDictionary *)bodyDic
successBlock:(void(^)(id httpResponse))successBlock
failedBlock:(void(^)(NSError * httpError))failedBlock {
    [self requestWithMethod:@"PUT" url:url httpHeader:nil httpBody:bodyDic bodyType:[WZZHttpTool shareInstance].bodyType successBlock:^(id httpResponse) {
        if (successBlock) {
            successBlock(httpResponse);
        }
    } failedBlock:^(NSError *httpError) {
        if (failedBlock) {
            failedBlock(httpError);
        }
    }];
}

//MARK:DELETE请求
+ (void)DELETE:(NSString *)url
      httpBody:(NSDictionary *)bodyDic
  successBlock:(void(^)(id httpResponse))successBlock
   failedBlock:(void(^)(NSError * httpError))failedBlock {
    [self requestWithMethod:@"DELETE" url:url httpHeader:nil httpBody:bodyDic bodyType:[WZZHttpTool shareInstance].bodyType successBlock:^(id httpResponse) {
        if (successBlock) {
            successBlock(httpResponse);
        }
    } failedBlock:^(NSError *httpError) {
        if (failedBlock) {
            failedBlock(httpError);
        }
    }];
}

#pragma mark - 下载
//MARK:开始下载
+ (WZZDownloadTaskModel *)downloadWithUrl:(NSString *)url {
    return [self downloadWithUrl:url bytes:@(0)];
}

//MARK:开始下载，带位置
+ (WZZDownloadTaskModel *)downloadWithUrl:(NSString *)url bytes:(NSNumber *)bytes {
    wzzHttpTool = [WZZHttpTool shareInstance];
    //配置请求
    NSURL * downUrl = [NSURL URLWithString:url];
    NSMutableURLRequest * downRequest = [NSMutableURLRequest requestWithURL:downUrl];

    if (![downUrl.absoluteString hasPrefix:@"https"]) {
        [downRequest setValue:[NSString stringWithFormat:@"bytes=%zd-", bytes.integerValue] forHTTPHeaderField:@"Range"];
    }

//    if (wzzHttpTool.downloadType == WZZHttpTool_Download_Type_DownloadTask) {
//        NSURLSessionDownloadTask * task = [wzzHttpTool->downloadSession downloadTaskWithRequest:downRequest];
//
//        [task resume];
//    }
    //任务
    NSURLSessionDataTask * task = [wzzHttpTool->downloadSession dataTaskWithRequest:downRequest];
    
    //生成模型
    NSString * tid = [self MD5:task.originalRequest.URL.absoluteString];
    WZZDownloadTaskModel * model;
    if (bytes.integerValue) {
        //继续
        NSDictionary * dic = wzzHttpTool.downloadModelDic;
        model = dic[tid];
        
        //本地文件
        NSString * locationStr = [NSString stringWithFormat:@"%@/tmp/%@", NSHomeDirectory(), tid];
        model.outStream = [NSOutputStream outputStreamWithURL:[NSURL fileURLWithPath:locationStr] append:YES];
        model.location = [NSURL fileURLWithPath:locationStr];
    } else {
        //重新
        model = [[WZZDownloadTaskModel alloc] init];
        model.progress = @(0);
        NSMutableDictionary * dic = [NSMutableDictionary dictionaryWithDictionary:wzzHttpTool.downloadModelDic];
        dic[tid] = model;
        wzzHttpTool->_downloadModelDic = [NSDictionary dictionaryWithDictionary:dic];
        
        //本地文件
        NSString * locationStr = [NSString stringWithFormat:@"%@/tmp/%@", NSHomeDirectory(), tid];
        model.outStream = [NSOutputStream outputStreamWithURL:[NSURL fileURLWithPath:locationStr] append:YES];
        model.location = [NSURL fileURLWithPath:locationStr];
        //如果已下载删除下载
        [[NSFileManager defaultManager] removeItemAtURL:model.location error:nil];
    }
    model.url = url;
    model.state = WZZHttpTool_Download_State_Loading;
    model.task = task;
    model.taskId = tid;
    
    //开始下载
    [task resume];
    
    return model;
}

//MARK:继续下载
+ (WZZDownloadTaskModel *)resumeDownloadWithTaskId:(NSString *)taskId {
    wzzHttpTool = [WZZHttpTool shareInstance];
    WZZDownloadTaskModel * model = wzzHttpTool.downloadModelDic[taskId];
    if ([model.url hasPrefix:@"https"]) {
        return [self downloadWithUrl:model.url];
    }
    return [self downloadWithUrl:model.url bytes:model.currentByte];
}

//MARK:取消下载/删除下载
+ (void)cancelDownloadWithTaskId:(NSString *)taskId {
    wzzHttpTool = [WZZHttpTool shareInstance];
    WZZDownloadTaskModel * model = wzzHttpTool.downloadModelDic[taskId];
    //取消任务
    [model.task cancel];
    
    //删除下载
    if (model.location) {
        //如果已下载删除下载
        [[NSFileManager defaultManager] removeItemAtURL:model.location error:nil];
    }
    
    //移除数据
    NSMutableDictionary * dic = [NSMutableDictionary dictionaryWithDictionary:wzzHttpTool.downloadModelDic];
    model.state = WZZHttpTool_Download_State_None;
    dic[taskId] = nil;
    wzzHttpTool->_downloadModelDic = [NSDictionary dictionaryWithDictionary:dic];
}

/**
 保存下载数据
 */
+ (void)downloadWillTerminate {
    wzzHttpTool = [WZZHttpTool shareInstance];
    if (wzzHttpTool.downloadModelDic) {
        NSArray * arr = wzzHttpTool.downloadModelDic.allKeys;
        for (int i = 0; i < arr.count; i++) {
            NSString * key = arr[i];
            WZZDownloadTaskModel * model = wzzHttpTool.downloadModelDic[key];
            [model stop];
        }
    }
    NSData * data = [NSKeyedArchiver archivedDataWithRootObject:wzzHttpTool.downloadModelDic];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"WZZHttpTool_downloadModelDic"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/**
 加载下载数据
 */
+ (void)loadDownloadData {
    NSData * data = [[NSUserDefaults standardUserDefaults] objectForKey:@"WZZHttpTool_downloadModelDic"];
    if (data) {
        wzzHttpTool->_downloadModelDic = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    } else {
        wzzHttpTool->_downloadModelDic = nil;
    }
}

//+ (void)downloadWillResignActive:(UIApplication *)application {
//    [self _gotoBackgroundLoopWithApplication:application];
//}
//
//+ (void)_gotoBackgroundLoopWithApplication:(UIApplication *)application {
//    __block UIBackgroundTaskIdentifier backId;
//    backId = [application beginBackgroundTaskWithExpirationHandler:^{
////        NSDictionary * dic = wzzHttpTool->_downloadModelDic;
////        NSArray * keysArr = [dic allKeys];
////        for (int i = 0; i < keysArr.count; i++) {
////            NSString * key = keysArr[i];
////            WZZDownloadTaskModel * model = dic[key];
////            [model stop];
////        }
//        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(9 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//            [application endBackgroundTask:backId];
//            [self _gotoBackgroundLoopWithApplication:application];
//        });
//    }];
//}

#pragma mark - 工具
//MARK:json字符串转对象
+ (id)jsonToObject:(NSString *)jsonString {
    if (jsonString == nil) {
        return nil;
    }
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    id object = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&err];
    if(err) {
        NSLog(@"json解析失败：%@",err);
        return nil;
    }
    return object;
}

//MARK:对象转json字符串
+ (NSString *)objectToJson:(id)object {
    if (object == nil) {
        return nil;
    }
    NSError * err = nil;
    NSData * data = [NSJSONSerialization dataWithJSONObject:object options:0 error:&err];
    if(err) {
        NSLog(@"json解析失败：%@",err);
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

//md5
+ (NSString *)MD5:(NSString *)string {
    const char *cStr = [string UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5( cStr, (CC_LONG)strlen(cStr), digest );
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    
    return output;
}

#pragma mark - NSURLSessionDataDelegate
//只要请求的地址是HTTPS的, 就会调用这个代理方法
//challenge:质询
//NSURLAuthenticationMethodServerTrust:服务器信任
//MARK:https代理
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
{
    if (![challenge.protectionSpace.authenticationMethod isEqualToString:@"NSURLAuthenticationMethodServerTrust"]) return;
    /*
     NSURLSessionAuthChallengeUseCredential 使用证书
     NSURLSessionAuthChallengePerformDefaultHandling  忽略证书 默认的做法
     NSURLSessionAuthChallengeCancelAuthenticationChallenge 取消请求,忽略证书
     NSURLSessionAuthChallengeRejectProtectionSpace 拒绝,忽略证书
     */
    
    NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
    
    completionHandler(NSURLSessionAuthChallengeUseCredential ,credential);
}

/**
 接收到数据

 @param session 会话
 @param dataTask 任务
 @param data 数据
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    NSString * taskId = [WZZHttpTool MD5:dataTask.originalRequest.URL.absoluteString];
    WZZDownloadTaskModel * model = _downloadModelDic[taskId];
    
    //写入数据
    [model.outStream write:data.bytes maxLength:data.length];
    
    model.currentByte = @(model.currentByte.integerValue+data.length);
    model.progress = @(model.currentByte.doubleValue/model.totalByte.doubleValue);
    NSLog(@"%@", model.progress);
    if (model.progressBlock) {
        model.progressBlock(model.progress);
    }
}

/**
 接收到服务器响应

 @param session 会话
 @param dataTask 任务
 @param response 响应
 @param completionHandler 完成回调
 */
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSHTTPURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    NSString * taskId = [WZZHttpTool MD5:dataTask.originalRequest.URL.absoluteString];
    WZZDownloadTaskModel * model = _downloadModelDic[taskId];
    
    // 打开流
    [model.outStream open];
    
    //获得服务器这次请求返回数据的总长度
    NSInteger thisByte = [response.allHeaderFields[@"Content-Length"] integerValue];
    model.totalByte = @(model.currentByte.integerValue+thisByte);
    
    // 接收这个请求，允许接收服务器的数据
    completionHandler(NSURLSessionResponseAllow);
}

/**
 下载完成

 @param session 会话
 @param task 任务
 @param error 错误
 */
- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    NSString * taskId = [WZZHttpTool MD5:task.originalRequest.URL.absoluteString];
    WZZDownloadTaskModel * model = _downloadModelDic[taskId];
    if (session == downloadSession) {
        if (model.downloadCompleteBlock) {
            if (error) {
                if (error.code == -1001) {
                    //暂停时间过长，超时
                    [model stop];
                } else if (error.code == -1005) {
                    //网络连接失败
                    [model stop];
                } else {
                    //其他失败
                    model.state = WZZHttpTool_Download_State_Failed;
                    model.downloadCompleteBlock(nil, error);
                    //如果已下载删除下载
                    [[NSFileManager defaultManager] removeItemAtURL:model.location error:nil];
                }
            } else {
                model.state = WZZHttpTool_Download_State_Success;
                model.downloadCompleteBlock(model.location, nil);
                //如果已下载删除下载
                [[NSFileManager defaultManager] removeItemAtURL:model.location error:nil];
            }
        }
    }
}


@end

#pragma mark - 表单数据
@interface WZZPOSTFormData ()
{
    NSMutableArray * _dataArr;
}

@end

@implementation WZZPOSTFormData

- (instancetype)init
{
    self = [super init];
    if (self) {
        _dataArr = [NSMutableArray array];
        _formDataArray = [NSArray arrayWithArray:_dataArr];
    }
    return self;
}

#pragma mark - 添加表单数据
- (void)addData:(NSData *)data
            key:(NSString *)key
           type:(WZZHttpTool_FormDataType)type {
    NSString * typeName = nil;
    NSString * fileName = nil;
    switch (type) {
        case WZZHttpTool_FormDataType_ImageJPG:
        {
            typeName = @"image/jpeg";
            fileName = @"fileName.jpg";
        }
            break;
        case WZZHttpTool_FormDataType_ImagePNG:
        {
            typeName = @"image/png";
            fileName = @"fileName.png";
        }
            break;
            
        default:
        {
            //如果是其他类型，直接return
            return;
        }
            break;
    }
    [self addData:data key:key fileName:fileName type:typeName];
}

- (void)addUrl:(NSURL *)url
           key:(NSString *)key
          type:(WZZHttpTool_FormDataType)type {
    NSString * typeName = nil;
    NSString * fileName = nil;
    switch (type) {
        case WZZHttpTool_FormDataType_ImageJPG:
        {
            typeName = @"image/jpeg";
            fileName = @"fileName.jpg";
        }
            break;
        case WZZHttpTool_FormDataType_ImagePNG:
        {
            typeName = @"image/png";
            fileName = @"fileName.png";
        }
            break;
            
        default:
        {
            //如果是其他类型，直接return
            return;
        }
            break;
    }
    [self addUrl:url key:key fileName:fileName type:typeName];
}

- (void)addData:(NSData *)data
            key:(NSString *)key
       fileName:(NSString *)fileName
           type:(NSString *)type {
    //数据为空
    if (!data.length) {
        NSLog(@"wzzhttptool:formdata数据为空");
        return;
    }
    
    //键格式有问题
    if (!key || ![key isKindOfClass:[NSString class]] || [key isEqualToString:@""]) {
        NSLog(@"wzzhttptool:键格式有问题");
        return;
    }
    
    //文件名格式有问题
    if (!fileName || ![fileName isKindOfClass:[NSString class]] || [fileName isEqualToString:@""]) {
        NSLog(@"wzzhttptool:文件名格式有问题");
        return;
    }
    
    //文件类型格式有问题
    if (!type || ![type isKindOfClass:[NSString class]] || [type isEqualToString:@""]) {
        NSLog(@"wzzhttptool:文件类型格式有问题");
        return;
    }
    
    //添加数据
    [_dataArr addObject:@{
                          @"data":data,
                          @"name":fileName,
                          @"type":type,
                          @"key":key
                          }];
    _formDataArray = [NSArray arrayWithArray:_dataArr];
}

- (void)addUrl:(NSURL *)url
           key:(NSString *)key
      fileName:(NSString *)fileName
          type:(NSString *)type {
    //数据为空
    if (!url.absoluteString.length) {
        NSLog(@"wzzhttptool:formurl为空");
        return;
    }
    
    //键格式有问题
    if (!key || ![key isKindOfClass:[NSString class]] || [key isEqualToString:@""]) {
        NSLog(@"wzzhttptool:键格式有问题");
        return;
    }
    
    //文件名格式有问题
    if (!fileName || ![fileName isKindOfClass:[NSString class]] || [fileName isEqualToString:@""]) {
        NSLog(@"wzzhttptool:文件名格式有问题");
        return;
    }
    
    //文件类型格式有问题
    if (!type || ![type isKindOfClass:[NSString class]] || [type isEqualToString:@""]) {
        NSLog(@"wzzhttptool:文件类型格式有问题");
        return;
    }
    
    //添加数据
    [_dataArr addObject:@{
                              @"url":url,
                              @"name":fileName,
                              @"type":type,
                              @"key":key
                              }];
    _formDataArray = [NSArray arrayWithArray:_dataArr];
}

@end

#pragma mark - 下载模型
@interface WZZDownloadTaskModel ()<NSCoding>
{
    void(^_progressBlock)(NSNumber *);
}

@end

@implementation WZZDownloadTaskModel

/**
 解压

 @param aDecoder 解压者
 @return 对象
 */
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        _taskId = [aDecoder decodeObjectForKey:@"_taskId"];
        _url = [aDecoder decodeObjectForKey:@"_url"];
        _progress = [aDecoder decodeObjectForKey:@"_progress"];
        _state = [aDecoder decodeIntegerForKey:@"_state"];
        _location = [aDecoder decodeObjectForKey:@"_location"];
        _totalByte = [aDecoder decodeObjectForKey:@"_totalByte"];
        _currentByte = [aDecoder decodeObjectForKey:@"_currentByte"];
        _tmpId = [aDecoder decodeObjectForKey:@"_tmpId"];
    }
    return self;
}

/**
 压缩

 @param aCoder 压缩者
 */
- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInteger:_state forKey:@"_state"];
    [aCoder encodeObject:_taskId forKey:@"_taskId"];
    [aCoder encodeObject:_url forKey:@"_url"];
    [aCoder encodeObject:_progress forKey:@"_progress"];
    [aCoder encodeObject:_location forKey:@"_location"];
    [aCoder encodeObject:_totalByte forKey:@"_totalByte"];
    [aCoder encodeObject:_currentByte forKey:@"_currentByte"];
    [aCoder encodeObject:_tmpId forKey:@"_tmpId"];
}

//MARK:停止下载，可继续
- (void)stop {
    if (_state == WZZHttpTool_Download_State_Loading || _state == WZZHttpTool_Download_State_Pause) {
        _state = WZZHttpTool_Download_State_Stop;
        [_task cancel];
    }
}

//MARK:暂停
- (void)pause {
    self.state = WZZHttpTool_Download_State_Pause;
    [_task suspend];
}

//MARK:继续
- (void)resume {
    self.state = WZZHttpTool_Download_State_Loading;
    [_task resume];
}

@end

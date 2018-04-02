//
//  WZZHttpTool.h
//  WZZHttpTool
//
//  Created by 王泽众 on 2017/5/20.
//  Copyright © 2017年 wzz. All rights reserved.
//

#import <Foundation/Foundation.h>
@class WZZPOSTFormData;
@class WZZDownloadTaskModel;

typedef enum {
    WZZHttpToolBodyType_textPlain = 0,
    WZZHttpToolBodyType_jsonData,
    WZZHttpToolBodyType_default = WZZHttpToolBodyType_textPlain
}WZZHttpToolBodyType;//请求体类型

@interface WZZHttpTool : NSObject

/**
 请求体类型
 */
@property (nonatomic, assign) WZZHttpToolBodyType bodyType;

/**
 下载数据
 */
@property (nonatomic, strong, readonly) NSDictionary <NSString *, WZZDownloadTaskModel *>* downloadModelDic;

+ (instancetype)shareInstance;

#pragma mark - 网络请求

/**
 通用网络请求
 method         请求方式
 url            url地址
 httpHeader     请求头
 httpBody       请求体
 bodyType       请求体格式
 successBlock   成功回调
 failedBlock    失败回调
 */
+ (void)requestWithMethod:(NSString *)method
                      url:(NSString *)url
               httpHeader:(NSDictionary *)headerDic
                 httpBody:(NSDictionary *)bodyDic
                 bodyType:(WZZHttpToolBodyType)bodyType
             successBlock:(void(^)(id httpResponse))successBlock
              failedBlock:(void(^)(NSError * httpError))failedBlock;

/**
 GET请求
 GET            url地址
 successBlock   成功回调
 failedBlock    失败回调
 */
+ (void)GET:(NSString *)url
successBlock:(void(^)(id httpResponse))successBlock
failedBlock:(void(^)(NSError * httpError))failedBlock;

/**
 GET请求
 GET            url地址
 urlParamDic    参数
 successBlock   成功回调
 failedBlock    失败回调
 */
+ (void)GET:(NSString *)url
urlParamDic:(NSDictionary *)urlParamDic
successBlock:(void(^)(id httpResponse))successBlock
failedBlock:(void(^)(NSError * httpError))failedBlock;

/**
 POST请求
 POST           url地址
 httpBody       请求体
 successBlock   成功回调
 failedBlock    失败回调
 */
+ (void)POST:(NSString *)url
    httpBody:(NSDictionary *)bodyDic
successBlock:(void(^)(id httpResponse))successBlock
 failedBlock:(void(^)(NSError * httpError))failedBlock;

/**
 POST请求带文件
 POST           url地址
 formDataBlock  表单数据
 httpBody       请求体
 successBlock   成功回调
 failedBlock    失败回调
 */
+ (void)POST:(NSString *)url
 addFormData:(void(^)(WZZPOSTFormData * formData))formDataBlock
    httpBody:(NSDictionary *)bodyDic
successBlock:(void(^)(id httpResponse))successBlock
 failedBlock:(void(^)(NSError * httpError))failedBlock;

/**
 PUT请求
 PUT            url地址
 httpBody       请求体
 successBlock   成功回调
 failedBlock    失败回调
 */
+ (void)PUT:(NSString *)url
   httpBody:(NSDictionary *)bodyDic
successBlock:(void(^)(id httpResponse))successBlock
failedBlock:(void(^)(NSError * httpError))failedBlock;

/**
 DELETE请求
 DELETE         url地址
 httpBody       请求体
 successBlock   成功回调
 failedBlock    失败回调
 */
+ (void)DELETE:(NSString *)url
      httpBody:(NSDictionary *)bodyDic
  successBlock:(void(^)(id httpResponse))successBlock
   failedBlock:(void(^)(NSError * httpError))failedBlock;

#pragma mark - 下载

/**
 开始下载
 开始下载后，本类会自动添加一条模型到downloadModelDic字典中
 
 @param url 链接
 @return 模型
 */
+ (WZZDownloadTaskModel *)downloadWithUrl:(NSString *)url;

/**
 恢复下载
 开始下载后，本类会自动添加一条模型到downloadModelDic字典中

 @param taskId 任务id
 @return 模型
 */
+ (WZZDownloadTaskModel *)resumeDownloadWithTaskId:(NSString *)taskId;

/**
 取消下载/删除下载

 @param taskId 任务id
 */
+ (void)cancelDownloadWithTaskId:(NSString *)taskId;

/**
 本地存储下载数据，程序将要结束时调用
 */
+ (void)downloadWillTerminate;

/**
 读取本地下载数据，一般用不到
 */
+ (void)loadDownloadData;

/**
 进入后台

 @param application 程序
 */
//+ (void)downloadWillResignActive:(UIApplication *)application;

#pragma mark - 工具
/**
 json转对象
 */
+ (id)jsonToObject:(NSString *)jsonString;

/**
 对象转json字符串
 */
+ (NSString *)objectToJson:(id)object;

@end

#pragma mark - 表单提交数据

typedef enum {
    WZZHttpTool_FormDataType_ImagePNG,//png图片
    WZZHttpTool_FormDataType_ImageJPG,//jpg图片
}WZZHttpTool_FormDataType;

@interface WZZPOSTFormData : NSObject

/**
 总数量
 */
@property (nonatomic, assign, readonly) NSUInteger count;

/**
 数据数组
 */
@property (nonatomic, strong, readonly) NSArray * formDataArray;

/**
 添加表单数据
 data   数据
 key    传给后台的键
 type   数据类型
 */
- (void)addData:(NSData *)data
            key:(NSString *)key
           type:(WZZHttpTool_FormDataType)type;

/**
 添加表单数据
 url    链接
 key    传给后台的键
 type   数据类型
 */
- (void)addUrl:(NSURL *)url
           key:(NSString *)key
          type:(WZZHttpTool_FormDataType)type;

/**
 添加表单数据
 data       数据
 key        传给后台的键
 fileName   传给后台的文件名
 type       数据类型
 */
- (void)addData:(NSData *)data
            key:(NSString *)key
       fileName:(NSString *)fileName
           type:(NSString *)type;

/**
 添加表单数据
 url        链接
 key        传给后台的键
 fileName   传给后台的文件名
 type       数据类型
 */
- (void)addUrl:(NSURL *)url
           key:(NSString *)key
      fileName:(NSString *)fileName
          type:(NSString *)type;

@end

#pragma mark - 下载任务模型

typedef enum : NSUInteger {
    WZZHttpTool_Download_State_None = 0,//未下载
    WZZHttpTool_Download_State_Success,//成功
    WZZHttpTool_Download_State_Failed,//失败
    WZZHttpTool_Download_State_Loading,//下载中
    WZZHttpTool_Download_State_Pause,//暂停
    WZZHttpTool_Download_State_Stop,//停止
} WZZHttpTool_Download_State;//下载状态

@interface WZZDownloadTaskModel : NSObject

/**
 任务id
 */
@property (nonatomic, strong) NSString * taskId;

/**
 备用id，可用于绑定下载项
 */
@property (nonatomic, strong) NSString * tmpId;

/**
 url
 */
@property (nonatomic, strong) NSString * url;

/**
 下载进度
 */
@property (nonatomic, strong) NSNumber * progress;

/**
 总大小
 */
@property (nonatomic, strong) NSNumber * totalByte;

/**
 已下载大小
 */
@property (nonatomic, strong) NSNumber * currentByte;

/**
 下载位置
 */
@property (nonatomic, strong) NSURL * location;

/**
 恢复数据
 */
@property (nonatomic, strong) NSData * resumeData;

/**
 下载状态
 */
@property (nonatomic, assign) WZZHttpTool_Download_State state;

/**
 下载任务
 */
@property (nonatomic, strong) NSURLSessionDataTask * task;

/**
 输出流
 */
@property (nonatomic, strong) NSOutputStream * outStream;

/**
 进度回调
 */
@property (nonatomic, strong) void (^progressBlock)(NSNumber * progress);

/**
 下载完成
 */
@property (nonatomic, strong) void (^downloadCompleteBlock)(NSURL * location, NSError * error);

/**
 停止下载，可继续
 */
- (void)stop;

/**
 暂停
 */
- (void)pause;

/**
 继续
 */
- (void)resume;

@end

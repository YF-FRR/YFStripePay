//
//  Card3DSExampleViewController.m
//  Custom Integration (ObjC)
//
//  Created by Ben Guo on 2/22/17.
//  Copyright © 2017 Stripe. All rights reserved.
//

#import <Stripe/Stripe.h>
#import "ViewController.h"
#import <AFNetworking.h>

#define KReplace_Url @"baocmsxy.ijianghu.net"
#define IPADDRESS [NSString stringWithFormat:@"http://%@/api.php",KReplace_Url]

#define ISPostSuccess [json[@"error"] isEqualToString:@"0"]
#define Error_Msg json[@"message"]
#define NOTCONNECT_STR NSLocalizedString(@"未能连接服务器,请稍后再试!", @"PrefixHeader")


@interface ViewController () <STPPaymentCardTextFieldDelegate>
@property (weak, nonatomic) STPPaymentCardTextField *paymentTextField;
@property (weak, nonatomic) UILabel *waitingLabel;
@property (weak, nonatomic) UIActivityIndicatorView *activityIndicator;
@end

@implementation ViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    // 设置key
    [[STPPaymentConfiguration sharedConfiguration] setPublishableKey:@"pk_test_Bi9Leiqh10iLckDTIh4ss22V"];
    
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"Card + 3DS";
    self.edgesForExtendedLayout = UIRectEdgeNone;
    
    STPPaymentCardTextField *paymentTextField = [[STPPaymentCardTextField alloc] init];
    paymentTextField.numberPlaceholder = @"42424242424242424242";
    STPCardParams *cardParams = [STPCardParams new];
    cardParams.number = @"";
    paymentTextField.cardParams = cardParams;
    paymentTextField.delegate = self;
    paymentTextField.cursorColor = [UIColor purpleColor];
    self.paymentTextField = paymentTextField;
    [self.view addSubview:paymentTextField];
    
    UILabel *label = [UILabel new];
    label.text = @"Waiting for payment authorization";
    [label sizeToFit];
    label.textColor = [UIColor grayColor];
    label.alpha = 0;
    [self.view addSubview:label];
    self.waitingLabel = label;
    
    NSString *title = @"Author";
    UIBarButtonItem *payButton = [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStyleDone target:self action:@selector(pay)];
    payButton.enabled = paymentTextField.isValid;
    self.navigationItem.rightBarButtonItem = payButton;
    
    UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    activityIndicator.hidesWhenStopped = YES;
    self.activityIndicator = activityIndicator;
    [self.view addSubview:activityIndicator];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.paymentTextField becomeFirstResponder];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat padding = 15;
    CGFloat width = CGRectGetWidth(self.view.frame) - (padding*2);
    CGRect bounds = self.view.bounds;
    self.paymentTextField.frame = CGRectMake(padding, padding, width, 44);
    self.activityIndicator.center = CGPointMake(CGRectGetMidX(bounds),
                                                CGRectGetMaxY(self.paymentTextField.frame) + padding*2);
    self.waitingLabel.center = CGPointMake(CGRectGetMidX(bounds),
                                           CGRectGetMaxY(self.activityIndicator.frame) + padding*2);
}

- (void)updateUIForPaymentInProgress:(BOOL)paymentInProgress {
    self.navigationController.navigationBar.userInteractionEnabled = !paymentInProgress;
    self.navigationItem.rightBarButtonItem.enabled = !paymentInProgress;
    self.paymentTextField.userInteractionEnabled = !paymentInProgress;
    [UIView animateWithDuration:0.2 animations:^{
        self.waitingLabel.alpha = paymentInProgress ? 1 : 0;
    }];
    if (paymentInProgress) {
        [self.activityIndicator startAnimating];
    } else {
        [self.activityIndicator stopAnimating];
    }
}

- (void)paymentCardTextFieldDidChange:(nonnull STPPaymentCardTextField *)textField {
    self.navigationItem.rightBarButtonItem.enabled = textField.isValid;
}

- (void)pay {
    if (![self.paymentTextField isValid]) {
        return;
    }
  
    [self updateUIForPaymentInProgress:YES];
    STPAPIClient *stripeClient = [STPAPIClient sharedClient];
    STPSourceParams *sourceParams = [STPSourceParams cardParamsWithCard:self.paymentTextField.cardParams];
    // 创建一个卡支付
    [stripeClient createSourceWithParams:sourceParams completion:^(STPSource *source, NSError *error) {
        // 判断这个卡需要3DS验证
        if (source.cardDetails.threeDSecure == STPSourceCard3DSecureStatusRequired ||
            source.cardDetails.threeDSecure == STPSourceCard3DSecureStatusOptional) {
            // 通过3DS验证的方式支付
            STPSourceParams *threeDSParams = [STPSourceParams threeDSecureParamsWithAmount:1111
                                                                                  currency:@"usd"
                                                                                 returnURL:@"payments-example://stripe-redirect"
                                                                                      card:source.stripeID];
            [stripeClient createSourceWithParams:threeDSParams completion:^(STPSource * source, NSError *error) {
                if (error) {
                     [self updateUIForPaymentInProgress:NO];
                } else {
                    // 跳转到卡授权的银行去进行验证,需要等界面加载全部完成后,点击界面的AUTHORIZE TEST PAYMENT 按钮才能够成功
                  __block STPRedirectContext * redirectContext = [[STPRedirectContext alloc] initWithSource:source completion:^(NSString *sourceID, NSString *clientSecret, NSError *error) {
                      [self updateUIForPaymentInProgress:NO];
                        // 验证后去支付,调用后台的支付
                      [self payWihtSourceID:sourceID block:^(BOOL success, NSString *msg) {
                          if (success) {
                               NSLog(@"\n\n支付成功\n\n");
                          }else{
                               NSLog(@"\n\n支付失败  %@\n\n",msg);
                          }
                           redirectContext = nil;
                      }];
                      
                    }];
                    [redirectContext startRedirectFlowFromViewController:self];
                }
            }];
        }else {
            NSLog(@"\n\n不支持3DS验证\n\n");
            [self updateUIForPaymentInProgress:NO];
        }
    }];
}

-(void)payWihtSourceID:(NSString *)sourceID block:(void(^)(BOOL success,NSString * msg))block{
    [self postWithAPI:@"client/payment/stripe_pay" withParams:@{@"stripe_source":sourceID,@"amount":@"11.11"} success:^(id json) {
        NSLog(@"Stripe支付接口 =======  %@",json);
        if (ISPostSuccess) {
            block(YES,@"");
        }else{
            block(nil,Error_Msg);
        }
        
    } failure:^(NSError *error) {
        NSLog(@"error : %@",error.description);
        block(nil,NOTCONNECT_STR);
    }];
}


- (void)postWithAPI:(NSString *)api withParams:(NSDictionary *)params success:(void (^)(id json))success failure:(void (^)(NSError * error))failure
{

    //获取token

    NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithDictionary:params];
    
    //将业务数据转换为json串
    NSString *jsonString = [self dictionaryToJson:params];
    
    NSString *city_id = [[NSUserDefaults standardUserDefaults] objectForKey:@"city_id"];
    city_id = city_id.length == 0 ? @"0" : city_id;
    
    NSString *cityCode = [[NSUserDefaults standardUserDefaults] objectForKey:@"cityCode"];
    cityCode = cityCode ? cityCode : @"0551";
    
    NSString *regisStr = [[NSUserDefaults standardUserDefaults]objectForKey:@"registrationID"];
    regisStr = regisStr.length == 0 ? @"" : regisStr;
    //定义系统级参数字典
    NSDictionary *systemDic = @{@"API":api,
                                @"CLIENT_API":@"CUSTOM",
                                @"CLIENT_OS":@"IOS",
                                @"data":jsonString};
    
    AFHTTPSessionManager *sharedClient = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:IPADDRESS]];
    sharedClient.securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    sharedClient.responseSerializer = [AFHTTPResponseSerializer serializer];
    [sharedClient POST:[[NSUserDefaults standardUserDefaults] objectForKey:@"IPADDRESS"] parameters:systemDic progress:^(NSProgress * _Nonnull uploadProgress) {}
     
                          success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                              
                              NSString *string = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];

                              NSError *error;
                              NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:responseObject
                                                                                   options:NSJSONReadingMutableContainers
                                                                                     error:&error];
                              if (error) {
                                  UIImage * image = [[UIImage alloc]initWithData:responseObject];
                                  if (success && image) {
                                      
                                      success(image);
                                      
                                  }else if(success){

                                      success(@{@"error":@"-100",
                                                @"message":string});
                                      
                                  }
                                  error = nil;
                                  string = nil;
                                  
                                  return ;
                              }
                              string = nil;
                              if (success) {
                                  success(JSON);
                              }
                          }
                          failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                              
                              if (failure) {
                                  failure(error);
                              }
                          }];
}

//将字典转换为json字符串
- (NSString*)dictionaryToJson:(NSDictionary *)dic

{
    NSError *parseError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&parseError];
    NSString *str = nil;
    str = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return str.length > 0 ? str : @"";
}

@end


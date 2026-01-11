//
//  VPNManager.h
//  SOCKS
//
//  Manages the VPN tunnel connection to bypass iOS device isolation
//

#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, VPNConnectionStatus) {
    VPNConnectionStatusDisconnected,
    VPNConnectionStatusConnecting,
    VPNConnectionStatusConnected,
    VPNConnectionStatusDisconnecting,
    VPNConnectionStatusError
};

@protocol VPNManagerDelegate <NSObject>
@optional
- (void)vpnStatusDidChange:(VPNConnectionStatus)status;
- (void)vpnDidFailWithError:(NSError *)error;
@end

@interface VPNManager : NSObject

@property (nonatomic, weak, nullable) id<VPNManagerDelegate> delegate;
@property (nonatomic, readonly) VPNConnectionStatus status;
@property (nonatomic, copy, nullable) NSString *serverAddress;
@property (nonatomic, assign) NSUInteger serverPort;

+ (instancetype)sharedManager;

// Configuration
- (void)configureVPNWithServerAddress:(NSString *)address port:(NSUInteger)port completion:(void (^)(NSError * _Nullable error))completion;

// Connection control
- (void)connectWithCompletion:(void (^)(NSError * _Nullable error))completion;
- (void)disconnect;

// Status
- (BOOL)isConnected;

@end

NS_ASSUME_NONNULL_END

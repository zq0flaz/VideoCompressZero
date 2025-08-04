#import "VideoCompressPlugin.h"
#import <video_compress_zero/video_compress_zero-Swift.h>

@implementation VideoCompressZero
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftVideoCompressZeroPlugin registerWithRegistrar:registrar];
}
@end

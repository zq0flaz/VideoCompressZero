#import "VideoCompressZeroPlugin.h"
#import <video_compress_zero/video_compress_zero-Swift.h>

@implementation VideoCompressZeroPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftVideoCompressZeroPlugin registerWithRegistrar:registrar];
}
@end

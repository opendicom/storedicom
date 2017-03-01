#import "NSDictionary+opendicom.h"

@implementation NSDictionary (opendicom)

+(NSDictionary*)studyAttributesForQidoURL:(NSURL*)url
{
    NSData *qidoData=[NSData dataWithContentsOfURL:url];
    if (qidoData)
    {
        NSDictionary *d=[NSJSONSerialization JSONObjectWithData:qidoData options:0 error:nil][0];
        return @{
                 @"00080061":((d[@"00080061"])[@"Value"])[0],
                 @"00100020":((d[@"00100020"])[@"Value"])[0],
                 @"00201206":((d[@"00201206"])[@"Value"])[0],
                 @"00201208":((d[@"00201208"])[@"Value"])[0]
                };
    }
    return @{};
}

@end

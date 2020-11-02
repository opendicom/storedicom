#import "NSDictionary+opendicom.h"

@implementation NSDictionary (opendicom)

+(NSDictionary*)studyAttributesForQidoURL:(NSURL*)url
{
   @try {
      NSData *qidoData=[NSData dataWithContentsOfURL:url];
      //NSString *r=[[NSString alloc]initWithData:qidoData encoding:NSUTF8StringEncoding];
      //NSLog(@"%@",r);
     if (qidoData)
     {
       if ([qidoData length])
       {
          NSDictionary *d=[NSJSONSerialization JSONObjectWithData:qidoData options:0 error:nil][0];
          return @{
                 @"00080061":((d[@"00080061"])[@"Value"])[0],
                 @"00100020":((d[@"00100020"])[@"Value"])[0],
                 @"00201206":((d[@"00201206"])[@"Value"])[0],
                 @"00201208":((d[@"00201208"])[@"Value"])[0]
                };
       }
       else return @{};
     }
     else return @{};
   }
   @catch (NSException *exception) {
    return @{
       @"name":exception.name,
       @"reason":exception.reason
    };
   }
}

@end

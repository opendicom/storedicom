//
//  main.mm
//  spoolstow
//
//  Created by jacquesfauquex on 2017-02-20.
//  Copyright (c) 2017 opendicom.com All rights reserved.

/*
 args
 [0] "/Users/Shared/stow/stow",
 [1] path to institutionMapping.plist
 [2] path to the root folder
 [3] url string del PACS "http://192.168.0.7:8080/dcm4chee-arc/aets/%@/rs/studies"
 [4] "export MYSQL_PWD=pacs;/usr/local/mysql/bin/mysql --raw --skip-column-names -upacs -h 192.168.0.7 -b pacsdb -e \"select access_control_id from study where study_iuid='%@'\" | awk -F\t '{print $1}'"
 [5] logLevel
 */

#include "Coerce.h"
#import "NSString+opendicom.h"
#import "NSDictionary+opendicom.h"
#import "ODLog.h"




int task(NSString *launchPath, NSArray *launchArgs, NSData *writeData, NSMutableData *readData)
{
    NSTask *task=[[NSTask alloc]init];
    [task setLaunchPath:launchPath];
    [task setArguments:launchArgs];
    //NSLog(@"%@",[task arguments]);
    NSPipe *writePipe = [NSPipe pipe];
    NSFileHandle *writeHandle = [writePipe fileHandleForWriting];
    [task setStandardInput:writePipe];
    
    NSPipe* readPipe = [NSPipe pipe];
    NSFileHandle *readingFileHandle=[readPipe fileHandleForReading];
    [task setStandardOutput:readPipe];
    [task setStandardError:readPipe];
    
    [task launch];
    [writeHandle writeData:writeData];
    [writeHandle closeFile];
    
    NSData *dataPiped = nil;
    while((dataPiped = [readingFileHandle availableData]) && [dataPiped length])
    {
        [readData appendData:dataPiped];
    }
    //while( [task isRunning]) [NSThread sleepForTimeInterval: 0.1];
    //[task waitUntilExit];		// <- This is VERY DANGEROUS : the main runloop is continuing...
    //[aTask interrupt];
    
    [task waitUntilExit];
    int terminationStatus = [task terminationStatus];
    if (terminationStatus!=0) NSLog(@"ERROR task terminationStatus: %d",terminationStatus);
    return terminationStatus;
}

static NSError *error=nil;
static short dashDash = 0x2D2D;
static unsigned short crlf = 0x0A0D;

int main(int argc, const char * argv[])
{
    @autoreleasepool {
       
#pragma mark init data markers for stow
        NSData *dashDashData =[NSData dataWithBytes:&dashDash length:2];
        NSData *crlfData =[NSData dataWithBytes:&crlf length:2];
        
        //we create a new boundary for each stow and check that the boundary doesn«t match any data within DICOM FILES
        
        //cdbc:     \r\n--%@\r\n
        NSString *boundaryString=[[NSUUID UUID]UUIDString];
        NSData *boundaryData=[boundaryString dataUsingEncoding:NSASCIIStringEncoding];
        NSMutableData *mutableCdbc=[NSMutableData dataWithData:crlfData];
        [mutableCdbc appendData:dashDashData];
        [mutableCdbc appendData:boundaryData];
        [mutableCdbc appendData:crlfData];
        
        //cdbdc:    \r\n--%@--\r\n
        NSData *cdbcData=[NSData dataWithData:mutableCdbc];
        NSMutableData *mutableCdbdc=[NSMutableData dataWithData:crlfData];
        [mutableCdbdc appendData:dashDashData];
        [mutableCdbdc appendData:boundaryData];
        [mutableCdbdc appendData:dashDashData];
        [mutableCdbdc appendData:crlfData];
        NSData *cdbdcData=[NSData dataWithData:mutableCdbdc];
        
        //ctad: Content-Type:application/dicom
        NSData *ctadData=[@"Content-Type:application/dicom\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];

        NSMutableData *body = [NSMutableData data];
        NSMutableArray *packaged=[NSMutableArray array];
        
        char lastByte;
        
        [Coerce registerCodecs];

        NSFileManager *fileManager=[NSFileManager defaultManager];

       
#pragma mark args
        NSArray *args=[[NSProcessInfo processInfo] arguments];
        if (args.count != 4)
        {
           
        }
        NSDictionary *institutionMapping=[NSDictionary dictionaryWithContentsOfFile:args[1]];
        //NSLog(@"%@",[institutionMapping description]);
        
        NSString *CLASSIFIED=[args[2] stringByAppendingPathComponent:@"CLASSIFIED"];//input pool originals
        NSString *DISCARDED=[args[2] stringByAppendingPathComponent:@"DISCARDED"];//output originals NOK
        NSString *ORIGINALS=[args[2] stringByAppendingPathComponent:@"ORIGINALS"];//output originals OK
       
       
        NSString *COERCED=[args[2] stringByAppendingPathComponent:@"COERCED"];//input pool coerced
        NSString *REJECTED=[args[2] stringByAppendingPathComponent:@"REJECTED"];//output coerced sent NOK
        NSString *STOWED=[args[2] stringByAppendingPathComponent:@"STOWED"];//output coerced sent OK

       
#pragma mark log level
       NSUInteger llindex=[@[@"DEBUG",@"VERBOSE",@"INFO",@"WARNING",@"ERROR",@"EXCEPTION"] indexOfObject:args[5]];
       if (llindex==NSNotFound)
       {
           NSLog(@"ODLogLevel (arg 1) should be one of [ DEBUG | VERBOSE | INFO | WARNING | ERROR | EXCEPTION ]");
           return 1;
       }
       ODLogLevel=(int)llindex;

       
#pragma mark loop CLASSIFIED

        NSArray *CLASSIFIEDarray=[fileManager contentsOfDirectoryAtPath:CLASSIFIED error:&error];
        for (NSString *CLASSIFIEDname in CLASSIFIEDarray)
        {
            if ([CLASSIFIEDname hasPrefix:@"."]) continue;
            NSString *CLASSIFIEDpath=[CLASSIFIED stringByAppendingPathComponent:CLASSIFIEDname];
            NSArray *properties=[CLASSIFIEDname componentsSeparatedByString:@"@"];
            
            
#pragma mark DISCARD IT (unknown source)?
            NSString *institutionName=institutionMapping[properties[1]];//aet-based
            if (!institutionName) institutionName=institutionMapping[properties[2]];//IP-based
            if (!institutionName)
            {
                NSLog(@"unknown: %@",CLASSIFIEDname);
                [fileManager moveItemAtPath:CLASSIFIEDpath
                                     toPath:[NSString stringWithFormat:@"%@/%@@%f",
                                             DISCARDED,CLASSIFIEDname,
                                             [[NSDate date]timeIntervalSinceReferenceDate
                                              ]
                                             ]
                                      error:&error
                 ];
                continue;
            }
           
           
            NSString *pacsURIString=[NSString stringWithFormat:args[3],institutionName];
            NSArray *CLASSIFIEDpathContents=[fileManager contentsOfDirectoryAtPath:CLASSIFIEDpath error:nil];
            
            if (![CLASSIFIEDpathContents count]) continue;
            if (([CLASSIFIEDpathContents count]==1)&&([CLASSIFIEDpathContents[0] hasPrefix:@"."])) continue;
            NSLog(@"%@ -> %@",CLASSIFIEDname,institutionName);

            
#pragma mark loop STUDIES
            for (NSString *StudyInstanceUID in CLASSIFIEDpathContents)
            {
                if ([StudyInstanceUID hasPrefix:@"."]) continue;
                NSString *STUDYpath=[CLASSIFIEDpath stringByAppendingPathComponent:StudyInstanceUID];

                NSMutableString *STUDYlog=[NSMutableString string];
                NSMutableData *sqlResponseData=[NSMutableData data];
#pragma mark try study
                @try {
                   
                   if ([args count]>4) task(@"/bin/bash",@[@"-s"],[[NSString stringWithFormat:args[4],StudyInstanceUID] dataUsingEncoding:NSUTF8StringEncoding],sqlResponseData);
                  if (sqlResponseData.length)
                  {
                       //studyUID already exists in PACS
                       [sqlResponseData getBytes:&lastByte range:NSMakeRange([sqlResponseData length]-1,1)];
                       NSString *sqlResponseString=nil;//remove eventual last space
                       if (lastByte==0x20) sqlResponseString=[[NSString alloc]initWithData:sqlResponseData encoding:NSUTF8StringEncoding];
                       else sqlResponseString=[[NSString alloc]initWithData:[sqlResponseData subdataWithRange:NSMakeRange(0,[sqlResponseData length]-1)] encoding:NSUTF8StringEncoding];
                       if (![sqlResponseString isEqualToString:institutionName])
                       {
                           //StudyIUID already registered in other institution
                           NSLog(@"%@ (discarded. Belongs to %@)",StudyInstanceUID,sqlResponseString);
                       
                           NSString *DISCARDEDpath=[[DISCARDED stringByAppendingPathComponent:CLASSIFIEDname]stringByAppendingPathComponent:StudyInstanceUID];
                           [fileManager createDirectoryAtPath:DISCARDEDpath withIntermediateDirectories:YES attributes:nil error:&error];
                           [fileManager moveItemAtPath:STUDYpath toPath:DISCARDEDpath  error:&error];
                           
                           //comment DISCARDEDpath
                           NSDictionary *q=
                           [NSDictionary studyAttributesForQidoURL:
                            [NSURL URLWithString:
                             [NSString stringWithFormat:
                              @"%@?StudyInstanceUID=%@",
                              [NSString stringWithFormat:args[3],sqlResponseString],
                              StudyInstanceUID
                             ]
                            ]
                           ];
                           //comment(DISCARDEDpath, [NSString stringWithFormat:@"[WARN] dest %@ unacceptable. StudyUID found in %@  %@ (%@/%@) for patient with ID %@",institutionName,sqlResponseString,q[@"00080061"],q[@"00201206"],q[@"00201208"],q[@"00100020"]]);
                           continue;
                       }
                   }
                   NSURL *pacsURI=[NSURL URLWithString:[NSString stringWithFormat:@"%@/%@",pacsURIString,StudyInstanceUID]];
                   NSString *qidoRequest=[NSString stringWithFormat:@"%@?StudyInstanceUID=%@",pacsURIString,StudyInstanceUID];
                   //NSLog(@"qido inicial: %@",qidoRequest);
                   NSURL *qidoRequestURL=[NSURL URLWithString:qidoRequest];
                   
                   NSDictionary *q=[NSDictionary studyAttributesForQidoURL:qidoRequestURL];
                   NSLog(@"%@ %@ (%@/%@) for patient %@ in PACS before STOW",
                         StudyInstanceUID,
                         q[@"00080061"],
                         q[@"00201206"],
                         q[@"00201208"],
                         q[@"00100020"]
                         );
                   
                   NSString *COERCEDpath=[[COERCED stringByAppendingPathComponent:CLASSIFIEDname] stringByAppendingPathComponent:StudyInstanceUID];
                   [fileManager createDirectoryAtPath:COERCEDpath withIntermediateDirectories:YES attributes:nil error:&error];
                   NSString *DISCARDEDpath=[[DISCARDED stringByAppendingPathComponent:CLASSIFIEDname] stringByAppendingPathComponent:StudyInstanceUID];
                   [fileManager createDirectoryAtPath:DISCARDEDpath withIntermediateDirectories:YES attributes:nil error:&error];
                   NSString *ORIGINALSpath=[[ORIGINALS stringByAppendingPathComponent:CLASSIFIEDname] stringByAppendingPathComponent:StudyInstanceUID];
                   [fileManager createDirectoryAtPath:ORIGINALSpath withIntermediateDirectories:YES attributes:nil error:&error];
                   NSString *REJECTEDpath=[[REJECTED stringByAppendingPathComponent:CLASSIFIEDname] stringByAppendingPathComponent:StudyInstanceUID];
                   [fileManager createDirectoryAtPath:REJECTEDpath withIntermediateDirectories:YES attributes:nil error:&error];
                   NSString *STOWEDpath=[[STOWED stringByAppendingPathComponent:CLASSIFIEDname] stringByAppendingPathComponent:StudyInstanceUID];
                   [fileManager createDirectoryAtPath:STOWEDpath withIntermediateDirectories:YES attributes:nil error:&error];

   #pragma mark loop SOPInstanceUID
                   NSArray *SOPIUIDarray=[fileManager contentsOfDirectoryAtPath:STUDYpath error:&error];
                   NSUInteger SOPIUIDCount=[SOPIUIDarray count];
                   [body setData:[NSData data]];
                   [packaged removeAllObjects];
                   
                   for (NSUInteger i=0; i<SOPIUIDCount; i++)
                   {
                       if ([SOPIUIDarray[i] hasPrefix:@"."]) continue;
                       
                       NSString *filePath=[STUDYpath stringByAppendingPathComponent:SOPIUIDarray[i]];
                       NSString *COERCEDfile=[COERCEDpath stringByAppendingPathComponent:SOPIUIDarray[i]];
                       NSString *coercedErrorMessage=[Coerce coerceFileAtPath:filePath toPath:COERCEDfile withInstitutionName:institutionName];
                       if (!coercedErrorMessage)
                       {
                           [body appendData:cdbcData];
                           [body appendData:ctadData];
                           [body appendData:[NSData dataWithContentsOfFile:COERCEDfile]];
                           [packaged addObject:COERCEDfile];
                           [fileManager moveItemAtPath:filePath toPath:[ORIGINALSpath stringByAppendingPathComponent:SOPIUIDarray[i]] error:&error];
                       }
                       else
                       {
                           //coerci—n imposible
                           //no se manda al PACS
                           //se traslada el original a DISCARDED
                           //y se informa del problema en comentario
                           [fileManager moveItemAtPath:filePath toPath:[DISCARDEDpath stringByAppendingPathComponent:SOPIUIDarray[i]] error:&error];
                           //comment([DISCARDEDpath stringByAppendingPathComponent:SOPIUIDarray[i]], coercedErrorMessage);
                       }
                       
                       
           #pragma mark send stow
                       if (([body length] > 10000000) || ((i==SOPIUIDCount-1) && [body length]))
                       {
                           //finalize body
                           [body appendData:cdbdcData];
                           //[body writeToFile:[args[2]stringByAppendingPathComponent:@"stow.data"] atomically:true];
                           
                           //create request
                           NSMutableURLRequest *request=
                           [NSMutableURLRequest requestWithURL:pacsURI];
                           [request setHTTPMethod:@"POST"];
                           [request setTimeoutInterval:300];
                           NSString *contentType = [NSString stringWithFormat:@"multipart/related;type=application/dicom;boundary=%@", boundaryString];
                           [request addValue:contentType forHTTPHeaderField:@"Content-Type"];
                           [request setHTTPBody:body];
                           
                           //send stow
                           NSHTTPURLResponse *stowResponse;
                           NSData *responseData=[NSURLConnection sendSynchronousRequest:request returningResponse:&stowResponse error:&error];
                           
                           NSLog(@"%@ %@ (%@/%@) [+%lu]",
                                 StudyInstanceUID,
                                 q[@"00080061"],
                                 q[@"00201206"],
                                 q[@"00201208"],
                                 (unsigned long)body.length
                                 );
                           
                           
                           if (  !responseData
                               ||!(
                                   ([stowResponse statusCode]==200)
                                   ||([stowResponse statusCode]==500)
                                   )
                               )
                           {
                               //incomplete acceptance or rejection
                              NSLog(@"\r\n-----------------\r\n%@\r\nstow response statusCode:%ld\r\n%@\r\n=================\r\n",
                                    pacsURI,
                                    (long)stowResponse .statusCode,
                                    [[NSString alloc]initWithData:responseData encoding:NSUTF8StringEncoding]
                                    );

                               //Failure
                                //=======
                                //400 - Bad Request (bad syntax)
                                //401 - Unauthorized
                                //403 - Forbidden (insufficient priviledges)
                                //409 - Conflict (formed correctly - system unable to store due to a conclict in the request
                                //(e.g., unsupported SOP Class or StudyInstance UID mismatch)
                                //additional information can be found in teh xml response body
                                //415 - unsopported media type (e.g. not supporting JSON)
                                //500 (instance already exists in db - delete file)
                                //503 - Busy (out of resource)
                                
                                //Warning
                                //=======
                                //202 - Accepted (stored some - not all)
                                //additional information can be found in teh xml response body
                                
                                //Success
                                //=======
                                //200 - OK (successfully stored all the instances)
                                
                            
                               for (NSString *fp in packaged)
                               {
                                   [fileManager moveItemAtPath:fp toPath:[REJECTEDpath stringByAppendingPathComponent:[fp lastPathComponent]] error:&error];
                               }
                           }
                           else
                           {
                               //full acceptance
                               for (NSString *fp in packaged)
                               {
                                   [fileManager moveItemAtPath:fp toPath:[STOWEDpath stringByAppendingPathComponent:[fp lastPathComponent]] error:&error];
                               }
                               //NSDictionary *q=[NSDictionary studyAttributesForQidoURL:qidoRequestURL];
                           }
                           [body setData:[NSData data]];
                           [packaged removeAllObjects];
                       }
                       
                   }
                   if(![[fileManager contentsOfDirectoryAtPath:STUDYpath error:&error]count])
                   [fileManager removeItemAtPath:STUDYpath error:&error];
                   
                   if(![[fileManager contentsOfDirectoryAtPath:COERCEDpath error:&error]count])
                   [fileManager removeItemAtPath:COERCEDpath error:&error];

                   if(![[fileManager contentsOfDirectoryAtPath:DISCARDEDpath error:&error]count])[fileManager removeItemAtPath:DISCARDEDpath error:&error];

                   if(![[fileManager contentsOfDirectoryAtPath:ORIGINALSpath error:&error]count])[fileManager removeItemAtPath:ORIGINALSpath error:&error];

                   if(![[fileManager contentsOfDirectoryAtPath:REJECTEDpath error:&error]count])[fileManager removeItemAtPath:REJECTEDpath error:&error];

                   if(![[fileManager contentsOfDirectoryAtPath:STOWEDpath error:&error]count])[fileManager removeItemAtPath:STOWEDpath error:&error];
                }
#pragma mark end try study
                @catch (NSException *exception) {
                   NSLog(@"%@", exception.reason);
                }
                @finally {
                   NSLog(@"Finally condition");
                }
            }
        }
    }
    return 0;
}


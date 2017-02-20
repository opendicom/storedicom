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
 */

/*
 Source code and binaries are subject to the terms of the Mozilla Public License, v. 2.0.
 If a copy of the MPL was not distributed with this file, You can obtain one at
 http://mozilla.org/MPL/2.0/
 
 Covered Software is provided under this License on an “as is” basis, without warranty of
 any kind, either expressed, implied, or statutory, including, without limitation,
 warranties that the Covered Software is free of defects, merchantable, fit for a particular
 purpose or non-infringing. The entire risk as to the quality and performance of the Covered
 Software is with You. Should any Covered Software prove defective in any respect, You (not
 any Contributor) assume the cost of any necessary servicing, repair, or correction. This
 disclaimer of warranty constitutes an essential part of this License. No use of any Covered
 Software is authorized under this License except under this disclaimer.
 
 Under no circumstances and under no legal theory, whether tort (including negligence),
 contract, or otherwise, shall any Contributor, or anyone who distributes Covered Software
 as permitted above, be liable to You for any direct, indirect, special, incidental, or
 consequential damages of any character including, without limitation, damages for lost
 profits, loss of goodwill, work stoppage, computer failure or malfunction, or any and all
 other commercial damages or losses, even if such party shall have been informed of the
 possibility of such damages. This limitation of liability shall not apply to liability for
 death or personal injury resulting from such party’s negligence to the extent applicable
 law prohibits such limitation. Some jurisdictions do not allow the exclusion or limitation
 of incidental or consequential damages, so this exclusion and limitation may not apply to
 You.
 */
#include "J2KR(noCodec).h"
//#import "sys/xattr.h"

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
int main(int argc, const char * argv[])
{
    @autoreleasepool {
        unsigned short dashDash = 0x2D2D;
        NSData *dashDashData =[NSData dataWithBytes:&dashDash length:2];
        
        unsigned short crlf = 0x0A0D;
        NSData *crlfData =[NSData dataWithBytes:&crlf length:2];
        
        //we create a new boundary for each stow and check that the boundary doesn´t match any data within DICOM FILES
        
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
        
        DJEncoderRegistration::registerCodecs(
                                              ECC_lossyRGB,
                                              EUC_never,
                                              OFFalse,
                                              OFFalse,
                                              0,
                                              0,
                                              0,
                                              OFTrue,
                                              ESS_444,
                                              OFFalse,
                                              OFFalse,
                                              0,
                                              0,
                                              0.0,
                                              0.0,
                                              0,
                                              0,
                                              0,
                                              0,
                                              OFTrue,
                                              OFTrue,
                                              OFFalse,
                                              OFFalse,
                                              OFTrue);
        

#pragma mark args
        /*
         [0] "/Users/Shared/stow/stow",
         [1] path to institutionMapping.plist
         [2] path to the root folder
         [3] url string del PACS "http://192.168.0.7:8080/dcm4chee-arc/aets/%@/rs/studies"
         */
        NSArray *args=[[NSProcessInfo processInfo] arguments];
        NSDictionary *institutionMapping=nil;
        institutionMapping=[NSDictionary dictionaryWithContentsOfFile:args[1]];
        NSLog(@"%@",[institutionMapping description]);
        
#pragma mark loop CLASSIFIED
        
        NSFileManager *fileManager=[NSFileManager defaultManager];
        NSString *CLASSIFIED=[args[2] stringByAppendingPathComponent:@"CLASSIFIED"];
        NSString *DISCARDED=[args[2] stringByAppendingPathComponent:@"DISCARDED"];
        NSString *ORIGINALS=[args[2] stringByAppendingPathComponent:@"ORIGINALS"];
        NSString *COERCED=[args[2] stringByAppendingPathComponent:@"COERCED"];
        NSString *REJECTED=[args[2] stringByAppendingPathComponent:@"REJECTED"];
        NSString *STOWED=[args[2] stringByAppendingPathComponent:@"STOWED"];

        NSArray *CLASSIFIEDarray=[fileManager contentsOfDirectoryAtPath:CLASSIFIED error:&error];
        for (NSString *CLASSIFIEDname in CLASSIFIEDarray)
        {
            if ([CLASSIFIEDname hasPrefix:@"."]) continue;
            NSString *CLASSIFIEDpath=[CLASSIFIED stringByAppendingPathComponent:CLASSIFIEDname];
            NSArray *properties=[CLASSIFIEDname componentsSeparatedByString:@"@"];
            
            
            NSString *institutionName=institutionMapping[properties[1]];
            if (!institutionName) institutionName=institutionMapping[properties[2]];
            NSLog(@"%@ -> %@",CLASSIFIEDname,institutionName);
            if (!institutionName)
            {
                NSLog(@"unknown aet and ip, moving folder to DISCARDED");
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
            
#pragma mark loop STUDIES
            for (NSString *StudyInstanceUID in [fileManager contentsOfDirectoryAtPath:CLASSIFIEDpath error:nil])
            {
                if ([StudyInstanceUID hasPrefix:@"."]) continue;

                NSString *STUDYpath=[CLASSIFIEDpath stringByAppendingPathComponent:StudyInstanceUID];

                NSMutableData *sqlResponseData=[NSMutableData data];
                if ([args count]>4) task(@"/bin/bash",@[@"-s"],[[NSString stringWithFormat:args[4],StudyInstanceUID] dataUsingEncoding:NSUTF8StringEncoding],sqlResponseData);
                NSString *sqlResponseString=[[NSString alloc]initWithData:sqlResponseData encoding:NSUTF8StringEncoding];
                if (([sqlResponseData length]>0) && ![sqlResponseString hasPrefix:institutionName])
                {
                    //StudyIUID already registered in other institution
                    NSLog(@"%@",sqlResponseString);
                    
                    NSString *DISCARDEDpath=[[DISCARDED stringByAppendingPathComponent:CLASSIFIEDname]stringByAppendingPathComponent:StudyInstanceUID];
                    [fileManager createDirectoryAtPath:DISCARDEDpath withIntermediateDirectories:YES attributes:nil error:&error];
                    [fileManager moveItemAtPath:STUDYpath toPath:DISCARDEDpath  error:&error];
                    continue;
                }
                return 0;
                
                NSURL *pacsURI=[NSURL URLWithString:[NSString stringWithFormat:@"%@/%@",pacsURIString,StudyInstanceUID]];
                NSString *qidoRequest=[NSString stringWithFormat:@"%@?StudyInstanceUID=%@",pacsURIString,StudyInstanceUID];
                
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
                    
                    [body appendData:cdbcData];
                    [body appendData:ctadData];
                    
                    NSString *filePath=[STUDYpath stringByAppendingPathComponent:SOPIUIDarray[i]];
                    
                    DcmFileFormat fileformat;
                    OFCondition cond = fileformat.loadFile( [filePath UTF8String]);
                    DcmDataset *dataset = fileformat.getDataset();
                    DcmXfer original_xfer(dataset->getOriginalXfer());
                    BOOL mayJ2KR=false;
                    if (!original_xfer.isEncapsulated())
                    {
                        DJ_RPLossy JP2KParamsLossLess(0 );//DCMLosslessQuality
                        DcmRepresentationParameter *params = &JP2KParamsLossLess;
                        DcmXfer oxferSyn( EXS_JPEG2000LosslessOnly);
                        dataset->chooseRepresentation(EXS_JPEG2000LosslessOnly, params);
                        if (dataset->canWriteXfer(EXS_JPEG2000LosslessOnly)) mayJ2KR=true;
                        else NSLog(@"cannot J2KR: %@)",filePath);
                    }
                    fileformat.loadAllDataIntoMemory();
                    
        #pragma mark metadata adjustments for all files
                    
                    // 00081060=-^-^- NameofPhysiciansReadingStudy
                    delete dataset->remove( DcmTagKey( 0x0008, 0x1060));
                    dataset->putAndInsertString( DcmTagKey( 0x0008, 0x1060),[@"-^-^-" cStringUsingEncoding:NSASCIIStringEncoding] );
                    
                    // 00200010=29991231235959
                    delete dataset->remove( DcmTagKey( 0x0020, 0x0010));
                    dataset->putAndInsertString( DcmTagKey( 0x0020, 0x0010),[@"29991231235959" cStringUsingEncoding:NSASCIIStringEncoding] );
                    
                    // 00080090=-^-^-^-
                    delete dataset->remove( DcmTagKey( 0x0008, 0x0090));
                    dataset->putAndInsertString( DcmTagKey( 0x0008, 0x0090),[@"-^-^-^-" cStringUsingEncoding:NSASCIIStringEncoding] );
                    
                    //remove SQ reqService
                    delete dataset->remove( DcmTagKey( 0x0032, 0x1034));
                    
                    // "GEIIS" The problematic private group, containing a *always* JPEG compressed PixelData
                    delete dataset->remove( DcmTagKey( 0x0009, 0x1110));
                    
#pragma mark institutionName adjustments
                    delete dataset->remove( DcmTagKey( 0x0008, 0x0080));
                    dataset->putAndInsertString( DcmTagKey( 0x0008, 0x0080),[institutionName cStringUsingEncoding:NSASCIIStringEncoding] );
                    
                    
        #pragma mark compress and add to stream (revisar bien a que corresponde toda esta sintaxis!!!)
                    NSString *COERCEDfile=[COERCEDpath stringByAppendingPathComponent:SOPIUIDarray[i]];
                    if (
                        mayJ2KR
                        && (
                            (fileformat.saveFile(
                                                 [COERCEDfile UTF8String],
                                                 EXS_JPEG2000LosslessOnly
                                                 )
                             ).good()
                            )
                        )
                    {
                        [body appendData:[NSData dataWithContentsOfFile:COERCEDfile]];
                        [packaged addObject:COERCEDfile];
                        [fileManager moveItemAtPath:filePath toPath:[ORIGINALSpath stringByAppendingPathComponent:SOPIUIDarray[i]] error:&error];
                    }
                    else if (
                             (fileformat.saveFile(
                                                  [COERCEDfile UTF8String],
                                                  original_xfer.getXfer()
                                                  )
                              ).good()
                             )
                    {
                        [body appendData:[NSData dataWithContentsOfFile:COERCEDfile]];
                        [packaged addObject:COERCEDfile];
                        [fileManager moveItemAtPath:filePath toPath:[ORIGINALSpath stringByAppendingPathComponent:SOPIUIDarray[i]] error:&error];
                    }
                    else
                    {
                        //no fue posible la coerción ni en J2KR ni en ELE
                        //no se manda al PACS
                        //se traslada el original a DISCARDED
                        [fileManager moveItemAtPath:filePath toPath:[DISCARDEDpath stringByAppendingPathComponent:SOPIUIDarray[i]] error:&error];
                    }
                    
                    
        #pragma mark send stow
                    if (([body length] > 10000000) || (i==SOPIUIDCount-1))
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
                        NSHTTPURLResponse *response;
                                                NSData *responseData=[NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
                     
                        if (  !responseData
                            ||!(
                                ([response statusCode]==200)
                                ||([response statusCode]==500)
                                )
                            )
                        {
                            NSLog(@"%@",[response description]);
                            //NSLog(@"%@",[[NSString alloc]initWithData:responseData encoding:NSUTF8StringEncoding]);

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
                            //NSLog(@"sent: %d bytes",[body length]);
                            for (NSString *fp in packaged)
                            {
                                [fileManager moveItemAtPath:fp toPath:[STOWEDpath stringByAppendingPathComponent:[fp lastPathComponent]] error:&error];
                            }
                            NSLog(@"%@",qidoRequest);
                            
                     
                            NSData *qidoResponse=[NSData dataWithContentsOfURL:[NSURL URLWithString:qidoRequest]];
                            if (!qidoResponse) NSLog(@"status:%d  -  could not verify pacs reception",[response statusCode] );
                            else
                            {
                                NSDictionary *d=[NSJSONSerialization JSONObjectWithData:qidoResponse options:0 error:&error][0];
                                
                                //NSLog(@"%@",[d description]);
                                NSLog(@"%@ %@ (%@/%@) [+%d]",
                                      ((d[@"00080061"])[@"Value"])[0],
                                      StudyInstanceUID,
                                      ((d[@"00201206"])[@"Value"])[0],
                                      ((d[@"00201208"])[@"Value"])[0],
                                      [body length]
                                      );
                            }
                        }
                        [body setData:[NSData data]];
                        [packaged removeAllObjects];
                    }
                    
                }
                if([[fileManager contentsOfDirectoryAtPath:STUDYpath error:&error]count]==0)[fileManager removeItemAtPath:STUDYpath error:&error];
                
                if([[fileManager contentsOfDirectoryAtPath:COERCEDpath error:&error]count]==0)[fileManager removeItemAtPath:COERCEDpath error:&error];

                if([[fileManager contentsOfDirectoryAtPath:DISCARDEDpath error:&error]count]==0)[fileManager removeItemAtPath:DISCARDEDpath error:&error];

                if([[fileManager contentsOfDirectoryAtPath:ORIGINALSpath error:&error]count]==0)[fileManager removeItemAtPath:ORIGINALSpath error:&error];

                if([[fileManager contentsOfDirectoryAtPath:REJECTEDpath error:&error]count]==0)[fileManager removeItemAtPath:REJECTEDpath error:&error];

                if([[fileManager contentsOfDirectoryAtPath:STOWEDpath error:&error]count]==0)[fileManager removeItemAtPath:STOWEDpath error:&error];
            }
        }
    }
    return 0;
}


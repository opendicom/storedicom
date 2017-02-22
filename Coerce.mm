#include "Coerce.h"

#include "sys/xattr.h"
#include "sys/types.h"

const char* tsColor[] = {
    "(\"none\n0\")",//White
    "(\"tsel\n1\")",//Gray
    "(\"j2kr\n2\")",//Green
    "(\"ecdc\n3\")",//Purple
    "(\"xreq\n4\")",//Blue
    "(\"xdsc\n5\")",//Yellow
    "(\"tsno\n6\")",//Red
    "(\"hpdf\n7\")" //Orange
};
enum TS { none,tsel,j2kr,ecdc,xreq,xdsc,tsno,hpdf };


BOOL setTS(NSString *path,int ts)
{
    return (-1!=setxattr([path fileSystemRepresentation], "com.apple.metadata:_kMDItemUserTags", tsColor[ts] , 10, 0, 0));
}

@implementation Coerce

+(void)registerCodecs
{
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

}

+(NSString*)coerceFileAtPath:(NSString*)srcPath toPath:(NSString*)dstPath withInstitutionName:(NSString*)InstitutionName
{
    //return nil o mensaje de error
    DcmFileFormat fileformat;
    if (fileformat.loadFile( [srcPath UTF8String]).bad()) return [@"can not load: " stringByAppendingString:srcPath];

    DcmDataset *dataset = fileformat.getDataset();

    
    const char* sopclass;
    NSString *sopclassstring=nil;
    if (dataset->findAndGetString(DCM_SOPClassUID, sopclass ).good()) sopclassstring=[NSString stringWithCString:sopclass encoding:NSASCIIStringEncoding];

    DcmXfer original_xfer(dataset->getOriginalXfer());
    switch (original_xfer.getXfer()) {
        case EXS_LittleEndianImplicit:
        case EXS_BigEndianExplicit:
            setTS(srcPath,tsno);
            return [@"not explicit little endian: " stringByAppendingString:srcPath];
        case EXS_LittleEndianExplicit:
            //discriminate por SOPClass  (xreq xdsc) hpdf tsel
            if ([sopclassstring isEqualToString:@"1.2.840.10008.5.1.4.1.1.104.2"]) setTS(srcPath,xdsc);
            else if ([sopclassstring isEqualToString:@"1.2.840.10008.5.1.4.1.1.104.1"]) setTS(srcPath,hpdf);
            else setTS(srcPath,tsel);
            break;
        case EXS_JPEG2000LosslessOnly:
            setTS(srcPath,j2kr);
            break;
        default:
            setTS(srcPath,ecdc);
            return [@"encapsulated not j2kr: " stringByAppendingString:srcPath];
    }
    
    
    BOOL mayJ2KR=false;
    if (!original_xfer.isEncapsulated())
    {
        DJ_RPLossy JP2KParamsLossLess(0 );//DCMLosslessQuality
        DcmRepresentationParameter *params = &JP2KParamsLossLess;
        DcmXfer oxferSyn( EXS_JPEG2000LosslessOnly);
        dataset->chooseRepresentation(EXS_JPEG2000LosslessOnly, params);
        if (dataset->canWriteXfer(EXS_JPEG2000LosslessOnly)) mayJ2KR=true;
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
    if (InstitutionName)
    {
        delete dataset->remove( DcmTagKey( 0x0008, 0x0080));
        dataset->putAndInsertString( DcmTagKey( 0x0008, 0x0080),[InstitutionName cStringUsingEncoding:NSASCIIStringEncoding] );
    }
    
#pragma mark compress and add to stream (revisar bien a que corresponde toda esta sintaxis!!!)
    if (mayJ2KR)
    {
        if (fileformat.saveFile([dstPath UTF8String],EXS_JPEG2000LosslessOnly).good()) return nil;
        return [@"can not save coerced J2KR to: " stringByAppendingString:dstPath];
    }
    if ((fileformat.saveFile([dstPath UTF8String],EXS_LittleEndianExplicit)).good()) return nil;
    return [@"can not save coerced to: " stringByAppendingString:dstPath];
}

@end

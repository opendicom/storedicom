#include "J2KR.h"

@implementation J2KR

+(void)register
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

+(BOOL)coerceFileAtPath:(NSString*)srcPath toPath:(NSString*)dstPath withInstitutionName:(NSString*)InstitutionName
{
    DcmFileFormat fileformat;
    if (fileformat.loadFile( [srcPath UTF8String]).bad()) return false;
    
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
    if (mayJ2KR && ((fileformat.saveFile([dstPath UTF8String],EXS_JPEG2000LosslessOnly)).good())) return true;
    if ((fileformat.saveFile([dstPath UTF8String],EXS_LittleEndianExplicit)).good()) return true;
    return false;
}

@end

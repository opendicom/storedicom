# storestow
storescp>stow

This executable is a complement to dcmtk storescp which forwards the files received using dcm4chee-arc-light DICOMweb stow API.

dcmtk storescp launchd should be set somehow like that (secure connection parameters may be added):
```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>Label</key>
<string>org.dcmtk.storescp.wfmFIR.plist</string>
<key>EnvironmentVariables</key>
<dict>
<key>DCMDICTPATH</key>
<string>/Users/Shared/storescp/dicom.dic</string>
</dict>
<key>StandardOutPath</key>
<string>/Users/Shared/storescp/wfmFIR.log</string>
<key>StandardErrorPath</key>
<string>/Users/Shared/storescp/wfmFIR.log</string>
<key>ProgramArguments</key>
<array>
<string>/Users/Shared/storescp/storescp</string>
<string>-ll</string>
<string>warn</string>
<string>--fork</string>
<string>-pm</string>
<string>+xa</string>
<string>-aet</string>
<string>wfmFIR</string>
<string>-pdu</string>
<string>131072</string>
<string>-dhl</string>
<string>-up</string>
<string>-od</string>
<string>/Volumes/IN/wfmFIR/ARRIVED/</string>
<string>-su</string>
<string></string>
<string>-uf</string>
<string>-xcr</string>
<string>/Users/Shared/storescp/classifier.sh #a #r #p #f</string>
<string>104</string>
</array>
<key>KeepAlive</key>
<true/>
<key>Umask</key>
<string>0</string>
</dict>
</plist>
```

The -su parameter indicates that the study folder is named after the StudyInstanceUID
The -xcs parameter triggers stow with the following parameters:

1. calling aet
2. calling ip
3. path to the study folder
4. url of dcm4chee-arc-light stow (%@ shall be replaced by calling aet)
5. institutionMapping.plist

Operation logs are visible from console.app and also spotlight searchable within the spool folder (user tags and spotlight comments are automatically generated).

##Metadata coercion

* 00081060=-^-^- (NameOfPhysiciansReadingStudy)
* 00200010=29991231235959 (StudyId)
* 00080090=-^-^-^- (RequestingPhysician)
* 00321034 removed (RequestingService
* 00091110 removed ("GEIIS", problematic private group containing JPEG compressed PixelData

These coercions are performed so that the corresponding fields values don´t remain NULL in the PACS database.

## ->J2KR

When received as explicit little endian and is possible, the file is encoded J2KR before being stowed. Pixel data length and md5 before compression are kept in the metadata for eventual auditing.

## InstitutionName

May be coerced based on calling AET or calling IP. A Plist dictionary contains the mapping.


//
//  ODLog.m
//  httpdicom
//
//  Created by jacquesfauquex on 20180113.
//  Copyright © 2018 opendicom.com. All rights reserved.
//

#import "ODLog.h"
#include <time.h>

ODLogLevelEnum ODLogLevel = ODLogLevel_Info;

static const char* levelNames[] = {"D", "V", "I", "W", "E", "X"};

/*{
 "DEBUG",       request and response data
 "VERBOSE",     request URL
 "INFO",        response OK
 "WARNING",     response KO
 "ERROR",
 "EXCEPTION"
 }*/

void ODLog(ODLogLevelEnum level, NSString* format, ...) {
    
    time_t current_time;
    current_time = time(NULL);

    struct tm tm;
    tm = *localtime(&current_time); // convert time_t to struct tm
    
    char dt[7]; // space enough for DD/MM/YYYY HH:MM:SS and terminator
    strftime(dt, sizeof dt, "%H%M%S", &tm); // format
    
    va_list arguments;
    va_start(arguments, format);
    NSString* message = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    fprintf(stderr, "%s [%s] %s\n", dt, levelNames[level], [message UTF8String]);
}

//dcmtk target useless main
#include "J2KR(noCodec).h"
int main(int argc, const char *argv[])
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSLog(@"no codec J2KR");
    [pool release];
    return 0;
}
